#import "MiOSContainerGridView.h"
#import "../Models/MiOSContainerConfig.h"
#import "../UI/MiOSTheme.h"
#import "../Utils/MiOSAppIconProvider.h"

@implementation MiOSContainerGridView {
    NSArray<MiOSContainerConfig *> *_containers;
    NSString *_activeID;
    void (^_onTap)(MiOSContainerConfig *);
}

- (instancetype)initWithContainers:(NSArray<MiOSContainerConfig *> *)containers
                          activeID:(NSString *)activeID
                             onTap:(void (^)(MiOSContainerConfig *))onTap {
    if (self = [super initWithFrame:CGRectZero]) {
        _containers = [containers copy];
        _activeID = [activeID copy];
        _onTap = [onTap copy];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self buildGrid];
    }
    return self;
}

- (void)buildGrid {
    UIStackView *rows = [[UIStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 12;
    [self addSubview:rows];

    [NSLayoutConstraint activateConstraints:@[
        [rows.topAnchor constraintEqualToAnchor:self.topAnchor],
        [rows.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [rows.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [rows.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    for (NSInteger i = 0; i < (NSInteger)_containers.count; i += 2) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 12;
        row.distribution = UIStackViewDistributionFillEqually;
        row.alignment = UIStackViewAlignmentFill;

        [row addArrangedSubview:[self tileForIndex:i]];
        if (i + 1 < (NSInteger)_containers.count) {
            [row addArrangedSubview:[self tileForIndex:i + 1]];
        } else {
            // Invisible spacer keeps a lone tile at half width.
            UIView *spacer = [[UIView alloc] init];
            [row addArrangedSubview:spacer];
        }
        [rows addArrangedSubview:row];
    }
}

- (UIView *)tileForIndex:(NSInteger)index {
    MiOSContainerConfig *container = _containers[index];
    BOOL isActive = [container.identifier isEqualToString:_activeID];
    UIColor *accent = [MiOSAppIconProvider accentForBundleIDs:container.apps];
    CGFloat r, g, b, a;
    [accent getRed:&r green:&g blue:&b alpha:&a];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.tag = index;
    card.backgroundColor = [UIColor colorWithRed:0.11 + r * 0.06
                                           green:0.11 + g * 0.06
                                            blue:0.15 + b * 0.06
                                           alpha:0.92];
    card.layer.cornerRadius = 22;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = isActive
        ? [accent colorWithAlphaComponent:0.45].CGColor
        : [UIColor colorWithWhite:1.0 alpha:0.07].CGColor;
    card.layer.shadowColor = accent.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 4);
    card.layer.shadowRadius = isActive ? 14 : 8;
    card.layer.shadowOpacity = isActive ? 0.25 : 0.08;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFill;
    iconView.clipsToBounds = YES;
    iconView.layer.cornerRadius = 12;
    iconView.layer.cornerCurve = kCACornerCurveContinuous;
    UIImage *icon = [MiOSAppIconProvider iconForBundleID:container.apps.firstObject];
    if (icon) {
        iconView.image = icon;
    } else {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        iconView.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill" withConfiguration:cfg];
        iconView.contentMode = UIViewContentModeCenter;
        iconView.tintColor = accent;
        iconView.backgroundColor = [accent colorWithAlphaComponent:0.12];
    }
    [card addSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = container.name.length > 0 ? container.name : @"Container";
    nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    nameLabel.textColor = [MiOSTheme primaryText];
    [card addSubview:nameLabel];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.text = [NSString stringWithFormat:@"%lu app%@", (unsigned long)container.apps.count,
                     container.apps.count == 1 ? @"" : @"s"];
    subLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    subLabel.textColor = [MiOSTheme secondaryText];
    [card addSubview:subLabel];

    UIStackView *dots = [[UIStackView alloc] init];
    dots.translatesAutoresizingMaskIntoConstraints = NO;
    dots.axis = UILayoutConstraintAxisHorizontal;
    dots.spacing = 5;
    NSArray<NSNumber *> *features = @[@(container.gpsEnabled), @(container.deviceSpoofEnabled),
                                      @(container.spoofVendorID || container.spoofAdvertisingID || container.spoofDeviceCheck)];
    for (NSNumber *on in features) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = on.boolValue ? accent : [UIColor colorWithWhite:1.0 alpha:0.12];
        dot.layer.cornerRadius = 3;
        [dot.widthAnchor constraintEqualToConstant:6].active = YES;
        [dot.heightAnchor constraintEqualToConstant:6].active = YES;
        [dots addArrangedSubview:dot];
    }
    [card addSubview:dots];

    NSMutableArray *constraints = [@[
        [iconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [iconView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [iconView.widthAnchor constraintEqualToConstant:46],
        [iconView.heightAnchor constraintEqualToConstant:46],
        [nameLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:12],
        [nameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [nameLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [subLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
        [subLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [subLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],
        [dots.topAnchor constraintEqualToAnchor:subLabel.bottomAnchor constant:10],
        [dots.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [dots.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
    ] mutableCopy];

    if (isActive) {
        UILabel *badge = [[UILabel alloc] init];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.text = @"ACTIVE";
        badge.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
        badge.textColor = accent;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.backgroundColor = [accent colorWithAlphaComponent:0.15];
        badge.layer.cornerRadius = 8;
        badge.layer.masksToBounds = YES;
        [card addSubview:badge];
        [constraints addObjectsFromArray:@[
            [badge.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
            [badge.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
            [badge.widthAnchor constraintEqualToConstant:50],
            [badge.heightAnchor constraintEqualToConstant:16],
        ]];
    }
    [NSLayoutConstraint activateConstraints:constraints];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tileTapped:)];
    [card addGestureRecognizer:tap];
    return card;
}

- (void)tileTapped:(UITapGestureRecognizer *)sender {
    UIView *card = sender.view;
    [UIView animateWithDuration:0.08 animations:^{
        card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            card.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    NSInteger index = card.tag;
    if (_onTap && index < (NSInteger)_containers.count) _onTap(_containers[index]);
}

@end
