#import <UIKit/UIKit.h>

@interface MiOSTheme : NSObject

+ (UIColor *)primaryBackground;
+ (UIColor *)secondaryBackground;
+ (UIColor *)cardBackground;
+ (UIColor *)glassBackground;
+ (UIColor *)accentColor;
+ (UIColor *)accentGradientEnd;
+ (UIColor *)primaryText;
+ (UIColor *)secondaryText;
+ (UIColor *)tertiaryText;
+ (UIColor *)separator;
+ (UIColor *)destructive;
+ (UIColor *)success;
+ (UIColor *)warning;

+ (UIFont *)titleFont;
+ (UIFont *)headlineFont;
+ (UIFont *)bodyFont;
+ (UIFont *)captionFont;
+ (UIFont *)monoFont;

+ (CGFloat)cornerRadius;
+ (CGFloat)cardCornerRadius;
+ (CGFloat)cardPadding;

+ (void)styleNavigationBar:(UINavigationBar *)bar;
+ (CAGradientLayer *)accentGradientForBounds:(CGRect)bounds;
+ (CAGradientLayer *)backgroundGradientForBounds:(CGRect)bounds;

+ (void)setDynamicAccentColor:(UIColor *)color;
+ (void)setDynamicAccentGradientEnd:(UIColor *)color;
+ (void)resetDynamicAccent;
+ (BOOL)hasDynamicAccent;

+ (void)applyGlassEffectToView:(UIView *)view;
+ (void)applyGlowToView:(UIView *)view color:(UIColor *)color radius:(CGFloat)radius;

@end
