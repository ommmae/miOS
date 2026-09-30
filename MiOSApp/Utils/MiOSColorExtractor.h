#import <UIKit/UIKit.h>

@interface MiOSColorExtractor : NSObject
+ (UIColor *)dominantColorFromImage:(UIImage *)image;
+ (UIColor *)vibrantColorFromImage:(UIImage *)image;
+ (UIColor *)accentGradientEndFromColor:(UIColor *)color;
@end
