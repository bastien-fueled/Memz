//
//  MZPollsViewController.m
//  Memz
//
//  Created by Bastien Falcou on 12/16/15.
//  Copyright © 2015 Falcou. All rights reserved.
//

#import "MZPollsViewController.h"

typedef NS_ENUM(NSInteger, MZScrollDirection) {
	MZScrollDirectionNone = 0,
	MZScrollDirectionDown,
	MZScrollDirectionUp
};

const CGFloat kTopShrinkableViewMinimumHeight = 40.0f;
const CGFloat kTopShrinkableViewMaximumHeight = 100.0f;

NSString * const kPollsTableViewCellIdentifier = @"MZPollsTableViewCellIdentifier";

@interface MZPollsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSArray *tableViewData;

@property (weak, nonatomic) IBOutlet UIView *topShrinkableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topShrinkableViewHeightConstraint;

@property (nonatomic, assign) CGPoint lastContentOffset;

@end

@implementation MZPollsViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	[self setupTableViewData];
	[self.tableView reloadData];

	self.tableView.contentInset = UIEdgeInsetsMake(kTopShrinkableViewMaximumHeight, 0.0f, 0.0f, 0.0f);
	self.tableView.contentOffset = CGPointMake(0.0f, -self.topShrinkableViewHeightConstraint.constant);
	self.tableView.tableFooterView = [[UIView alloc] init];
}

- (void)setupTableViewData {
	self.tableViewData = @[@{@"hey": @"test hey"},
												 @{@"hey2" : @"test hey 2"},
												 @{@"hey3" : @"test hey 3"},
												 @{@"hey4" : @"test hey 4"},
												 @{@"hey": @"test hey"},
												 @{@"hey2" : @"test hey 2"},
												 @{@"hey3" : @"test hey 3"},
												 @{@"hey4" : @"test hey 4"}];
}

#pragma mark - Table View DataSource & Delegate Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.tableViewData.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 100.0f; // TODO: Should be self sized here
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kPollsTableViewCellIdentifier
																													forIndexPath:indexPath];
	return cell;
}

#pragma mark - Scroll Management

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	MZScrollDirection scrollDirection = [self scrollDirectionForScrollView:scrollView];
	scrollView.contentInset = UIEdgeInsetsMake(self.topShrinkableViewHeightConstraint.constant,
																						 scrollView.contentInset.left,
																						 scrollView.contentInset.bottom,
																						 scrollView.contentInset.right);

	if (scrollView.contentOffset.y < -scrollView.contentInset.top
			|| scrollView.contentOffset.y > (scrollView.contentSize.height - scrollView.frame.size.height + scrollView.contentInset.bottom)) {
		// TODO: Second condition doesn't work if contentSize.height < scrollView.frame.size.height
		self.lastContentOffset = scrollView.contentOffset;
		return;
	}

	if (scrollDirection == MZScrollDirectionDown) {
		if (self.topShrinkableViewHeightConstraint.constant < kTopShrinkableViewMaximumHeight) {
			self.topShrinkableViewHeightConstraint.constant += self.lastContentOffset.y - scrollView.contentOffset.y;
		}
	}

	if (scrollDirection == MZScrollDirectionUp) {
		if (self.topShrinkableViewHeightConstraint.constant > kTopShrinkableViewMinimumHeight) {
			self.topShrinkableViewHeightConstraint.constant += self.lastContentOffset.y - scrollView.contentOffset.y;
		}
	}

	if (self.topShrinkableViewHeightConstraint.constant > kTopShrinkableViewMaximumHeight) {
		self.topShrinkableViewHeightConstraint.constant = kTopShrinkableViewMaximumHeight;
	} else if (self.topShrinkableViewHeightConstraint.constant < kTopShrinkableViewMinimumHeight) {
		self.topShrinkableViewHeightConstraint.constant = kTopShrinkableViewMinimumHeight;
	}
	self.lastContentOffset = scrollView.contentOffset;
}

- (MZScrollDirection)scrollDirectionForScrollView:(UIScrollView *)scrollView {
	if (self.lastContentOffset.y > scrollView.contentOffset.y) {
		return MZScrollDirectionDown;
	} else if (self.lastContentOffset.y < scrollView.contentOffset.y) {
		return MZScrollDirectionUp;
	} else {
		return MZScrollDirectionNone;
	}
}

@end
