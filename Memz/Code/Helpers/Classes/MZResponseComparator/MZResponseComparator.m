//
//  MZResponseComparator.m
//  Memz
//
//  Created by Bastien Falcou on 1/3/16.
//  Copyright © 2016 Falcou. All rights reserved.
//

#import "MZResponseComparator.h"
#import "NSString+LevenshteinDistances.h"
#import "MZWord.h"

const CGFloat kMinimumPercentageConsiderTrue = 0.9f;
const CGFloat kMinimumPercentageConsiderLearningInProgress = 0.65f;

@implementation MZResponseComparator

- (instancetype)initWithResponse:(MZResponse *)response {
	if (self = [super init]) {
		_response = response;
	}
	return self;
}

+ (instancetype)responseComparatorWithResponse:(MZResponse *)response {
	return [[MZResponseComparator alloc] initWithResponse:response];
}

- (MZResponseResult)checkTranslations:(NSArray<NSString *> *)translations {
	// (1) Build arrays of similarity percentage
	// For each correct translation, calculate percentage of similarity with each proposed translation.
	NSMutableArray<NSMutableArray<NSNumber *> *> *arrayPercentages = [NSMutableArray arrayWithCapacity:self.response.word.translation.count];

	NSUInteger i = 0;
	for (MZWord *actualTranslation in self.response.word.translation.allObjects) {
		arrayPercentages[i] = [[NSMutableArray alloc] initWithCapacity:self.response.word.translation.count];

		NSUInteger j = 0;
		for (NSString *proposedTranslation in translations) {
			arrayPercentages[i][j] = @([actualTranslation.word percentageSimilarity:proposedTranslation]);
			j++;
		}
		i++;
	}

	// (2) Interpreat those arrays of similarity percentage one by one
	// The highest percentage points to the word with most chances to be right - or an attempt to write the correct translation
	NSMutableSet<NSString *> *mutableSet = [NSMutableSet setWithCapacity:self.response.word.translation.count];

	CGFloat totalSuccessPercentage = 0.0f;
	CGFloat unitySucessPercentage = 1.0f / self.response.word.translation.count;

	for (NSUInteger i = 0; i < arrayPercentages.count; i++) {
		NSString *mostLikelyTranslation;
		CGFloat highestPercentage = 0.0f;

		for (NSUInteger j = 0; j < arrayPercentages[i].count; j++) {
			CGFloat percentage = arrayPercentages[i][j].floatValue;

			if (percentage >= highestPercentage && ![mutableSet containsObject:translations[j]]) {
				highestPercentage = percentage;
				mostLikelyTranslation = translations[j];
			}
		}

		// (3) Add word to already selected translations set, exclude empty strings because would keep from considering following empty ones
		// Notify delegate that this word has been checked and results.
		if (mostLikelyTranslation && ![mostLikelyTranslation isEqualToString:@""]) {
			[mutableSet addObject:mostLikelyTranslation];
		}

		if ([self.delegate respondsToSelector:@selector(responseComparator:didCheckTranslation:correctWithWord:isTranslationCorrect:)]) {
			[self.delegate responseComparator:self
										didCheckTranslation:mostLikelyTranslation
												correctWithWord:self.response.word.translation.allObjects[i]
									 isTranslationCorrect:highestPercentage >= kMinimumPercentageConsiderTrue];
		}

		// (4) Calculate global result, addition takes place at each iteration according to similarity percentage
		// If percentage considered wrong, do not add any value. If in progress, add certain percentage of unity value. If right, add one unity.
		if (highestPercentage >= kMinimumPercentageConsiderTrue) {
			totalSuccessPercentage += unitySucessPercentage;
		} else if (highestPercentage >= kMinimumPercentageConsiderLearningInProgress) {
			totalSuccessPercentage += unitySucessPercentage / 2.0f;
		}
	}

	return [self responseResultForSimilarityPercentage:totalSuccessPercentage];
}

#pragma mark - Helpers

- (MZResponseResult)responseResultForSimilarityPercentage:(CGFloat)similarityPercentage {
	if (similarityPercentage >= kMinimumPercentageConsiderTrue) {
		return MZResponseResultRight;
	} else if (similarityPercentage >= kMinimumPercentageConsiderLearningInProgress) {
		return MZResponseResultLearningInProgress;
	}
	return MZResponseResultWrond;
}

@end