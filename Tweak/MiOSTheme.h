#import <UIKit/UIKit.h>

// Shared visual language — colors, fonts, SF-symbol helpers, rounded cards.
@interface MiOSTheme : NSObject
+ (UIColor *)accent;              // signature cyan-blue accent
+ (UIColor *)accentSecondary;     // violet highlight for Spoof mode
+ (UIColor *)background;
+ (UIColor *)card;
+ (UIColor *)cardElevated;
+ (UIColor *)separator;
+ (UIColor *)text;
+ (UIColor *)textSecondary;
+ (UIColor *)destructive;

+ (UIFont *)titleFont;
+ (UIFont *)headerFont;
+ (UIFont *)bodyFont;
+ (UIFont *)captionFont;

+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size;
+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size color:(UIColor *)color;
+ (void)applyCardStyleTo:(UIView *)view;
@end
