#import "MiOSUI.h"
#import "MiOSTheme.h"
#import "MiOSContainer.h"
#import "MiOSDeviceDB.h"
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#pragma mark - Helpers

static UIWindow *MiOSKeyWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if ([app respondsToSelector:@selector(connectedScenes)]) {
        for (UIScene *s in app.connectedScenes) {
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            if (s.activationState == UISceneActivationStateUnattached) continue;
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) return w;
        }
        for (UIScene *s in app.connectedScenes) {
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)s;
            if (ws.windows.count) return ws.windows.lastObject;
        }
    }
    for (UIWindow *w in app.windows) if (w.isKeyWindow) return w;
    return app.windows.lastObject;
}
static UIViewController *MiOSTopVC(void) {
    UIViewController *vc = MiOSKeyWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}
static void MiOSRelaunch(NSString *message) {
    UIViewController *top = MiOSTopVC();
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Restart Required"
        message:message ?: @"The container is applied when Instagram launches. The app will close now."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Close Now" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *x){ exit(0); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [top presentViewController:a animated:YES completion:nil];
}
static UIImpactFeedbackGenerator *MiOSHaptic(void) {
    static UIImpactFeedbackGenerator *g;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight]; [g prepare]; });
    return g;
}

#pragma mark - MiOSNebulaBackgroundView

@interface MiOSNebulaBackgroundView : UIView
@end
@implementation MiOSNebulaBackgroundView {
    CAGradientLayer *_base;
    CAGradientLayer *_nebula1;
    CAGradientLayer *_nebula2;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor blackColor];
        _base = [CAGradientLayer layer];
        _base.colors = @[
            (id)[UIColor colorWithRed:0.10 green:0.02 blue:0.18 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.04 green:0.03 blue:0.08 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0].CGColor,
        ];
        _base.locations = @[@0.0, @0.5, @1.0];
        [self.layer addSublayer:_base];

        _nebula1 = [CAGradientLayer layer];
        _nebula1.type = kCAGradientLayerRadial;
        _nebula1.colors = @[
            (id)[[UIColor systemPurpleColor] colorWithAlphaComponent:0.25].CGColor,
            (id)[UIColor clearColor].CGColor,
        ];
        _nebula1.startPoint = CGPointMake(0.5, 0.5);
        _nebula1.endPoint   = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_nebula1];

        _nebula2 = [CAGradientLayer layer];
        _nebula2.type = kCAGradientLayerRadial;
        _nebula2.colors = @[
            (id)[[UIColor systemIndigoColor] colorWithAlphaComponent:0.18].CGColor,
            (id)[UIColor clearColor].CGColor,
        ];
        _nebula2.startPoint = CGPointMake(0.5, 0.5);
        _nebula2.endPoint   = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_nebula2];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    _base.frame = b;
    CGFloat w = b.size.width * 1.4;
    _nebula1.frame = CGRectMake(-w * 0.15, -w * 0.1, w, w);
    _nebula2.frame = CGRectMake(b.size.width * 0.25, b.size.height * 0.2, w * 0.9, w * 0.9);
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) return;
    [_nebula1 removeAllAnimations];
    [_nebula2 removeAllAnimations];
    CABasicAnimation *d1 = [CABasicAnimation animationWithKeyPath:@"position"];
    d1.fromValue = [NSValue valueWithCGPoint:_nebula1.position];
    d1.toValue   = [NSValue valueWithCGPoint:CGPointMake(_nebula1.position.x + 30, _nebula1.position.y + 20)];
    d1.duration = 8; d1.autoreverses = YES; d1.repeatCount = HUGE_VALF;
    d1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_nebula1 addAnimation:d1 forKey:@"drift"];
    CABasicAnimation *d2 = [CABasicAnimation animationWithKeyPath:@"position"];
    d2.fromValue = [NSValue valueWithCGPoint:_nebula2.position];
    d2.toValue   = [NSValue valueWithCGPoint:CGPointMake(_nebula2.position.x - 25, _nebula2.position.y - 15)];
    d2.duration = 10; d2.autoreverses = YES; d2.repeatCount = HUGE_VALF;
    d2.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_nebula2 addAnimation:d2 forKey:@"drift"];
}
@end

#pragma mark - MiOSFloatingTabBar

@interface MiOSFloatingTabBar : UIView
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^onSelect)(NSInteger);
@end
@implementation MiOSFloatingTabBar {
    NSArray<UIButton *> *_buttons;
    UIView *_indicator;
    UIVisualEffectView *_blur;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];

        _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];
        _blur.translatesAutoresizingMaskIntoConstraints = NO;
        _blur.layer.cornerRadius = 28;
        _blur.clipsToBounds = YES;
        _blur.layer.borderWidth = 0.5;
        _blur.layer.borderColor = [MiOSTheme cardBorder].CGColor;
        [self addSubview:_blur];

        _indicator = [UIView new];
        _indicator.backgroundColor = [[MiOSTheme accent] colorWithAlphaComponent:0.18];
        _indicator.layer.cornerRadius = 20;
        _indicator.layer.cornerCurve = kCACornerCurveContinuous;
        [_blur.contentView addSubview:_indicator];

        NSArray *icons = @[@"house.fill", @"square.stack.3d.up", @"mappin.and.ellipse", @"cloud.fill", @"gearshape.fill"];
        NSMutableArray *btns = [NSMutableArray array];
        for (NSInteger i = 0; i < (NSInteger)icons.count; i++) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            [b setImage:[MiOSTheme symbol:icons[i] size:19] forState:UIControlStateNormal];
            b.tintColor = (i == 0) ? [MiOSTheme accent] : [MiOSTheme textSecondary];
            b.tag = i;
            [b addTarget:self action:@selector(_tapped:) forControlEvents:UIControlEventTouchUpInside];
            b.translatesAutoresizingMaskIntoConstraints = NO;
            [_blur.contentView addSubview:b];
            [btns addObject:b];
        }
        _buttons = btns;
        _selectedIndex = 0;

        [NSLayoutConstraint activateConstraints:@[
            [_blur.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_blur.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_blur.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_blur.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];
        UIButton *prev = nil;
        for (NSInteger i = 0; i < (NSInteger)_buttons.count; i++) {
            UIButton *b = _buttons[i];
            [b.centerYAnchor constraintEqualToAnchor:_blur.contentView.centerYAnchor].active = YES;
            [b.widthAnchor constraintEqualToConstant:48].active = YES;
            [b.heightAnchor constraintEqualToConstant:48].active = YES;
            if (i == 0) [b.leadingAnchor constraintEqualToAnchor:_blur.contentView.leadingAnchor constant:6].active = YES;
            else [b.leadingAnchor constraintEqualToAnchor:prev.trailingAnchor constant:2].active = YES;
            if (i == (NSInteger)_buttons.count - 1) [b.trailingAnchor constraintEqualToAnchor:_blur.contentView.trailingAnchor constant:-6].active = YES;
            prev = b;
        }
    }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 56); }
- (void)layoutSubviews { [super layoutSubviews]; [self _moveIndicator:NO]; }
- (void)_tapped:(UIButton *)s {
    if (s.tag == _selectedIndex) return;
    [MiOSHaptic() impactOccurred];
    _selectedIndex = s.tag;
    [self _moveIndicator:YES];
    if (self.onSelect) self.onSelect(s.tag);
}
- (void)setSelectedIndex:(NSInteger)idx {
    _selectedIndex = idx;
    [self _moveIndicator:YES];
}
- (void)_moveIndicator:(BOOL)animated {
    for (NSInteger i = 0; i < (NSInteger)_buttons.count; i++)
        _buttons[i].tintColor = (i == _selectedIndex) ? [MiOSTheme accent] : [MiOSTheme textSecondary];
    UIButton *sel = _buttons[_selectedIndex];
    void (^m)(void) = ^{ self->_indicator.frame = CGRectInset(sel.frame, -1, -1); };
    if (animated) [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:m completion:nil];
    else m();
}
@end

#pragma mark - MiOSHeroBannerView

@interface MiOSHeroBannerView : UIView
@end
@implementation MiOSHeroBannerView {
    CAGradientLayer *_grad;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _grad = [CAGradientLayer layer];
        _grad.colors = @[
            (id)[[MiOSTheme accent] colorWithAlphaComponent:0.35].CGColor,
            (id)[[MiOSTheme accentGradientEnd] colorWithAlphaComponent:0.15].CGColor,
            (id)[UIColor clearColor].CGColor,
        ];
        _grad.locations = @[@0.0, @0.6, @1.0];
        _grad.cornerRadius = [MiOSTheme cardCornerRadius];
        [self.layer addSublayer:_grad];
        self.layer.cornerRadius = [MiOSTheme cardCornerRadius];
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [MiOSTheme accentBorder].CGColor;

        UILabel *sub = [UILabel new];
        sub.text = @"CONTAINERS"; sub.font = [MiOSTheme captionBold]; sub.textColor = [MiOSTheme accent];
        sub.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *title = [UILabel new];
        title.text = @"miOS"; title.font = [MiOSTheme largeTitleFont]; title.textColor = [MiOSTheme text];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *tag = [UILabel new];
        tag.text = @"MORE APPS. MORE FREEDOM."; tag.font = [MiOSTheme captionFont]; tag.textColor = [MiOSTheme textSecondary];
        tag.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:sub]; [self addSubview:title]; [self addSubview:tag];
        [NSLayoutConstraint activateConstraints:@[
            [sub.topAnchor constraintEqualToAnchor:self.topAnchor constant:18],
            [sub.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [title.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:4],
            [title.leadingAnchor constraintEqualToAnchor:sub.leadingAnchor],
            [tag.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
            [tag.leadingAnchor constraintEqualToAnchor:sub.leadingAnchor],
            [tag.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-18],
        ]];
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; _grad.frame = self.bounds; }
@end

#pragma mark - MiOSContainerTileCell

@interface MiOSContainerTileCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIView *accentBar;
@property (nonatomic, strong) UIImageView *plusIcon;
@property (nonatomic, strong) UILabel *plusLabel;
@end
@implementation MiOSContainerTileCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        UIView *cv = self.contentView;
        cv.layer.cornerRadius = [MiOSTheme tileCornerRadius];
        cv.layer.cornerCurve = kCACornerCurveContinuous;
        cv.layer.borderWidth = 0.5;
        cv.layer.borderColor = [MiOSTheme cardBorder].CGColor;
        cv.backgroundColor = [MiOSTheme tileBackground];

        _accentBar = [UIView new]; _accentBar.backgroundColor = [MiOSTheme accent];
        _accentBar.layer.cornerRadius = 1.5; _accentBar.translatesAutoresizingMaskIntoConstraints = NO;
        _accentBar.hidden = YES; [cv addSubview:_accentBar];

        _nameLabel = [UILabel new]; _nameLabel.font = [MiOSTheme headline]; _nameLabel.textColor = [MiOSTheme text];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO; [cv addSubview:_nameLabel];

        _statusDot = [UIView new]; _statusDot.layer.cornerRadius = 4;
        _statusDot.translatesAutoresizingMaskIntoConstraints = NO; _statusDot.hidden = YES; [cv addSubview:_statusDot];

        _statusLabel = [UILabel new]; _statusLabel.font = [MiOSTheme captionBold];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO; [cv addSubview:_statusLabel];

        _detailLabel = [UILabel new]; _detailLabel.font = [MiOSTheme captionFont];
        _detailLabel.textColor = [MiOSTheme textSecondary]; _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _detailLabel.numberOfLines = 2; [cv addSubview:_detailLabel];

        _plusIcon = [[UIImageView alloc] initWithImage:[MiOSTheme symbol:@"plus" size:26 color:[MiOSTheme accent]]];
        _plusIcon.translatesAutoresizingMaskIntoConstraints = NO; _plusIcon.hidden = YES; [cv addSubview:_plusIcon];
        _plusLabel = [UILabel new]; _plusLabel.text = @"New Container";
        _plusLabel.font = [MiOSTheme subhead]; _plusLabel.textColor = [MiOSTheme accent];
        _plusLabel.textAlignment = NSTextAlignmentCenter;
        _plusLabel.translatesAutoresizingMaskIntoConstraints = NO; _plusLabel.hidden = YES; [cv addSubview:_plusLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_accentBar.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor],
            [_accentBar.topAnchor constraintEqualToAnchor:cv.topAnchor constant:12],
            [_accentBar.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-12],
            [_accentBar.widthAnchor constraintEqualToConstant:3],
            [_nameLabel.topAnchor constraintEqualToAnchor:cv.topAnchor constant:14],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:14],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-14],
            [_statusDot.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_statusDot.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:6],
            [_statusDot.widthAnchor constraintEqualToConstant:8],
            [_statusDot.heightAnchor constraintEqualToConstant:8],
            [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:5],
            [_statusLabel.centerYAnchor constraintEqualToAnchor:_statusDot.centerYAnchor],
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_detailLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],
            [_detailLabel.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-14],
            [_plusIcon.centerXAnchor constraintEqualToAnchor:cv.centerXAnchor],
            [_plusIcon.centerYAnchor constraintEqualToAnchor:cv.centerYAnchor constant:-12],
            [_plusLabel.topAnchor constraintEqualToAnchor:_plusIcon.bottomAnchor constant:6],
            [_plusLabel.centerXAnchor constraintEqualToAnchor:cv.centerXAnchor],
        ]];
    }
    return self;
}
- (void)prepareForReuse {
    [super prepareForReuse];
    _accentBar.hidden = YES; _statusDot.hidden = YES; _plusIcon.hidden = YES; _plusLabel.hidden = YES;
    _nameLabel.hidden = NO; _statusLabel.hidden = NO; _detailLabel.hidden = NO;
    self.contentView.backgroundColor = [MiOSTheme tileBackground];
    self.contentView.layer.borderWidth = 0.5;
    self.contentView.layer.borderColor = [MiOSTheme cardBorder].CGColor;
}
- (void)configureWithContainer:(MiOSContainer *)c isActive:(BOOL)active {
    _plusIcon.hidden = YES; _plusLabel.hidden = YES;
    _nameLabel.hidden = NO; _statusDot.hidden = NO; _statusLabel.hidden = NO; _detailLabel.hidden = NO;
    _nameLabel.text = c.name;
    if (active) {
        _statusDot.backgroundColor = [MiOSTheme statusGreen];
        _statusLabel.text = @"ACTIVE"; _statusLabel.textColor = [MiOSTheme statusGreen];
        _accentBar.hidden = NO;
        self.contentView.layer.borderColor = [MiOSTheme accentBorder].CGColor;
        self.contentView.layer.borderWidth = 1.0;
    } else {
        _statusDot.backgroundColor = [MiOSTheme statusGray];
        _statusLabel.text = @"STANDBY"; _statusLabel.textColor = [MiOSTheme statusGray];
        _accentBar.hidden = YES;
        self.contentView.layer.borderColor = [MiOSTheme cardBorder].CGColor;
        self.contentView.layer.borderWidth = 0.5;
    }
    NSMutableString *det = [NSMutableString string];
    if (c.deviceDisplayName.length) [det appendString:c.deviceDisplayName];
    if (c.iosVersion.length) [det appendFormat:det.length ? @" · iOS %@" : @"iOS %@", c.iosVersion];
    _detailLabel.text = det.length ? det : @"No device set";
}
- (void)configureAsNewContainer {
    _nameLabel.hidden = YES; _statusDot.hidden = YES; _statusLabel.hidden = YES; _detailLabel.hidden = YES;
    _accentBar.hidden = YES;
    _plusIcon.hidden = NO; _plusLabel.hidden = NO;
    self.contentView.backgroundColor = [[MiOSTheme accent] colorWithAlphaComponent:0.06];
    self.contentView.layer.borderColor = [MiOSTheme accentBorder].CGColor;
    self.contentView.layer.borderWidth = 1.0;
}
@end

#pragma mark - Base cell (shared icon-bubble setup)

@interface MiOSBaseCell : UITableViewCell
@property (nonatomic, strong) UIView *bubble;
@property (nonatomic, strong) UIImageView *bubbleIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
- (void)setBubbleSymbol:(NSString *)name color:(UIColor *)color;
@end
@implementation MiOSBaseCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:r])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _bubble = [UIView new]; _bubble.translatesAutoresizingMaskIntoConstraints = NO;
        _bubble.layer.cornerRadius = 10; _bubble.layer.cornerCurve = kCACornerCurveContinuous;
        [self.contentView addSubview:_bubble];
        _bubbleIcon = [UIImageView new]; _bubbleIcon.contentMode = UIViewContentModeScaleAspectFit;
        _bubbleIcon.translatesAutoresizingMaskIntoConstraints = NO; [_bubble addSubview:_bubbleIcon];
        _titleLabel = [UILabel new]; _titleLabel.font = [MiOSTheme bodyFont]; _titleLabel.textColor = [MiOSTheme text];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:_titleLabel];
        _subtitleLabel = [UILabel new]; _subtitleLabel.font = [MiOSTheme captionFont];
        _subtitleLabel.textColor = [MiOSTheme textSecondary]; _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.hidden = YES; [self.contentView addSubview:_subtitleLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_bubble.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_bubble.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_bubble.widthAnchor constraintEqualToConstant:36],
            [_bubble.heightAnchor constraintEqualToConstant:36],
            [_bubbleIcon.centerXAnchor constraintEqualToAnchor:_bubble.centerXAnchor],
            [_bubbleIcon.centerYAnchor constraintEqualToAnchor:_bubble.centerYAnchor],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:1],
        ]];
    }
    return self;
}
- (void)setBubbleSymbol:(NSString *)name color:(UIColor *)color {
    _bubble.backgroundColor = [color colorWithAlphaComponent:0.15];
    _bubbleIcon.image = [MiOSTheme symbol:name size:17 color:color];
}
@end

#pragma mark - MiOSToggleCell

@interface MiOSToggleCell : MiOSBaseCell
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, copy) void (^onToggle)(BOOL);
- (void)setSymbol:(NSString *)sym tint:(UIColor *)tint title:(NSString *)title subtitle:(NSString *)sub;
@end
@implementation MiOSToggleCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:s reuseIdentifier:r])) {
        _toggle = [UISwitch new]; _toggle.onTintColor = [MiOSTheme accent];
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggle addTarget:self action:@selector(_toggled) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggle];
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.bubble.trailingAnchor constant:12],
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
            [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-8],
            [_toggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
    }
    return self;
}
- (void)_toggled { [MiOSHaptic() impactOccurred]; if (self.onToggle) self.onToggle(self.toggle.isOn); }
- (void)setSymbol:(NSString *)sym tint:(UIColor *)tint title:(NSString *)title subtitle:(NSString *)sub {
    [self setBubbleSymbol:sym color:tint ?: [MiOSTheme accent]];
    self.titleLabel.text = title;
    self.subtitleLabel.text = sub; self.subtitleLabel.hidden = (sub.length == 0);
}
@end

#pragma mark - MiOSNavCell

@interface MiOSNavCell : MiOSBaseCell
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIImageView *chevron;
- (void)setSymbol:(NSString *)sym tint:(UIColor *)tint title:(NSString *)title value:(NSString *)value;
@end
@implementation MiOSNavCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:s reuseIdentifier:r])) {
        _valueLabel = [UILabel new]; _valueLabel.font = [MiOSTheme bodyFont]; _valueLabel.textColor = [MiOSTheme textSecondary];
        _valueLabel.textAlignment = NSTextAlignmentRight; _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_valueLabel];
        _chevron = [[UIImageView alloc] initWithImage:[MiOSTheme symbol:@"chevron.right" size:13 color:[MiOSTheme textSecondary]]];
        _chevron.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:_chevron];
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.bubble.trailingAnchor constant:12],
            [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevron.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_chevron.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:_chevron.leadingAnchor constant:-6],
            [_valueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.trailingAnchor constant:8],
        ]];
    }
    return self;
}
- (void)setSymbol:(NSString *)sym tint:(UIColor *)tint title:(NSString *)t value:(NSString *)v {
    [self setBubbleSymbol:sym color:tint ?: [MiOSTheme accent]];
    self.titleLabel.text = t; _valueLabel.text = v;
}
@end

#pragma mark - MiOSFieldCell

@interface MiOSFieldCell : MiOSBaseCell <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, copy) void (^onChange)(NSString *);
- (void)setSymbol:(NSString *)s title:(NSString *)t value:(NSString *)v placeholder:(NSString *)ph;
@end
@implementation MiOSFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:s reuseIdentifier:r])) {
        _field = [UITextField new]; _field.font = [MiOSTheme bodyFont]; _field.textColor = [MiOSTheme textSecondary];
        _field.textAlignment = NSTextAlignmentRight;
        _field.autocorrectionType = UITextAutocorrectionTypeNo;
        _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _field.clearButtonMode = UITextFieldViewModeWhileEditing; _field.delegate = self;
        _field.translatesAutoresizingMaskIntoConstraints = NO;
        [_field addTarget:self action:@selector(_changed) forControlEvents:UIControlEventEditingChanged];
        [self.contentView addSubview:_field];
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.bubble.trailingAnchor constant:12],
            [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_field.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:8],
            [_field.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_field.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_field.widthAnchor constraintGreaterThanOrEqualToConstant:120],
        ]];
    }
    return self;
}
- (void)_changed { if (self.onChange) self.onChange(self.field.text ?: @""); }
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }
- (void)setSymbol:(NSString *)s title:(NSString *)t value:(NSString *)v placeholder:(NSString *)ph {
    [self setBubbleSymbol:s color:[MiOSTheme accent]];
    self.titleLabel.text = t; _field.text = v; _field.placeholder = ph ?: @"";
}
@end

#pragma mark - PanModal presentation

@interface MiOSPanModalPC : UIPresentationController
@property (nonatomic, strong) UIView *dimView;
@end
@implementation MiOSPanModalPC
- (CGRect)frameOfPresentedViewInContainerView {
    CGRect b = self.containerView.bounds;
    CGFloat h = b.size.height * 0.88;
    return CGRectMake(0, b.size.height - h, b.size.width, h);
}
- (void)presentationTransitionWillBegin {
    self.dimView = [[UIView alloc] initWithFrame:self.containerView.bounds];
    self.dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.dimView.alpha = 0;
    self.dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:self.dimView];
    [self.dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dismiss)]];
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> c) {
        self.dimView.alpha = 1;
    } completion:nil];
    self.presentedView.layer.cornerRadius = 24;
    self.presentedView.layer.cornerCurve = kCACornerCurveContinuous;
    self.presentedView.layer.masksToBounds = YES;
}
- (void)_dismiss { [self.presentingViewController dismissViewControllerAnimated:YES completion:nil]; }
- (void)dismissalTransitionWillBegin {
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> c) {
        self.dimView.alpha = 0;
    } completion:nil];
}
@end

@interface MiOSPanModalDelegate : NSObject <UIViewControllerTransitioningDelegate> @end
@implementation MiOSPanModalDelegate
+ (instancetype)shared { static MiOSPanModalDelegate *d; static dispatch_once_t o; dispatch_once(&o, ^{ d = [self new]; }); return d; }
- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)p
        presentingViewController:(UIViewController *)pr sourceViewController:(UIViewController *)s {
    return [[MiOSPanModalPC alloc] initWithPresentedViewController:p presentingViewController:pr];
}
@end

#pragma mark - MiOSPickerVC

@interface MiOSPickerVC : UITableViewController
@property (nonatomic, copy) NSArray<NSString *> *options;
@property (nonatomic, copy) NSString *selected;
@property (nonatomic, copy) void (^onPick)(NSString *);
@end
@implementation MiOSPickerVC
- (instancetype)init { return [super initWithStyle:UITableViewStylePlain]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];
    self.tableView.backgroundColor = [MiOSTheme background];
    self.tableView.separatorColor = [MiOSTheme separator]; self.tableView.rowHeight = 48;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.options.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"c"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
        c.backgroundColor = [MiOSTheme cardBackground]; c.textLabel.textColor = [MiOSTheme text];
        c.tintColor = [MiOSTheme accent];
        c.selectedBackgroundView = [UIView new];
        c.selectedBackgroundView.backgroundColor = [MiOSTheme secondaryBackground];
    }
    NSString *opt = self.options[ip.row];
    c.textLabel.text = opt;
    c.accessoryType = [opt isEqualToString:self.selected] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [MiOSHaptic() impactOccurred];
    if (self.onPick) self.onPick(self.options[ip.row]);
    [self.navigationController popViewControllerAnimated:YES];
}
@end

#pragma mark - MiOSHomeVC

@interface MiOSHomeVC : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<MiOSContainer *> *containers;
@property (nonatomic, copy) void (^onSelectContainer)(MiOSContainer *);
@property (nonatomic, strong) UIView *emptyView;
@end
@implementation MiOSHomeVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    UICollectionViewFlowLayout *fl = [UICollectionViewFlowLayout new];
    fl.minimumInteritemSpacing = 12; fl.minimumLineSpacing = 12;
    fl.sectionInset = UIEdgeInsetsMake(12, 16, 80, 16);
    fl.headerReferenceSize = CGSizeMake(0, 116);
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:fl];
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.dataSource = self; _collectionView.delegate = self;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.alwaysBounceVertical = YES;
    [_collectionView registerClass:[MiOSContainerTileCell class] forCellWithReuseIdentifier:@"tile"];
    [_collectionView registerClass:[UICollectionReusableView class]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"hdr"];
    [self.view addSubview:_collectionView];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_collectionView.topAnchor constraintEqualToAnchor:g.topAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    _emptyView = [UIView new]; _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.hidden = YES; [self.view addSubview:_emptyView];
    UIImageView *eIcon = [[UIImageView alloc] initWithImage:[MiOSTheme symbol:@"shippingbox" size:48 color:[MiOSTheme textSecondary]]];
    eIcon.translatesAutoresizingMaskIntoConstraints = NO; [_emptyView addSubview:eIcon];
    UILabel *eTitle = [UILabel new]; eTitle.text = @"No Containers Yet"; eTitle.font = [MiOSTheme headline];
    eTitle.textColor = [MiOSTheme text]; eTitle.translatesAutoresizingMaskIntoConstraints = NO; [_emptyView addSubview:eTitle];
    UILabel *eSub = [UILabel new]; eSub.text = @"Create your first container to get started.";
    eSub.font = [MiOSTheme captionFont]; eSub.textColor = [MiOSTheme textSecondary];
    eSub.translatesAutoresizingMaskIntoConstraints = NO; [_emptyView addSubview:eSub];
    [NSLayoutConstraint activateConstraints:@[
        [_emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [eIcon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [eIcon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [eTitle.topAnchor constraintEqualToAnchor:eIcon.bottomAnchor constant:12],
        [eTitle.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [eSub.topAnchor constraintEqualToAnchor:eTitle.bottomAnchor constant:4],
        [eSub.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [eSub.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_longPress:)];
    [_collectionView addGestureRecognizer:lp];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self _reload];
}
- (void)_reload {
    self.containers = [[MiOSContainer loadAll] mutableCopy];
    _emptyView.hidden = self.containers.count > 0;
    _collectionView.hidden = self.containers.count == 0;
    [_collectionView reloadData];
}
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s {
    return self.containers.count + 1;
}
- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat w = (cv.bounds.size.width - 16 * 2 - 12) / 2;
    return CGSizeMake(w, 110);
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)cv
    viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)ip {
    UICollectionReusableView *hdr = [cv dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"hdr" forIndexPath:ip];
    if (![hdr viewWithTag:999]) {
        MiOSHeroBannerView *banner = [[MiOSHeroBannerView alloc] initWithFrame:CGRectZero];
        banner.translatesAutoresizingMaskIntoConstraints = NO; banner.tag = 999;
        [hdr addSubview:banner];
        [NSLayoutConstraint activateConstraints:@[
            [banner.topAnchor constraintEqualToAnchor:hdr.topAnchor],
            [banner.leadingAnchor constraintEqualToAnchor:hdr.leadingAnchor constant:16],
            [banner.trailingAnchor constraintEqualToAnchor:hdr.trailingAnchor constant:-16],
            [banner.bottomAnchor constraintEqualToAnchor:hdr.bottomAnchor constant:-4],
        ]];
    }
    return hdr;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    MiOSContainerTileCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"tile" forIndexPath:ip];
    if (ip.item < (NSInteger)self.containers.count) {
        MiOSContainer *c = self.containers[ip.item];
        BOOL active = [[MiOSContainer activeContainerID] isEqualToString:c.identifier];
        [cell configureWithContainer:c isActive:active];
    } else {
        [cell configureAsNewContainer];
    }
    return cell;
}
- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [MiOSHaptic() impactOccurred];
    if (ip.item >= (NSInteger)self.containers.count) {
        MiOSContainer *c = [MiOSContainer newRandomContainerNamed:
            [NSString stringWithFormat:@"Container %lu", (unsigned long)(self.containers.count + 1)]];
        [c save];
        [self _reload];
        if (self.onSelectContainer) self.onSelectContainer(c);
        return;
    }
    MiOSContainer *c = self.containers[ip.item];
    if (self.onSelectContainer) self.onSelectContainer(c);
}
- (void)_longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:_collectionView];
    NSIndexPath *ip = [_collectionView indexPathForItemAtPoint:p];
    if (!ip || ip.item >= (NSInteger)self.containers.count) return;
    MiOSContainer *c = self.containers[ip.item];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:c.name message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL isActive = [[MiOSContainer activeContainerID] isEqualToString:c.identifier];
    if (!isActive) {
        [a addAction:[UIAlertAction actionWithTitle:@"Activate & Restart" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
            [c containerRootEnsureCreated:YES];
            [MiOSContainer setActiveContainerID:c.identifier];
            exit(0);
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        UIAlertController *r = [UIAlertController alertControllerWithTitle:@"Rename Container"
            message:nil preferredStyle:UIAlertControllerStyleAlert];
        [r addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = c.name; }];
        [r addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *y){
            NSString *n = r.textFields.firstObject.text;
            if (n.length) { c.name = n; [c save]; [self _reload]; }
        }]];
        [r addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:r animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){
        BOOL wasActive = isActive;
        [MiOSContainer removeContainerWithID:c.identifier];
        [self _reload];
        if (wasActive) MiOSRelaunch(@"Active container deleted. Restart to continue.");
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

#pragma mark - MiOSSpoofVC (fingerprint + proxy editor)

typedef NS_ENUM(NSInteger, MiOSSpoofSec) {
    MiOSSecMode = 0,
    MiOSSecDevice,
    MiOSSecIdentifiers,
    MiOSSecNetwork,
    MiOSSecModules,
    MiOSSecProxy,
    MiOSSecRandomize,
    MiOSSecCount,
};

@interface MiOSSpoofVC : UITableViewController
@property (nonatomic, strong) MiOSContainer *container;
@end
@implementation MiOSSpoofVC
- (instancetype)initWithContainer:(MiOSContainer *)c {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) _container = c;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [MiOSTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 64, 0, 0);
    [self.tableView registerClass:[MiOSToggleCell class] forCellReuseIdentifier:@"tc"];
    [self.tableView registerClass:[MiOSNavCell class]    forCellReuseIdentifier:@"nc"];
    [self.tableView registerClass:[MiOSFieldCell class]  forCellReuseIdentifier:@"fc"];
    self.tableView.rowHeight = 56;

    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 70)];
    UILabel *nm = [UILabel new]; nm.text = self.container.name;
    nm.font = [MiOSTheme titleFont]; nm.textColor = [MiOSTheme text];
    nm.frame = CGRectMake(16, 8, 200, 28);
    UILabel *dt = [UILabel new];
    dt.text = self.container.deviceDisplayName.length ? self.container.deviceDisplayName : @"Select a device model";
    dt.font = [MiOSTheme captionFont]; dt.textColor = [MiOSTheme textSecondary];
    dt.frame = CGRectMake(16, 38, 250, 18);
    BOOL isActive = [[MiOSContainer activeContainerID] isEqualToString:self.container.identifier];
    UIButton *ab = [UIButton buttonWithType:UIButtonTypeCustom];
    [ab setTitle:isActive ? @"Active" : @"Activate" forState:UIControlStateNormal];
    ab.titleLabel.font = [MiOSTheme captionBold];
    ab.backgroundColor = isActive ? [MiOSTheme statusGreen] : [MiOSTheme accent];
    [ab setTitleColor:[MiOSTheme textOnAccent] forState:UIControlStateNormal];
    ab.layer.cornerRadius = 14;
    ab.frame = CGRectMake(h.bounds.size.width - 100, 16, 84, 28);
    ab.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    if (!isActive) [ab addTarget:self action:@selector(_activate) forControlEvents:UIControlEventTouchUpInside];
    [h addSubview:nm]; [h addSubview:dt]; [h addSubview:ab];
    self.tableView.tableHeaderView = h;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}
- (void)_activate {
    [self.container containerRootEnsureCreated:YES];
    [MiOSContainer setActiveContainerID:self.container.identifier];
    exit(0);
}
- (void)_save { [self.container save]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return MiOSSecCount; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    switch (s) {
        case MiOSSecMode: return @"MODE";
        case MiOSSecDevice: return @"DEVICE FINGERPRINT";
        case MiOSSecIdentifiers: return @"IDENTIFIERS";
        case MiOSSecNetwork: return @"CARRIER · CELLULAR · WIFI";
        case MiOSSecModules: return @"MODULES";
        case MiOSSecProxy: return @"PROXY (BETA)";
        default: return @"RANDOMIZE";
    }
}
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    UIView *v = [UIView new];
    UILabel *l = [UILabel new]; l.text = [self tableView:t titleForHeaderInSection:s];
    l.textColor = [MiOSTheme accent]; l.font = [MiOSTheme captionBold];
    l.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:l];
    [l.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16].active = YES;
    [l.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-6].active = YES;
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 36; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s { return [UIView new]; }
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { return 4; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case MiOSSecMode: return 1;
        case MiOSSecDevice: return 7;
        case MiOSSecIdentifiers: return 4;
        case MiOSSecNetwork: return 5;
        case MiOSSecModules: return 7;
        case MiOSSecProxy: return 5;
        case MiOSSecRandomize: return 2;
        default: return 0;
    }
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    __weak typeof(self) ws = self;
    MiOSContainer *m = self.container;

    switch (ip.section) {
    case MiOSSecMode: {
        MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
        [c setSymbol:@"shield.lefthalf.filled" tint:[MiOSTheme accent] title:@"Spoof Mode"
            subtitle:@"Apply this container's fingerprint"];
        c.toggle.on = m.enableSpoof;
        c.onToggle = ^(BOOL on){ ws.container.enableSpoof = on; [ws _save]; };
        return c;
    }
    case MiOSSecDevice: {
        if (ip.row == 0) {
            MiOSNavCell *c = [t dequeueReusableCellWithIdentifier:@"nc" forIndexPath:ip];
            [c setSymbol:@"iphone" tint:[MiOSTheme accent] title:@"Model"
                value:m.deviceDisplayName.length ? m.deviceDisplayName : @"Choose"];
            return c;
        }
        if (ip.row == 1) {
            MiOSNavCell *c = [t dequeueReusableCellWithIdentifier:@"nc" forIndexPath:ip];
            [c setSymbol:@"info.circle" tint:[MiOSTheme accent] title:@"iOS Version"
                value:m.iosVersion.length ? m.iosVersion : @"Choose"];
            return c;
        }
        if (ip.row == 2) {
            MiOSNavCell *c = [t dequeueReusableCellWithIdentifier:@"nc" forIndexPath:ip];
            [c setSymbol:@"terminal" tint:[MiOSTheme accent] title:@"Kernel"
                value:m.enableSpoofKernelVersion ? @"Spoofed" : @"Real"];
            return c;
        }
        if (ip.row == 3) {
            MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
            [c setSymbol:@"memorychip" tint:[MiOSTheme accent] title:@"Memory"
                subtitle:m.ramGB > 0 ? [NSString stringWithFormat:@"%ld GB", (long)m.ramGB] : @"From model"];
            c.toggle.on = m.enableSpoofMemory;
            c.onToggle = ^(BOOL on){ ws.container.enableSpoofMemory = on; [ws _save]; };
            return c;
        }
        if (ip.row == 4) {
            MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
            [c setSymbol:@"cpu" tint:[MiOSTheme accent] title:@"Processor"
                subtitle:m.cpuCores > 0 ? [NSString stringWithFormat:@"%ld cores · %@", (long)m.cpuCores, m.chipName ?: @""] : @"From model"];
            c.toggle.on = m.enableSpoofProcessor;
            c.onToggle = ^(BOOL on){ ws.container.enableSpoofProcessor = on; [ws _save]; };
            return c;
        }
        if (ip.row == 5) {
            MiOSFieldCell *c = [t dequeueReusableCellWithIdentifier:@"fc" forIndexPath:ip];
            [c setSymbol:@"textformat" title:@"Device Name" value:m.deviceName placeholder:@"iPhone"];
            c.onChange = ^(NSString *v){ ws.container.deviceName = v; ws.container.enableSpoofDeviceName = v.length > 0; [ws _save]; };
            return c;
        }
        MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
        [c setSymbol:@"battery.100" tint:[MiOSTheme accent] title:@"Battery"
            subtitle:m.enableSpoofBatteryLevel ? [NSString stringWithFormat:@"%ld%%", (long)m.batteryLevel] : @"Real"];
        c.toggle.on = m.enableSpoofBatteryLevel;
        c.onToggle = ^(BOOL on){ ws.container.enableSpoofBatteryLevel = on; [ws _save]; };
        return c;
    }
    case MiOSSecIdentifiers: {
        MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
        switch (ip.row) {
            case 0:
                [c setSymbol:@"person.text.rectangle" tint:[MiOSTheme accent] title:@"Vendor ID (IDFV)" subtitle:m.vendorID];
                c.toggle.on = m.enableSpoofVendorID;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofVendorID = on;
                    if (on && ws.container.vendorID.length == 0) ws.container.vendorID = [NSUUID UUID].UUIDString;
                    [ws _save]; [ws.tableView reloadData]; }; break;
            case 1:
                [c setSymbol:@"a.square" tint:[MiOSTheme accent] title:@"Advertising ID" subtitle:m.advertisingID];
                c.toggle.on = m.enableSpoofAdvertisingID;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofAdvertisingID = on;
                    if (on && ws.container.advertisingID.length == 0) ws.container.advertisingID = [NSUUID UUID].UUIDString;
                    [ws _save]; [ws.tableView reloadData]; }; break;
            case 2:
                [c setSymbol:@"checkmark.shield" tint:[MiOSTheme accent] title:@"Block DeviceCheck"
                    subtitle:@"DCDevice → unsupported"];
                c.toggle.on = m.enableSpoofDeviceCheck;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofDeviceCheck = on; [ws _save]; }; break;
            default:
                [c setSymbol:@"icloud.slash" tint:[MiOSTheme accent] title:@"Hide iCloud Token"
                    subtitle:@"ubiquityIdentityToken → nil"];
                c.toggle.on = m.enableSpoofCloudToken;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofCloudToken = on; [ws _save]; }; break;
        }
        return c;
    }
    case MiOSSecNetwork: {
        MiOSToggleCell *tc = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
        switch (ip.row) {
            case 0:
                [tc setSymbol:@"antenna.radiowaves.left.and.right" tint:[MiOSTheme accent] title:@"Carrier"
                    subtitle:m.carrierName.length ? [NSString stringWithFormat:@"%@ %@", m.carrierFlag ?: @"", m.carrierName] : @"Random"];
                tc.toggle.on = m.enableSpoofCarrier;
                tc.onToggle = ^(BOOL on){ ws.container.enableSpoofCarrier = on;
                    if (on && ws.container.carrierName.length == 0) [ws.container randomizeCarrier];
                    [ws _save]; [ws.tableView reloadData]; }; break;
            case 1:
                [tc setSymbol:@"dot.radiowaves.right" tint:[MiOSTheme accent] title:@"Cellular Type"
                    subtitle:m.cellularType.length ? m.cellularType : @"Random"];
                tc.toggle.on = m.enableSpoofCellularType;
                tc.onToggle = ^(BOOL on){ ws.container.enableSpoofCellularType = on; [ws _save]; }; break;
            case 2:
                [tc setSymbol:@"network" tint:[MiOSTheme accent] title:@"Cellular IP"
                    subtitle:m.cellularAddress.length ? m.cellularAddress : @"Random"];
                tc.toggle.on = m.enableSpoofCellular;
                tc.onToggle = ^(BOOL on){ ws.container.enableSpoofCellular = on;
                    if (on && ws.container.cellularAddress.length == 0) [ws.container randomizeCellular];
                    [ws _save]; [ws.tableView reloadData]; }; break;
            case 3:
                [tc setSymbol:@"wifi" tint:[MiOSTheme accent] title:@"Wi-Fi"
                    subtitle:m.wifiSSID.length ? [NSString stringWithFormat:@"%@ · %@", m.wifiSSID, m.wifiBSSID] : @"Random"];
                tc.toggle.on = m.enableSpoofWiFi;
                tc.onToggle = ^(BOOL on){ ws.container.enableSpoofWiFi = on;
                    if (on && ws.container.wifiSSID.length == 0) [ws.container randomizeWiFi];
                    [ws _save]; [ws.tableView reloadData]; }; break;
            default: {
                MiOSFieldCell *fc = [t dequeueReusableCellWithIdentifier:@"fc" forIndexPath:ip];
                [fc setSymbol:@"globe" title:@"Wi-Fi IP" value:m.wifiAddress placeholder:@"192.168.1.42"];
                fc.onChange = ^(NSString *v){ ws.container.wifiAddress = v; [ws _save]; };
                return fc;
            }
        }
        return tc;
    }
    case MiOSSecModules: {
        MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
        switch (ip.row) {
            case 0:
                [c setSymbol:@"globe" tint:[MiOSTheme accent] title:@"Locale & TimeZone"
                    subtitle:m.localeID.length ? [NSString stringWithFormat:@"%@ · %@", m.localeID, m.timeZoneID] : @"Random"];
                c.toggle.on = m.enableSpoofLocale;
                c.onToggle = ^(BOOL on){
                    ws.container.enableSpoofLocale = on; ws.container.enableSpoofTimeZone = on;
                    if (on && ws.container.localeID.length == 0) [ws.container randomizeLocale];
                    [ws _save]; [ws.tableView reloadData]; }; break;
            case 1:
                [c setSymbol:@"sun.max" tint:[MiOSTheme accent] title:@"Brightness"
                    subtitle:[NSString stringWithFormat:@"%.0f%%", m.brightnessLevel * 100]];
                c.toggle.on = m.enableSpoofBrightness;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofBrightness = on; [ws _save]; }; break;
            case 2:
                [c setSymbol:@"bolt.slash" tint:[MiOSTheme accent] title:@"Low Power Mode"
                    subtitle:m.lowPowerModeEnabled ? @"Enabled" : @"Disabled"];
                c.toggle.on = m.enableSpoofLowPowerMode;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofLowPowerMode = on; [ws _save]; }; break;
            case 3:
                [c setSymbol:@"gyroscope" tint:[MiOSTheme accent] title:@"Gyroscope" subtitle:@"Random x/y/z each read"];
                c.toggle.on = m.enableSpoofGyroscope;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofGyroscope = on; [ws _save]; }; break;
            case 4:
                [c setSymbol:@"camera.metering.unknown" tint:[MiOSTheme accent] title:@"Screenshot Detection"
                    subtitle:@"Suppress screenshot events"];
                c.toggle.on = m.enableSpoofScreenshot;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofScreenshot = on; [ws _save]; }; break;
            case 5:
                [c setSymbol:@"envelope.badge.shield.half.filled" tint:[MiOSTheme accent] title:@"Mail / Messages"
                    subtitle:@"canSendMail / canSendText → false"];
                c.toggle.on = m.enableSpoofMail && m.enableSpoofMessage;
                c.onToggle = ^(BOOL on){
                    ws.container.enableSpoofMail = on; ws.container.mailAvailable = NO;
                    ws.container.enableSpoofMessage = on; ws.container.messageAvailable = NO; [ws _save]; }; break;
            default:
                [c setSymbol:@"eye.slash" tint:[MiOSTheme accent] title:@"Anti-Detection"
                    subtitle:@"Hide jailbreak probes"];
                c.toggle.on = m.enableDisableDetection;
                c.onToggle = ^(BOOL on){ ws.container.enableDisableDetection = on; [ws _save]; }; break;
        }
        return c;
    }
    case MiOSSecProxy: {
        if (ip.row == 0) {
            MiOSToggleCell *c = [t dequeueReusableCellWithIdentifier:@"tc" forIndexPath:ip];
            [c setSymbol:@"arrow.triangle.branch" tint:[MiOSTheme accent] title:@"Enable Proxy"
                subtitle:@"Route traffic through HTTPS proxy"];
            c.toggle.on = m.enableProxy;
            c.onToggle = ^(BOOL on){ ws.container.enableProxy = on; [ws _save]; };
            return c;
        }
        MiOSFieldCell *f = [t dequeueReusableCellWithIdentifier:@"fc" forIndexPath:ip];
        switch (ip.row) {
            case 1: [f setSymbol:@"server.rack" title:@"Host" value:m.proxyHost placeholder:@"proxy.example.com"];
                f.onChange = ^(NSString *v){ ws.container.proxyHost = v; [ws _save]; }; break;
            case 2: [f setSymbol:@"number" title:@"Port" value:m.proxyPort > 0 ? [NSString stringWithFormat:@"%ld", (long)m.proxyPort] : @""
                    placeholder:@"8080"];
                f.field.keyboardType = UIKeyboardTypeNumberPad;
                f.onChange = ^(NSString *v){ ws.container.proxyPort = v.integerValue; [ws _save]; }; break;
            case 3: [f setSymbol:@"person" title:@"Username" value:m.proxyUsername placeholder:@"optional"];
                f.onChange = ^(NSString *v){ ws.container.proxyUsername = v; [ws _save]; }; break;
            default: [f setSymbol:@"key" title:@"Password" value:m.proxyPassword placeholder:@"optional"];
                f.field.secureTextEntry = YES;
                f.onChange = ^(NSString *v){ ws.container.proxyPassword = v; [ws _save]; }; break;
        }
        return f;
    }
    default: {
        MiOSNavCell *c = [t dequeueReusableCellWithIdentifier:@"nc" forIndexPath:ip];
        if (ip.row == 0) {
            [c setSymbol:@"shuffle.circle" tint:[MiOSTheme accent] title:@"Randomize Full Fingerprint" value:@""];
            c.titleLabel.textColor = [MiOSTheme accent];
        } else {
            [c setSymbol:@"die.face.5" tint:[MiOSTheme textSecondary] title:@"Randomize Single Module…" value:@""];
        }
        return c;
    }
    }
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    __weak typeof(self) ws = self;
    MiOSContainer *m = self.container;

    if (ip.section == MiOSSecDevice && ip.row == 0) {
        NSMutableArray *names = [NSMutableArray array];
        for (MiOSDeviceModel *d in [MiOSDeviceDatabase allDevices]) [names addObject:d.displayName];
        MiOSPickerVC *p = [MiOSPickerVC new];
        p.title = @"Choose iPhone"; p.options = names; p.selected = m.deviceDisplayName;
        p.onPick = ^(NSString *v) {
            for (MiOSDeviceModel *d in [MiOSDeviceDatabase allDevices])
                if ([d.displayName isEqualToString:v]) { [ws.container applyDeviceModelIdentifier:d.identifier iosVersion:nil]; break; }
            [ws _save]; [ws.tableView reloadData];
        };
        [self.navigationController pushViewController:p animated:YES];
    } else if (ip.section == MiOSSecDevice && ip.row == 1) {
        MiOSDeviceModel *d = [MiOSDeviceDatabase deviceForIdentifier:m.deviceIdentifier];
        NSArray *vers = d ? [MiOSDeviceDatabase supportedIOSVersionsForDevice:d] : [MiOSDeviceDatabase allIOSVersions];
        MiOSPickerVC *p = [MiOSPickerVC new];
        p.title = @"Choose iOS Version"; p.options = vers; p.selected = m.iosVersion;
        p.onPick = ^(NSString *v){ ws.container.iosVersion = v; ws.container.enableSpoofSoftwareVersion = YES; [ws _save]; [ws.tableView reloadData]; };
        [self.navigationController pushViewController:p animated:YES];
    } else if (ip.section == MiOSSecDevice && ip.row == 2) {
        [m randomizeKernelVersion]; [self _save]; [t reloadData];
    } else if (ip.section == MiOSSecRandomize) {
        if (ip.row == 0) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Randomize Full Fingerprint?"
                message:@"Replace every spoofed value with a fresh random one." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Randomize" style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *x){ [m randomizeAllModules]; [self _save]; [t reloadData]; }]];
            [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        } else {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Randomize Module" message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];
            for (NSString *mod in @[@"device",@"identifiers",@"carrier",@"wifi",@"cellular",@"locale",@"kernel",@"battery",@"brightness",@"gyroscope"])
                [a addAction:[UIAlertAction actionWithTitle:mod style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *x){ [m randomizeModule:mod]; [self _save]; [t reloadData]; }]];
            [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        }
    }
}
@end

#pragma mark - MiOSLocationVC (GPS spoofer)

@interface MiOSLocationVC : UIViewController <MKMapViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) MiOSContainer *container;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UISwitch *enableToggle;
@property (nonatomic, strong) UITextField *latField;
@property (nonatomic, strong) UITextField *lonField;
@property (nonatomic, strong) UILabel *placeLabel;
@end
@implementation MiOSLocationVC
- (instancetype)initWithContainer:(MiOSContainer *)c { if ((self = [super init])) _container = c; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    _scroll = [UIScrollView new]; _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _scroll.alwaysBounceVertical = YES;
    [self.view addSubview:_scroll];
    UILayoutGuide *sg = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll.topAnchor constraintEqualToAnchor:sg.topAnchor],
        [_scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    UIView *content = [UIView new]; content.translatesAutoresizingMaskIntoConstraints = NO;
    [_scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:_scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:_scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:_scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:_scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:_scroll.widthAnchor],
    ]];

    UIView *searchCard = [UIView new]; searchCard.translatesAutoresizingMaskIntoConstraints = NO;
    [MiOSTheme applyCardStyleTo:searchCard];
    [content addSubview:searchCard];
    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[MiOSTheme symbol:@"magnifyingglass" size:16 color:[MiOSTheme textSecondary]]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO; [searchCard addSubview:searchIcon];
    _searchField = [UITextField new]; _searchField.placeholder = @"Search location...";
    _searchField.font = [MiOSTheme bodyFont]; _searchField.textColor = [MiOSTheme text];
    _searchField.returnKeyType = UIReturnKeySearch; _searchField.delegate = self;
    _searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    _searchField.translatesAutoresizingMaskIntoConstraints = NO; [searchCard addSubview:_searchField];

    _mapView = [MKMapView new]; _mapView.delegate = self;
    _mapView.translatesAutoresizingMaskIntoConstraints = NO;
    _mapView.layer.cornerRadius = [MiOSTheme cardCornerRadius];
    _mapView.layer.cornerCurve = kCACornerCurveContinuous; _mapView.clipsToBounds = YES;
    [_mapView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_longPressed:)]];
    [content addSubview:_mapView];

    UIView *coordCard = [UIView new]; coordCard.translatesAutoresizingMaskIntoConstraints = NO;
    [MiOSTheme applyCardStyleTo:coordCard]; [content addSubview:coordCard];

    UILabel *eLbl = [UILabel new]; eLbl.text = @"Spoof Location"; eLbl.font = [MiOSTheme bodyFont];
    eLbl.textColor = [MiOSTheme text]; eLbl.translatesAutoresizingMaskIntoConstraints = NO;
    _enableToggle = [UISwitch new]; _enableToggle.onTintColor = [MiOSTheme accent];
    _enableToggle.on = self.container.spoofLocation;
    [_enableToggle addTarget:self action:@selector(_toggle) forControlEvents:UIControlEventValueChanged];
    _enableToggle.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *sep = [UIView new]; sep.backgroundColor = [MiOSTheme separator];
    sep.translatesAutoresizingMaskIntoConstraints = NO;

    _latField = [UITextField new]; _latField.placeholder = @"Latitude";
    _latField.keyboardType = UIKeyboardTypeDecimalPad; _latField.textColor = [MiOSTheme text];
    _latField.font = [MiOSTheme bodyFont]; _latField.translatesAutoresizingMaskIntoConstraints = NO;
    [_latField addTarget:self action:@selector(_fieldChanged) forControlEvents:UIControlEventEditingChanged];
    _lonField = [UITextField new]; _lonField.placeholder = @"Longitude";
    _lonField.keyboardType = UIKeyboardTypeDecimalPad; _lonField.textColor = [MiOSTheme text];
    _lonField.font = [MiOSTheme bodyFont]; _lonField.translatesAutoresizingMaskIntoConstraints = NO;
    [_lonField addTarget:self action:@selector(_fieldChanged) forControlEvents:UIControlEventEditingChanged];

    _placeLabel = [UILabel new]; _placeLabel.font = [MiOSTheme captionFont];
    _placeLabel.textColor = [MiOSTheme textSecondary]; _placeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _placeLabel.text = self.container.locationName;

    [coordCard addSubview:eLbl]; [coordCard addSubview:_enableToggle]; [coordCard addSubview:sep];
    [coordCard addSubview:_latField]; [coordCard addSubview:_lonField]; [coordCard addSubview:_placeLabel];

    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [resetBtn setTitle:@"  Reset to Real Location" forState:UIControlStateNormal];
    [resetBtn setImage:[MiOSTheme symbol:@"xmark.circle" size:16 color:[MiOSTheme destructive]] forState:UIControlStateNormal];
    [resetBtn setTitleColor:[MiOSTheme destructive] forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [MiOSTheme bodyFont];
    resetBtn.backgroundColor = [MiOSTheme cardBackground];
    resetBtn.layer.cornerRadius = [MiOSTheme cardCornerRadius];
    resetBtn.layer.borderWidth = 0.5; resetBtn.layer.borderColor = [MiOSTheme cardBorder].CGColor;
    resetBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [resetBtn addTarget:self action:@selector(_reset) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:resetBtn];

    CGFloat pad = 16;
    [NSLayoutConstraint activateConstraints:@[
        [searchCard.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
        [searchCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:pad],
        [searchCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-pad],
        [searchCard.heightAnchor constraintEqualToConstant:44],
        [searchIcon.leadingAnchor constraintEqualToAnchor:searchCard.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchCard.centerYAnchor],
        [_searchField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [_searchField.trailingAnchor constraintEqualToAnchor:searchCard.trailingAnchor constant:-12],
        [_searchField.centerYAnchor constraintEqualToAnchor:searchCard.centerYAnchor],

        [_mapView.topAnchor constraintEqualToAnchor:searchCard.bottomAnchor constant:12],
        [_mapView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:pad],
        [_mapView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-pad],
        [_mapView.heightAnchor constraintEqualToConstant:260],

        [coordCard.topAnchor constraintEqualToAnchor:_mapView.bottomAnchor constant:12],
        [coordCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:pad],
        [coordCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-pad],
        [eLbl.topAnchor constraintEqualToAnchor:coordCard.topAnchor constant:12],
        [eLbl.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [_enableToggle.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],
        [_enableToggle.centerYAnchor constraintEqualToAnchor:eLbl.centerYAnchor],
        [sep.topAnchor constraintEqualToAnchor:eLbl.bottomAnchor constant:10],
        [sep.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [sep.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],
        [sep.heightAnchor constraintEqualToConstant:0.5],
        [_latField.topAnchor constraintEqualToAnchor:sep.bottomAnchor constant:10],
        [_latField.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [_latField.widthAnchor constraintEqualToAnchor:coordCard.widthAnchor multiplier:0.5 constant:-18],
        [_lonField.topAnchor constraintEqualToAnchor:_latField.topAnchor],
        [_lonField.leadingAnchor constraintEqualToAnchor:_latField.trailingAnchor constant:8],
        [_lonField.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],
        [_placeLabel.topAnchor constraintEqualToAnchor:_latField.bottomAnchor constant:8],
        [_placeLabel.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [_placeLabel.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],
        [_placeLabel.bottomAnchor constraintEqualToAnchor:coordCard.bottomAnchor constant:-12],

        [resetBtn.topAnchor constraintEqualToAnchor:coordCard.bottomAnchor constant:12],
        [resetBtn.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:pad],
        [resetBtn.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-pad],
        [resetBtn.heightAnchor constraintEqualToConstant:48],
        [resetBtn.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-80],
    ]];
    [self _loadFromContainer];
}
- (void)_loadFromContainer {
    CLLocationCoordinate2D c = self.container.coordinate;
    if (c.latitude != 0 || c.longitude != 0) {
        [self _setPinAt:c save:NO];
        [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 1500, 1500) animated:NO];
        self.latField.text = [NSString stringWithFormat:@"%.6f", c.latitude];
        self.lonField.text = [NSString stringWithFormat:@"%.6f", c.longitude];
    }
}
- (void)_toggle { self.container.spoofLocation = self.enableToggle.isOn; [self.container save]; }
- (void)_fieldChanged {
    double lat = self.latField.text.doubleValue, lon = self.lonField.text.doubleValue;
    [self _setPinAt:CLLocationCoordinate2DMake(lat, lon) save:YES];
}
- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    if (tf == _searchField && _searchField.text.length > 0) {
        [tf resignFirstResponder];
        CLGeocoder *gc = [CLGeocoder new];
        [gc geocodeAddressString:_searchField.text completionHandler:^(NSArray<CLPlacemark *> *marks, NSError *err) {
            CLPlacemark *m = marks.firstObject;
            if (!m) return;
            CLLocationCoordinate2D c = m.location.coordinate;
            [self _setPinAt:c save:YES];
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 1500, 1500) animated:YES];
            self.latField.text = [NSString stringWithFormat:@"%.6f", c.latitude];
            self.lonField.text = [NSString stringWithFormat:@"%.6f", c.longitude];
        }];
    }
    [tf resignFirstResponder];
    return YES;
}
- (void)_longPressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:self.mapView];
    CLLocationCoordinate2D c = [self.mapView convertPoint:p toCoordinateFromView:self.mapView];
    [self _setPinAt:c save:YES];
    self.latField.text = [NSString stringWithFormat:@"%.6f", c.latitude];
    self.lonField.text = [NSString stringWithFormat:@"%.6f", c.longitude];
    [MiOSHaptic() impactOccurred];
}
- (void)_setPinAt:(CLLocationCoordinate2D)c save:(BOOL)save {
    if (!self.pin) { self.pin = [MKPointAnnotation new]; [self.mapView addAnnotation:self.pin]; }
    self.pin.coordinate = c;
    if (save) {
        self.container.coordinate = c; self.container.spoofLocation = YES;
        self.enableToggle.on = YES; [self.container save];
        [self _reverseGeocode:c];
    }
}
- (void)_reverseGeocode:(CLLocationCoordinate2D)c {
    CLGeocoder *g = [CLGeocoder new];
    [g reverseGeocodeLocation:[[CLLocation alloc] initWithLatitude:c.latitude longitude:c.longitude]
            completionHandler:^(NSArray<CLPlacemark *> *marks, NSError *err){
        CLPlacemark *m = marks.firstObject;
        NSString *name = m.name ? [NSString stringWithFormat:@"%@, %@", m.name, m.country ?: @""] : @"";
        self.container.locationName = name;
        self.container.locationCountryCode = m.ISOcountryCode ?: @"";
        self.placeLabel.text = name;
        [self.container save];
    }];
}
- (void)_reset {
    self.container.coordinate = CLLocationCoordinate2DMake(0, 0);
    self.container.spoofLocation = NO; self.container.locationName = @"";
    self.enableToggle.on = NO; self.latField.text = @""; self.lonField.text = @"";
    self.placeLabel.text = @"";
    if (self.pin) { [self.mapView removeAnnotation:self.pin]; self.pin = nil; }
    [self.container save];
}
@end

#pragma mark - MiOSCloudVC (coming soon)

@interface MiOSCloudVC : UIViewController @end
@implementation MiOSCloudVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[MiOSTheme symbol:@"cloud.fill" size:52 color:[MiOSTheme textSecondary]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:icon];
    UILabel *t = [UILabel new]; t.text = @"Cloud Sync"; t.font = [MiOSTheme headline]; t.textColor = [MiOSTheme text];
    t.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:t];
    UILabel *s = [UILabel new]; s.text = @"Coming Soon"; s.font = [MiOSTheme captionFont]; s.textColor = [MiOSTheme textSecondary];
    s.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:s];
    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        [t.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [t.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [s.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:4],
        [s.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];
}
@end

#pragma mark - MiOSSettingsVC

@interface MiOSSettingsVC : UITableViewController @end
@implementation MiOSSettingsVC
- (instancetype)init { return [super initWithStyle:UITableViewStyleGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [MiOSTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 64, 0, 0);
    [self.tableView registerClass:[MiOSNavCell class] forCellReuseIdentifier:@"nc"];
    self.tableView.rowHeight = 56;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 3; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    if (s == 0) return 2; if (s == 1) return 3; return 2;
}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return @"ISOLATION"; if (s == 1) return @"ABOUT"; return @"DATA";
}
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    UIView *v = [UIView new];
    UILabel *l = [UILabel new]; l.text = [self tableView:t titleForHeaderInSection:s];
    l.textColor = [MiOSTheme accent]; l.font = [MiOSTheme captionBold];
    l.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:l];
    [l.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16].active = YES;
    [l.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-6].active = YES;
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 36; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s { return [UIView new]; }
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { return 4; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    MiOSNavCell *c = [t dequeueReusableCellWithIdentifier:@"nc" forIndexPath:ip];
    BOOL hasActive = [MiOSContainer activeContainerID].length > 0;
    if (ip.section == 0 && ip.row == 0) {
        [c setSymbol:@"folder.fill.badge.gearshape" tint:[MiOSTheme accent] title:@"File Isolation"
            value:hasActive ? @"Active" : @"Off"];
        c.chevron.hidden = YES;
    } else if (ip.section == 0 && ip.row == 1) {
        [c setSymbol:@"key.fill" tint:[MiOSTheme accent] title:@"Keychain Isolation"
            value:hasActive ? @"Active" : @"Off"];
        c.chevron.hidden = YES;
    } else if (ip.section == 1 && ip.row == 0) {
        [c setSymbol:@"info.circle" tint:[MiOSTheme accent] title:@"Version" value:@"2.0.0"];
        c.chevron.hidden = YES;
    } else if (ip.section == 1 && ip.row == 1) {
        [c setSymbol:@"app.badge" tint:[MiOSTheme accent] title:@"Target" value:@"com.burbn.instagram"];
        c.chevron.hidden = YES;
    } else if (ip.section == 1 && ip.row == 2) {
        [c setSymbol:@"text.alignleft" tint:[MiOSTheme textSecondary] title:@"Description" value:@""];
        c.chevron.hidden = YES;
        c.subtitleLabel.text = @"Instagram-only spoof engine";
        c.subtitleLabel.hidden = NO;
    } else if (ip.section == 2 && ip.row == 0) {
        [c setSymbol:@"trash" tint:[MiOSTheme destructive] title:@"Reset All Settings" value:@""];
        c.titleLabel.textColor = [MiOSTheme destructive];
    } else {
        [c setSymbol:@"arrow.counterclockwise" tint:[MiOSTheme accent] title:@"Restart App" value:@""];
    }
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 2 && ip.row == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset miOS?"
            message:@"This erases every container, every spoof setting, and every snapshot. Cannot be undone."
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Erase Everything" style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *x){ [MiOSContainer resetAll]; MiOSRelaunch(@"miOS has been reset. Restart Instagram."); }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    } else if (ip.section == 2 && ip.row == 1) {
        MiOSRelaunch(@"Close Instagram and reopen it.");
    }
}
@end

#pragma mark - MiOSMainVC (tab host with nebula + floating tab bar)

@interface MiOSMainVC : UIViewController
@property (nonatomic, strong) MiOSNebulaBackgroundView *nebula;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) MiOSFloatingTabBar *tabBar;
@property (nonatomic, strong) UIView *grabber;
@property (nonatomic, strong) NSMutableArray *tabVCs;
@property (nonatomic, strong) UIViewController *currentVC;
@end
@implementation MiOSMainVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];

    _nebula = [[MiOSNebulaBackgroundView alloc] initWithFrame:self.view.bounds];
    _nebula.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_nebula];

    _grabber = [UIView new]; _grabber.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
    _grabber.layer.cornerRadius = 2.5; _grabber.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_grabber];

    UILabel *title = [UILabel new]; title.text = @"miOS";
    title.font = [MiOSTheme titleFont]; title.textColor = [MiOSTheme text];
    title.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[MiOSTheme symbol:@"xmark.circle.fill" size:22 color:[MiOSTheme textSecondary]] forState:UIControlStateNormal];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(_close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    _contentView = [UIView new]; _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentView.clipsToBounds = YES; [self.view addSubview:_contentView];

    _tabBar = [[MiOSFloatingTabBar alloc] initWithFrame:CGRectZero];
    _tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) ws = self;
    _tabBar.onSelect = ^(NSInteger idx) { [ws _switchToTab:idx]; };
    [self.view addSubview:_tabBar];

    [NSLayoutConstraint activateConstraints:@[
        [_grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [_grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_grabber.widthAnchor constraintEqualToConstant:40], [_grabber.heightAnchor constraintEqualToConstant:5],
        [title.topAnchor constraintEqualToAnchor:_grabber.bottomAnchor constant:10],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [close.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_contentView.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [_contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_tabBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
        [_tabBar.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_tabBar.heightAnchor constraintEqualToConstant:56],
    ]];

    [self _buildTabs];
    [self _switchToTab:0];
}

- (MiOSContainer *)_activeOrFirst {
    MiOSContainer *a = [MiOSContainer activeContainer];
    if (a) return a;
    NSArray *all = [MiOSContainer loadAll];
    return all.firstObject;
}

- (void)_buildTabs {
    MiOSContainer *active = [self _activeOrFirst] ?: [MiOSContainer newRandomContainerNamed:@"Container 1"];
    if (![MiOSContainer loadAll].count) [active save];

    MiOSHomeVC *homeVC = [MiOSHomeVC new];
    __weak typeof(self) ws = self;
    homeVC.onSelectContainer = ^(MiOSContainer *c) {
        [ws _showSpoofFor:c];
    };

    MiOSSpoofVC *spoofVC = [[MiOSSpoofVC alloc] initWithContainer:active];
    UINavigationController *spoofNav = [[UINavigationController alloc] initWithRootViewController:spoofVC];
    spoofNav.navigationBar.barStyle = UIBarStyleBlack;
    spoofNav.navigationBar.tintColor = [MiOSTheme accent];
    spoofNav.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [MiOSTheme text]};
    [spoofNav.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    spoofNav.navigationBar.shadowImage = [UIImage new];
    spoofNav.navigationBar.translucent = YES;
    [spoofNav setNavigationBarHidden:YES animated:NO];

    MiOSLocationVC *locVC = [[MiOSLocationVC alloc] initWithContainer:active];
    MiOSCloudVC *cloudVC = [MiOSCloudVC new];
    MiOSSettingsVC *settVC = [MiOSSettingsVC new];

    _tabVCs = [@[homeVC, spoofNav, locVC, cloudVC, settVC] mutableCopy];
}

- (void)_showSpoofFor:(MiOSContainer *)c {
    MiOSSpoofVC *spoofVC = [[MiOSSpoofVC alloc] initWithContainer:c];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:spoofVC];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.tintColor = [MiOSTheme accent];
    nav.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [MiOSTheme text]};
    [nav.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    nav.navigationBar.shadowImage = [UIImage new];
    nav.navigationBar.translucent = YES;
    [nav setNavigationBarHidden:YES animated:NO];
    _tabVCs[1] = nav;

    MiOSLocationVC *locVC = [[MiOSLocationVC alloc] initWithContainer:c];
    _tabVCs[2] = locVC;

    _tabBar.selectedIndex = 1;
    [self _switchToTab:1];
}

- (void)_switchToTab:(NSInteger)idx {
    UIViewController *next = _tabVCs[idx];
    if (_currentVC == next) return;
    if (_currentVC) {
        [_currentVC willMoveToParentViewController:nil];
        [_currentVC.view removeFromSuperview];
        [_currentVC removeFromParentViewController];
    }
    [self addChildViewController:next];
    next.view.frame = _contentView.bounds;
    next.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    next.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, 64, 0);
    [_contentView addSubview:next.view];
    [next didMoveToParentViewController:self];
    _currentVC = next;
}

- (void)_close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - Floating button + installer

@interface MiOSOverlayWindow : UIWindow @end
@implementation MiOSOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *sub in self.rootViewController.view.subviews) {
        if (!sub.hidden && sub.alpha > 0 && sub.userInteractionEnabled &&
            [sub pointInside:[self convertPoint:point toView:sub] withEvent:event])
            return YES;
    }
    return NO;
}
@end

@interface MiOSOverlayVC : UIViewController @end
@implementation MiOSOverlayVC
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
@end

@interface MiOSFloatingButton : UIButton @end
@implementation MiOSFloatingButton @end

@implementation MiOSUI

static MiOSOverlayWindow *gOverlayWindow = nil;
static MiOSFloatingButton *gButton = nil;
static BOOL gInstalled = NO;

+ (void)install {
    if (gInstalled) return;
    gInstalled = YES;
    NSArray<NSNotificationName> *names = @[
        UIApplicationDidBecomeActiveNotification,
        UIApplicationDidFinishLaunchingNotification,
        UIWindowDidBecomeKeyNotification,
        @"UISceneDidActivateNotification",
    ];
    for (NSNotificationName n in names) {
        [[NSNotificationCenter defaultCenter] addObserverForName:n object:nil
            queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *_){ [self attachButton]; }];
    }
    for (NSNumber *delay in @[@0.5, @2.0, @5.0, @10.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self attachButton]; });
    }
}

+ (UIWindowScene *)activeWindowScene {
    UIApplication *app = UIApplication.sharedApplication;
    if (![app respondsToSelector:@selector(connectedScenes)]) return nil;
    for (UIScene *s in app.connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        if (s.activationState == UISceneActivationStateForegroundActive) return (UIWindowScene *)s;
    }
    for (UIScene *s in app.connectedScenes) {
        if (![s isKindOfClass:[UIWindowScene class]]) continue;
        if (s.activationState != UISceneActivationStateUnattached) return (UIWindowScene *)s;
    }
    return nil;
}

+ (void)attachButton {
    if (gOverlayWindow && !gOverlayWindow.hidden && gButton && gButton.superview) return;
    UIWindowScene *scene = [self activeWindowScene];
    if (!scene && ![UIApplication.sharedApplication.windows count]) return;

    if (!gOverlayWindow) {
        if (scene) gOverlayWindow = [[MiOSOverlayWindow alloc] initWithWindowScene:scene];
        else gOverlayWindow = [[MiOSOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        gOverlayWindow.windowLevel = UIWindowLevelAlert + 1;
        gOverlayWindow.backgroundColor = [UIColor clearColor];
        gOverlayWindow.rootViewController = [MiOSOverlayVC new];
        gOverlayWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
    } else if (scene && gOverlayWindow.windowScene != scene) {
        gOverlayWindow.windowScene = scene;
    }

    if (!gButton || !gButton.superview) {
        [gButton removeFromSuperview];
        CGRect wb = gOverlayWindow.bounds;
        MiOSFloatingButton *b = [MiOSFloatingButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(0, 0, 56, 56);
        b.center = CGPointMake(wb.size.width - 42, wb.size.height * 0.4);

        CAGradientLayer *grad = [MiOSTheme accentGradientForBounds:b.bounds];
        grad.cornerRadius = 28;
        [b.layer addSublayer:grad];

        UILabel *lbl = [UILabel new];
        lbl.text = @"miOS"; lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        lbl.textColor = [UIColor whiteColor]; lbl.textAlignment = NSTextAlignmentCenter;
        lbl.frame = b.bounds; [b addSubview:lbl];

        b.layer.cornerRadius = 28;
        b.layer.shadowColor = [UIColor blackColor].CGColor;
        b.layer.shadowOpacity = 0.5; b.layer.shadowRadius = 10; b.layer.shadowOffset = CGSizeMake(0, 4);
        [b addTarget:self action:@selector(present) forControlEvents:UIControlEventTouchUpInside];
        [b addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_pan:)]];
        [gOverlayWindow.rootViewController.view addSubview:b];
        gButton = b;
    }
    gOverlayWindow.hidden = NO;
}

+ (void)_pan:(UIPanGestureRecognizer *)pan {
    UIView *b = pan.view;
    CGPoint tr = [pan translationInView:b.superview];
    b.center = CGPointMake(b.center.x + tr.x, b.center.y + tr.y);
    [pan setTranslation:CGPointZero inView:b.superview];
    if (pan.state == UIGestureRecognizerStateEnded) {
        CGRect bounds = b.superview.bounds;
        CGFloat x = MIN(MAX(b.center.x, 30), bounds.size.width - 30);
        CGFloat y = MIN(MAX(b.center.y, 60), bounds.size.height - 60);
        [UIView animateWithDuration:0.2 animations:^{ b.center = CGPointMake(x, y); }];
    }
}

+ (void)present {
    UIViewController *top = MiOSTopVC();
    if (!top || top.presentedViewController) return;
    MiOSMainVC *main = [MiOSMainVC new];
    main.transitioningDelegate = [MiOSPanModalDelegate shared];
    main.modalPresentationStyle = UIModalPresentationCustom;
    [top presentViewController:main animated:YES completion:nil];
}

@end
