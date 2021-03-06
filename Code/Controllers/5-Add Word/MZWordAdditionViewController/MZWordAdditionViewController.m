//
//  MZWordAdditionViewController.m
//  Memz
//
//  Created by Bastien Falcou on 12/16/15.
//  Copyright © 2015 Falcou. All rights reserved.
//

#import "MZWordAdditionViewController.h"
#import "UIViewController+MemzAdditions.h"
#import "MZWordAdditionTableViewHeader.h"
#import "MZTextFieldTableViewCell.h"
#import "MZTranslatedWordTableViewCell.h"
#import "MZAutoCompletionTableViewCell.h"
#import "MZSuggestedWordTableViewCell.h"
#import "NSManagedObject+MemzCoreData.h"
#import "MZBingTranslatorCoordinator.h"
#import "MZWord+CoreDataProperties.h"
#import "UIScrollView+KeyboardHelper.h"
#import "MZWordAdditionViewHeader.h"
#import "NSArray+MemzAdditions.h"
#import "UIView+MemzAdditions.h"
#import "MZDataManager.h"
#import "MZTableView.h"

typedef NS_ENUM(NSInteger, MZWordAdditionWordRowType) {
	MZWordAdditionWordRowTypeNewWord,
	MZWordAdditionWordRowTypeAlreadyExisting
};

NSString * const kWordAdditionTableViewHeaderIdentifier = @"MZWordAdditionTableViewHeaderIdentifier";
NSString * const kTextFieldTableViewCellIdentifier = @"MZTextFieldTableViewCellIdentifier";
NSString * const kAutoCompletionTableViewCellIdentifier = @"MZAutoCompletionTableViewCellIdentifier";
NSString * const kTranslatedWordTableViewCellIdentifier = @"MZTranslatedWordTableViewCellIdentifier";
NSString * const kSuggestedWordTableViewCellIdentifier = @"MZSuggestedWordTableViewCellIdentifier";

NSString * const kSectionTypeKey = @"SectionTypeKey";
NSString * const kWordRowTypeKey = @"WordRowTypeKey";
NSString * const kContentTypeKey = @"ContentTypeKey";

const CGFloat kTableViewSectionHeaderHeight = 45.0f;
const CGFloat kWordAdditionTableViewEstimatedRowHeight = 100.0f;

@interface MZWordAdditionViewController () <UITableViewDataSource,
UITableViewDelegate,
MZTextFieldTableViewCellDelegate,
MZTranslatedWordTableViewCellDelegate,
MZWordAdditionTableViewHeaderDelegate,
MZWordAdditionViewHeaderProtocol>

@property (nonatomic, strong) IBOutlet MZTableView *tableView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *tableViewTopConstraint;
@property (nonatomic, strong) IBOutlet MZWordAdditionViewHeader *tableHeaderView;

@property (nonatomic, weak, readonly) NSArray<NSDictionary *> *tableViewData;

@property (nonatomic, strong) NSString *wordToTranslate;
@property (nonatomic, strong) NSMutableOrderedSet<MZWord *> *alreadyExistingWords;
@property (nonatomic, strong) NSMutableArray<NSString *> *wordTranslations;
@property (nonatomic, strong) NSMutableArray<NSString *> *wordSuggestions;

@end

@implementation MZWordAdditionViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = NSLocalizedString(@"WordAdditionViewControllerTitle", nil);
	self.navigationController.navigationBarHidden = YES;
	
	self.wordTranslations = [[NSMutableArray alloc] init];
	self.alreadyExistingWords = [[NSMutableOrderedSet alloc] init];

	[self configureTapEndEditing];

	// (1) Disable iterative transition when editing
	[[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification
																										object:nil
																										 queue:[NSOperationQueue mainQueue]
																								usingBlock:
	 ^(NSNotification *notification) {
		 self.tableView.backgroundColor = self.tableView.progressiveBackgroundColor;
		 self.tableView.transitionDelegate = nil;
	 }];

	// (2) Re-enable iterative transition when end editing
	[[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification
																										object:nil
																										 queue:[NSOperationQueue mainQueue]
																								usingBlock:
	 ^(NSNotification *notification) {
		 self.tableView.backgroundColor = [UIColor clearColor];
		 self.tableView.transitionDelegate = self;
	}];

	[self setupTableView];
	[self.tableView reloadData];

	[[MZAnalyticsManager sharedManager] trackScreen:MZAnalyticsScreenWordAddition];
}

#pragma mark - Setups

- (void)setupTableView {
	self.tableView.estimatedRowHeight = kWordAdditionTableViewEstimatedRowHeight;
	self.tableView.rowHeight = UITableViewAutomaticDimension;

	[self.tableView handleKeyboardNotifications];

	[self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([MZWordAdditionTableViewHeader class]) bundle:nil] forHeaderFooterViewReuseIdentifier:kWordAdditionTableViewHeaderIdentifier];
}

#pragma mark - Data Management Calculated Property

- (NSArray *)tableViewData {
	NSMutableArray *mutableArray = [[NSMutableArray alloc] init];

	// Section (1)
	[mutableArray addObject:@{kSectionTypeKey: @(MZWordAdditionSectionTypeWord),
														kContentTypeKey: [[NSMutableArray alloc] init]}];

	NSMutableArray *firstSectionContentMutableArray = [mutableArray[MZWordAdditionSectionTypeWord][kContentTypeKey] safeCastToClass:[NSMutableArray class]];

	[firstSectionContentMutableArray addObject:@{kWordRowTypeKey: @(MZWordAdditionWordRowTypeNewWord),
																							 kContentTypeKey: self.wordToTranslate ?: @""}];

	for (MZWord *word in self.alreadyExistingWords) {
		[firstSectionContentMutableArray addObject:@{kWordRowTypeKey: @(MZWordAdditionWordRowTypeAlreadyExisting),
																								 kContentTypeKey: word}];
	}

	// Section (2)
	if (self.wordSuggestions.count) {
		[mutableArray addObject:@{kSectionTypeKey: @(MZWordAdditionSectionTypeSuggestions),
															kContentTypeKey: self.wordSuggestions}];
	}

	// Section (3)
	[mutableArray addObject:@{kSectionTypeKey: @(MZWordAdditionSectionTypeManual),
														kContentTypeKey: @[@""]}];

	// Section (4)
	if (self.wordTranslations.count) {
		[mutableArray addObject:@{kSectionTypeKey: @(MZWordAdditionSectionTypeTranslations),
															kContentTypeKey: self.wordTranslations}];
	}

	return mutableArray;
}

#pragma mark - Table View Data Source & Delegate Methods

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return kTableViewSectionHeaderHeight;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.tableViewData.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  MZWordAdditionTableViewHeader *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kWordAdditionTableViewHeaderIdentifier];
	headerView.sectionType = [self.tableViewData[section][kSectionTypeKey] integerValue] ;
	headerView.backgroundColor = [UIColor mainMediumGrayColor];
	headerView.delegate = self;
	return headerView;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.tableViewData[section][kContentTypeKey] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch ([self.tableViewData[indexPath.section][kSectionTypeKey] integerValue]) {

		case MZWordAdditionSectionTypeWord: {
			switch ([self.tableViewData[indexPath.section][kContentTypeKey][indexPath.row][kWordRowTypeKey] integerValue]) {
				case MZWordAdditionWordRowTypeNewWord: {
					MZTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTextFieldTableViewCellIdentifier
																																					 forIndexPath:indexPath];
					cell.textField.text = self.wordToTranslate;
					cell.cellType = MZTextFieldTableViewCellTypeRegular;
					cell.language = [MZUser currentUser].newLanguage.integerValue;
					cell.delegate = self;
					return cell;
				}

				case MZWordAdditionWordRowTypeAlreadyExisting: {
					MZAutoCompletionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAutoCompletionTableViewCellIdentifier
																																								forIndexPath:indexPath];
					MZWord *word = [self.tableViewData[indexPath.section][kContentTypeKey][indexPath.row][kContentTypeKey] safeCastToClass:[MZWord class]];
					cell.wordLabel.text = word.word;
					return cell;
				}
			}

		case MZWordAdditionSectionTypeSuggestions: {
			MZSuggestedWordTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSuggestedWordTableViewCellIdentifier
																																					 forIndexPath:indexPath];
			cell.suggestedWordLabel.text = self.wordSuggestions[indexPath.row];
			cell.language = [MZUser currentUser].knownLanguage.integerValue;
			return cell;
		}

		case MZWordAdditionSectionTypeManual: {
			MZTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTextFieldTableViewCellIdentifier
																																			 forIndexPath:indexPath];
			cell.language = [MZUser currentUser].knownLanguage.integerValue;
			cell.cellType = MZTextFieldTableViewCellTypeAddition;
			cell.delegate = self;
			return cell;
		}

		case MZWordAdditionSectionTypeTranslations: {
			MZTranslatedWordTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTranslatedWordTableViewCellIdentifier
																																						forIndexPath:indexPath];
			cell.translatedWordLabel.text = self.wordTranslations[indexPath.row];
			cell.language = [MZUser currentUser].knownLanguage.integerValue;
			cell.delegate = self;
			return cell;
		}

		default:
			return nil;
		}
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self.view endEditing:YES];
	switch ([self.tableViewData[indexPath.section][kSectionTypeKey] integerValue]) {

		case MZWordAdditionSectionTypeWord: {
			if ([self.tableViewData[indexPath.section][kContentTypeKey][indexPath.row][kWordRowTypeKey] integerValue] == MZWordAdditionWordRowTypeAlreadyExisting) {
				[self setupWithWord:self.alreadyExistingWords[indexPath.row - 1]];  // first cell is word to translate
			}
			break;
		}

		case MZWordAdditionSectionTypeSuggestions: {
			NSString *word = self.wordSuggestions[indexPath.row];
			[self addTranslations:word];

			[self.wordSuggestions removeObjectAtIndex:indexPath.row];
			if (self.wordSuggestions.count > 0) {
				[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
			} else {
				[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:MZWordAdditionSectionTypeSuggestions]
											withRowAnimation:UITableViewRowAnimationFade];
			}
			break;
		}

		default:
			return;
	}
}

#pragma mark - Text Field Cells Delegate Methods

- (void)textFieldTableViewCellDidTapAddButton:(MZTextFieldTableViewCell *)cell {
	// TODO: Check if valid

	[self addTranslations:cell.textField.text];
	cell.textField.text = @"";
}

- (void)textFieldTableViewCell:(MZTextFieldTableViewCell *)cell textDidChange:(NSString *)text {
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	if (indexPath.section == MZWordAdditionSectionTypeWord && indexPath.row == MZWordAdditionWordRowTypeNewWord) {
		// (1) Update current word to translate
		self.wordToTranslate = text;

		// (2) If word matches an existing one, update and populate table view with its existing tranlations
		if ([text.lowercaseString isEqualToString:self.alreadyExistingWords.firstObject.word.lowercaseString]) {
			[self setupWithWord:self.alreadyExistingWords.firstObject];
			return;
		}

		// (3) Remove current translations if word is ammended
		[self removeTranslationsAnimated:YES];

		// (4) Update existing word suggestions and translation suggestions
		[self updateExistingWords];
		[self updateSuggestedTranslations];
	}
}

- (void)textFieldTableViewCellDidHitReturnKey:(MZTextFieldTableViewCell *)cell {
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	if (cell.textField.text.length == 0 || indexPath.section == MZWordAdditionSectionTypeWord) {
		[self.view endEditing:YES];
		return;
	}

	// TODO: Check if valid

	[self addTranslations:cell.textField.text];
	cell.textField.text = @"";
}

#pragma mark - Updates Upon Text Change

- (void)updateExistingWords {
	NSOrderedSet<MZWord *> *newAlreadyExistingWords = [MZWord existingWordsForLanguage:[MZUser currentUser].newLanguage.integerValue
																																		startingByString:self.wordToTranslate
																																					 inContext:nil];

	if (newAlreadyExistingWords.count > self.alreadyExistingWords.count) {
		// (1) Case existing words to insert
		NSMutableOrderedSet<MZWord *> *wordsToInsert = [newAlreadyExistingWords mutableCopy];
		[wordsToInsert minusOrderedSet:self.alreadyExistingWords];

		for (MZWord *wordToInsert in wordsToInsert) {
			[self.alreadyExistingWords addObject:wordToInsert];
			[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:[self.alreadyExistingWords indexOfObject:wordToInsert] + 1	// First row is TextField
																																	inSection:MZWordAdditionSectionTypeWord]]
														withRowAnimation:UITableViewRowAnimationFade];
		}
	} else {
		// (2) Case previously suggested existing words to remove
		NSMutableOrderedSet<MZWord *> *wordsToDelete = [self.alreadyExistingWords mutableCopy];
		[wordsToDelete minusOrderedSet:newAlreadyExistingWords];

		for (MZWord *wordToDelete in wordsToDelete) {
			NSUInteger index = [self.alreadyExistingWords indexOfObject:wordToDelete] + 1;	// First row is TextField
			[self.alreadyExistingWords removeObject:wordToDelete];
			[self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index
																																	inSection:MZWordAdditionSectionTypeWord]]
														withRowAnimation:UITableViewRowAnimationFade];
		}
	}
}

- (void)updateSuggestedTranslations {
	[[MZBingTranslatorCoordinator sharedManager] translateString:self.wordToTranslate
																									fromLanguage:[MZUser currentUser].newLanguage.integerValue
																										toLanguage:[MZUser currentUser].knownLanguage.integerValue
																						 completionHandler:
	 ^(NSArray<NSString *> *translations, NSError *error) {
		 if (!error) {
			 dispatch_async(dispatch_get_main_queue(), ^{
				 // (1) Remove translations already entered by user
				 NSMutableSet *mutableSet = [NSMutableSet setWithArray:[translations allLowercaseStrings]];
				 [mutableSet minusSet:[NSSet setWithArray:[self.wordTranslations allLowercaseStrings]]];
				 NSArray<NSString *> *refinedTranslations = mutableSet.allObjects;

				 // (2) Delete section if needed
				 if (refinedTranslations.count == 0 && self.wordSuggestions.count > 0) {
					 self.wordSuggestions = refinedTranslations.mutableCopy;
					 [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:MZWordAdditionSectionTypeSuggestions]
												 withRowAnimation:UITableViewRowAnimationFade];
					 return;
				 }

				 // (3) Insert section if needed
				 if (self.wordSuggestions.count == 0 && refinedTranslations.count > 0) {
					 self.wordSuggestions = refinedTranslations.mutableCopy;
					 [self.tableView insertSections:[NSIndexSet indexSetWithIndex:MZWordAdditionSectionTypeSuggestions]
												 withRowAnimation:UITableViewRowAnimationFade];
					 return;
				 }

				 // (4) Otherwise, update currently displayed suggestion cells if applicable
				 for (NSInteger i = 0; i < refinedTranslations.count && i < self.wordSuggestions.count; i++) {
					 NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:MZWordAdditionSectionTypeSuggestions];
					 MZSuggestedWordTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
					 cell.suggestedWordLabel.text = refinedTranslations[i];
				 }

				 // (5) Update number of suggestion cells according to new needs
				 NSMutableArray<NSIndexPath *> *indexPathsToDelete = [[NSMutableArray alloc] init];
				 for (NSInteger i = refinedTranslations.count; i < self.wordSuggestions.count; i++) {
					 [indexPathsToDelete addObject:[NSIndexPath indexPathForItem:i inSection:MZWordAdditionSectionTypeSuggestions]];
				 }

				 NSMutableArray<NSIndexPath *> *indexPathsToInsert = [[NSMutableArray alloc] init];
				 for (NSInteger i = self.wordSuggestions.count; i < refinedTranslations.count; i++) {
					 [indexPathsToInsert addObject:[NSIndexPath indexPathForItem:i inSection:MZWordAdditionSectionTypeSuggestions]];
				 }

				 self.wordSuggestions = refinedTranslations.mutableCopy;
				 if (indexPathsToDelete.count > 0) {
					 [self.tableView deleteRowsAtIndexPaths:indexPathsToDelete withRowAnimation:UITableViewRowAnimationFade];
				 }
				 if (indexPathsToInsert.count > 0) {
					 [self.tableView insertRowsAtIndexPaths:indexPathsToInsert withRowAnimation:UITableViewRowAnimationFade];
				 }
			 });
		 }
	 }];
}

#pragma mark - Updates Upon Actions

- (void)setupWithWord:(MZWord *)word {
	// (1) Update current word
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:MZWordAdditionSectionTypeWord];
	MZTextFieldTableViewCell *wordToTranslateCell = [[self.tableView cellForRowAtIndexPath:indexPath]
																									 safeCastToClass:[MZTextFieldTableViewCell class]];
	wordToTranslateCell.textField.text = word.word;
	self.wordToTranslate = word.word;

	// (2) Remove current existing words suggested
	NSMutableArray *indexesToRemove = [[NSMutableArray alloc] init];
	for (NSUInteger i = 0; i < self.alreadyExistingWords.count; i++) {
		[indexesToRemove addObject:[NSIndexPath indexPathForItem:i + 1 inSection:MZWordAdditionSectionTypeWord]];
	}

	[self.alreadyExistingWords removeAllObjects];
	[self.tableView deleteRowsAtIndexPaths:indexesToRemove withRowAnimation:UITableViewRowAnimationFade];

	// (3) Update suggested translations
	[self updateSuggestedTranslations];

	// (4) Insert existing translations for already existing word chosen
	[self removeTranslationsAnimated:NO];
	for (MZWord *translation in word.translations) {
		[self.wordTranslations addObject:translation.word];
	}
	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:self.tableView.numberOfSections]
																							withRowAnimation:UITableViewRowAnimationFade];

	// (5) Update table view header
	[self updateViewHeaderEnabled];
}

- (void)addTranslations:(NSString *)translation {
	if ([self.wordTranslations containsObject:translation]) {
		// TODO: Show error
		return;
	}

	// (1) Add translation to internal array and update header
	[self.wordTranslations addObject:translation];
	[self updateViewHeaderEnabled];

	// (2) Add translation to table view
	if (self.wordTranslations.count == 1) {
		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:self.tableView.numberOfSections]
									withRowAnimation:UITableViewRowAnimationFade];
	} else {
		[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.wordTranslations.count - 1
																																inSection:self.tableView.numberOfSections - 1]]
													withRowAnimation:UITableViewRowAnimationFade];
	}
}

#pragma mark - Helpers

- (void)removeTranslationsAnimated:(BOOL)animated {
	if (self.wordTranslations.count > 0) {
		[self.wordTranslations removeAllObjects];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:self.tableView.numberOfSections - 1]
									withRowAnimation:animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone];
	}
}

- (void)removeSuggestionsAnimated:(BOOL)animated {
	if (self.wordSuggestions.count > 0) {
		self.wordSuggestions = [[NSMutableArray alloc] init];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:MZWordAdditionSectionTypeSuggestions]
									withRowAnimation:animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone];
	}
}

- (void)updateViewHeaderEnabled {
	BOOL isEnabled = self.wordToTranslate.length > 0 && self.wordTranslations.count > 0;
	self.tableHeaderView.enable = isEnabled;
}

#pragma mark - View Header Delegate

- (void)wordAdditionViewHeaderDidTapAddButton:(MZWordAdditionViewHeader *)header {
	// TODO: Test texts not empty, etc.
	// TODO: In edit mode, remove no longer needed translations

	[[MZUser currentUser] addWord:self.wordToTranslate translations:self.wordTranslations inContext:nil];

	[[MZAnalyticsManager sharedManager] trackWordAddition:self.wordToTranslate
																					 translations:self.wordTranslations
																					knownLanguage:[MZUser currentUser].knownLanguage.integerValue
																						newLanguage:[MZUser currentUser].newLanguage.integerValue];
	
	[[MZDataManager sharedDataManager] saveChanges];
	[self dismissViewControllerWithCompletion:nil];
}

#pragma mark - Table View Header Delegate

- (void)wordAdditionTableViewHeaderDidTapClearButton:(MZWordAdditionTableViewHeader *)tableViewHeader {
	[self removeTranslationsAnimated:YES];
	[self updateViewHeaderEnabled];
}

#pragma mark - Translated Word Cells Delegate Methods

- (void)translatedWordTableViewCellDidTapRemoveButton:(MZTranslatedWordTableViewCell *)cell {
	NSUInteger wordTranslationIndex = [self.wordTranslations indexOfObject:cell.translatedWordLabel.text];
	[self.wordTranslations removeObjectAtIndex:wordTranslationIndex];
	[self updateViewHeaderEnabled];

	if (self.wordTranslations.count == 0) {
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:self.tableView.numberOfSections - 1]
									withRowAnimation:UITableViewRowAnimationFade];
	} else {
		[self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:wordTranslationIndex
																																inSection:self.tableView.numberOfSections - 1]]
													withRowAnimation:UITableViewRowAnimationFade];
	}
}

@end
