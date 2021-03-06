//
//  MZSwitch.m
//  Memz
//
//  Created by Bastien Falcou on 1/7/15.
//  Copyright (c) 2015 Fueled. All rights reserved.
//

#import "MZSwitch.h"

const CGFloat kSwitchWidth = 51.0f;
const CGFloat kSwitchHeight = 31.0f;
const CGFloat kSwitchCurveRadius = 16.0f;

const NSTimeInterval kSwitchAnimationDuration = 0.2f;

#define RECT_FOR_ON	CGRectMake(0.0f, 0.0f, kSwitchWidth, kSwitchHeight)

@interface MZSwitch ()

@property (nonatomic, retain, readwrite) UIImageView* backgroundImage;

@property (nonatomic, strong) UIColor *onTintColorSaved;
@property (nonatomic, strong) UIColor *tintColorSaved;
@property (nonatomic, strong) UIColor *backgroundColorSaved;

@property (nonatomic, strong) UIImage *onImage;
@property (nonatomic, strong) UIImage *offImage;

@property (nonatomic, strong) UIColor *defaultOnTintColor;
@property (nonatomic, strong) UIColor *defaultTintColor;
@property (nonatomic, strong) UIColor *defaultBackgroundColor;

@end

@implementation MZSwitch
@synthesize onImage = _onImage;
@synthesize offImage = _offImage;

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (void)awakeFromNib {
  self.tintColorSaved = self.tintColor;
  self.onTintColorSaved = self.onTintColor;
  self.backgroundColorSaved = self.backgroundColor;
  
  UISwitch *defaultSwitch = [[UISwitch alloc] init];
  self.defaultOnTintColor = defaultSwitch.onTintColor;
  self.defaultTintColor = defaultSwitch.tintColor;
  self.defaultBackgroundColor = defaultSwitch.backgroundColor;
}

- (void)commonInit {
  [self setupUserInterface];
  [self addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)dealloc {
  [self removeTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)setOn:(BOOL)on {
  [super setOn:on];
  
  [self updateDesign];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
  [super setOn:on animated:animated];
  
  [self updateDesign];
}

- (void)setupUserInterface {
  UIImageView *background = [[UIImageView alloc] initWithFrame:RECT_FOR_ON];
  background.contentMode = UIViewContentModeScaleAspectFit;
  self.backgroundImage = background;
  
  [self addSubview:self.backgroundImage];
  [self sendSubviewToBack:self.backgroundImage];
  
  [self updateDesign];
}

- (void)updateDesign {
  if (self.on) {

    if (self.onImage != nil) {
      self.onTintColor = [UIColor clearColor];
      [UIView transitionWithView:self.backgroundImage
                        duration:kSwitchAnimationDuration
                         options:UIViewAnimationOptionTransitionCrossDissolve
                      animations:^{
                        self.backgroundImage.image = self.onImage;
                      } completion:nil];
    } else {
      self.backgroundImage.image = nil;
      [self updateColorsOn];
    }
  } else {
    if (self.offImage != nil) {
      [UIView transitionWithView:self.backgroundImage
                        duration:kSwitchAnimationDuration
                         options:UIViewAnimationOptionTransitionCrossDissolve
                      animations:^{
                        self.backgroundImage.image = self.offImage;
                      } completion:nil];
    } else {
      self.backgroundImage.image = nil;
      [self updateColorsOff];
    }
  }
}

- (void)switchValueChanged:(id)sender {
  [self updateDesign];
}

#pragma mark - Update colors methods 

- (void)updateColorsOn {
  self.backgroundColor = [UIColor clearColor];
  self.layer.cornerRadius = 0.0f;
}

- (void)updateColorsOff {
  // Trick: a Radius will be applied to the background in that case so it matches exactly the shape of the switch.
	// Allows to apply a background color when the switch is turned off (impossible otherwise).
  self.backgroundColor = self.offTintColor != nil ? self.offTintColor : self.defaultBackgroundColor;
  self.tintColor = self.offTintColor != nil ? self.offTintColor : self.defaultTintColor;
  self.layer.cornerRadius = kSwitchCurveRadius;
}

#pragma mark - Helpers 

- (void)restoreOnTintColor {
  if (self.onTintColorSaved != nil) {
    self.onTintColor = self.onTintColorSaved;
  } else {
    self.onTintColor = self.defaultOnTintColor;
  }
}

- (void)restoreTintColor {
  if (self.tintColorSaved != nil) {
    self.tintColor = self.tintColorSaved;
  } else {
    self.tintColor = self.defaultTintColor;
  }
}

- (void)restoreBackgroundColor {
  if (self.backgroundColorSaved != nil) {
    self.backgroundColor = self.backgroundColorSaved;
  } else {
    self.backgroundColor = self.defaultBackgroundColor;
  }
}

- (void)saveAndClearOnTintColor {
  self.onTintColorSaved = self.onTintColor;
  self.onTintColor = [UIColor clearColor];
}

- (void)saveAndClearTintColor {
  self.tintColorSaved = self.tintColor;
  self.tintColor = [UIColor clearColor];
}

- (void)saveAndClearBackgroundColor {
  self.backgroundColorSaved = self.backgroundColor;
  self.backgroundColor = [UIColor clearColor];
}

#pragma mark - Setters

- (void)setOnImage:(UIImage *)onImage {
  _onImage = onImage;

  if (self.isOn) {
    self.backgroundImage.image = onImage;

    if (onImage == nil) {
      [self restoreOnTintColor];
      
      // Restore the border color if there is no offImage (seen only in that case), make it clear otherwise.
      if (self.offImage == nil) {
        [self restoreTintColor];
      } else {
        self.tintColor = [UIColor clearColor];
      }
      
      [self updateColorsOn];
    } else {
      // Save and make border and onTintColor clear if we are setting a new onImage.
      [self saveAndClearOnTintColor];
      [self saveAndClearTintColor];
    }
  } else {
    // Restore the border color if we are deleting the onImage, save and make it clear if we are setting a onImage. Those colors will be seen when the switch will be switched off.
    if (onImage == nil) {
      [self restoreOnTintColor];
    } else {
      [self saveAndClearOnTintColor];
    }
  }
}

- (void)setOffImage:(UIImage *)offImage {
  _offImage = offImage;
  
  if (!self.isOn) {
    self.backgroundImage.image = offImage;

    // If deleting the offImage, make tintColor and backgroundColor appear. Save and clear them otherwise.
    if (offImage == nil) {
      [self restoreTintColor];
      [self restoreBackgroundColor];
      
      [self updateColorsOff];
    } else {
      [self saveAndClearTintColor];
      [self saveAndClearBackgroundColor];
    }
  } else {
    [self saveAndClearTintColor];
  }
}

- (void)setOnTintColor:(UIColor *)onTintColor {
  // Don't udate onTintColor but save it instead if onImage is already displayed (would be overlapped by onTintColor otherwise).
	// However, it is not necessary to prevent this update if onTintColor is clear (won't impact the way the onImage is displayed,
  // it is even mandatory to accept updates with a clear color for a few cases).
  if (self.onImage != nil && self.isOn && onTintColor != [UIColor clearColor]) {
    self.onTintColorSaved = onTintColor;
    return;
  }
  
  // Call super constructor passing new or default onTintColor depending on its value (nil removes previous color and will
	// set default color instead).
  if (onTintColor != nil) {
    [super setOnTintColor:onTintColor];
  } else {
    [super setOnTintColor:self.defaultOnTintColor];
  }
  
  if (self.isOn) {
    // Restore border color if onImage is being deleted.
    if (self.onImage == nil && self.tintColorSaved != nil) {
      self.tintColor = self.tintColorSaved;
    }
    
    [self updateColorsOn];
  }
}

- (void)setOffTintColor:(UIColor *)offTintColor {
  _offTintColor = offTintColor;
  
  // Direct display, if offImage is being set we won't need any border color anymore.
  if (!self.isOn && self.offImage == nil) {
    [self updateColorsOff];
  } else {
    self.tintColor = [UIColor clearColor];
  }
}

@end

