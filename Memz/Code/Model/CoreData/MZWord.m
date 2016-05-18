//
//  MZWord.m
//  
//
//  Created by Bastien Falcou on 12/19/15.
//
//

#import "MZWord.h"
#import "NSManagedObject+MemzCoreData.h"
#import "MZDataManager.h"

@implementation MZWord

#pragma mark - Private Initializer

- (instancetype)initWithWord:(NSString *)word
									inLanguage:(MZLanguage)wordLanguage
								translations:(NSArray<NSString *> *)translations
									toLanguage:(MZLanguage)toLanguage
										 forUser:(MZUser *)user
									 inContext:(NSManagedObjectContext *)context {
	context = context ?: [MZDataManager sharedDataManager].managedObjectContext;

	MZWord *newWord = [MZWord newInstanceInContext:context];
	newWord.word = word;
	newWord.language = @(wordLanguage);
	if (user) {
		[newWord addUsersObject:user];
	}
	[newWord updateTranslations:translations inLanguage:toLanguage forUser:user inContext:context];
	return newWord;
}

#pragma mark - Public Methods

+ (MZWord *)addWord:(NSString *)word
				 inLanguage:(MZLanguage)wordLanguage
			 translations:(NSArray<NSString *> *)translations
				 toLanguage:(MZLanguage)toLanguage
						forUser:(MZUser *)user
					inContext:(NSManagedObjectContext *)context {
	context = context ?: [MZDataManager sharedDataManager].managedObjectContext;

	MZWord *existingWord = [MZWord existingWordForString:word inLanguage:wordLanguage inContext:context];

	if (!existingWord) {
		return [[MZWord alloc] initWithWord:word inLanguage:wordLanguage translations:translations toLanguage:toLanguage forUser:user inContext:context];
	} else {
		[existingWord updateTranslations:translations inLanguage:toLanguage forUser:user inContext:context];
		return existingWord;
	}
}

+ (NSOrderedSet<MZWord *> *)existingWordsForLanguage:(MZLanguage)language
																		startingByString:(NSString *)string
																					 inContext:(NSManagedObjectContext *)context {
	context = context ?: [MZDataManager sharedDataManager].managedObjectContext;

	NSPredicate *alreadyExistsPrecidate = [NSPredicate predicateWithFormat:@"(word BEGINSWITH[cd] %@) AND language = %d", string, language];
	return [NSOrderedSet orderedSetWithArray:[MZWord allObjectsMatchingPredicate:alreadyExistsPrecidate]];
}

+ (MZWord *)existingWordForString:(NSString *)string
											 inLanguage:(MZLanguage)language
												inContext:(NSManagedObjectContext *)context {
	context = context ?: [MZDataManager sharedDataManager].managedObjectContext;
	
	NSPredicate *alreadyExistsPrecidate = [NSPredicate predicateWithFormat:@"word CONTAINS[cd] %@ AND language = %d", string, language];
	return [MZWord allObjectsMatchingPredicate:alreadyExistsPrecidate context:context].firstObject;
}

- (void)updateTranslations:(NSArray<NSString *> *)translations
								inLanguage:(MZLanguage)language
									 forUser:(MZUser *)user
								 inContext:(NSManagedObjectContext *)context {
	// (1) Initialize context if not specified
	context = context ?: [MZDataManager sharedDataManager].managedObjectContext;

	// (2) Add new translations
	[translations enumerateObjectsUsingBlock:^(NSString *translation, NSUInteger idx, BOOL *stop) {
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"word ==[cd] %@ AND language = %d", translation, language];
		MZWord *wordTranslation = [MZWord allObjectsMatchingPredicate:predicate context:context].firstObject;

		if (!wordTranslation) {
			wordTranslation = [MZWord newInstanceInContext:context];
			wordTranslation.word = translation;
			wordTranslation.language = @(language);
		}

		[self addTranslationsObject:wordTranslation];
	}];

	// (3) Remove no longer needed translations
	[self.translations.mutableCopy enumerateObjectsUsingBlock:^(MZWord *translation, NSUInteger idx, BOOL *stop) {
		if (![translations containsObject:translation.word]) {
			[self removeTranslations:[NSSet setWithObject:translation]];

			if (translation.translations.count == 0) {
				[context deleteObject:translation];
			}
		}
	}];

	// (4) Set translation and reverse relationship user if exists
	if (user && ![user.translations containsObject:self]) {
		[user addTranslationsObject:self];
	}

	// (5) Remove word if no translations anymore
	// TODO: Actually perform deletion 
}

#pragma mark - Statistics

- (NSUInteger)numberTranslationsInLanguage:(MZLanguage)language {
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"word = %@ AND quiz.newLanguage = %ld AND quiz.isAnswered = true", self, language];
	return [MZResponse countOfObjectsMatchingPredicate:predicate];
}

- (CGFloat)percentageSuccessTranslationsInLanguage:(MZLanguage)language {
	NSPredicate *successCountPredicate = [NSPredicate predicateWithFormat:@"word = %@ AND result = true AND quiz.newLanguage = %ld AND quiz.isAnswered = true", self, language];
	NSPredicate *allObjectsCountPredicate = [NSPredicate predicateWithFormat:@"word = %@ AND quiz.newLanguage = %ld AND quiz.isAnswered = true", self, language];

	NSUInteger successCount = [MZResponse countOfObjectsMatchingPredicate:successCountPredicate];
	NSUInteger allObjectsCount = [MZResponse countOfObjectsMatchingPredicate:allObjectsCountPredicate];

	return allObjectsCount > 0 ? successCount * 100.0f / allObjectsCount : 0.0f;
}

@end
