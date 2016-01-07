//
//  UIImage+AssetIdentifiers.h
//  Memz
//
//  Created by Bastien Falcou on 1/5/16.
//  Copyright © 2016 Falcou. All rights reserved.
//

#import <UIKit/UIKit.h>

@import UIKit;

typedef NS_ENUM(NSInteger, MZAssetIdentifier) {
	MZAssetIdentifierFlagFrance,
	MZAssetIdentifierFlagUnitedKingdom,
	MZAssetIdentifierNavigationAdd,
	MZAssetIdentifierNavigationBack,
	MZAssetIdentifierNavigationCancel,
	MZAssetIdentifierNavigationSettings,
	MZAssetIdentifierFeedGradient,
	MZAssetIdentifierQuizBell,
	MZAssetIdentifierQuizCross,
	MZAssetIdentifierQuizTick,
	MZAssetIdentifierAddWordMinusIcon,
	MZAssetIdentifierAddWordPlusIcon,
	MZAssetIdentifierAddWordTriangleIcon
};

@interface UIImage (AssetIdentifier)

+ (instancetype)imageWithAssetIdentifier:(MZAssetIdentifier)assetIdentifier;

@end
