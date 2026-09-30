#import "MiOSTheme.h"

@implementation MiOSTheme

+ (UIColor *)primaryBackground {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0]
            : [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0];
    }];
}

+ (UIColor *)secondaryBackground {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.10 green:0.10 blue:0.14 alpha:1.0]
            : [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    }];
}

+ (UIColor *)cardBackground {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0]
            : [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    }];
}

+ (UIColor *)accentColor {
    return [UIColor colorWithRed:0.0 green:0.82 blue:0.95 alpha:1.0];
}

+ (UIColor *)accentGradientEnd {
    return [UIColor colorWithRed:0.45 green:0.30 blue:1.0 alpha:1.0];
}

+ (UIColor *)primaryText {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor whiteColor]
            : [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0];
    }];
}

+ (UIColor *)secondaryText {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.6 alpha:1.0]
            : [UIColor colorWithWhite:0.45 alpha:1.0];
    }];
}

+ (UIColor *)tertiaryText {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.4 alpha:1.0]
            : [UIColor colorWithWhite:0.65 alpha:1.0];
    }];
}

+ (UIColor *)separator {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.08];
    }];
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

+ (CGFloat)cornerRadius {
    return 14.0;
}

+ (CGFloat)cardCornerRadius {
    return 16.0;
}

+ (CGFloat)cardPadding {
    return 16.0;
}

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
    gradient.cornerRadius = bounds.size.height / 2.0;
    return gradient;
}

@end
