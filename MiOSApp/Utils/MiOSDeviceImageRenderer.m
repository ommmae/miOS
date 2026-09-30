#import "MiOSDeviceImageRenderer.h"

@implementation MiOSDeviceImageRenderer

+ (MiOSDeviceFormFactor)formFactorForDeviceName:(NSString *)name {
    if (!name) return MiOSDeviceFormFactorNotch;

    NSString *lower = name.lowercaseString;
    if ([lower containsString:@"se"]) return MiOSDeviceFormFactorHomeButton;
    if ([lower containsString:@"iphone 7"] || [lower containsString:@"iphone 8"])
        return MiOSDeviceFormFactorHomeButton;

    if ([lower containsString:@"14 pro"] || [lower containsString:@"15"] || [lower containsString:@"16"])
        return MiOSDeviceFormFactorDynamicIsland;

    return MiOSDeviceFormFactorNotch;
}

+ (UIImage *)renderDeviceForName:(NSString *)displayName size:(CGSize)size accentColor:(UIColor *)color {
    MiOSDeviceFormFactor form = [self formFactorForDeviceName:displayName];
    if (!color) color = [UIColor colorWithRed:0.0 green:0.82 blue:0.95 alpha:1.0];

    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;

    CGFloat phoneAspect = (form == MiOSDeviceFormFactorHomeButton) ? 0.52 : 0.47;
    CGFloat phoneHeight = size.height * 0.94;
    CGFloat phoneWidth = phoneHeight * phoneAspect;
    CGFloat x = (size.width - phoneWidth) / 2.0;
    CGFloat y = (size.height - phoneHeight) / 2.0;
    CGRect phoneRect = CGRectMake(x, y, phoneWidth, phoneHeight);

    CGFloat frameRadius = phoneWidth * 0.20;
    if (form == MiOSDeviceFormFactorHomeButton) frameRadius = phoneWidth * 0.16;

    // Outer frame shadow/glow
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeZero, phoneWidth * 0.2,
        [color colorWithAlphaComponent:0.25].CGColor);
    UIBezierPath *glowPath = [UIBezierPath bezierPathWithRoundedRect:phoneRect cornerRadius:frameRadius];
    [[UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0] setFill];
    [glowPath fill];
    CGContextRestoreGState(ctx);

    // Frame body gradient
    CGContextSaveGState(ctx);
    UIBezierPath *framePath = [UIBezierPath bezierPathWithRoundedRect:phoneRect cornerRadius:frameRadius];
    [framePath addClip];

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *frameColors = @[
        (__bridge id)[UIColor colorWithRed:0.20 green:0.20 blue:0.22 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.14 green:0.14 blue:0.16 alpha:1.0].CGColor,
    ];
    CGFloat frameLocs[] = {0.0, 0.5, 1.0};
    CGGradientRef frameGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)frameColors, frameLocs);
    CGContextDrawLinearGradient(ctx, frameGrad, phoneRect.origin,
        CGPointMake(CGRectGetMaxX(phoneRect), CGRectGetMaxY(phoneRect)), 0);
    CGGradientRelease(frameGrad);
    CGContextRestoreGState(ctx);

    // Thin highlight edge at top
    UIBezierPath *edgePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(phoneRect, 0.5, 0.5) cornerRadius:frameRadius - 0.5];
    edgePath.lineWidth = 0.5;
    [[UIColor colorWithWhite:1.0 alpha:0.12] setStroke];
    [edgePath stroke];

    // Screen area
    CGFloat bezelSide = phoneWidth * 0.05;
    CGFloat bezelTop = phoneWidth * 0.05;
    CGFloat bezelBot = bezelTop;
    if (form == MiOSDeviceFormFactorHomeButton) {
        bezelTop = phoneWidth * 0.10;
        bezelBot = phoneWidth * 0.18;
    }

    CGRect screenRect = CGRectMake(
        phoneRect.origin.x + bezelSide,
        phoneRect.origin.y + bezelTop,
        phoneWidth - bezelSide * 2,
        phoneHeight - bezelTop - bezelBot
    );
    CGFloat screenRadius = frameRadius - bezelSide;
    if (screenRadius < 4) screenRadius = 4;

    CGContextSaveGState(ctx);
    UIBezierPath *screenPath = [UIBezierPath bezierPathWithRoundedRect:screenRect cornerRadius:screenRadius];
    [screenPath addClip];

    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];

    NSArray *screenColors = @[
        (__bridge id)[UIColor colorWithRed:r*0.15 green:g*0.15 blue:b*0.15 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:r*0.08 green:g*0.08 blue:b*0.08 alpha:1.0].CGColor,
    ];
    CGFloat screenLocs[] = {0.0, 0.6, 1.0};
    CGGradientRef screenGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)screenColors, screenLocs);
    CGContextDrawLinearGradient(ctx, screenGrad, screenRect.origin,
        CGPointMake(screenRect.origin.x + screenRect.size.width * 0.3, CGRectGetMaxY(screenRect)), 0);
    CGGradientRelease(screenGrad);

    // Screen reflection highlight
    CGRect highlightRect = CGRectMake(screenRect.origin.x, screenRect.origin.y,
        screenRect.size.width * 0.6, screenRect.size.height * 0.3);
    CGGradientRef highlightGrad;
    NSArray *hlColors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.06].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    ];
    highlightGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)hlColors, NULL);
    CGContextDrawLinearGradient(ctx, highlightGrad, highlightRect.origin,
        CGPointMake(highlightRect.origin.x + highlightRect.size.width, CGRectGetMaxY(highlightRect)), 0);
    CGGradientRelease(highlightGrad);

    CGContextRestoreGState(ctx);

    // Draw form-factor details
    if (form == MiOSDeviceFormFactorNotch) {
        [self drawNotchInRect:screenRect phoneWidth:phoneWidth ctx:ctx];
    } else if (form == MiOSDeviceFormFactorDynamicIsland) {
        [self drawDynamicIslandInRect:screenRect phoneWidth:phoneWidth ctx:ctx];
    } else {
        [self drawHomeButtonInRect:phoneRect screenBottom:CGRectGetMaxY(screenRect) phoneWidth:phoneWidth ctx:ctx];
    }

    // Side buttons
    [self drawSideButtonsInRect:phoneRect form:form ctx:ctx];

    // Status bar dots on screen
    [self drawStatusBarInRect:screenRect form:form accentColor:color ctx:ctx];

    CGColorSpaceRelease(cs);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Form Factor Details

+ (void)drawNotchInRect:(CGRect)screen phoneWidth:(CGFloat)pw ctx:(CGContextRef)ctx {
    CGFloat notchWidth = pw * 0.38;
    CGFloat notchHeight = pw * 0.06;
    CGFloat notchX = CGRectGetMidX(screen) - notchWidth / 2;
    CGFloat notchY = screen.origin.y;

    UIBezierPath *notch = [UIBezierPath bezierPathWithRoundedRect:
        CGRectMake(notchX, notchY, notchWidth, notchHeight)
        byRoundingCorners:UIRectCornerBottomLeft | UIRectCornerBottomRight
        cornerRadii:CGSizeMake(notchHeight * 0.6, notchHeight * 0.6)];
    [[UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0] setFill];
    [notch fill];

    // Camera dot
    CGFloat dotSize = pw * 0.025;
    CGRect camDot = CGRectMake(CGRectGetMidX(screen) + notchWidth * 0.12 - dotSize/2,
        notchY + notchHeight * 0.3, dotSize, dotSize);
    [[UIColor colorWithRed:0.15 green:0.15 blue:0.20 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:camDot] fill];
}

+ (void)drawDynamicIslandInRect:(CGRect)screen phoneWidth:(CGFloat)pw ctx:(CGContextRef)ctx {
    CGFloat pillWidth = pw * 0.26;
    CGFloat pillHeight = pw * 0.045;
    CGFloat pillX = CGRectGetMidX(screen) - pillWidth / 2;
    CGFloat pillY = screen.origin.y + pw * 0.03;

    UIBezierPath *pill = [UIBezierPath bezierPathWithRoundedRect:
        CGRectMake(pillX, pillY, pillWidth, pillHeight) cornerRadius:pillHeight / 2.0];
    [[UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0] setFill];
    [pill fill];

    // Camera dot inside pill
    CGFloat dotSize = pillHeight * 0.55;
    CGRect camDot = CGRectMake(pillX + pillWidth * 0.7 - dotSize/2,
        pillY + (pillHeight - dotSize) / 2, dotSize, dotSize);
    [[UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:camDot] fill];
}

+ (void)drawHomeButtonInRect:(CGRect)phone screenBottom:(CGFloat)screenBot phoneWidth:(CGFloat)pw ctx:(CGContextRef)ctx {
    CGFloat btnDiameter = pw * 0.16;
    CGFloat btnY = screenBot + (CGRectGetMaxY(phone) - screenBot - btnDiameter) / 2.0;
    CGRect btnRect = CGRectMake(CGRectGetMidX(phone) - btnDiameter / 2, btnY, btnDiameter, btnDiameter);

    UIBezierPath *btn = [UIBezierPath bezierPathWithOvalInRect:btnRect];
    [[UIColor colorWithRed:0.14 green:0.14 blue:0.16 alpha:1.0] setFill];
    [btn fill];

    btn.lineWidth = 0.5;
    [[UIColor colorWithWhite:1.0 alpha:0.08] setStroke];
    [btn stroke];

    // Inner rounded square (Touch ID hint)
    CGFloat innerSize = btnDiameter * 0.45;
    CGRect innerRect = CGRectMake(CGRectGetMidX(btnRect) - innerSize/2,
        CGRectGetMidY(btnRect) - innerSize/2, innerSize, innerSize);
    UIBezierPath *inner = [UIBezierPath bezierPathWithRoundedRect:innerRect cornerRadius:innerSize * 0.25];
    inner.lineWidth = 0.5;
    [[UIColor colorWithWhite:1.0 alpha:0.06] setStroke];
    [inner stroke];
}

+ (void)drawSideButtonsInRect:(CGRect)phone form:(MiOSDeviceFormFactor)form ctx:(CGContextRef)ctx {
    CGFloat btnWidth = 1.5;
    CGFloat rightX = CGRectGetMaxX(phone);

    // Power button (right side)
    CGFloat powerY = phone.origin.y + phone.size.height * 0.18;
    CGFloat powerH = phone.size.height * 0.08;
    CGRect powerRect = CGRectMake(rightX - 0.5, powerY, btnWidth, powerH);
    [[UIColor colorWithRed:0.22 green:0.22 blue:0.24 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:powerRect cornerRadius:0.5] fill];

    // Volume buttons (left side)
    CGFloat leftX = phone.origin.x - btnWidth + 0.5;
    CGFloat volUpY = phone.origin.y + phone.size.height * 0.16;
    CGFloat volH = phone.size.height * 0.055;

    CGRect volUp = CGRectMake(leftX, volUpY, btnWidth, volH);
    [[UIBezierPath bezierPathWithRoundedRect:volUp cornerRadius:0.5] fill];

    CGRect volDown = CGRectMake(leftX, volUpY + volH + phone.size.height * 0.02, btnWidth, volH);
    [[UIBezierPath bezierPathWithRoundedRect:volDown cornerRadius:0.5] fill];

    // Mute switch (only on non-Dynamic Island for simplicity, actually present on all but 16)
    if (form != MiOSDeviceFormFactorDynamicIsland) {
        CGFloat muteY = phone.origin.y + phone.size.height * 0.11;
        CGRect muteRect = CGRectMake(leftX, muteY, btnWidth, phone.size.height * 0.025);
        [[UIBezierPath bezierPathWithRoundedRect:muteRect cornerRadius:0.5] fill];
    }
}

+ (void)drawStatusBarInRect:(CGRect)screen form:(MiOSDeviceFormFactor)form accentColor:(UIColor *)color ctx:(CGContextRef)ctx {
    CGFloat dotSize = screen.size.width * 0.015;
    if (dotSize < 1) dotSize = 1;
    CGFloat barY;
    if (form == MiOSDeviceFormFactorHomeButton) {
        barY = screen.origin.y + screen.size.width * 0.04;
    } else if (form == MiOSDeviceFormFactorNotch) {
        barY = screen.origin.y + screen.size.width * 0.08;
    } else {
        barY = screen.origin.y + screen.size.width * 0.07;
    }

    // Time text placeholder (left)
    CGFloat timeW = screen.size.width * 0.12;
    CGFloat timeH = dotSize * 2;
    CGRect timeRect = CGRectMake(screen.origin.x + screen.size.width * 0.05, barY, timeW, timeH);
    UIBezierPath *timePath = [UIBezierPath bezierPathWithRoundedRect:timeRect cornerRadius:timeH / 2];
    [[UIColor colorWithWhite:1.0 alpha:0.25] setFill];
    [timePath fill];

    // Signal bars (right side)
    CGFloat barsX = CGRectGetMaxX(screen) - screen.size.width * 0.18;
    for (int i = 0; i < 4; i++) {
        CGFloat barH = timeH * (0.4 + 0.2 * i);
        CGRect barRect = CGRectMake(barsX + i * (dotSize * 1.5 + 1),
            barY + timeH - barH, dotSize * 1.5, barH);
        UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:barRect cornerRadius:0.5];
        [[UIColor colorWithWhite:1.0 alpha:0.2] setFill];
        [bar fill];
    }

    // Battery icon (far right)
    CGFloat battW = screen.size.width * 0.06;
    CGFloat battH = timeH * 0.8;
    CGRect battRect = CGRectMake(CGRectGetMaxX(screen) - screen.size.width * 0.08,
        barY + (timeH - battH) / 2, battW, battH);
    UIBezierPath *batt = [UIBezierPath bezierPathWithRoundedRect:battRect cornerRadius:1];
    batt.lineWidth = 0.5;
    [[UIColor colorWithWhite:1.0 alpha:0.2] setStroke];
    [batt stroke];

    CGRect battFill = CGRectInset(battRect, 1, 1);
    battFill.size.width *= 0.7;
    UIBezierPath *battF = [UIBezierPath bezierPathWithRoundedRect:battFill cornerRadius:0.5];
    [[color colorWithAlphaComponent:0.4] setFill];
    [battF fill];
}

@end
