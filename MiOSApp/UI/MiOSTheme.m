#import "MiOSTheme.h"

static UIColor *_dynamicAccent = nil;
static UIColor *_dynamicAccentEnd = nil;

@implementation MiOSTheme

#pragma mark - Dynamic Accent

+ (void)setDynamicAccentColor:(UIColor *)color {
    _dynamicAccent = color;
}

+ (void)setDynamicAccentGradientEnd:(UIColor *)color {
    _dynamicAccentEnd = color;
}

+ (void)resetDynamicAccent {
    _dynamicAccent = nil;
    _dynamicAccentEnd = nil;
}

+ (BOOL)hasDynamicAccent {
    return _dynamicAccent != nil;
}

#pragma mark - Colors

+ (UIColor *)primaryBackground {
    return [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
}

+ (UIColor *)secondaryBackground {
    return [UIColor colorWithRed:0.08 green:0.08 blue:0.11 alpha:1.0];
}

+ (UIColor *)cardBackground {
    return [UIColor colorWithRed:0.10 green:0.10 blue:0.14 alpha:0.85];
}

+ (UIColor *)glassBackground {
    return [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:0.65];
}

+ (UIColor *)accentColor {
    if (_dynamicAccent) return _dynamicAccent;
    return [UIColor colorWithRed:0.0 green:0.82 blue:0.95 alpha:1.0];
}

+ (UIColor *)accentGradientEnd {
    if (_dynamicAccentEnd) return _dynamicAccentEnd;
    return [UIColor colorWithRed:0.45 green:0.30 blue:1.0 alpha:1.0];
}

+ (UIColor *)primaryText {
    return [UIColor colorWithWhite:0.95 alpha:1.0];
}

+ (UIColor *)secondaryText {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

+ (UIColor *)tertiaryText {
    return [UIColor colorWithWhite:0.35 alpha:1.0];
}

+ (UIColor *)separator {
    return [UIColor colorWithWhite:1.0 alpha:0.08];
}

+ (UIColor *)destructive {
    return [UIColor systemRedColor];
}

+ (UIColor *)success {
    return [UIColor systemGreenColor];
}

+ (UIColor *)warning {
    return [UIColor systemOrangeColor];
}

#pragma mark - Fonts

+ (UIFont *)titleFont {
    return [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
}

+ (UIFont *)headlineFont {
    return [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
}

+ (UIFont *)bodyFont {
    return [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
}

+ (UIFont *)captionFont {
    return [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
}

+ (UIFont *)monoFont {
    return [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
}

#pragma mark - Dimensions

+ (CGFloat)cornerRadius {
    return 16.0;
}

+ (CGFloat)cardCornerRadius {
    return 20.0;
}

+ (CGFloat)cardPadding {
    return 16.0;
}

#pragma mark - Styling

+ (void)styleNavigationBar:(UINavigationBar *)bar {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = [UIColor clearColor];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [self primaryText]};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [self primaryText]};
    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = appearance;
    bar.compactAppearance = appearance;
}

+ (CAGradientLayer *)accentGradientForBounds:(CGRect)bounds {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.colors = @[(id)[self accentColor].CGColor, (id)[self accentGradientEnd].CGColor];
    gradient.startPoint = CGPointMake(0, 0.5);
    gradient.endPoint = CGPointMake(1, 0.5);
    gradient.cornerRadius = 14;
    return gradient;
}

+ (CAGradientLayer *)backgroundGradientForBounds:(CGRect)bounds {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    UIColor *accent = [self accentColor];
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.06 green:0.06 blue:0.10 alpha:1.0].CGColor,
        (id)[self primaryBackground].CGColor,
        (id)[[accent colorWithAlphaComponent:0.03] CGColor],
        (id)[self primaryBackground].CGColor,
    ];
    gradient.locations = @[@0.0, @0.3, @0.7, @1.0];
    gradient.startPoint = CGPointMake(0.5, 0);
    gradient.endPoint = CGPointMake(0.5, 1);
    return gradient;
}

#pragma mark - Glass Effects

+ (void)applyGlassEffectToView:(UIView *)view {
    view.backgroundColor = [self glassBackground];
    view.layer.cornerRadius = [self cardCornerRadius];
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.06].CGColor;
    view.layer.borderWidth = 0.5;

    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 16;
    view.layer.shadowOpacity = 0.3;
    view.clipsToBounds = NO;
}

+ (void)applyAccentGlassEffectToView:(UIView *)view {
    UIColor *accent = [self accentColor];
    CGFloat r, g, b, a;
    [accent getRed:&r green:&g blue:&b alpha:&a];
    view.backgroundColor = [UIColor colorWithRed:0.10 + r * 0.03
                                           green:0.10 + g * 0.03
                                            blue:0.14 + b * 0.03
                                           alpha:0.85];
    view.layer.cornerRadius = [self cardCornerRadius];
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderColor = [accent colorWithAlphaComponent:0.15].CGColor;
    view.layer.borderWidth = 1.0;

    view.layer.shadowColor = accent.CGColor;
    view.layer.shadowOffset = CGSizeMake(0, 2);
    view.layer.shadowRadius = 12;
    view.layer.shadowOpacity = 0.08;
    view.clipsToBounds = NO;
}

+ (void)applyGlowToView:(UIView *)view color:(UIColor *)color radius:(CGFloat)radius {
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowRadius = radius;
    view.layer.shadowOpacity = 0.5;
}

+ (UIColor *)accentTintedCardBackground {
    UIColor *accent = [self accentColor];
    CGFloat r, g, b, a;
    [accent getRed:&r green:&g blue:&b alpha:&a];
    return [UIColor colorWithRed:0.10 + r * 0.04
                           green:0.10 + g * 0.04
                            blue:0.14 + b * 0.04
                           alpha:0.85];
}

+ (UIColor *)accentBorderColor {
    return [[self accentColor] colorWithAlphaComponent:0.15];
}

@end
