//
//  MZGraphicView.m
//  Memz
//
//  Created by Bastien Falcou on 2/6/16.
//  Copyright © 2016 Falcou. All rights reserved.
//

#import "MZGraphicView.h"
#import "UIColor+MemzAdditions.h"

#define DEFAULT_GRADIENT_START_COLOR [UIColor graphGradientDefaultStartColor]
#define DEFAULT_GRADIENT_END_COLOR [UIColor graphGradientDefaultEndColor]
#define DEFAULT_GRADIENT_UNDER_GRAPH_START_COLOR [UIColor graphGradientDefaultUnderGraphStartColor]

const CGFloat kHorizontalInsets = 20.0f;
const CGFloat kFirstLastPointsAdditionalInset = 2.0f;

const CGFloat kPointRadius = 5.0f;
const CGFloat kInnerPointRadius = 3.0f;

@interface MZGraphicView ()

@property (strong, nonatomic) IBOutlet UIView *titleContainerView;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *averageLabel;
@property (strong, nonatomic) IBOutlet UILabel *totalValuesLabel;
@property (strong, nonatomic) IBOutlet UILabel *timeStampLabel;

@property (strong, nonatomic) IBOutlet UIView *metricsContainerView;

@end

@implementation MZGraphicView

#pragma mark - Initialization

- (instancetype)init {
	if (self = [super init]) {
		[self commonInit];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	if (self = [super initWithCoder:aDecoder]) {
		[self commonInit];
	}
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		[self commonInit];
	}
	return self;
}

- (void)commonInit {
	self.gradientStartColor = DEFAULT_GRADIENT_START_COLOR;
	self.gradientEndColor = DEFAULT_GRADIENT_END_COLOR;
	self.gradientUnderGraphStartColor = DEFAULT_GRADIENT_UNDER_GRAPH_START_COLOR;

	self.showAverage = YES;

	self.values = @[@0, @8, @3, @6, @2, @7, @3];		// TODO: Delete after tests
}

#pragma mark - Global Overridden Methods

- (void)drawRect:(CGRect)rect {
	[super drawRect:rect];

	// (1) Add rounded corners
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
																						 byRoundingCorners:UIRectCornerAllCorners
																									 cornerRadii:CGSizeMake(8.0f, 8.0f)];
	[path addClip];

	// (2) Draw background gradient
	[self drawBackgroundGradient];

	// (3) Draw under graph gradient
	[self drawUnderGraphGradient];

	// (4) Draw graph line
	[self drawLine];

	// (5) Draw points
	[self drawPoints];

	// (6) Draw average dashed line
	if (self.showAverage) {
		[self drawDashedLine];
	}

	// (7) Draw top and bottom separation lines

}

#pragma mark - Points Calculations

- (CGFloat)xPointForColumn:(NSInteger)column {
	CGFloat spacer = (self.bounds.size.width - kHorizontalInsets * 2 - kFirstLastPointsAdditionalInset * 2) / (self.values.count - 1);
	return column * spacer + kHorizontalInsets + kFirstLastPointsAdditionalInset;
}

- (CGFloat)yPointForValue:(NSNumber *)value {
	CGFloat graphHeight = self.frame.size.height - self.titleContainerView.frame.size.height - self.metricsContainerView.frame.size.height;
	CGFloat maximumValue = [[self.values valueForKeyPath:@"@max.self"] floatValue];

	CGFloat yPoint = value.floatValue / maximumValue * graphHeight;
	return graphHeight + self.titleContainerView.frame.size.height - yPoint;
}

- (CGFloat)yPointForColumn:(NSInteger)column {
	return [self yPointForValue:self.values[column]];
}

#pragma mark - Gradient Background

- (CGGradientRef)generateBackgroundGradient {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	CFMutableArrayRef colorArray = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
	CFArrayAppendValue(colorArray, self.gradientStartColor.CGColor);
	CFArrayAppendValue(colorArray, self.gradientEndColor.CGColor);

	CGFloat colorLocations[2] = {0.0f, 1.0f};

	return CGGradientCreateWithColors(colorSpace, colorArray, colorLocations);
}

- (void)drawBackgroundGradient {
	CGPoint startPoint = CGPointZero;
	CGPoint endPoint = CGPointMake(0.0f, self.bounds.size.height);
	CGContextDrawLinearGradient(UIGraphicsGetCurrentContext(),
															[self generateBackgroundGradient],
															startPoint,
															endPoint,
															kCGGradientDrawsBeforeStartLocation);
}

#pragma mark - Under Graph Gradient

- (CGGradientRef)generateUnderGraphGradient {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	CFMutableArrayRef colorArray = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
	CFArrayAppendValue(colorArray, self.gradientUnderGraphStartColor.CGColor);
	CFArrayAppendValue(colorArray, self.gradientEndColor.CGColor);

	CGFloat colorLocations[2] = {0.0f, 1.0f};

	return CGGradientCreateWithColors(colorSpace, colorArray, colorLocations);
}

- (void)drawUnderGraphGradient {
	CGContextSaveGState(UIGraphicsGetCurrentContext());

	UIBezierPath *graphPath = [self generateGraphLine];

	[graphPath addLineToPoint:CGPointMake([self xPointForColumn:self.values.count - 1], self.frame.size.height)];
	[graphPath addLineToPoint:CGPointMake([self xPointForColumn:0], self.frame.size.height)];
	[graphPath closePath];

	[graphPath addClip];

	[[UIColor greenColor] setFill];
	UIBezierPath *rectPath = [UIBezierPath bezierPathWithRect:self.bounds];
	[rectPath fill];

	NSNumber *maxValue = [self.values valueForKeyPath:@"@max.self"];
	NSUInteger indexMaxValue = [self.values indexOfObject:maxValue];
	CGFloat highestPoint = [self yPointForColumn:indexMaxValue];

	CGPoint startPoint = CGPointMake(kHorizontalInsets, highestPoint);
	CGPoint endPoint = CGPointMake(kHorizontalInsets, self.bounds.size.height);

	CGContextDrawLinearGradient(UIGraphicsGetCurrentContext(),
															[self generateUnderGraphGradient],
															startPoint,
															endPoint,
															kCGGradientDrawsBeforeStartLocation);

	CGContextRestoreGState(UIGraphicsGetCurrentContext());
}

#pragma mark - Graph Line

- (UIBezierPath *)generateGraphLine {
	if (self.values.count == 0) {
		return nil;
	}

	[[UIColor whiteColor] setFill];
	[[UIColor whiteColor] setStroke];

	UIBezierPath *graphPath = [[UIBezierPath alloc] init];
	[graphPath moveToPoint:CGPointMake([self xPointForColumn:0], [self yPointForColumn:0])];

	for (NSUInteger i = 1; i < self.values.count; i++) {
		CGPoint nextPoint = CGPointMake([self xPointForColumn:i], [self yPointForColumn:i]);
		[graphPath addLineToPoint:nextPoint];
	}
	return graphPath;
}

- (void)drawLine {
	UIBezierPath *graphLine = [self generateGraphLine];
	graphLine.lineWidth = 1.0f;
	[graphLine stroke];
}

#pragma mark - Points

- (void)drawPoints {
	for (NSUInteger i = 0; i < self.values.count; i++) {
		CGPoint point = CGPointMake([self xPointForColumn:i], [self yPointForColumn:i]);
		point.x -= kPointRadius / 2.0f;
		point.y -= kPointRadius / 2.0f;

		UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(point.x,
																																						 point.y,
																																						 kPointRadius,
																																						 kPointRadius)];
		[[UIColor whiteColor] setFill];
		[circle fill];

		UIBezierPath *innerCircle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(point.x + (kPointRadius - kInnerPointRadius) / 2.0f,
																																									point.y + (kPointRadius - kInnerPointRadius) / 2.0f,
																																									kInnerPointRadius,
																																									kInnerPointRadius)];

		[[UIColor averageColorBetweenColor:DEFAULT_GRADIENT_START_COLOR andColor:DEFAULT_GRADIENT_END_COLOR] setFill];
		[innerCircle fill];
	}
}

#pragma mark - Horizontal Average Dashed Line

- (void)drawDashedLine {
	UIBezierPath *linePath = [[UIBezierPath alloc] init];

	CGFloat dashArray[2] = {2.0f, 2.0f};
	[linePath setLineDash:dashArray count:2 phase:0];

	NSNumber *average = [self.values valueForKeyPath:@"@avg.self"];

	[linePath moveToPoint:CGPointMake(kHorizontalInsets, [self yPointForValue:average])];
	[linePath addLineToPoint:CGPointMake(self.frame.size.width - kHorizontalInsets, [self yPointForValue:average])];

	[[[UIColor whiteColor] colorWithAlphaComponent:0.5f] setStroke];
	linePath.lineWidth = 1.0f;
	[linePath stroke];
}

#pragma mark - Horizontal Top Separator Line

@end
