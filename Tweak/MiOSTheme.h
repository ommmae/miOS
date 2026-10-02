#import <UIKit/UIKit.h>

@interface MiOSTheme : NSObject

+ (UIColor *)accent;
+ (UIColor *)accentGradientEnd;
+ (UIColor *)accentBorder;
+ (UIColor *)background;
+ (UIColor *)secondaryBackground;
+ (UIColor *)cardBackground;
+ (UIColor *)cardBorder;
+ (UIColor *)tileBackground;
+ (UIColor *)glassBackground;
+ (UIColor *)separator;
+ (UIColor *)text;
+ (UIColor *)textSecondary;
+ (UIColor *)textOnAccent;
+ (UIColor *)destructive;
+ (UIColor *)statusGreen;
+ (UIColor *)statusYellow;
+ (UIColor *)statusGray;

+ (UIFont *)largeTitleFont;
+ (UIFont *)titleFont;
+ (UIFont *)headline;
+ (UIFont *)bodyFont;
+ (UIFont *)subhead;
+ (UIFont *)captionFont;
+ (UIFont *)captionBold;

+ (CGFloat)cardCornerRadius;
+ (CGFloat)tileCornerRadius;
+ (CGFloat)cardPadding;

+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size;
+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size color:(UIColor *)color;
+ (UIView *)iconBubbleWithSymbol:(NSString *)name color:(UIColor *)color size:(CGFloat)size;

+ (void)applyCardStyleTo:(UIView *)view;
+ (void)applyGlassStyleTo:(UIView *)view;
+ (CAGradientLayer *)accentGradientForBounds:(CGRect)bounds;
+ (CAGradientLayer *)backgroundGradientForBounds:(CGRect)bounds;

@end
