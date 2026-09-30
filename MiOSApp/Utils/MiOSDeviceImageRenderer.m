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

+ (NSInteger)cameraCountForFormFactor:(MiOSDeviceFormFactor)form name:(NSString *)name {
    NSString *lower = name.lowercaseString;
    if (form == MiOSDeviceFormFactorHomeButton) {
        if ([lower containsString:@"se"]) return 1;
        if ([lower containsString:@"plus"]) return 2;
        return 1;
    }
    if ([lower containsString:@"pro"]) return 3;
    if ([lower containsString:@"16"]) return 2;
    if ([lower containsString:@"15"]) return 2;
    if ([lower containsString:@"14"]) return 2;
    if ([lower containsString:@"13 mini"] || [lower containsString:@"12 mini"]) return 2;
    if ([lower containsString:@"13"] || [lower containsString:@"12"]) return 2;
    if ([lower containsString:@"11 pro"]) return 3;
    if ([lower containsString:@"11"]) return 2;
    return 2;
}

+ (UIImage *)renderDeviceForName:(NSString *)displayName size:(CGSize)size accentColor:(UIColor *)color {
    MiOSDeviceFormFactor form = [self formFactorForDeviceName:displayName];
    NSInteger camCount = [self cameraCountForFormFactor:form name:displayName ?: @""];
    if (!color) color = [UIColor colorWithRed:0.0 green:0.82 blue:0.95 alpha:1.0];

    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;

    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];

    CGFloat phoneAspect = 0.48;
    if (form == MiOSDeviceFormFactorHomeButton) phoneAspect = 0.52;
    CGFloat phoneHeight = size.height * 0.92;
    CGFloat phoneWidth = phoneHeight * phoneAspect;
    CGFloat px = (size.width - phoneWidth) / 2.0;
    CGFloat py = (size.height - phoneHeight) / 2.0;
    CGRect phoneRect = CGRectMake(px, py, phoneWidth, phoneHeight);

    CGFloat frameRadius = phoneWidth * 0.20;
    if (form == MiOSDeviceFormFactorHomeButton) frameRadius = phoneWidth * 0.16;

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    // Drop shadow with accent glow
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), phoneWidth * 0.25,
        [color colorWithAlphaComponent:0.35].CGColor);
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:phoneRect cornerRadius:frameRadius];
    [[UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0] setFill];
    [shadowPath fill];
    CGContextRestoreGState(ctx);

    // Back body — titanium/aluminum gradient tinted by accent
    CGContextSaveGState(ctx);
    UIBezierPath *bodyPath = [UIBezierPath bezierPathWithRoundedRect:phoneRect cornerRadius:frameRadius];
    [bodyPath addClip];

    UIColor *bodyTop = [UIColor colorWithRed:0.22 + r * 0.06
                                       green:0.22 + g * 0.06
                                        blue:0.24 + b * 0.06
                                       alpha:1.0];
    UIColor *bodyMid = [UIColor colorWithRed:0.14 + r * 0.04
                                       green:0.14 + g * 0.04
                                        blue:0.16 + b * 0.04
                                       alpha:1.0];
    UIColor *bodyBot = [UIColor colorWithRed:0.10 + r * 0.03
                                       green:0.10 + g * 0.03
                                        blue:0.12 + b * 0.03
                                       alpha:1.0];

    NSArray *bodyColors = @[
        (__bridge id)bodyTop.CGColor,
        (__bridge id)bodyMid.CGColor,
        (__bridge id)bodyBot.CGColor,
    ];
    CGFloat bodyLocs[] = {0.0, 0.5, 1.0};
    CGGradientRef bodyGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)bodyColors, bodyLocs);
    CGContextDrawLinearGradient(ctx, bodyGrad,
        CGPointMake(phoneRect.origin.x, phoneRect.origin.y),
        CGPointMake(phoneRect.origin.x + phoneWidth * 0.3, CGRectGetMaxY(phoneRect)), 0);
    CGGradientRelease(bodyGrad);

    // Subtle horizontal sheen across the back
    NSArray *sheenColors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.06].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    ];
    CGFloat sheenLocs[] = {0.0, 0.5, 1.0};
    CGGradientRef sheenGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)sheenColors, sheenLocs);
    CGContextDrawLinearGradient(ctx, sheenGrad,
        CGPointMake(phoneRect.origin.x, phoneRect.origin.y + phoneHeight * 0.15),
        CGPointMake(CGRectGetMaxX(phoneRect), phoneRect.origin.y + phoneHeight * 0.45), 0);
    CGGradientRelease(sheenGrad);

    CGContextRestoreGState(ctx);

    // Edge highlight
    UIBezierPath *edgePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(phoneRect, 0.5, 0.5) cornerRadius:frameRadius - 0.5];
    edgePath.lineWidth = 0.5;
    [[UIColor colorWithWhite:1.0 alpha:0.15] setStroke];
    [edgePath stroke];

    // Camera module
    if (form == MiOSDeviceFormFactorHomeButton && camCount == 1) {
        [self drawSingleCameraInRect:phoneRect accentColor:color ctx:ctx cs:cs];
    } else if (camCount <= 2) {
        [self drawDualCameraInRect:phoneRect accentColor:color form:form ctx:ctx cs:cs];
    } else {
        [self drawTripleCameraInRect:phoneRect accentColor:color form:form ctx:ctx cs:cs];
    }

    // Apple logo (centered on back)
    [self drawAppleLogoInRect:phoneRect accentColor:color ctx:ctx];

    // Side buttons
    [self drawSideButtonsInRect:phoneRect form:form ctx:ctx];

    CGColorSpaceRelease(cs);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Camera Modules

+ (void)drawLensAtCenter:(CGPoint)center radius:(CGFloat)radius accentColor:(UIColor *)color ctx:(CGContextRef)ctx cs:(CGColorSpaceRef)cs {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];

    // Outer ring
    CGRect outerRect = CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2);
    UIBezierPath *outerRing = [UIBezierPath bezierPathWithOvalInRect:outerRect];
    [[UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0] setFill];
    [outerRing fill];
    outerRing.lineWidth = 0.5;
    [[UIColor colorWithWhite:0.3 alpha:1.0] setStroke];
    [outerRing stroke];

    // Inner glass with accent reflection
    CGFloat innerR = radius * 0.7;
    CGRect innerRect = CGRectMake(center.x - innerR, center.y - innerR, innerR * 2, innerR * 2);

    CGContextSaveGState(ctx);
    UIBezierPath *innerPath = [UIBezierPath bezierPathWithOvalInRect:innerRect];
    [innerPath addClip];

    NSArray *lensColors = @[
        (__bridge id)[UIColor colorWithRed:0.03 + r * 0.1 green:0.03 + g * 0.1 blue:0.05 + b * 0.1 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:r * 0.08 green:g * 0.08 blue:b * 0.12 alpha:1.0].CGColor,
    ];
    CGFloat lensLocs[] = {0.0, 0.5, 1.0};
    CGGradientRef lensGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)lensColors, lensLocs);
    CGContextDrawRadialGradient(ctx, lensGrad,
        CGPointMake(center.x - innerR * 0.3, center.y - innerR * 0.3), 0,
        center, innerR, 0);
    CGGradientRelease(lensGrad);
    CGContextRestoreGState(ctx);

    // Specular highlight dot
    CGFloat hlR = radius * 0.2;
    CGRect hlRect = CGRectMake(center.x - hlR - innerR * 0.25,
                               center.y - hlR - innerR * 0.25,
                               hlR * 2, hlR * 2);
    CGContextSaveGState(ctx);
    UIBezierPath *hlPath = [UIBezierPath bezierPathWithOvalInRect:hlRect];
    [hlPath addClip];
    NSArray *hlColors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.4].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    ];
    CGGradientRef hlGrad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)hlColors, NULL);
    CGContextDrawRadialGradient(ctx, hlGrad,
        CGPointMake(CGRectGetMidX(hlRect), CGRectGetMidY(hlRect)), 0,
        CGPointMake(CGRectGetMidX(hlRect), CGRectGetMidY(hlRect)), hlR, 0);
    CGGradientRelease(hlGrad);
    CGContextRestoreGState(ctx);
}

+ (void)drawFlashAtCenter:(CGPoint)center radius:(CGFloat)radius ctx:(CGContextRef)ctx {
    CGRect flashRect = CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2);
    UIBezierPath *flashPath = [UIBezierPath bezierPathWithOvalInRect:flashRect];
    [[UIColor colorWithRed:0.25 green:0.22 blue:0.15 alpha:1.0] setFill];
    [flashPath fill];
    flashPath.lineWidth = 0.3;
    [[UIColor colorWithWhite:0.4 alpha:1.0] setStroke];
    [flashPath stroke];
}

+ (void)drawLiDARAtCenter:(CGPoint)center radius:(CGFloat)radius ctx:(CGContextRef)ctx {
    CGRect rect = CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2);
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:rect];
    [[UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0] setFill];
    [path fill];
    path.lineWidth = 0.3;
    [[UIColor colorWithWhite:0.25 alpha:1.0] setStroke];
    [path stroke];
}

+ (void)drawSingleCameraInRect:(CGRect)phone accentColor:(UIColor *)color ctx:(CGContextRef)ctx cs:(CGColorSpaceRef)cs {
    CGFloat lensR = phone.size.width * 0.065;
    CGFloat cx = phone.origin.x + phone.size.width * 0.22;
    CGFloat cy = phone.origin.y + phone.size.height * 0.08;

    [self drawLensAtCenter:CGPointMake(cx, cy) radius:lensR accentColor:color ctx:ctx cs:cs];

    CGFloat flashR = lensR * 0.35;
    [self drawFlashAtCenter:CGPointMake(cx + lensR * 2.2, cy) radius:flashR ctx:ctx];
}

+ (void)drawDualCameraInRect:(CGRect)phone accentColor:(UIColor *)color form:(MiOSDeviceFormFactor)form ctx:(CGContextRef)ctx cs:(CGColorSpaceRef)cs {
    CGFloat moduleSize = phone.size.width * 0.40;
    CGFloat moduleRadius = moduleSize * 0.28;
    CGFloat moduleX = phone.origin.x + phone.size.width * 0.08;
    CGFloat moduleY = phone.origin.y + phone.size.height * 0.04;
    CGRect moduleRect = CGRectMake(moduleX, moduleY, moduleSize, moduleSize);

    // Module background (raised bump)
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 3,
        [UIColor colorWithWhite:0 alpha:0.4].CGColor);
    UIBezierPath *modulePath = [UIBezierPath bezierPathWithRoundedRect:moduleRect cornerRadius:moduleRadius];
    [[UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0] setFill];
    [modulePath fill];
    CGContextRestoreGState(ctx);

    modulePath.lineWidth = 0.5;
    [[UIColor colorWithWhite:0.28 alpha:1.0] setStroke];
    [modulePath stroke];

    CGFloat lensR = moduleSize * 0.18;
    CGFloat modCx = CGRectGetMidX(moduleRect);
    CGFloat modCy = CGRectGetMidY(moduleRect);

    // Diagonal arrangement for dual
    CGFloat offset = moduleSize * 0.16;
    [self drawLensAtCenter:CGPointMake(modCx - offset * 0.2, modCy - offset) radius:lensR accentColor:color ctx:ctx cs:cs];
    [self drawLensAtCenter:CGPointMake(modCx + offset * 0.2, modCy + offset) radius:lensR accentColor:color ctx:ctx cs:cs];

    // Flash
    CGFloat flashR = lensR * 0.3;
    [self drawFlashAtCenter:CGPointMake(modCx + offset * 1.3, modCy - offset * 0.8) radius:flashR ctx:ctx];
}

+ (void)drawTripleCameraInRect:(CGRect)phone accentColor:(UIColor *)color form:(MiOSDeviceFormFactor)form ctx:(CGContextRef)ctx cs:(CGColorSpaceRef)cs {
    CGFloat moduleSize = phone.size.width * 0.44;
    CGFloat moduleRadius = moduleSize * 0.26;
    CGFloat moduleX = phone.origin.x + phone.size.width * 0.07;
    CGFloat moduleY = phone.origin.y + phone.size.height * 0.035;
    CGRect moduleRect = CGRectMake(moduleX, moduleY, moduleSize, moduleSize);

    // Module background
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 4,
        [UIColor colorWithWhite:0 alpha:0.5].CGColor);
    UIBezierPath *modulePath = [UIBezierPath bezierPathWithRoundedRect:moduleRect cornerRadius:moduleRadius];
    [[UIColor colorWithRed:0.15 green:0.15 blue:0.17 alpha:1.0] setFill];
    [modulePath fill];
    CGContextRestoreGState(ctx);

    modulePath.lineWidth = 0.5;
    [[UIColor colorWithWhite:0.26 alpha:1.0] setStroke];
    [modulePath stroke];

    CGFloat lensR = moduleSize * 0.16;
    CGFloat modCx = CGRectGetMidX(moduleRect);
    CGFloat modCy = CGRectGetMidY(moduleRect);

    // Triangle arrangement (like iPhone Pro)
    CGFloat spread = moduleSize * 0.19;

    // Top-left lens
    [self drawLensAtCenter:CGPointMake(modCx - spread, modCy - spread * 0.6) radius:lensR accentColor:color ctx:ctx cs:cs];
    // Top-right lens
    [self drawLensAtCenter:CGPointMake(modCx + spread, modCy - spread * 0.6) radius:lensR accentColor:color ctx:ctx cs:cs];
    // Bottom-center lens
    [self drawLensAtCenter:CGPointMake(modCx, modCy + spread * 0.8) radius:lensR accentColor:color ctx:ctx cs:cs];

    // Flash (between top-right and bottom)
    CGFloat flashR = lensR * 0.28;
    [self drawFlashAtCenter:CGPointMake(modCx + spread, modCy + spread * 0.5) radius:flashR ctx:ctx];

    // LiDAR (between top-left and bottom)
    CGFloat lidarR = lensR * 0.22;
    [self drawLiDARAtCenter:CGPointMake(modCx - spread, modCy + spread * 0.5) radius:lidarR ctx:ctx];
}

#pragma mark - Apple Logo

+ (void)drawAppleLogoInRect:(CGRect)phone accentColor:(UIColor *)color ctx:(CGContextRef)ctx {
    CGFloat logoSize = phone.size.width * 0.16;
    CGFloat cx = CGRectGetMidX(phone);
    CGFloat cy = CGRectGetMidY(phone) + phone.size.height * 0.03;

    UIBezierPath *logo = [UIBezierPath bezierPath];

    CGFloat w = logoSize;
    CGFloat h = logoSize * 1.2;
    CGFloat left = cx - w / 2;
    CGFloat top = cy - h / 2;

    // Apple body
    [logo moveToPoint:CGPointMake(cx, top + h)];
    [logo addCurveToPoint:CGPointMake(left, top + h * 0.55)
            controlPoint1:CGPointMake(cx - w * 0.1, top + h * 0.88)
            controlPoint2:CGPointMake(left, top + h * 0.78)];
    [logo addCurveToPoint:CGPointMake(cx - w * 0.08, top + h * 0.18)
            controlPoint1:CGPointMake(left, top + h * 0.32)
            controlPoint2:CGPointMake(left + w * 0.15, top + h * 0.18)];
    [logo addCurveToPoint:CGPointMake(cx, top + h * 0.28)
            controlPoint1:CGPointMake(cx - w * 0.02, top + h * 0.18)
            controlPoint2:CGPointMake(cx, top + h * 0.24)];
    [logo addCurveToPoint:CGPointMake(cx + w * 0.08, top + h * 0.18)
            controlPoint1:CGPointMake(cx, top + h * 0.24)
            controlPoint2:CGPointMake(cx + w * 0.02, top + h * 0.18)];
    [logo addCurveToPoint:CGPointMake(left + w, top + h * 0.55)
            controlPoint1:CGPointMake(left + w - w * 0.15, top + h * 0.18)
            controlPoint2:CGPointMake(left + w, top + h * 0.32)];
    [logo addCurveToPoint:CGPointMake(cx, top + h)
            controlPoint1:CGPointMake(left + w, top + h * 0.78)
            controlPoint2:CGPointMake(cx + w * 0.1, top + h * 0.88)];
    [logo closePath];

    // Leaf
    UIBezierPath *leaf = [UIBezierPath bezierPath];
    [leaf moveToPoint:CGPointMake(cx + w * 0.05, top + h * 0.15)];
    [leaf addCurveToPoint:CGPointMake(cx + w * 0.3, top - h * 0.02)
            controlPoint1:CGPointMake(cx + w * 0.08, top + h * 0.04)
            controlPoint2:CGPointMake(cx + w * 0.2, top - h * 0.02)];
    [leaf addCurveToPoint:CGPointMake(cx + w * 0.05, top + h * 0.15)
            controlPoint1:CGPointMake(cx + w * 0.25, top + h * 0.06)
            controlPoint2:CGPointMake(cx + w * 0.12, top + h * 0.12)];
    [leaf closePath];

    [[UIColor colorWithWhite:1.0 alpha:0.08] setFill];
    [logo fill];
    [leaf fill];
}

#pragma mark - Side Buttons

+ (void)drawSideButtonsInRect:(CGRect)phone form:(MiOSDeviceFormFactor)form ctx:(CGContextRef)ctx {
    CGFloat btnWidth = 1.5;
    CGFloat rightX = CGRectGetMaxX(phone);

    CGFloat powerY = phone.origin.y + phone.size.height * 0.18;
    CGFloat powerH = phone.size.height * 0.08;
    CGRect powerRect = CGRectMake(rightX - 0.5, powerY, btnWidth, powerH);
    [[UIColor colorWithRed:0.24 green:0.24 blue:0.26 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:powerRect cornerRadius:0.5] fill];

    CGFloat leftX = phone.origin.x - btnWidth + 0.5;
    CGFloat volUpY = phone.origin.y + phone.size.height * 0.16;
    CGFloat volH = phone.size.height * 0.055;

    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX, volUpY, btnWidth, volH) cornerRadius:0.5] fill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX, volUpY + volH + phone.size.height * 0.02, btnWidth, volH) cornerRadius:0.5] fill];

    if (form != MiOSDeviceFormFactorDynamicIsland) {
        CGFloat muteY = phone.origin.y + phone.size.height * 0.11;
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX, muteY, btnWidth, phone.size.height * 0.025) cornerRadius:0.5] fill];
    }
}

@end
