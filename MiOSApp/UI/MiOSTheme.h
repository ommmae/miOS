#import <UIKit/UIKit.h>

@interface MiOSTheme : NSObject
+ (UIColor *)primaryBackground;
+ (UIColor *)secondaryBackground;
+ (UIColor *)cardBackground;
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
@end
