#import "MiOSTheme.h"

@implementation MiOSTheme

+ (UIColor *)accent          { return [UIColor colorWithRed:0.33 green:0.73 blue:1.00 alpha:1.0]; } // #54BAFF
+ (UIColor *)accentSecondary { return [UIColor colorWithRed:0.65 green:0.47 blue:1.00 alpha:1.0]; } // #A678FF
+ (UIColor *)background      { return [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0]; } // near-black
+ (UIColor *)card            { return [UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1.0]; }
+ (UIColor *)cardElevated    { return [UIColor colorWithRed:0.15 green:0.15 blue:0.17 alpha:1.0]; }
+ (UIColor *)separator       { return [UIColor colorWithWhite:1.0 alpha:0.08]; }
+ (UIColor *)text            { return [UIColor whiteColor]; }
+ (UIColor *)textSecondary   { return [UIColor colorWithWhite:1.0 alpha:0.55]; }
+ (UIColor *)destructive     { return [UIColor colorWithRed:1.00 green:0.33 blue:0.33 alpha:1.0]; }

+ (UIFont *)titleFont   { return [UIFont systemFontOfSize:22 weight:UIFontWeightBold]; }
+ (UIFont *)headerFont  { return [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; }
+ (UIFont *)bodyFont    { return [UIFont systemFontOfSize:16 weight:UIFontWeightRegular]; }
+ (UIFont *)captionFont { return [UIFont systemFontOfSize:12 weight:UIFontWeightRegular]; }

+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size {
    return [self symbol:name size:size color:nil];
}
+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size color:(UIColor *)color {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium];
    UIImage *img = [UIImage systemImageNamed:name withConfiguration:cfg];
    if (color) img = [img imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}

+ (void)applyCardStyleTo:(UIView *)view {
    view.backgroundColor = [self card];
    view.layer.cornerRadius = 14;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [self separator].CGColor;
}

@end
