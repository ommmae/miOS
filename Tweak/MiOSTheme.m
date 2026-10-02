#import "MiOSTheme.h"
#import <QuartzCore/QuartzCore.h>

@implementation MiOSTheme

#pragma mark - Colors

+ (UIColor *)accent              { return [UIColor systemPurpleColor]; }
+ (UIColor *)accentGradientEnd   { return [UIColor systemIndigoColor]; }
+ (UIColor *)accentBorder        { return [[UIColor systemPurpleColor] colorWithAlphaComponent:0.3]; }
+ (UIColor *)background          { return [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:1.0]; }
+ (UIColor *)secondaryBackground { return [UIColor colorWithRed:0.09 green:0.09 blue:0.12 alpha:1.0]; }
+ (UIColor *)cardBackground      { return [UIColor colorWithRed:0.11 green:0.11 blue:0.14 alpha:0.85]; }
+ (UIColor *)cardBorder          { return [UIColor colorWithWhite:1.0 alpha:0.08]; }
+ (UIColor *)tileBackground      { return [UIColor colorWithRed:0.13 green:0.13 blue:0.17 alpha:0.9]; }
+ (UIColor *)glassBackground     { return [UIColor colorWithWhite:1.0 alpha:0.06]; }
+ (UIColor *)separator           { return [UIColor colorWithWhite:1.0 alpha:0.06]; }
+ (UIColor *)text                { return [UIColor whiteColor]; }
+ (UIColor *)textSecondary       { return [UIColor colorWithWhite:1.0 alpha:0.55]; }
+ (UIColor *)textOnAccent        { return [UIColor whiteColor]; }
+ (UIColor *)destructive         { return [UIColor systemRedColor]; }
+ (UIColor *)statusGreen         { return [UIColor systemGreenColor]; }
+ (UIColor *)statusYellow        { return [UIColor systemYellowColor]; }
+ (UIColor *)statusGray          { return [UIColor systemGrayColor]; }

#pragma mark - Fonts

+ (UIFont *)largeTitleFont { return [UIFont systemFontOfSize:28 weight:UIFontWeightBold]; }
+ (UIFont *)titleFont      { return [UIFont systemFontOfSize:22 weight:UIFontWeightBold]; }
+ (UIFont *)headline       { return [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; }
+ (UIFont *)bodyFont       { return [UIFont systemFontOfSize:16 weight:UIFontWeightRegular]; }
+ (UIFont *)subhead        { return [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]; }
+ (UIFont *)captionFont    { return [UIFont systemFontOfSize:12 weight:UIFontWeightRegular]; }
+ (UIFont *)captionBold    { return [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]; }

#pragma mark - Layout constants

+ (CGFloat)cardCornerRadius { return 16; }
+ (CGFloat)tileCornerRadius { return 14; }
+ (CGFloat)cardPadding      { return 16; }

#pragma mark - Symbols

+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size {
    return [self symbol:name size:size color:nil];
}

+ (UIImage *)symbol:(NSString *)name size:(CGFloat)size color:(UIColor *)color {
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium];
    UIImage *img = [UIImage systemImageNamed:name withConfiguration:cfg];
    if (color) img = [img imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}

+ (UIView *)iconBubbleWithSymbol:(NSString *)name color:(UIColor *)color size:(CGFloat)size {
    UIView *bubble = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    bubble.backgroundColor = [color colorWithAlphaComponent:0.15];
    bubble.layer.cornerRadius = size * 0.28;
    bubble.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageView *iv = [[UIImageView alloc] initWithImage:[self symbol:name size:size * 0.48 color:color]];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    [bubble addSubview:iv];
    [NSLayoutConstraint activateConstraints:@[
        [iv.centerXAnchor constraintEqualToAnchor:bubble.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:bubble.centerYAnchor],
    ]];
    return bubble;
}

#pragma mark - Styling helpers

+ (void)applyCardStyleTo:(UIView *)view {
    view.backgroundColor = [self cardBackground];
    view.layer.cornerRadius = [self cardCornerRadius];
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [self cardBorder].CGColor;
}

+ (void)applyGlassStyleTo:(UIView *)view {
    for (UIView *sub in view.subviews)
        if ([sub isKindOfClass:[UIVisualEffectView class]]) return;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:blur];
    bv.frame = view.bounds;
    bv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bv.layer.cornerRadius = [self cardCornerRadius];
    bv.layer.cornerCurve = kCACornerCurveContinuous;
    bv.clipsToBounds = YES;
    [view insertSubview:bv atIndex:0];
    view.backgroundColor = [UIColor clearColor];
    view.layer.cornerRadius = [self cardCornerRadius];
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [self cardBorder].CGColor;
}

+ (CAGradientLayer *)accentGradientForBounds:(CGRect)bounds {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = bounds;
    g.colors = @[(id)[self accent].CGColor, (id)[self accentGradientEnd].CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint   = CGPointMake(1, 1);
    return g;
}

+ (CAGradientLayer *)backgroundGradientForBounds:(CGRect)bounds {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = bounds;
    g.colors = @[
        (id)[UIColor colorWithRed:0.08 green:0.02 blue:0.15 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.04 green:0.04 blue:0.08 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:1.0].CGColor,
    ];
    g.locations  = @[@0.0, @0.5, @1.0];
    g.startPoint = CGPointMake(0.5, 0);
    g.endPoint   = CGPointMake(0.5, 1);
    return g;
}

@end
