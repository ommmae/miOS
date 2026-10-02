#import "MiOSUI.h"
#import "MiOSTheme.h"
#import "MiOSContainer.h"
#import "MiOSDeviceDB.h"
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#pragma mark - Helpers

static UIWindow *MiOSKeyWindow(void) {
    // Scene-aware: iOS 13+ keeps windows on UIWindowScene, not UIApplication.
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Restart required"
        message:message ?: @"The container is applied when Instagram launches. The app will close now — reopen it to continue."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Close now" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *x){ exit(0); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [top presentViewController:a animated:YES completion:nil];
}
static UIImpactFeedbackGenerator *MiOSHaptic(void) {
    static UIImpactFeedbackGenerator *g = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight]; [g prepare]; });
    return g;
}

#pragma mark - MiOSSwitchCell / MiOSListCell / MiOSSegmentCell

@interface MiOSSwitchCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, copy) void (^onToggle)(BOOL);
- (void)setSymbol:(NSString *)symbol tint:(UIColor *)tint title:(NSString *)title subtitle:(NSString *)subtitle;
@end
@implementation MiOSSwitchCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:r])) {
        self.backgroundColor = [MiOSTheme card];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconView = [UIImageView new];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel = [UILabel new]; _titleLabel.font = [MiOSTheme bodyFont]; _titleLabel.textColor = [MiOSTheme text];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel = [UILabel new]; _subtitleLabel.font = [MiOSTheme captionFont]; _subtitleLabel.textColor = [MiOSTheme textSecondary];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _toggle = [UISwitch new]; _toggle.onTintColor = [MiOSTheme accent];
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggle addTarget:self action:@selector(_toggled) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_iconView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_subtitleLabel];
        [self.contentView addSubview:_toggle];
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:26],
            [_iconView.heightAnchor constraintEqualToConstant:26],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-8],
            [_toggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
    }
    return self;
}
- (void)_toggled { [MiOSHaptic() impactOccurred]; if (self.onToggle) self.onToggle(self.toggle.isOn); }
- (void)setSymbol:(NSString *)sym tint:(UIColor *)tint title:(NSString *)title subtitle:(NSString *)sub {
    self.iconView.image = sym ? [MiOSTheme symbol:sym size:20 color:tint ?: [MiOSTheme accent]] : nil;
    self.titleLabel.text = title; self.subtitleLabel.text = sub;
    self.subtitleLabel.hidden = (sub.length == 0);
}
@end

@interface MiOSListCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
- (void)setSymbol:(NSString *)symbol tint:(UIColor *)tint title:(NSString *)title value:(NSString *)value;
@end
@implementation MiOSListCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:r])) {
        self.backgroundColor = [MiOSTheme card];
        self.selectedBackgroundView = [UIView new];
        self.selectedBackgroundView.backgroundColor = [MiOSTheme cardElevated];
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        _iconView = [UIImageView new];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel = [UILabel new]; _titleLabel.font = [MiOSTheme bodyFont]; _titleLabel.textColor = [MiOSTheme text];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel = [UILabel new]; _valueLabel.font = [MiOSTheme bodyFont]; _valueLabel.textColor = [MiOSTheme textSecondary];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_iconView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_valueLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:26],
            [_iconView.heightAnchor constraintEqualToConstant:26],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6],
            [_valueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_titleLabel.trailingAnchor constant:8],
        ]];
    }
    return self;
}
- (void)setSymbol:(NSString *)sym tint:(UIColor *)tint title:(NSString *)t value:(NSString *)v {
    self.iconView.image = sym ? [MiOSTheme symbol:sym size:20 color:tint ?: [MiOSTheme accent]] : nil;
    self.titleLabel.text = t; self.valueLabel.text = v;
}
@end

@interface MiOSFieldCell : UITableViewCell <UITextFieldDelegate>
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, copy) void (^onChange)(NSString *);
- (void)setSymbol:(NSString *)s title:(NSString *)t value:(NSString *)v placeholder:(NSString *)ph;
@end
@implementation MiOSFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:r])) {
        self.backgroundColor = [MiOSTheme card];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconView = [UIImageView new];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel = [UILabel new]; _titleLabel.font = [MiOSTheme bodyFont]; _titleLabel.textColor = [MiOSTheme text];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _field = [UITextField new]; _field.font = [MiOSTheme bodyFont]; _field.textColor = [MiOSTheme textSecondary];
        _field.textAlignment = NSTextAlignmentRight;
        _field.autocorrectionType = UITextAutocorrectionTypeNo;
        _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _field.clearButtonMode = UITextFieldViewModeWhileEditing;
        _field.delegate = self;
        _field.translatesAutoresizingMaskIntoConstraints = NO;
        [_field addTarget:self action:@selector(_changed) forControlEvents:UIControlEventEditingChanged];
        [self.contentView addSubview:_iconView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_field];
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:26],
            [_iconView.heightAnchor constraintEqualToConstant:26],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_field.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:8],
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
    self.iconView.image = s ? [MiOSTheme symbol:s size:20 color:[MiOSTheme accent]] : nil;
    self.titleLabel.text = t; self.field.text = v; self.field.placeholder = ph ?: @"";
}
@end

#pragma mark - PanModal presentation (grabber sheet)

@interface MiOSPanModalPresentationController : UIPresentationController
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *grabber;
@end
@implementation MiOSPanModalPresentationController
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
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dismiss)];
    [self.dimView addGestureRecognizer:tap];
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
        self.dimView.alpha = 1;
    } completion:nil];

    self.presentedView.layer.cornerRadius = 24;
    self.presentedView.layer.cornerCurve = kCACornerCurveContinuous;
    self.presentedView.layer.masksToBounds = YES;
}
- (void)_dismiss { [self.presentingViewController dismissViewControllerAnimated:YES completion:nil]; }
- (void)dismissalTransitionWillBegin {
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
        self.dimView.alpha = 0;
    } completion:nil];
}
@end

@interface MiOSPanModalDelegate : NSObject <UIViewControllerTransitioningDelegate>
@end
@implementation MiOSPanModalDelegate
+ (instancetype)shared { static MiOSPanModalDelegate *d; static dispatch_once_t o; dispatch_once(&o, ^{ d = [self new]; }); return d; }
- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented
                                                      presentingViewController:(UIViewController *)presenting
                                                          sourceViewController:(UIViewController *)source {
    return [[MiOSPanModalPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
}
@end

#pragma mark - Picker (generic single-choice)

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
    self.tableView.separatorColor = [MiOSTheme separator];
    self.tableView.rowHeight = 48;
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.options.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"c"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
        c.backgroundColor = [MiOSTheme card];
        c.textLabel.textColor = [MiOSTheme text];
        c.selectedBackgroundView = [UIView new];
        c.selectedBackgroundView.backgroundColor = [MiOSTheme cardElevated];
        c.tintColor = [MiOSTheme accent];
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

#pragma mark - Containers tab

@interface MiOSContainersVC : UITableViewController
@property (nonatomic, strong) NSMutableArray<MiOSContainer *> *containers;
@property (nonatomic, copy) void (^onEdit)(MiOSContainer *);   // open editor in Spoof tab
@end
@implementation MiOSContainersVC
- (instancetype)init { return [super initWithStyle:UITableViewStylePlain]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];
    self.tableView.backgroundColor = [MiOSTheme background];
    self.tableView.separatorColor = [MiOSTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    self.tableView.rowHeight = 68;
    [self.tableView registerClass:[MiOSListCell class] forCellReuseIdentifier:@"c"];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.containers = [[MiOSContainer loadAll] mutableCopy];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.containers.count + 1; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    MiOSListCell *c = [t dequeueReusableCellWithIdentifier:@"c" forIndexPath:ip];
    if (ip.row == 0) {
        [c setSymbol:@"plus.circle.fill" tint:[MiOSTheme accent] title:@"New Container" value:@""];
        c.titleLabel.textColor = [MiOSTheme accent];
        return c;
    }
    MiOSContainer *m = self.containers[ip.row - 1];
    NSString *active = [MiOSContainer activeContainerID];
    BOOL isActive = [active isEqualToString:m.identifier];
    NSString *sub = m.deviceDisplayName.length ? m.deviceDisplayName : @"";
    [c setSymbol:(isActive ? @"checkmark.seal.fill" : @"shippingbox")
            tint:(isActive ? [MiOSTheme accent] : [MiOSTheme textSecondary])
           title:m.name value:sub];
    c.titleLabel.textColor = [MiOSTheme text];
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == 0) {
        MiOSContainer *c = [MiOSContainer newRandomContainerNamed:
            [NSString stringWithFormat:@"Container %lu", (unsigned long)(self.containers.count + 1)]];
        [c save];
        self.containers = [[MiOSContainer loadAll] mutableCopy];
        [t reloadData];
        if (self.onEdit) self.onEdit(c);
        return;
    }
    MiOSContainer *m = self.containers[ip.row - 1];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:m.name
        message:@"Activate this container? Instagram will restart to apply it." preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Activate & restart" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *x){
            [m containerRootEnsureCreated:YES];
            [MiOSContainer setActiveContainerID:m.identifier];
            exit(0);
        }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Edit fingerprint" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *x){ if (self.onEdit) self.onEdit(m); }]];
    UIAlertAction *rename = [UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *x){
            UIAlertController *r = [UIAlertController alertControllerWithTitle:@"Rename Container"
                message:@"Enter the name you want to change your container to." preferredStyle:UIAlertControllerStyleAlert];
            [r addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = m.name; }];
            [r addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *y){
                    NSString *n = r.textFields.firstObject.text;
                    if (n.length == 0) return;
                    m.name = n; [m save];
                    [self.tableView reloadData];
                }]];
            [r addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:r animated:YES completion:nil];
        }];
    [a addAction:rename];
    [a addAction:[UIAlertAction actionWithTitle:@"Delete Container" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *x){
            BOOL wasActive = [[MiOSContainer activeContainerID] isEqualToString:m.identifier];
            [MiOSContainer removeContainerWithID:m.identifier];
            self.containers = [[MiOSContainer loadAll] mutableCopy];
            [self.tableView reloadData];
            if (wasActive) MiOSRelaunch(@"The active container was deleted. Restart Instagram to continue without it.");
        }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

#pragma mark - Spoof (fingerprint) tab

typedef NS_ENUM(NSInteger, MiOSSpoofSec) {
    MiOSSecMode = 0,
    MiOSSecDevice,
    MiOSSecIdentifiers,
    MiOSSecNetwork,
    MiOSSecModules,
    MiOSSecRandomize,
    MiOSSecCount,
};

@interface MiOSSpoofVC : UITableViewController
@property (nonatomic, strong) MiOSContainer *container;
@end
@implementation MiOSSpoofVC
- (instancetype)initWithContainer:(MiOSContainer *)c {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _container = c; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];
    self.tableView.backgroundColor = [MiOSTheme background];
    self.tableView.separatorColor = [MiOSTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 54, 0, 0);
    [self.tableView registerClass:[MiOSSwitchCell class] forCellReuseIdentifier:@"sw"];
    [self.tableView registerClass:[MiOSListCell class] forCellReuseIdentifier:@"ls"];
    [self.tableView registerClass:[MiOSFieldCell class] forCellReuseIdentifier:@"fd"];
    self.tableView.rowHeight = 56;
}
- (void)save { [self.container save]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return MiOSSecCount; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    switch (s) {
        case MiOSSecMode: return @"MODE";
        case MiOSSecDevice: return @"DEVICE FINGERPRINT";
        case MiOSSecIdentifiers: return @"IDENTIFIERS";
        case MiOSSecNetwork: return @"CARRIER · CELLULAR · WIFI";
        case MiOSSecModules: return @"MODULES";
        default: return @"RANDOMIZE";
    }
}
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.backgroundColor = [MiOSTheme background];
    UILabel *l = [UILabel new]; l.text = [self tableView:t titleForHeaderInSection:s];
    l.textColor = [MiOSTheme accent]; l.font = [MiOSTheme headerFont];
    l.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [l.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [l.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-6],
    ]];
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 36; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case MiOSSecMode: return 1;
        case MiOSSecDevice: return 7;          // model, iOS, kernel, memory, processor, deviceName+switch, batteryLevel
        case MiOSSecIdentifiers: return 4;
        case MiOSSecNetwork: return 5;         // carrier, cellularType, cellularIP, wifi, wifiIP
        case MiOSSecModules: return 7;         // locale, brightness, lowpower, gyro, orientation, proximity, screenshot/mail/msg… trim
        case MiOSSecRandomize: return 2;
        default: return 0;
    }
}

#define BIND(cellVar, setter) \
    __weak typeof(self) ws = self; \
    cellVar.onToggle = ^(BOOL on){ ws.container.setter = on; [ws save]; [ws.tableView reloadData]; };

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    __weak typeof(self) ws = self;
    switch (ip.section) {
        case MiOSSecMode: {
            MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
            [c setSymbol:@"shield.lefthalf.filled" tint:[MiOSTheme accentSecondary]
                   title:@"Spoof mode"
                subtitle:@"Apply this container's fingerprint on launch"];
            c.toggle.on = self.container.enableSpoof;
            c.onToggle = ^(BOOL on){ ws.container.enableSpoof = on; [ws save]; };
            return c;
        }
        case MiOSSecDevice: {
            MiOSContainer *m = self.container;
            if (ip.row == 0) {
                MiOSListCell *c = [t dequeueReusableCellWithIdentifier:@"ls" forIndexPath:ip];
                [c setSymbol:@"iphone" tint:[MiOSTheme accent] title:@"Model"
                       value:m.deviceDisplayName.length ? m.deviceDisplayName : @"Choose"];
                return c;
            }
            if (ip.row == 1) {
                MiOSListCell *c = [t dequeueReusableCellWithIdentifier:@"ls" forIndexPath:ip];
                [c setSymbol:@"info.circle" tint:[MiOSTheme accent] title:@"iOS version"
                       value:m.iosVersion.length ? m.iosVersion : @"Choose"];
                return c;
            }
            if (ip.row == 2) {
                MiOSListCell *c = [t dequeueReusableCellWithIdentifier:@"ls" forIndexPath:ip];
                [c setSymbol:@"terminal" tint:[MiOSTheme accent] title:@"Kernel"
                       value:m.enableSpoofKernelVersion ? @"Spoofed" : @"Real"];
                return c;
            }
            if (ip.row == 3) {
                MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
                [c setSymbol:@"memorychip" tint:[MiOSTheme accent] title:@"Memory"
                   subtitle:m.ramGB > 0 ? [NSString stringWithFormat:@"%ld GB", (long)m.ramGB] : @"Derived from model"];
                c.toggle.on = m.enableSpoofMemory;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofMemory = on; [ws save]; };
                return c;
            }
            if (ip.row == 4) {
                MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
                [c setSymbol:@"cpu" tint:[MiOSTheme accent] title:@"Processor"
                   subtitle:m.cpuCores > 0 ? [NSString stringWithFormat:@"%ld cores · %@", (long)m.cpuCores, m.chipName ?: @""] : @"Derived from model"];
                c.toggle.on = m.enableSpoofProcessor;
                c.onToggle = ^(BOOL on){ ws.container.enableSpoofProcessor = on; [ws save]; };
                return c;
            }
            if (ip.row == 5) {
                MiOSFieldCell *c = [t dequeueReusableCellWithIdentifier:@"fd" forIndexPath:ip];
                [c setSymbol:@"textformat" title:@"Device name" value:m.deviceName placeholder:@"iPhone"];
                c.onChange = ^(NSString *v){ ws.container.deviceName = v; ws.container.enableSpoofDeviceName = v.length > 0; [ws save]; };
                return c;
            }
            MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
            [c setSymbol:@"battery.100" tint:[MiOSTheme accent] title:@"Battery"
               subtitle:m.enableSpoofBatteryLevel ? [NSString stringWithFormat:@"%ld%%", (long)m.batteryLevel] : @"Real"];
            c.toggle.on = m.enableSpoofBatteryLevel;
            c.onToggle = ^(BOOL on){ ws.container.enableSpoofBatteryLevel = on; [ws save]; };
            return c;
        }
        case MiOSSecIdentifiers: {
            MiOSContainer *m = self.container;
            MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
            switch (ip.row) {
                case 0: {
                    [c setSymbol:@"person.text.rectangle" tint:[MiOSTheme accent]
                           title:@"Vendor ID (IDFV)" subtitle:m.vendorID];
                    c.toggle.on = m.enableSpoofVendorID;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofVendorID = on;
                        if (on && ws.container.vendorID.length == 0) ws.container.vendorID = [NSUUID UUID].UUIDString;
                        [ws save]; [ws.tableView reloadData]; };
                    break;
                }
                case 1: {
                    [c setSymbol:@"a.square" tint:[MiOSTheme accent]
                           title:@"Advertising ID" subtitle:m.advertisingID];
                    c.toggle.on = m.enableSpoofAdvertisingID;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofAdvertisingID = on;
                        if (on && ws.container.advertisingID.length == 0) ws.container.advertisingID = [NSUUID UUID].UUIDString;
                        [ws save]; [ws.tableView reloadData]; };
                    break;
                }
                case 2: {
                    [c setSymbol:@"checkmark.shield" tint:[MiOSTheme accent]
                           title:@"Block DeviceCheck" subtitle:@"Return 'unsupported' to DCDevice"];
                    c.toggle.on = m.enableSpoofDeviceCheck;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofDeviceCheck = on; [ws save]; };
                    break;
                }
                default: {
                    [c setSymbol:@"icloud.slash" tint:[MiOSTheme accent]
                           title:@"Hide iCloud token" subtitle:@"ubiquityIdentityToken → nil"];
                    c.toggle.on = m.enableSpoofCloudToken;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofCloudToken = on; [ws save]; };
                    break;
                }
            }
            return c;
        }
        case MiOSSecNetwork: {
            MiOSContainer *m = self.container;
            MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
            switch (ip.row) {
                case 0: {
                    [c setSymbol:@"antenna.radiowaves.left.and.right" tint:[MiOSTheme accent]
                           title:@"Carrier" subtitle:m.carrierName.length ? [NSString stringWithFormat:@"%@ %@", m.carrierFlag ?: @"", m.carrierName] : @"Random"];
                    c.toggle.on = m.enableSpoofCarrier;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofCarrier = on;
                        if (on && ws.container.carrierName.length == 0) [ws.container randomizeCarrier];
                        [ws save]; [ws.tableView reloadData]; };
                    break;
                }
                case 1: {
                    [c setSymbol:@"dot.radiowaves.right" tint:[MiOSTheme accent]
                           title:@"Cellular type" subtitle:m.cellularType.length ? m.cellularType : @"Random"];
                    c.toggle.on = m.enableSpoofCellularType;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofCellularType = on; [ws save]; };
                    break;
                }
                case 2: {
                    [c setSymbol:@"network" tint:[MiOSTheme accent]
                           title:@"Cellular IP" subtitle:m.cellularAddress.length ? m.cellularAddress : @"Random"];
                    c.toggle.on = m.enableSpoofCellular;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofCellular = on;
                        if (on && ws.container.cellularAddress.length == 0) [ws.container randomizeCellular];
                        [ws save]; [ws.tableView reloadData]; };
                    break;
                }
                case 3: {
                    [c setSymbol:@"wifi" tint:[MiOSTheme accent]
                           title:@"Wi-Fi" subtitle:m.wifiSSID.length ? [NSString stringWithFormat:@"%@ · %@", m.wifiSSID, m.wifiBSSID] : @"Random"];
                    c.toggle.on = m.enableSpoofWiFi;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofWiFi = on;
                        if (on && ws.container.wifiSSID.length == 0) [ws.container randomizeWiFi];
                        [ws save]; [ws.tableView reloadData]; };
                    break;
                }
                default: {
                    MiOSFieldCell *f = [t dequeueReusableCellWithIdentifier:@"fd" forIndexPath:ip];
                    [f setSymbol:@"globe" title:@"Wi-Fi IP" value:m.wifiAddress placeholder:@"192.168.1.42"];
                    f.onChange = ^(NSString *v){ ws.container.wifiAddress = v; [ws save]; };
                    return f;
                }
            }
            return c;
        }
        case MiOSSecModules: {
            MiOSContainer *m = self.container;
            MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
            switch (ip.row) {
                case 0: {
                    [c setSymbol:@"globe" tint:[MiOSTheme accent] title:@"Locale & TimeZone"
                       subtitle:m.localeID.length ? [NSString stringWithFormat:@"%@ · %@", m.localeID, m.timeZoneID] : @"Random"];
                    c.toggle.on = m.enableSpoofLocale;
                    c.onToggle = ^(BOOL on){
                        ws.container.enableSpoofLocale = on; ws.container.enableSpoofTimeZone = on;
                        if (on && ws.container.localeID.length == 0) [ws.container randomizeLocale];
                        [ws save]; [ws.tableView reloadData];
                    };
                    break;
                }
                case 1: {
                    [c setSymbol:@"sun.max" tint:[MiOSTheme accent] title:@"Brightness"
                       subtitle:[NSString stringWithFormat:@"%.0f%%", m.brightnessLevel * 100]];
                    c.toggle.on = m.enableSpoofBrightness;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofBrightness = on; [ws save]; };
                    break;
                }
                case 2: {
                    [c setSymbol:@"bolt.slash" tint:[MiOSTheme accent] title:@"Low Power Mode"
                       subtitle:m.lowPowerModeEnabled ? @"Enabled" : @"Disabled"];
                    c.toggle.on = m.enableSpoofLowPowerMode;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofLowPowerMode = on; [ws save]; };
                    break;
                }
                case 3: {
                    [c setSymbol:@"gyroscope" tint:[MiOSTheme accent] title:@"Gyroscope"
                       subtitle:@"Random x / y / z each read"];
                    c.toggle.on = m.enableSpoofGyroscope;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofGyroscope = on; [ws save]; };
                    break;
                }
                case 4: {
                    [c setSymbol:@"camera.metering.unknown" tint:[MiOSTheme accent] title:@"Screenshot detection"
                       subtitle:@"Hide 'screenshot taken' events"];
                    c.toggle.on = m.enableSpoofScreenshot;
                    c.onToggle = ^(BOOL on){ ws.container.enableSpoofScreenshot = on; [ws save]; };
                    break;
                }
                case 5: {
                    [c setSymbol:@"envelope.badge.shield.half.filled" tint:[MiOSTheme accent] title:@"Mail / Messages availability"
                       subtitle:@"canSendMail / canSendText → false"];
                    c.toggle.on = m.enableSpoofMail && m.enableSpoofMessage;
                    c.onToggle = ^(BOOL on){
                        ws.container.enableSpoofMail = on; ws.container.mailAvailable = NO;
                        ws.container.enableSpoofMessage = on; ws.container.messageAvailable = NO; [ws save];
                    };
                    break;
                }
                default: {
                    [c setSymbol:@"eye.slash" tint:[MiOSTheme accent] title:@"Disable detection"
                       subtitle:@"Hide jailbreak probes"];
                    c.toggle.on = m.enableDisableDetection;
                    c.onToggle = ^(BOOL on){ ws.container.enableDisableDetection = on; [ws save]; };
                    break;
                }
            }
            return c;
        }
        default: {
            MiOSListCell *c = [t dequeueReusableCellWithIdentifier:@"ls" forIndexPath:ip];
            if (ip.row == 0) {
                [c setSymbol:@"shuffle.circle" tint:[MiOSTheme accentSecondary] title:@"Randomize full fingerprint" value:@""];
                c.titleLabel.textColor = [MiOSTheme accentSecondary];
            } else {
                [c setSymbol:@"die.face.5" tint:[MiOSTheme accent] title:@"Randomize a single module…" value:@""];
            }
            return c;
        }
    }
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    MiOSContainer *m = self.container;
    __weak typeof(self) ws = self;

    if (ip.section == MiOSSecDevice && ip.row == 0) {           // model picker
        NSMutableArray *names = [NSMutableArray array];
        for (MiOSDeviceModel *d in [MiOSDeviceDatabase allDevices]) [names addObject:d.displayName];
        MiOSPickerVC *p = [MiOSPickerVC new];
        p.title = @"Choose an iPhone"; p.options = names; p.selected = m.deviceDisplayName;
        p.onPick = ^(NSString *v) {
            for (MiOSDeviceModel *d in [MiOSDeviceDatabase allDevices]) {
                if ([d.displayName isEqualToString:v]) { [ws.container applyDeviceModelIdentifier:d.identifier iosVersion:nil]; break; }
            }
            [ws save]; [ws.tableView reloadData];
        };
        [self.navigationController pushViewController:p animated:YES];
    } else if (ip.section == MiOSSecDevice && ip.row == 1) {    // iOS version picker
        MiOSDeviceModel *d = [MiOSDeviceDatabase deviceForIdentifier:m.deviceIdentifier];
        NSArray *vers = d ? [MiOSDeviceDatabase supportedIOSVersionsForDevice:d] : [MiOSDeviceDatabase allIOSVersions];
        MiOSPickerVC *p = [MiOSPickerVC new];
        p.title = @"Choose iOS version"; p.options = vers; p.selected = m.iosVersion;
        p.onPick = ^(NSString *v) { ws.container.iosVersion = v; ws.container.enableSpoofSoftwareVersion = YES; [ws save]; [ws.tableView reloadData]; };
        [self.navigationController pushViewController:p animated:YES];
    } else if (ip.section == MiOSSecDevice && ip.row == 2) {    // kernel re-roll
        [m randomizeKernelVersion]; [self save]; [t reloadData];
    } else if (ip.section == MiOSSecRandomize) {
        if (ip.row == 0) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Randomize full fingerprint?"
                message:@"Replaces every spoofed value for this container with a fresh random one." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Randomize" style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *x){ [m randomizeAllModules]; [self save]; [t reloadData]; }]];
            [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        } else {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Randomize module" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            NSArray *mods = @[@"device", @"identifiers", @"carrier", @"wifi", @"cellular", @"locale", @"kernel", @"battery", @"brightness", @"gyroscope"];
            for (NSString *mod in mods) {
                [a addAction:[UIAlertAction actionWithTitle:mod style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *x){ [m randomizeModule:mod]; [self save]; [t reloadData]; }]];
            }
            [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        }
    }
}
@end

#pragma mark - Location tab (MKMapView picker + snapshots)

@interface MiOSLocationVC : UIViewController <MKMapViewDelegate>
@property (nonatomic, strong) MiOSContainer *container;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UISegmentedControl *mapStyleSeg;
@property (nonatomic, strong) UISwitch *enableToggle;
@property (nonatomic, strong) UITextField *latField;
@property (nonatomic, strong) UITextField *lonField;
@property (nonatomic, strong) UILabel *placeLabel;
@end
@implementation MiOSLocationVC
- (instancetype)initWithContainer:(MiOSContainer *)c { if ((self = [super init])) _container = c; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];
    self.title = @"Location";

    _mapView = [MKMapView new];
    _mapView.delegate = self;
    _mapView.translatesAutoresizingMaskIntoConstraints = NO;
    _mapView.layer.cornerRadius = 14;
    _mapView.layer.cornerCurve = kCACornerCurveContinuous;
    _mapView.layer.masksToBounds = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_longPressed:)];
    [_mapView addGestureRecognizer:lp];
    [self.view addSubview:_mapView];

    _mapStyleSeg = [[UISegmentedControl alloc] initWithItems:@[@"Standard", @"Satellite", @"Hybrid"]];
    _mapStyleSeg.selectedSegmentIndex = 0;
    _mapStyleSeg.selectedSegmentTintColor = [MiOSTheme accent];
    _mapStyleSeg.translatesAutoresizingMaskIntoConstraints = NO;
    [_mapStyleSeg addTarget:self action:@selector(_styleChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_mapStyleSeg];

    UIView *coordCard = [UIView new];
    [MiOSTheme applyCardStyleTo:coordCard];
    coordCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:coordCard];

    _enableToggle = [UISwitch new];
    _enableToggle.onTintColor = [MiOSTheme accent];
    _enableToggle.on = self.container.spoofLocation;
    [_enableToggle addTarget:self action:@selector(_toggle) forControlEvents:UIControlEventValueChanged];
    _enableToggle.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *enableLbl = [UILabel new];
    enableLbl.text = @"Spoof Location"; enableLbl.textColor = [MiOSTheme text]; enableLbl.font = [MiOSTheme bodyFont];
    enableLbl.translatesAutoresizingMaskIntoConstraints = NO;

    _latField = [UITextField new]; _latField.placeholder = @"Latitude"; _latField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    _latField.textColor = [MiOSTheme text]; _latField.font = [MiOSTheme bodyFont];
    _latField.translatesAutoresizingMaskIntoConstraints = NO;
    _lonField = [UITextField new]; _lonField.placeholder = @"Longitude"; _lonField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    _lonField.textColor = [MiOSTheme text]; _lonField.font = [MiOSTheme bodyFont];
    _lonField.translatesAutoresizingMaskIntoConstraints = NO;
    [_latField addTarget:self action:@selector(_fieldChanged) forControlEvents:UIControlEventEditingChanged];
    [_lonField addTarget:self action:@selector(_fieldChanged) forControlEvents:UIControlEventEditingChanged];

    _placeLabel = [UILabel new]; _placeLabel.font = [MiOSTheme captionFont]; _placeLabel.textColor = [MiOSTheme textSecondary];
    _placeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _placeLabel.text = self.container.locationName;

    [coordCard addSubview:enableLbl];
    [coordCard addSubview:_enableToggle];
    [coordCard addSubview:_latField];
    [coordCard addSubview:_lonField];
    [coordCard addSubview:_placeLabel];
    UILabel *tip = [UILabel new]; tip.text = @"Long-press the map to drop a pin.";
    tip.font = [MiOSTheme captionFont]; tip.textColor = [MiOSTheme textSecondary];
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tip];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_mapView.topAnchor constraintEqualToAnchor:g.topAnchor constant:12],
        [_mapView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [_mapView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [_mapView.heightAnchor constraintGreaterThanOrEqualToConstant:280],

        [_mapStyleSeg.topAnchor constraintEqualToAnchor:_mapView.bottomAnchor constant:10],
        [_mapStyleSeg.leadingAnchor constraintEqualToAnchor:_mapView.leadingAnchor],
        [_mapStyleSeg.trailingAnchor constraintEqualToAnchor:_mapView.trailingAnchor],

        [tip.topAnchor constraintEqualToAnchor:_mapStyleSeg.bottomAnchor constant:8],
        [tip.leadingAnchor constraintEqualToAnchor:_mapView.leadingAnchor constant:4],

        [coordCard.topAnchor constraintEqualToAnchor:tip.bottomAnchor constant:8],
        [coordCard.leadingAnchor constraintEqualToAnchor:_mapView.leadingAnchor],
        [coordCard.trailingAnchor constraintEqualToAnchor:_mapView.trailingAnchor],
        [coordCard.bottomAnchor constraintLessThanOrEqualToAnchor:g.bottomAnchor constant:-16],

        [enableLbl.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [enableLbl.topAnchor constraintEqualToAnchor:coordCard.topAnchor constant:12],
        [_enableToggle.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],
        [_enableToggle.centerYAnchor constraintEqualToAnchor:enableLbl.centerYAnchor],

        [_latField.topAnchor constraintEqualToAnchor:enableLbl.bottomAnchor constant:12],
        [_latField.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [_latField.widthAnchor constraintEqualToAnchor:coordCard.widthAnchor multiplier:0.5 constant:-18],
        [_lonField.topAnchor constraintEqualToAnchor:_latField.topAnchor],
        [_lonField.leadingAnchor constraintEqualToAnchor:_latField.trailingAnchor constant:8],
        [_lonField.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],

        [_placeLabel.topAnchor constraintEqualToAnchor:_latField.bottomAnchor constant:10],
        [_placeLabel.leadingAnchor constraintEqualToAnchor:coordCard.leadingAnchor constant:14],
        [_placeLabel.trailingAnchor constraintEqualToAnchor:coordCard.trailingAnchor constant:-14],
        [_placeLabel.bottomAnchor constraintEqualToAnchor:coordCard.bottomAnchor constant:-12],
    ]];
    [self _loadFromContainer];
}
- (void)_loadFromContainer {
    CLLocationCoordinate2D c = self.container.coordinate;
    if (c.latitude || c.longitude) {
        [self _setPinAt:c save:NO];
        [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 1500, 1500) animated:NO];
        self.latField.text = [NSString stringWithFormat:@"%.6f", c.latitude];
        self.lonField.text = [NSString stringWithFormat:@"%.6f", c.longitude];
    }
}
- (void)_toggle { self.container.spoofLocation = self.enableToggle.isOn; [self.container save]; }
- (void)_fieldChanged {
    double lat = self.latField.text.doubleValue, lon = self.lonField.text.doubleValue;
    CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lon);
    [self _setPinAt:c save:YES];
}
- (void)_styleChanged {
    switch (self.mapStyleSeg.selectedSegmentIndex) {
        case 0: self.mapView.mapType = MKMapTypeStandard; break;
        case 1: self.mapView.mapType = MKMapTypeSatellite; break;
        default: self.mapView.mapType = MKMapTypeHybrid; break;
    }
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
        self.container.coordinate = c;
        self.container.spoofLocation = YES;
        self.enableToggle.on = YES;
        [self.container save];
        [self _reverseGeocode:c];
        [self _writeSnapshotAt:c];
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
- (void)_writeSnapshotAt:(CLLocationCoordinate2D)c {
    NSString *root = MiOSBaseDir();
    MKMapSnapshotOptions *opts = [MKMapSnapshotOptions new];
    opts.region = MKCoordinateRegionMakeWithDistance(c, 1500, 1500);
    opts.size = CGSizeMake(600, 400);
    opts.mapType = MKMapTypeStandard;
    MKMapSnapshotter *snap = [[MKMapSnapshotter alloc] initWithOptions:opts];
    [snap startWithCompletionHandler:^(MKMapSnapshot *s, NSError *e){
        if (!s) return;
        NSString *p = [root stringByAppendingPathComponent:@"location-snapshot.png"];
        [UIImagePNGRepresentation(s.image) writeToFile:p atomically:YES];
    }];
}
@end

#pragma mark - Proxy tab

@interface MiOSProxyVC : UITableViewController
@property (nonatomic, strong) MiOSContainer *container;
@end
@implementation MiOSProxyVC
- (instancetype)initWithContainer:(MiOSContainer *)c { if ((self = [super initWithStyle:UITableViewStyleGrouped])) _container = c; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];
    self.tableView.backgroundColor = [MiOSTheme background];
    self.tableView.separatorColor = [MiOSTheme separator];
    [self.tableView registerClass:[MiOSSwitchCell class] forCellReuseIdentifier:@"sw"];
    [self.tableView registerClass:[MiOSFieldCell class] forCellReuseIdentifier:@"fd"];
    self.tableView.rowHeight = 56;
    self.title = @"Proxy (BETA)";
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return s == 0 ? @"PROXY MODE" : @"CONNECTION";
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s == 0 ? 1 : 4; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    __weak typeof(self) ws = self;
    if (ip.section == 0) {
        MiOSSwitchCell *c = [t dequeueReusableCellWithIdentifier:@"sw" forIndexPath:ip];
        [c setSymbol:@"shippingbox.and.arrow.backward" tint:[MiOSTheme accentSecondary]
               title:@"Route Instagram through proxy"
            subtitle:@"NSURLSessionConfiguration gets HTTPS/HTTP proxy"];
        c.toggle.on = self.container.enableProxy;
        c.onToggle = ^(BOOL on){ ws.container.enableProxy = on; [ws.container save]; };
        return c;
    }
    MiOSFieldCell *f = [t dequeueReusableCellWithIdentifier:@"fd" forIndexPath:ip];
    MiOSContainer *m = self.container;
    switch (ip.row) {
        case 0: {
            [f setSymbol:@"server.rack" title:@"Host" value:m.proxyHost placeholder:@"proxy.example.com"];
            f.onChange = ^(NSString *v){ ws.container.proxyHost = v; [ws.container save]; };
            break;
        }
        case 1: {
            [f setSymbol:@"number" title:@"Port" value:m.proxyPort > 0 ? [NSString stringWithFormat:@"%ld", (long)m.proxyPort] : @""
             placeholder:@"8080"];
            f.field.keyboardType = UIKeyboardTypeNumberPad;
            f.onChange = ^(NSString *v){ ws.container.proxyPort = v.integerValue; [ws.container save]; };
            break;
        }
        case 2: {
            [f setSymbol:@"person" title:@"Username" value:m.proxyUsername placeholder:@"optional"];
            f.onChange = ^(NSString *v){ ws.container.proxyUsername = v; [ws.container save]; };
            break;
        }
        default: {
            [f setSymbol:@"key" title:@"Password" value:m.proxyPassword placeholder:@"optional"];
            f.field.secureTextEntry = YES;
            f.onChange = ^(NSString *v){ ws.container.proxyPassword = v; [ws.container save]; };
            break;
        }
    }
    return f;
}
@end

#pragma mark - Settings tab

@interface MiOSSettingsVC : UITableViewController
@end
@implementation MiOSSettingsVC
- (instancetype)init { return [super initWithStyle:UITableViewStyleGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];
    self.tableView.backgroundColor = [MiOSTheme background];
    self.tableView.separatorColor = [MiOSTheme separator];
    [self.tableView registerClass:[MiOSListCell class] forCellReuseIdentifier:@"ls"];
    self.tableView.rowHeight = 56;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s == 0 ? 2 : 1; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return s == 0 ? @"ABOUT" : @"RESET";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    MiOSListCell *c = [t dequeueReusableCellWithIdentifier:@"ls" forIndexPath:ip];
    if (ip.section == 0 && ip.row == 0) {
        [c setSymbol:@"info.circle" tint:[MiOSTheme accent] title:@"miOS version" value:@"2.0.0"];
        c.accessoryType = UITableViewCellAccessoryNone;
    } else if (ip.section == 0 && ip.row == 1) {
        [c setSymbol:@"shippingbox" tint:[MiOSTheme accent] title:@"Target app" value:@"com.burbn.instagram"];
        c.accessoryType = UITableViewCellAccessoryNone;
    } else {
        [c setSymbol:@"trash" tint:[MiOSTheme destructive] title:@"Reset miOS" value:@""];
        c.titleLabel.textColor = [MiOSTheme destructive];
    }
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 1) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset miOS?"
            message:@"This erases every container, every spoof setting, and every snapshot. This action cannot be undone."
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Erase everything" style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *x){ [MiOSContainer resetAll]; MiOSRelaunch(@"miOS has been reset. Restart Instagram to continue."); }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}
@end

#pragma mark - Main tab host

@interface MiOSMainVC : UIViewController
@property (nonatomic, strong) UISegmentedControl *tabs;
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UIView *grabber;
@property (nonatomic, strong) UIViewController *current;
@property (nonatomic, strong) NSArray<UIViewController *> *vcs;
@end
@implementation MiOSMainVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme background];

    _grabber = [UIView new];
    _grabber.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    _grabber.layer.cornerRadius = 2.5;
    _grabber.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_grabber];

    UILabel *title = [UILabel new];
    title.text = @"miOS"; title.font = [MiOSTheme titleFont]; title.textColor = [MiOSTheme text];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[MiOSTheme symbol:@"xmark.circle.fill" size:22 color:[MiOSTheme textSecondary]] forState:UIControlStateNormal];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(_close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    _tabs = [[UISegmentedControl alloc] initWithItems:@[@"Containers", @"Spoof", @"Location", @"Proxy", @"⚙︎"]];
    _tabs.selectedSegmentIndex = 0;
    _tabs.selectedSegmentTintColor = [MiOSTheme accent];
    [_tabs setTitleTextAttributes:@{NSForegroundColorAttributeName:[MiOSTheme text]} forState:UIControlStateSelected];
    [_tabs setTitleTextAttributes:@{NSForegroundColorAttributeName:[MiOSTheme textSecondary]} forState:UIControlStateNormal];
    _tabs.translatesAutoresizingMaskIntoConstraints = NO;
    [_tabs addTarget:self action:@selector(_tabChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_tabs];

    _container = [UIView new];
    _container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_container];

    [NSLayoutConstraint activateConstraints:@[
        [_grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [_grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_grabber.widthAnchor constraintEqualToConstant:40],
        [_grabber.heightAnchor constraintEqualToConstant:5],

        [title.topAnchor constraintEqualToAnchor:_grabber.bottomAnchor constant:10],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [close.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [close.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        [_tabs.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [_tabs.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_tabs.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_tabs.heightAnchor constraintEqualToConstant:34],

        [_container.topAnchor constraintEqualToAnchor:_tabs.bottomAnchor constant:10],
        [_container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_container.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [self _buildVCs];
    [self _tabChanged];
}

- (MiOSContainer *)activeOrFirst {
    MiOSContainer *a = [MiOSContainer activeContainer];
    if (a) return a;
    NSArray<MiOSContainer *> *all = [MiOSContainer loadAll];
    return all.firstObject;
}

- (void)_buildVCs {
    MiOSContainersVC *containersVC = [MiOSContainersVC new];
    __weak typeof(self) ws = self;
    containersVC.onEdit = ^(MiOSContainer *c){
        ws.tabs.selectedSegmentIndex = 1;
        [ws _showSpoofFor:c];
    };
    MiOSContainer *active = [self activeOrFirst] ?: [MiOSContainer newRandomContainerNamed:@"Container 1"];
    if (![MiOSContainer loadAll].count) [active save];
    MiOSSpoofVC *spoofVC = [[MiOSSpoofVC alloc] initWithContainer:active];
    MiOSLocationVC *locVC = [[MiOSLocationVC alloc] initWithContainer:active];
    MiOSProxyVC *proxyVC = [[MiOSProxyVC alloc] initWithContainer:active];
    MiOSSettingsVC *settVC = [MiOSSettingsVC new];
    _vcs = @[containersVC, spoofVC, locVC, proxyVC, settVC];
}

- (void)_showSpoofFor:(MiOSContainer *)c {
    MiOSSpoofVC *spoofVC = [[MiOSSpoofVC alloc] initWithContainer:c];
    NSMutableArray *v = [_vcs mutableCopy]; v[1] = spoofVC;
    _vcs = v;
    [self _tabChanged];
}

- (void)_tabChanged {
    UIViewController *next = self.vcs[self.tabs.selectedSegmentIndex];
    if (self.current == next) return;
    if (self.current) {
        [self.current willMoveToParentViewController:nil];
        [self.current.view removeFromSuperview];
        [self.current removeFromParentViewController];
    }
    [self addChildViewController:next];
    next.view.frame = self.container.bounds;
    next.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.container addSubview:next.view];
    [next didMoveToParentViewController:self];
    self.current = next;
}
- (void)_close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - Floating button + installer

// Dedicated overlay window that stays above all app windows (login, modals, etc.).
// UIWindowLevelAlert + 1 keeps it on top; userInteractionEnabled passthrough lets
// touches outside the button reach the app.

@interface MiOSOverlayWindow : UIWindow
@end
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

@interface MiOSOverlayVC : UIViewController
@end
@implementation MiOSOverlayVC
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
@end

@interface MiOSFloatingButton : UIButton @end
@implementation MiOSFloatingButton
@end

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
        if (scene) {
            gOverlayWindow = [[MiOSOverlayWindow alloc] initWithWindowScene:scene];
        } else {
            gOverlayWindow = [[MiOSOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
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

        CAGradientLayer *grad = [CAGradientLayer layer];
        grad.frame = b.bounds;
        grad.colors = @[(id)[MiOSTheme accent].CGColor, (id)[MiOSTheme accentSecondary].CGColor];
        grad.startPoint = CGPointMake(0, 0); grad.endPoint = CGPointMake(1, 1);
        grad.cornerRadius = 28;
        [b.layer addSublayer:grad];

        UILabel *lbl = [UILabel new];
        lbl.text = @"miOS";
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.frame = b.bounds;
        [b addSubview:lbl];

        b.layer.cornerRadius = 28;
        b.layer.shadowColor = [UIColor blackColor].CGColor;
        b.layer.shadowOpacity = 0.5; b.layer.shadowRadius = 10; b.layer.shadowOffset = CGSizeMake(0, 4);
        [b addTarget:self action:@selector(present) forControlEvents:UIControlEventTouchUpInside];
        [b addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];

        [gOverlayWindow.rootViewController.view addSubview:b];
        gButton = b;
    }

    gOverlayWindow.hidden = NO;
}

+ (void)handlePan:(UIPanGestureRecognizer *)pan {
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
