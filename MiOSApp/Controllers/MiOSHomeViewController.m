#import "MiOSHomeViewController.h"
#import "MiOSContainerCreateViewController.h"
#import "MiOSContainerDetailViewController.h"
#import "MiOSSettingsViewController.h"
#import "../Models/MiOSContainerConfig.h"
#import "../Models/MiOSAppInfo.h"
#import "../UI/MiOSTheme.h"
#import "../Utils/MiOSColorExtractor.h"
#import "../Utils/MiOSDeviceImageRenderer.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface UIImage (MiOSPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

static NSString *const kMiOSCorePrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist";

@interface MiOSHomeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;
@property (nonatomic, strong) NSMutableDictionary *corePrefs;
@property (nonatomic, strong) NSArray<MiOSContainerConfig *> *containers;
@property (nonatomic, copy) NSString *activeContainerID;
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
@property (nonatomic, strong) CAGradientLayer *glowLayer;
@end

@implementation MiOSHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"miOS";
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    [MiOSTheme styleNavigationBar:self.navigationController.navigationBar];
    [self setupNavBarButtons];
    [self loadPreferences];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadPreferences];
    [self reloadContainers];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _bgGradientLayer.frame = self.view.bounds;
    CGFloat glowSize = self.view.bounds.size.width * 1.6;
    _glowLayer.frame = CGRectMake(self.view.bounds.size.width / 2 - glowSize / 2,
                                  self.view.bounds.size.height - glowSize * 0.55,
                                  glowSize, glowSize);
}

#pragma mark - Nav Bar

- (void)setupNavBarButtons {
    // Non-clickable notification bell (top-right)
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImage *bell = [UIImage systemImageNamed:@"bell.fill" withConfiguration:cfg];
    UIBarButtonItem *bellItem = [[UIBarButtonItem alloc] initWithImage:bell style:UIBarButtonItemStylePlain target:nil action:nil];
    bellItem.tintColor = [MiOSTheme secondaryText];
    self.navigationItem.rightBarButtonItem = bellItem;
}

#pragma mark - Preferences

- (void)loadPreferences {
    _corePrefs = [[NSMutableDictionary dictionaryWithContentsOfFile:kMiOSCorePrefsPath] mutableCopy];
    if (!_corePrefs) {
        _corePrefs = [@{@"enabled": @YES} mutableCopy];
    }
}

- (void)savePreferences {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [kMiOSCorePrefsPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [_corePrefs writeToFile:kMiOSCorePrefsPath atomically:YES];
}

- (void)reloadContainers {
    _containers = [MiOSContainerConfig loadAll];
    _activeContainerID = [MiOSContainerConfig activeContainerID];
    [self rebuildContent];
}

#pragma mark - UI Setup

- (void)setupUI {
    // Base vertical gradient
    _bgGradientLayer = [CAGradientLayer layer];
    _bgGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.07 green:0.07 blue:0.11 alpha:1.0].CGColor,
        (id)[MiOSTheme primaryBackground].CGColor,
        (id)[UIColor colorWithRed:0.03 green:0.03 blue:0.05 alpha:1.0].CGColor,
    ];
    _bgGradientLayer.locations = @[@0.0, @0.5, @1.0];
    _bgGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    _bgGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    _bgGradientLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:_bgGradientLayer atIndex:0];

    // Accent glow blooming from the bottom (screenshot-2 style)
    _glowLayer = [CAGradientLayer layer];
    _glowLayer.type = kCAGradientLayerRadial;
    UIColor *accent = [MiOSTheme accentColor];
    _glowLayer.colors = @[
        (id)[accent colorWithAlphaComponent:0.28].CGColor,
        (id)[accent colorWithAlphaComponent:0.10].CGColor,
        (id)[accent colorWithAlphaComponent:0.0].CGColor,
    ];
    _glowLayer.locations = @[@0.0, @0.45, @1.0];
    _glowLayer.startPoint = CGPointMake(0.5, 0.5);
    _glowLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.view.layer insertSublayer:_glowLayer atIndex:1];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    _mainStack = [[UIStackView alloc] init];
    _mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    _mainStack.axis = UILayoutConstraintAxisVertical;
    _mainStack.spacing = 18;
    [_scrollView addSubview:_mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:12],
        [_mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-32],
    ]];

    [self reloadContainers];
}

- (void)rebuildContent {
    for (UIView *v in [_mainStack.arrangedSubviews copy]) {
        [_mainStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    // 1. Active container hero (or empty prompt)
    MiOSContainerConfig *active = [self activeContainer];
    if (active) {
        [self buildActiveContainerCard:active];
    } else if (_containers.count == 0) {
        [self buildEmptyState];
    }

    // 2. New Container button (above the grid)
    [self buildNewContainerButton];

    // 3. Container grid
    if (_containers.count > 0) {
        [self buildContainerGrid];
    }
}

- (MiOSContainerConfig *)activeContainer {
    for (MiOSContainerConfig *c in _containers) {
        if ([c.identifier isEqualToString:_activeContainerID]) return c;
    }
    return _containers.firstObject;
}

#pragma mark - App Icon Helpers

- (UIImage *)iconForBundleID:(NSString *)bundleID {
    UIImage *img = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:0 scale:[UIScreen mainScreen].scale];
    if (img) return img;

    NSArray<MiOSAppInfo *> *allApps = [MiOSAppInfo allApps];
    for (MiOSAppInfo *app in allApps) {
        if ([app.bundleID isEqualToString:bundleID]) {
            return app.icon;
        }
    }
    return nil;
}

- (UIColor *)accentForContainer:(MiOSContainerConfig *)container {
    UIColor *cardAccent = [MiOSTheme accentColor];
    if (container.apps.count > 0) {
        UIImage *firstIcon = [self iconForBundleID:container.apps.firstObject];
        if (firstIcon) {
            UIColor *extracted = [MiOSColorExtractor vibrantColorFromImage:firstIcon];
            if (extracted) cardAccent = extracted;
        }
    }
    return cardAccent;
}

#pragma mark - Active Container Card

- (void)buildActiveContainerCard:(MiOSContainerConfig *)container {
    BOOL enabled = [_corePrefs[@"enabled"] boolValue];
    UIColor *accent = [self accentForContainer:container];
    CGFloat ar, ag, ab, aa;
    [accent getRed:&ar green:&ag blue:&ab alpha:&aa];

    // Section header
    UILabel *sectionHeader = [[UILabel alloc] init];
    sectionHeader.translatesAutoresizingMaskIntoConstraints = NO;
    sectionHeader.text = @"ACTIVE CONTAINER";
    sectionHeader.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    sectionHeader.textColor = accent;
    [_mainStack addArrangedSubview:sectionHeader];

    // Card
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithRed:0.10 + ar * 0.07
                                           green:0.10 + ag * 0.07
                                            blue:0.14 + ab * 0.07
                                           alpha:0.92];
    card.layer.cornerRadius = 22;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [accent colorWithAlphaComponent:0.35].CGColor;
    card.layer.shadowColor = accent.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 6);
    card.layer.shadowRadius = 20;
    card.layer.shadowOpacity = 0.22;
    card.clipsToBounds = NO;
    [_mainStack addArrangedSubview:card];

    // Device image (left)
    MiOSContainerConfig *c = container;
    NSString *deviceName = (c.deviceSpoofEnabled && c.deviceName.length > 0) ? c.deviceName : @"iPhone 15 Pro";
    UIImageView *deviceImageView = [[UIImageView alloc] init];
    deviceImageView.translatesAutoresizingMaskIntoConstraints = NO;
    deviceImageView.contentMode = UIViewContentModeScaleAspectFit;
    deviceImageView.image = [MiOSDeviceImageRenderer renderDeviceForName:deviceName
                                                                    size:CGSizeMake(90, 118)
                                                             accentColor:accent];
    if (!c.deviceSpoofEnabled) deviceImageView.alpha = 0.55;
    [card addSubview:deviceImageView];

    // Name + status row (right of device)
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = container.name.length > 0 ? container.name : @"Container";
    nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    nameLabel.textColor = [MiOSTheme primaryText];
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.minimumScaleFactor = 0.7;
    nameLabel.numberOfLines = 1;
    [card addSubview:nameLabel];

    // Status dot + label
    UIView *statusDot = [[UIView alloc] init];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.backgroundColor = enabled ? [MiOSTheme success] : [MiOSTheme tertiaryText];
    statusDot.layer.cornerRadius = 4;
    statusDot.layer.shadowColor = (enabled ? [MiOSTheme success] : [UIColor clearColor]).CGColor;
    statusDot.layer.shadowOffset = CGSizeZero;
    statusDot.layer.shadowRadius = 4;
    statusDot.layer.shadowOpacity = 0.8;
    [card addSubview:statusDot];

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.text = enabled ? @"Active" : @"Disabled";
    statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    statusLabel.textColor = [MiOSTheme secondaryText];
    [card addSubview:statusLabel];

    // Master toggle (global enable)
    UISwitch *masterToggle = [[UISwitch alloc] init];
    masterToggle.translatesAutoresizingMaskIntoConstraints = NO;
    masterToggle.onTintColor = accent;
    masterToggle.on = enabled;
    [masterToggle addTarget:self action:@selector(masterToggleChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:masterToggle];

    // Info rows: iOS version, storage, GPS, device name
    UIStackView *infoStack = [[UIStackView alloc] init];
    infoStack.translatesAutoresizingMaskIntoConstraints = NO;
    infoStack.axis = UILayoutConstraintAxisVertical;
    infoStack.spacing = 6;

    NSString *iosText = (c.deviceSpoofEnabled && c.iosVersion.length > 0)
        ? [NSString stringWithFormat:@"iOS %@", c.iosVersion] : @"iOS default";
    [infoStack addArrangedSubview:[self infoRowWithIcon:@"gear" text:iosText accent:accent]];

    if (c.deviceSpoofEnabled && c.storageSizeGB > 0) {
        [infoStack addArrangedSubview:[self infoRowWithIcon:@"internaldrive"
                                                       text:[NSString stringWithFormat:@"%ld GB", (long)c.storageSizeGB]
                                                     accent:accent]];
    }

    NSString *gpsText;
    if (c.gpsEnabled) {
        gpsText = c.locationName.length > 0 ? c.locationName
            : [NSString stringWithFormat:@"%.3f, %.3f", c.latitude, c.longitude];
    } else {
        gpsText = @"GPS off";
    }
    [infoStack addArrangedSubview:[self infoRowWithIcon:@"location.fill" text:gpsText accent:accent]];

    [card addSubview:infoStack];

    // App icons row (all selected apps)
    UIView *iconsRow = [self appIconsRowForBundleIDs:container.apps maxIcons:7 iconSize:30];
    [card addSubview:iconsRow];

    [NSLayoutConstraint activateConstraints:@[
        [deviceImageView.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [deviceImageView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [deviceImageView.widthAnchor constraintEqualToConstant:90],
        [deviceImageView.heightAnchor constraintEqualToConstant:118],

        [nameLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [nameLabel.leadingAnchor constraintEqualToAnchor:deviceImageView.trailingAnchor constant:14],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:masterToggle.leadingAnchor constant:-8],

        [masterToggle.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [masterToggle.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [statusDot.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [statusDot.centerYAnchor constraintEqualToAnchor:statusLabel.centerYAnchor],
        [statusDot.widthAnchor constraintEqualToConstant:8],
        [statusDot.heightAnchor constraintEqualToConstant:8],
        [statusLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:6],
        [statusLabel.leadingAnchor constraintEqualToAnchor:statusDot.trailingAnchor constant:6],

        [infoStack.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:12],
        [infoStack.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [infoStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [iconsRow.topAnchor constraintGreaterThanOrEqualToAnchor:infoStack.bottomAnchor constant:14],
        [iconsRow.topAnchor constraintGreaterThanOrEqualToAnchor:deviceImageView.bottomAnchor constant:14],
        [iconsRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [iconsRow.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-16],
        [iconsRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        [iconsRow.heightAnchor constraintEqualToConstant:30],
    ]];

    // Tap to edit
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activeCardTapped:)];
    card.userInteractionEnabled = YES;
    objc_setAssociatedObject(card, "containerID", container.identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [card addGestureRecognizer:tap];
}

- (UIView *)infoRowWithIcon:(NSString *)iconName text:(NSString *)text accent:(UIColor *)accent {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:cfg]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = accent;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.textColor = [MiOSTheme secondaryText];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:16],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:8],
        [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [label.topAnchor constraintEqualToAnchor:row.topAnchor],
        [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    return row;
}

- (UIView *)appIconsRowForBundleIDs:(NSArray<NSString *> *)bundleIDs maxIcons:(NSInteger)maxIcons iconSize:(CGFloat)iconSize {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    CGFloat x = 0;
    CGFloat overlap = iconSize * 0.28;
    NSInteger shown = MIN((NSInteger)bundleIDs.count, maxIcons);

    for (NSInteger i = 0; i < shown; i++) {
        UIImageView *iv = [[UIImageView alloc] init];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = iconSize * 0.22;
        iv.layer.cornerCurve = kCACornerCurveContinuous;
        iv.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.4].CGColor;
        iv.layer.borderWidth = 1.5;

        UIImage *icon = [self iconForBundleID:bundleIDs[i]];
        if (icon) {
            iv.image = icon;
        } else {
            iv.image = [UIImage systemImageNamed:@"app.fill"];
            iv.tintColor = [MiOSTheme tertiaryText];
            iv.contentMode = UIViewContentModeCenter;
            iv.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        }

        [container addSubview:iv];
        [NSLayoutConstraint activateConstraints:@[
            [iv.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:x],
            [iv.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [iv.widthAnchor constraintEqualToConstant:iconSize],
            [iv.heightAnchor constraintEqualToConstant:iconSize],
        ]];
        x += iconSize - overlap;
    }

    // "+N" overflow badge
    if ((NSInteger)bundleIDs.count > maxIcons) {
        UILabel *more = [[UILabel alloc] init];
        more.translatesAutoresizingMaskIntoConstraints = NO;
        more.text = [NSString stringWithFormat:@"+%ld", (long)(bundleIDs.count - maxIcons)];
        more.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        more.textColor = [MiOSTheme secondaryText];
        [container addSubview:more];
        [NSLayoutConstraint activateConstraints:@[
            [more.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:x + overlap + 4],
            [more.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        ]];
    }

    if (shown == 0) {
        UILabel *none = [[UILabel alloc] init];
        none.translatesAutoresizingMaskIntoConstraints = NO;
        none.text = @"No apps";
        none.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        none.textColor = [MiOSTheme tertiaryText];
        [container addSubview:none];
        [NSLayoutConstraint activateConstraints:@[
            [none.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [none.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        ]];
    }

    return container;
}

- (void)masterToggleChanged:(UISwitch *)sender {
    _corePrefs[@"enabled"] = @(sender.on);
    [self savePreferences];
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
    [self rebuildContent];
}

- (void)activeCardTapped:(UITapGestureRecognizer *)sender {
    UIView *card = sender.view;
    [UIView animateWithDuration:0.08 animations:^{
        card.transform = CGAffineTransformMakeScale(0.98, 0.98);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            card.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
    NSString *containerID = objc_getAssociatedObject(card, "containerID");
    [self editContainerWithID:containerID];
}

#pragma mark - Empty State

- (void)buildEmptyState {
    UIView *emptyCard = [[UIView alloc] init];
    emptyCard.translatesAutoresizingMaskIntoConstraints = NO;
    emptyCard.backgroundColor = [MiOSTheme accentTintedCardBackground];
    emptyCard.layer.cornerRadius = 20;
    emptyCard.layer.cornerCurve = kCACornerCurveContinuous;
    emptyCard.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    emptyCard.layer.borderWidth = 1.0;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightThin];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.stack.3d.up.slash" withConfiguration:cfg]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [MiOSTheme tertiaryText];
    [emptyCard addSubview:icon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"No Containers Yet";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    titleLabel.textColor = [MiOSTheme primaryText];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [emptyCard addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = @"Create a container to isolate app data,\nspoof GPS, device info, and identifiers.";
    subtitleLabel.font = [UIFont systemFontOfSize:14];
    subtitleLabel.textColor = [MiOSTheme secondaryText];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    [emptyCard addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [emptyCard.heightAnchor constraintEqualToConstant:200],
        [icon.centerXAnchor constraintEqualToAnchor:emptyCard.centerXAnchor],
        [icon.topAnchor constraintEqualToAnchor:emptyCard.topAnchor constant:32],
        [titleLabel.centerXAnchor constraintEqualToAnchor:emptyCard.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:emptyCard.centerXAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:emptyCard.leadingAnchor constant:24],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:emptyCard.trailingAnchor constant:-24],
    ]];

    [_mainStack addArrangedSubview:emptyCard];
}

#pragma mark - Container Grid

- (void)buildContainerGrid {
    UILabel *sectionHeader = [[UILabel alloc] init];
    sectionHeader.translatesAutoresizingMaskIntoConstraints = NO;
    sectionHeader.text = @"ALL CONTAINERS";
    sectionHeader.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    sectionHeader.textColor = [MiOSTheme accentColor];
    [_mainStack addArrangedSubview:sectionHeader];

    for (NSInteger i = 0; i < (NSInteger)_containers.count; i += 2) {
        UIView *rowView = [[UIView alloc] init];
        rowView.translatesAutoresizingMaskIntoConstraints = NO;

        UIView *leftCard = [self buildGridCardForContainer:_containers[i]];
        [rowView addSubview:leftCard];

        [NSLayoutConstraint activateConstraints:@[
            [leftCard.topAnchor constraintEqualToAnchor:rowView.topAnchor],
            [leftCard.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor],
            [leftCard.bottomAnchor constraintLessThanOrEqualToAnchor:rowView.bottomAnchor],
        ]];

        if (i + 1 < (NSInteger)_containers.count) {
            UIView *rightCard = [self buildGridCardForContainer:_containers[i + 1]];
            [rowView addSubview:rightCard];

            [NSLayoutConstraint activateConstraints:@[
                [rightCard.topAnchor constraintEqualToAnchor:rowView.topAnchor],
                [rightCard.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor],
                [rightCard.bottomAnchor constraintLessThanOrEqualToAnchor:rowView.bottomAnchor],
                [leftCard.widthAnchor constraintEqualToAnchor:rightCard.widthAnchor],
                [leftCard.trailingAnchor constraintEqualToAnchor:rightCard.leadingAnchor constant:-12],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [leftCard.widthAnchor constraintEqualToAnchor:rowView.widthAnchor multiplier:0.5 constant:-6],
            ]];
        }

        [_mainStack addArrangedSubview:rowView];
    }
}

- (UIView *)buildGridCardForContainer:(MiOSContainerConfig *)container {
    BOOL isActive = [container.identifier isEqualToString:_activeContainerID];

    UIColor *cardAccent = [self accentForContainer:container];
    CGFloat cr, cg, cb, ca;
    [cardAccent getRed:&cr green:&cg blue:&cb alpha:&ca];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithRed:0.10 + cr * 0.06
                                           green:0.10 + cg * 0.06
                                            blue:0.14 + cb * 0.06
                                           alpha:0.90];
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = isActive ? 1.5 : 0.5;
    card.layer.borderColor = isActive
        ? [cardAccent colorWithAlphaComponent:0.35].CGColor
        : [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;

    card.layer.shadowColor = cardAccent.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowRadius = isActive ? 12 : 6;
    card.layer.shadowOpacity = isActive ? 0.20 : 0.08;
    card.clipsToBounds = NO;

    UIImageView *appIconView = [[UIImageView alloc] init];
    appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    appIconView.contentMode = UIViewContentModeScaleAspectFill;
    appIconView.clipsToBounds = YES;
    appIconView.layer.cornerRadius = 12;
    appIconView.layer.cornerCurve = kCACornerCurveContinuous;

    if (container.apps.count > 0) {
        UIImage *icon = [self iconForBundleID:container.apps.firstObject];
        if (icon) {
            appIconView.image = icon;
        } else {
            appIconView.image = [UIImage systemImageNamed:@"app.fill"];
            appIconView.tintColor = [MiOSTheme tertiaryText];
            appIconView.contentMode = UIViewContentModeCenter;
            appIconView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        }
    } else {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
        appIconView.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill" withConfiguration:cfg];
        appIconView.tintColor = cardAccent;
        appIconView.contentMode = UIViewContentModeCenter;
        appIconView.backgroundColor = [cardAccent colorWithAlphaComponent:0.10];
    }

    appIconView.layer.shadowColor = cardAccent.CGColor;
    appIconView.layer.shadowOffset = CGSizeZero;
    appIconView.layer.shadowRadius = 6;
    appIconView.layer.shadowOpacity = 0.25;
    [card addSubview:appIconView];

    UIView *activeDot = nil;
    if (isActive) {
        activeDot = [[UIView alloc] init];
        activeDot.translatesAutoresizingMaskIntoConstraints = NO;
        activeDot.backgroundColor = cardAccent;
        activeDot.layer.cornerRadius = 4;
        activeDot.layer.shadowColor = cardAccent.CGColor;
        activeDot.layer.shadowOffset = CGSizeZero;
        activeDot.layer.shadowRadius = 4;
        activeDot.layer.shadowOpacity = 0.6;
        [card addSubview:activeDot];
    }

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = container.name.length > 0 ? container.name : @"Container";
    nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    nameLabel.textColor = [MiOSTheme primaryText];
    nameLabel.numberOfLines = 1;
    [card addSubview:nameLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = [NSString stringWithFormat:@"%lu app%@",
        (unsigned long)container.apps.count, container.apps.count == 1 ? @"" : @"s"];
    subtitleLabel.font = [UIFont systemFontOfSize:11];
    subtitleLabel.textColor = [MiOSTheme secondaryText];
    [card addSubview:subtitleLabel];

    UIStackView *dotsStack = [[UIStackView alloc] init];
    dotsStack.translatesAutoresizingMaskIntoConstraints = NO;
    dotsStack.axis = UILayoutConstraintAxisHorizontal;
    dotsStack.spacing = 4;

    if (container.gpsEnabled) [dotsStack addArrangedSubview:[self featureDotWithColor:cardAccent]];
    if (container.deviceSpoofEnabled) [dotsStack addArrangedSubview:[self featureDotWithColor:cardAccent]];
    if (container.spoofVendorID || container.spoofAdvertisingID) [dotsStack addArrangedSubview:[self featureDotWithColor:cardAccent]];
    [card addSubview:dotsStack];

    NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
        [appIconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [appIconView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [appIconView.widthAnchor constraintEqualToConstant:44],
        [appIconView.heightAnchor constraintEqualToConstant:44],
        [nameLabel.topAnchor constraintEqualToAnchor:appIconView.bottomAnchor constant:10],
        [nameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [nameLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [subtitleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [dotsStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8],
        [dotsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [dotsStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
    ]];

    if (activeDot) {
        [constraints addObjectsFromArray:@[
            [activeDot.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
            [activeDot.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
            [activeDot.widthAnchor constraintEqualToConstant:8],
            [activeDot.heightAnchor constraintEqualToConstant:8],
        ]];
    }

    [NSLayoutConstraint activateConstraints:constraints];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gridCardTapped:)];
    card.userInteractionEnabled = YES;
    objc_setAssociatedObject(card, "containerID", container.identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [card addGestureRecognizer:tap];

    return card;
}

- (UIView *)featureDotWithColor:(UIColor *)color {
    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = [color colorWithAlphaComponent:0.5];
    dot.layer.cornerRadius = 3;
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:6],
        [dot.heightAnchor constraintEqualToConstant:6],
    ]];
    return dot;
}

- (void)gridCardTapped:(UITapGestureRecognizer *)sender {
    UIView *card = sender.view;
    [UIView animateWithDuration:0.08 animations:^{
        card.transform = CGAffineTransformMakeScale(0.96, 0.96);
        card.alpha = 0.7;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            card.transform = CGAffineTransformIdentity;
            card.alpha = 1.0;
        } completion:nil];
    }];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    NSString *containerID = objc_getAssociatedObject(card, "containerID");
    [self editContainerWithID:containerID];
}

#pragma mark - New Container Button

- (void)buildNewContainerButton {
    UIView *btn = [[UIView alloc] init];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.layer.cornerRadius = 16;
    btn.layer.cornerCurve = kCACornerCurveContinuous;

    // Textured glass look: accent-tinted fill + accent border + subtle glow
    UIColor *accent = [MiOSTheme accentColor];
    CGFloat ar, ag, ab, aa;
    [accent getRed:&ar green:&ag blue:&ab alpha:&aa];
    btn.backgroundColor = [UIColor colorWithRed:0.10 + ar * 0.10
                                          green:0.10 + ag * 0.10
                                           blue:0.14 + ab * 0.10
                                          alpha:0.92];
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [accent colorWithAlphaComponent:0.45].CGColor;
    btn.layer.shadowColor = accent.CGColor;
    btn.layer.shadowOffset = CGSizeMake(0, 3);
    btn.layer.shadowRadius = 12;
    btn.layer.shadowOpacity = 0.20;

    // Inner top sheen for texture
    CAGradientLayer *sheen = [CAGradientLayer layer];
    sheen.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.10].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    ];
    sheen.startPoint = CGPointMake(0.5, 0.0);
    sheen.endPoint = CGPointMake(0.5, 1.0);
    sheen.cornerRadius = 16;
    sheen.masksToBounds = YES;
    [btn.layer insertSublayer:sheen atIndex:0];
    objc_setAssociatedObject(btn, "sheen", sheen, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [accent colorWithAlphaComponent:0.20];
    iconBadge.layer.cornerRadius = 14;
    [btn addSubview:iconBadge];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    UIImageView *plusIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus" withConfiguration:config]];
    plusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    plusIcon.tintColor = accent;
    [iconBadge addSubview:plusIcon];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"New Container";
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    label.textColor = [MiOSTheme primaryText];
    [btn addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [btn.heightAnchor constraintEqualToConstant:56],
        [iconBadge.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:14],
        [iconBadge.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [iconBadge.widthAnchor constraintEqualToConstant:28],
        [iconBadge.heightAnchor constraintEqualToConstant:28],
        [plusIcon.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [plusIcon.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:12],
        [label.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(newContainerTapped:)];
    [btn addGestureRecognizer:tap];
    btn.userInteractionEnabled = YES;

    [_mainStack addArrangedSubview:btn];

    dispatch_async(dispatch_get_main_queue(), ^{
        sheen.frame = btn.bounds;
    });
}

- (void)newContainerTapped:(UITapGestureRecognizer *)sender {
    UIView *btn = sender.view;
    [UIView animateWithDuration:0.08 animations:^{
        btn.transform = CGAffineTransformMakeScale(0.97, 0.97);
        btn.alpha = 0.85;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            btn.transform = CGAffineTransformIdentity;
            btn.alpha = 1.0;
        } completion:nil];
    }];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    MiOSContainerCreateViewController *vc = [[MiOSContainerCreateViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf reloadContainers];
    };
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Edit Container

- (void)editContainerWithID:(NSString *)containerID {
    MiOSContainerConfig *config = nil;
    for (MiOSContainerConfig *c in _containers) {
        if ([c.identifier isEqualToString:containerID]) {
            config = c;
            break;
        }
    }
    if (!config) return;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    MiOSContainerCreateViewController *vc = [[MiOSContainerCreateViewController alloc] init];
    vc.editingContainer = config;
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf reloadContainers];
    };
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

@end
