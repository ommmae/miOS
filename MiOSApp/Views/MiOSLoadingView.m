#import "MiOSLoadingView.h"

@interface MiOSLoadingView ()
@property (nonatomic, strong) UILabel *logoLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UIView *progressBarBackground;
@property (nonatomic, strong) UIView *progressBarFill;
@property (nonatomic, strong) CAGradientLayer *progressGradient;
@property (nonatomic, strong) CAShapeLayer *ringLayer;
@property (nonatomic, strong) CAGradientLayer *ringGradientLayer;
@end

@implementation MiOSLoadingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithRed:0.03 green:0.03 blue:0.05 alpha:1.0];

    // Logo text
    self.logoLabel = [[UILabel alloc] init];
    self.logoLabel.text = @"miOS";
    self.logoLabel.font = [UIFont boldSystemFontOfSize:44];
    self.logoLabel.textColor = [UIColor whiteColor];
    self.logoLabel.textAlignment = NSTextAlignmentCenter;
    self.logoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.logoLabel];

    // Version text
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.text = @"v1.0";
    self.versionLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.versionLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.4];
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.versionLabel];

    // Progress bar background
    self.progressBarBackground = [[UIView alloc] init];
    self.progressBarBackground.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.progressBarBackground.layer.cornerRadius = 1.5;
    self.progressBarBackground.clipsToBounds = YES;
    self.progressBarBackground.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.progressBarBackground];

    // Progress bar fill
    self.progressBarFill = [[UIView alloc] init];
    self.progressBarFill.layer.cornerRadius = 1.5;
    self.progressBarFill.clipsToBounds = YES;
    self.progressBarFill.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressBarBackground addSubview:self.progressBarFill];

    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.logoLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.logoLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-20],

        [self.versionLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.logoLabel.bottomAnchor constant:8],

        [self.progressBarBackground.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.progressBarBackground.topAnchor constraintEqualToAnchor:self.versionLabel.bottomAnchor constant:24],
        [self.progressBarBackground.widthAnchor constraintEqualToConstant:140],
        [self.progressBarBackground.heightAnchor constraintEqualToConstant:3],

        [self.progressBarFill.leadingAnchor constraintEqualToAnchor:self.progressBarBackground.leadingAnchor],
        [self.progressBarFill.topAnchor constraintEqualToAnchor:self.progressBarBackground.topAnchor],
        [self.progressBarFill.bottomAnchor constraintEqualToAnchor:self.progressBarBackground.bottomAnchor],
        [self.progressBarFill.widthAnchor constraintEqualToConstant:0],
    ]];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // Update gradient ring position
    if (self.ringGradientLayer) {
        CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) - 20);
        CGFloat radius = 50;
        CGFloat size = (radius + 4) * 2;
        self.ringGradientLayer.frame = CGRectMake(center.x - size / 2, center.y - size / 2, size, size);

        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size / 2, size / 2)
                                                            radius:radius
                                                        startAngle:0
                                                          endAngle:M_PI * 2
                                                         clockwise:YES];
        self.ringLayer.path = path.CGPath;
        self.ringLayer.frame = CGRectMake(0, 0, size, size);
    }

    // Update progress bar gradient
    if (self.progressGradient) {
        self.progressGradient.frame = self.progressBarFill.bounds;
    }
}

- (void)setupGradientRing {
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) - 20);
    CGFloat radius = 50;
    CGFloat size = (radius + 4) * 2;

    // Shape layer for the ring stroke
    self.ringLayer = [CAShapeLayer layer];
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size / 2, size / 2)
                                                        radius:radius
                                                    startAngle:0
                                                      endAngle:M_PI * 2
                                                     clockwise:YES];
    self.ringLayer.path = path.CGPath;
    self.ringLayer.fillColor = [UIColor clearColor].CGColor;
    self.ringLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.ringLayer.lineWidth = 2.5;
    self.ringLayer.frame = CGRectMake(0, 0, size, size);

    // Gradient layer for the ring
    self.ringGradientLayer = [CAGradientLayer layer];
    self.ringGradientLayer.frame = CGRectMake(center.x - size / 2, center.y - size / 2, size, size);
    self.ringGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.0 green:0.82 blue:0.95 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.45 green:0.30 blue:1.0 alpha:1.0].CGColor,
    ];
    self.ringGradientLayer.startPoint = CGPointMake(0, 0);
    self.ringGradientLayer.endPoint = CGPointMake(1, 1);
    self.ringGradientLayer.mask = self.ringLayer;

    [self.layer addSublayer:self.ringGradientLayer];

    // Rotation animation
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.fromValue = @0;
    rotation.toValue = @(M_PI * 2);
    rotation.duration = 2.0;
    rotation.repeatCount = HUGE_VALF;
    rotation.removedOnCompletion = NO;
    [self.ringGradientLayer addAnimation:rotation forKey:@"rotateRing"];
}

- (void)setupProgressGradient {
    self.progressGradient = [CAGradientLayer layer];
    self.progressGradient.colors = @[
        (id)[UIColor colorWithRed:0.0 green:0.82 blue:0.95 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.45 green:0.30 blue:1.0 alpha:1.0].CGColor,
    ];
    self.progressGradient.startPoint = CGPointMake(0, 0.5);
    self.progressGradient.endPoint = CGPointMake(1, 0.5);
    self.progressGradient.frame = CGRectMake(0, 0, 140, 3);
    [self.progressBarFill.layer addSublayer:self.progressGradient];
}

- (void)startAnimation {
    [self layoutIfNeeded];

    [self setupGradientRing];
    [self setupProgressGradient];

    // Animate progress bar fill width from 0 to 140
    NSLayoutConstraint *widthConstraint = nil;
    for (NSLayoutConstraint *c in self.progressBarFill.constraints) {
        if (c.firstAttribute == NSLayoutAttributeWidth && c.firstItem == self.progressBarFill) {
            widthConstraint = c;
            break;
        }
    }

    if (widthConstraint) {
        widthConstraint.constant = 140;
        [UIView animateWithDuration:1.5
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self layoutIfNeeded];
            self.progressGradient.frame = CGRectMake(0, 0, 140, 3);
        }
                         completion:^(BOOL finished) {
            // Fade out after progress completes
            [UIView animateWithDuration:0.4
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.alpha = 0;
            }
                             completion:^(BOOL finished) {
                if (self.onComplete) {
                    self.onComplete();
                }
            }];
        }];
    }
}

@end
