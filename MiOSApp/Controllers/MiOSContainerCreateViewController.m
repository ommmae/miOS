#import "MiOSContainerCreateViewController.h"
#import "../Models/MiOSContainerConfig.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"
#import "../Models/MiOSAppInfo.h"
#import "../Models/MiOSDeviceDatabase.h"
#import <objc/runtime.h>

#pragma mark - App Collection Cell

static NSString *const kAppCellReuseID = @"MiOSAppCollectionCell";

@interface MiOSAppCollectionCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@property (nonatomic, strong) UIImageView *checkmark;
@property (nonatomic, assign) BOOL isChecked;
@end

@implementation MiOSAppCollectionCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupCell];
    }
    return self;
}

- (void)setupCell {
    self.contentView.backgroundColor = [MiOSTheme cardBackground];
    self.contentView.layer.cornerRadius = 14;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    self.contentView.layer.borderColor = [MiOSTheme separator].CGColor;
    self.contentView.layer.borderWidth = 0.5;
    self.contentView.clipsToBounds = YES;

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFill;
    _iconView.clipsToBounds = YES;
    _iconView.layer.cornerRadius = 12;
    _iconView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.contentView addSubview:_iconView];

    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2;

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [MiOSTheme headlineFont];
    _nameLabel.textColor = [MiOSTheme primaryText];
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [textStack addArrangedSubview:_nameLabel];

    _bundleLabel = [[UILabel alloc] init];
    _bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bundleLabel.font = [MiOSTheme captionFont];
    _bundleLabel.textColor = [MiOSTheme secondaryText];
    _bundleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [textStack addArrangedSubview:_bundleLabel];

    [self.contentView addSubview:textStack];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    _checkmark = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:cfg]];
    _checkmark.translatesAutoresizingMaskIntoConstraints = NO;
    _checkmark.tintColor = [MiOSTheme accentColor];
    _checkmark.hidden = YES;
    [self.contentView addSubview:_checkmark];

    [NSLayoutConstraint activateConstraints:@[
        [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:48],
        [_iconView.heightAnchor constraintEqualToConstant:48],
        [textStack.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:10],
        [textStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-30],
        [textStack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_checkmark.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_checkmark.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
    ]];
}

- (void)setIsChecked:(BOOL)isChecked {
    _isChecked = isChecked;
    _checkmark.hidden = !isChecked;
    self.contentView.layer.borderColor = isChecked
        ? [MiOSTheme accentColor].CGColor
        : [MiOSTheme separator].CGColor;
    self.contentView.layer.borderWidth = isChecked ? 1.5 : 0.5;
}

- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    [super traitCollectionDidChange:prev];
    self.contentView.layer.borderColor = _isChecked
        ? [MiOSTheme accentColor].CGColor
        : [MiOSTheme separator].CGColor;
}

@end

#pragma mark - Main View Controller

@interface MiOSContainerCreateViewController () <UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout, UITextFieldDelegate, UIPickerViewDataSource,
    UIPickerViewDelegate, MiOSToggleCellDelegate>

// Step views
@property (nonatomic, strong) UIView *step1View;
@property (nonatomic, strong) UIView *step2View;
@property (nonatomic, assign) NSInteger currentStep;

// Step 1 - App Selection
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) NSArray<MiOSAppInfo *> *allAppsList;
@property (nonatomic, strong) NSArray<MiOSAppInfo *> *filteredApps;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedBundleIDs;

// Step 2 - Configuration
@property (nonatomic, strong) UIScrollView *step2Scroll;
@property (nonatomic, strong) UIStackView *step2Stack;

// GPS
@property (nonatomic, assign) BOOL gpsEnabled;
@property (nonatomic, strong) UITextField *latField;
@property (nonatomic, strong) UITextField *lonField;
@property (nonatomic, strong) UIView *gpsFieldsContainer;

// Device spoof
@property (nonatomic, assign) BOOL deviceSpoofEnabled;
@property (nonatomic, strong) UIView *devicePickerContainer;
@property (nonatomic, strong) UIPickerView *devicePicker;
@property (nonatomic, strong) UIPickerView *iosPicker;
@property (nonatomic, strong) UILabel *devicePreviewLabel;
@property (nonatomic, strong) NSArray<MiOSDeviceModel *> *deviceList;
@property (nonatomic, strong) NSArray<NSString *> *iosVersionList;
@property (nonatomic, assign) NSInteger selectedDeviceIndex;
@property (nonatomic, assign) NSInteger selectedIOSIndex;

// Identifiers
@property (nonatomic, assign) BOOL spoofDeviceCheck;
@property (nonatomic, assign) BOOL spoofVendorID;
@property (nonatomic, copy) NSString *vendorID;
@property (nonatomic, strong) UIView *vendorIDContainer;
@property (nonatomic, strong) UILabel *vendorIDLabel;
@property (nonatomic, assign) BOOL spoofAdvertisingID;
@property (nonatomic, copy) NSString *advertisingID;
@property (nonatomic, strong) UIView *advertisingIDContainer;
@property (nonatomic, strong) UILabel *advertisingIDLabel;
@property (nonatomic, assign) BOOL spoofCloudToken;

@end

@implementation MiOSContainerCreateViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    self.modalPresentationStyle = UIModalPresentationPageSheet;

    _currentStep = 1;
    _selectedBundleIDs = [NSMutableSet set];
    _deviceList = [MiOSDeviceDatabase allDevices];
    _iosVersionList = [MiOSDeviceDatabase allIOSVersions];
    _selectedDeviceIndex = 0;
    _selectedIOSIndex = 0;

    [self loadApps];
    [self prefillFromEditing];
    [self buildStep1];
    [self buildStep2];
    [self showStep:1 animated:NO];
}

- (void)prefillFromEditing {
    if (!_editingContainer) return;

    if (_editingContainer.apps) {
        [_selectedBundleIDs addObjectsFromArray:_editingContainer.apps];
    }
    _gpsEnabled = _editingContainer.gpsEnabled;
    _deviceSpoofEnabled = _editingContainer.deviceSpoofEnabled;
    _spoofDeviceCheck = _editingContainer.spoofDeviceCheck;
    _spoofVendorID = _editingContainer.spoofVendorID;
    _vendorID = _editingContainer.vendorID;
    _spoofAdvertisingID = _editingContainer.spoofAdvertisingID;
    _advertisingID = _editingContainer.advertisingID;
    _spoofCloudToken = _editingContainer.spoofCloudToken;

    // Find device index
    if (_editingContainer.deviceIdentifier) {
        for (NSInteger i = 0; i < (NSInteger)_deviceList.count; i++) {
            if ([_deviceList[i].identifier isEqualToString:_editingContainer.deviceIdentifier]) {
                _selectedDeviceIndex = i;
                break;
            }
        }
        [self updateIOSVersionsForDevice];
        if (_editingContainer.iosVersion) {
            for (NSInteger i = 0; i < (NSInteger)_iosVersionList.count; i++) {
                if ([_iosVersionList[i] isEqualToString:_editingContainer.iosVersion]) {
                    _selectedIOSIndex = i;
                    break;
                }
            }
        }
    }
}

- (void)loadApps {
    _allAppsList = [MiOSAppInfo allApps];
    [self filterApps];
}

- (void)filterApps {
    NSString *searchText = _searchBar.text.lowercaseString ?: @"";
    NSInteger segment = _segmentedControl ? _segmentedControl.selectedSegmentIndex : 0;

    NSMutableArray<MiOSAppInfo *> *result = [NSMutableArray array];
    for (MiOSAppInfo *app in _allAppsList) {
        // Segment filter
        if (segment == 0) {
            // User Apps
            if ([app.bundleID hasPrefix:@"com.apple."]) continue;
        } else if (segment == 1) {
            // System Apps
            if (![app.bundleID hasPrefix:@"com.apple."]) continue;
        }
        // segment == 2 => All

        // Search filter
        if (searchText.length > 0) {
            NSString *nameLower = app.name.lowercaseString ?: @"";
            NSString *bundleLower = app.bundleID.lowercaseString ?: @"";
            if (![nameLower containsString:searchText] && ![bundleLower containsString:searchText]) {
                continue;
            }
        }

        [result addObject:app];
    }

    _filteredApps = [result copy];
    [_collectionView reloadData];
}

#pragma mark - Step Navigation

- (void)showStep:(NSInteger)step animated:(BOOL)animated {
    _currentStep = step;
    UIView *incoming = (step == 1) ? _step1View : _step2View;
    UIView *outgoing = (step == 1) ? _step2View : _step1View;
    BOOL forward = (step == 2);

    if (!animated) {
        incoming.hidden = NO;
        incoming.alpha = 1;
        incoming.transform = CGAffineTransformIdentity;
        outgoing.hidden = YES;
        return;
    }

    incoming.hidden = NO;
    incoming.alpha = 0;
    incoming.transform = CGAffineTransformMakeTranslation(forward ? self.view.bounds.size.width : -self.view.bounds.size.width, 0);

    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        incoming.alpha = 1;
        incoming.transform = CGAffineTransformIdentity;
        outgoing.alpha = 0;
        outgoing.transform = CGAffineTransformMakeTranslation(forward ? -self.view.bounds.size.width : self.view.bounds.size.width, 0);
    } completion:^(BOOL finished) {
        outgoing.hidden = YES;
    }];
}

- (void)nextTapped {
    // Validate
    NSString *name = [_nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        [self shakeView:_nameField];
        return;
    }
    if (_selectedBundleIDs.count == 0) {
        [self showValidationAlert:@"Please select at least one app."];
        return;
    }
    [self.view endEditing:YES];
    [self showStep:2 animated:YES];
}

- (void)backTapped {
    [self.view endEditing:YES];
    [self showStep:1 animated:YES];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shakeView:(UIView *)view {
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    anim.duration = 0.4;
    anim.values = @[@(-10), @(10), @(-8), @(8), @(-4), @(4), @(0)];
    [view.layer addAnimation:anim forKey:@"shake"];
}

- (void)showValidationAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Missing Info"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Build Step 1

- (void)buildStep1 {
    _step1View = [[UIView alloc] init];
    _step1View.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_step1View];

    [NSLayoutConstraint activateConstraints:@[
        [_step1View.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_step1View.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_step1View.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_step1View.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *closeCfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:closeCfg] forState:UIControlStateNormal];
    closeBtn.tintColor = [MiOSTheme secondaryText];
    closeBtn.backgroundColor = [MiOSTheme cardBackground];
    closeBtn.layer.cornerRadius = 16;
    [closeBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [_step1View addSubview:closeBtn];

    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = _editingContainer ? @"Edit Container" : @"New Container";
    titleLabel.font = [MiOSTheme titleFont];
    titleLabel.textColor = [MiOSTheme primaryText];
    [_step1View addSubview:titleLabel];

    // Step indicator
    UILabel *stepLabel = [[UILabel alloc] init];
    stepLabel.translatesAutoresizingMaskIntoConstraints = NO;
    stepLabel.text = @"Step 1 of 2 - Select Apps";
    stepLabel.font = [MiOSTheme captionFont];
    stepLabel.textColor = [MiOSTheme tertiaryText];
    [_step1View addSubview:stepLabel];

    // Name field
    _nameField = [[UITextField alloc] init];
    _nameField.translatesAutoresizingMaskIntoConstraints = NO;
    _nameField.placeholder = @"Container name...";
    _nameField.font = [MiOSTheme bodyFont];
    _nameField.textColor = [MiOSTheme primaryText];
    _nameField.backgroundColor = [MiOSTheme cardBackground];
    _nameField.layer.cornerRadius = 14;
    _nameField.layer.cornerCurve = kCACornerCurveContinuous;
    _nameField.layer.borderColor = [MiOSTheme separator].CGColor;
    _nameField.layer.borderWidth = 0.5;
    _nameField.delegate = self;
    _nameField.returnKeyType = UIReturnKeyDone;
    _nameField.autocorrectionType = UITextAutocorrectionTypeNo;

    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 48)];
    _nameField.leftView = leftPad;
    _nameField.leftViewMode = UITextFieldViewModeAlways;
    UIView *rightPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 48)];
    _nameField.rightView = rightPad;
    _nameField.rightViewMode = UITextFieldViewModeAlways;

    if (_editingContainer) {
        _nameField.text = _editingContainer.name;
    }
    [_step1View addSubview:_nameField];

    // Segmented control
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"User Apps", @"System Apps", @"All"]];
    _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    _segmentedControl.selectedSegmentIndex = 0;
    _segmentedControl.selectedSegmentTintColor = [MiOSTheme accentColor];
    [_segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    [_segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [MiOSTheme secondaryText]} forState:UIControlStateNormal];
    [_segmentedControl addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    [_step1View addSubview:_segmentedControl];

    // Search bar
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.placeholder = @"Search apps...";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.barTintColor = [UIColor clearColor];
    _searchBar.tintColor = [MiOSTheme accentColor];
    _searchBar.delegate = (id<UISearchBarDelegate>)self;

    UITextField *searchField = _searchBar.searchTextField;
    searchField.backgroundColor = [MiOSTheme cardBackground];
    searchField.textColor = [MiOSTheme primaryText];
    [_step1View addSubview:_searchBar];

    // Collection view
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 8;
    layout.minimumLineSpacing = 8;
    layout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.allowsMultipleSelection = YES;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_collectionView registerClass:[MiOSAppCollectionCell class] forCellWithReuseIdentifier:kAppCellReuseID];
    [_step1View addSubview:_collectionView];

    // Next button
    _nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_nextButton setTitle:@"Next" forState:UIControlStateNormal];
    [_nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _nextButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _nextButton.backgroundColor = [MiOSTheme accentColor];
    _nextButton.layer.cornerRadius = 14;
    _nextButton.layer.cornerCurve = kCACornerCurveContinuous;
    [_nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [_step1View addSubview:_nextButton];

    [NSLayoutConstraint activateConstraints:@[
        [closeBtn.topAnchor constraintEqualToAnchor:_step1View.topAnchor constant:16],
        [closeBtn.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [closeBtn.widthAnchor constraintEqualToConstant:32],
        [closeBtn.heightAnchor constraintEqualToConstant:32],

        [titleLabel.topAnchor constraintEqualToAnchor:_step1View.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeBtn.leadingAnchor constant:-8],

        [stepLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [stepLabel.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],

        [_nameField.topAnchor constraintEqualToAnchor:stepLabel.bottomAnchor constant:16],
        [_nameField.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_nameField.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_nameField.heightAnchor constraintEqualToConstant:48],

        [_segmentedControl.topAnchor constraintEqualToAnchor:_nameField.bottomAnchor constant:12],
        [_segmentedControl.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_segmentedControl.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_segmentedControl.heightAnchor constraintEqualToConstant:32],

        [_searchBar.topAnchor constraintEqualToAnchor:_segmentedControl.bottomAnchor constant:8],
        [_searchBar.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:8],
        [_searchBar.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-8],

        [_collectionView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor constant:4],
        [_collectionView.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_collectionView.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_collectionView.bottomAnchor constraintEqualToAnchor:_nextButton.topAnchor constant:-12],

        [_nextButton.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_nextButton.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_nextButton.bottomAnchor constraintEqualToAnchor:_step1View.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [_nextButton.heightAnchor constraintEqualToConstant:50],
    ]];

    [self updateNextButtonTitle];
}

- (void)updateNextButtonTitle {
    NSString *title = [NSString stringWithFormat:@"Next (%lu selected)", (unsigned long)_selectedBundleIDs.count];
    [_nextButton setTitle:title forState:UIControlStateNormal];
}

#pragma mark - Build Step 2

- (void)buildStep2 {
    _step2View = [[UIView alloc] init];
    _step2View.translatesAutoresizingMaskIntoConstraints = NO;
    _step2View.hidden = YES;
    [self.view addSubview:_step2View];

    [NSLayoutConstraint activateConstraints:@[
        [_step2View.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_step2View.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_step2View.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_step2View.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Back button
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *backCfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [backBtn setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:backCfg] forState:UIControlStateNormal];
    [backBtn setTitle:@" Back" forState:UIControlStateNormal];
    backBtn.tintColor = [MiOSTheme accentColor];
    backBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [backBtn addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    [_step2View addSubview:backBtn];

    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Configure";
    titleLabel.font = [MiOSTheme titleFont];
    titleLabel.textColor = [MiOSTheme primaryText];
    [_step2View addSubview:titleLabel];

    // Step indicator
    UILabel *stepLabel = [[UILabel alloc] init];
    stepLabel.translatesAutoresizingMaskIntoConstraints = NO;
    stepLabel.text = @"Step 2 of 2 - Settings";
    stepLabel.font = [MiOSTheme captionFont];
    stepLabel.textColor = [MiOSTheme tertiaryText];
    [_step2View addSubview:stepLabel];

    // Scroll view
    _step2Scroll = [[UIScrollView alloc] init];
    _step2Scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _step2Scroll.showsVerticalScrollIndicator = NO;
    _step2Scroll.alwaysBounceVertical = YES;
    _step2Scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_step2View addSubview:_step2Scroll];

    _step2Stack = [[UIStackView alloc] init];
    _step2Stack.translatesAutoresizingMaskIntoConstraints = NO;
    _step2Stack.axis = UILayoutConstraintAxisVertical;
    _step2Stack.spacing = 20;
    [_step2Scroll addSubview:_step2Stack];

    [NSLayoutConstraint activateConstraints:@[
        [backBtn.topAnchor constraintEqualToAnchor:_step2View.topAnchor constant:16],
        [backBtn.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:8],

        [titleLabel.topAnchor constraintEqualToAnchor:backBtn.bottomAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:16],

        [stepLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [stepLabel.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:16],

        [_step2Scroll.topAnchor constraintEqualToAnchor:stepLabel.bottomAnchor constant:16],
        [_step2Scroll.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor],
        [_step2Scroll.trailingAnchor constraintEqualToAnchor:_step2View.trailingAnchor],
        [_step2Scroll.bottomAnchor constraintEqualToAnchor:_step2View.bottomAnchor],

        [_step2Stack.topAnchor constraintEqualToAnchor:_step2Scroll.topAnchor],
        [_step2Stack.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:16],
        [_step2Stack.trailingAnchor constraintEqualToAnchor:_step2View.trailingAnchor constant:-16],
        [_step2Stack.bottomAnchor constraintEqualToAnchor:_step2Scroll.bottomAnchor constant:-32],
    ]];

    [self buildGPSSection];
    [self buildDeviceSection];
    [self buildIdentifiersSection];
    [self buildSaveButton];
}

#pragma mark - GPS Section

- (void)buildGPSSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"GPS Spoofing"];

    MiOSToggleCell *gpsToggle = [[MiOSToggleCell alloc]
        initWithTitle:@"Enable GPS Spoof"
             subtitle:@"Override device location"
                 icon:@"location.fill"
                color:[UIColor systemBlueColor]
                  key:@"gpsEnabled"];
    gpsToggle.isOn = _gpsEnabled;
    gpsToggle.delegate = self;
    [section addCellView:gpsToggle];

    // GPS fields container
    _gpsFieldsContainer = [[UIView alloc] init];
    _gpsFieldsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _gpsFieldsContainer.hidden = !_gpsEnabled;

    _latField = [self createStyledTextFieldWithPlaceholder:@"Latitude" keyboardType:UIKeyboardTypeDecimalPad];
    _lonField = [self createStyledTextFieldWithPlaceholder:@"Longitude" keyboardType:UIKeyboardTypeDecimalPad];

    if (_editingContainer) {
        if (_editingContainer.latitude != 0) _latField.text = [NSString stringWithFormat:@"%f", _editingContainer.latitude];
        if (_editingContainer.longitude != 0) _lonField.text = [NSString stringWithFormat:@"%f", _editingContainer.longitude];
    }

    UIStackView *coordStack = [[UIStackView alloc] initWithArrangedSubviews:@[_latField, _lonField]];
    coordStack.translatesAutoresizingMaskIntoConstraints = NO;
    coordStack.axis = UILayoutConstraintAxisHorizontal;
    coordStack.spacing = 8;
    coordStack.distribution = UIStackViewDistributionFillEqually;
    [_gpsFieldsContainer addSubview:coordStack];

    [NSLayoutConstraint activateConstraints:@[
        [coordStack.topAnchor constraintEqualToAnchor:_gpsFieldsContainer.topAnchor constant:8],
        [coordStack.leadingAnchor constraintEqualToAnchor:_gpsFieldsContainer.leadingAnchor constant:16],
        [coordStack.trailingAnchor constraintEqualToAnchor:_gpsFieldsContainer.trailingAnchor constant:-16],
        [coordStack.bottomAnchor constraintEqualToAnchor:_gpsFieldsContainer.bottomAnchor constant:-8],
        [_latField.heightAnchor constraintEqualToConstant:44],
    ]];

    [section addCellView:_gpsFieldsContainer];
    [_step2Stack addArrangedSubview:section];
}

#pragma mark - Device Section

- (void)buildDeviceSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Device Spoofing"];

    MiOSToggleCell *deviceToggle = [[MiOSToggleCell alloc]
        initWithTitle:@"Enable Device Spoof"
             subtitle:@"Spoof device model and iOS version"
                 icon:@"iphone.gen3"
                color:[UIColor systemTealColor]
                  key:@"deviceSpoofEnabled"];
    deviceToggle.isOn = _deviceSpoofEnabled;
    deviceToggle.delegate = self;
    [section addCellView:deviceToggle];

    // Device picker container
    _devicePickerContainer = [[UIView alloc] init];
    _devicePickerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _devicePickerContainer.hidden = !_deviceSpoofEnabled;

    UILabel *deviceLabel = [[UILabel alloc] init];
    deviceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    deviceLabel.text = @"DEVICE MODEL";
    deviceLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    deviceLabel.textColor = [MiOSTheme tertiaryText];
    [_devicePickerContainer addSubview:deviceLabel];

    _devicePicker = [[UIPickerView alloc] init];
    _devicePicker.translatesAutoresizingMaskIntoConstraints = NO;
    _devicePicker.dataSource = self;
    _devicePicker.delegate = self;
    _devicePicker.tag = 100;
    [_devicePickerContainer addSubview:_devicePicker];

    UILabel *iosLabel = [[UILabel alloc] init];
    iosLabel.translatesAutoresizingMaskIntoConstraints = NO;
    iosLabel.text = @"iOS VERSION";
    iosLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    iosLabel.textColor = [MiOSTheme tertiaryText];
    [_devicePickerContainer addSubview:iosLabel];

    _iosPicker = [[UIPickerView alloc] init];
    _iosPicker.translatesAutoresizingMaskIntoConstraints = NO;
    _iosPicker.dataSource = self;
    _iosPicker.delegate = self;
    _iosPicker.tag = 200;
    [_devicePickerContainer addSubview:_iosPicker];

    // Preview label
    _devicePreviewLabel = [[UILabel alloc] init];
    _devicePreviewLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _devicePreviewLabel.font = [MiOSTheme captionFont];
    _devicePreviewLabel.textColor = [MiOSTheme accentColor];
    _devicePreviewLabel.textAlignment = NSTextAlignmentCenter;
    [_devicePickerContainer addSubview:_devicePreviewLabel];

    [NSLayoutConstraint activateConstraints:@[
        [deviceLabel.topAnchor constraintEqualToAnchor:_devicePickerContainer.topAnchor constant:12],
        [deviceLabel.leadingAnchor constraintEqualToAnchor:_devicePickerContainer.leadingAnchor constant:16],

        [_devicePicker.topAnchor constraintEqualToAnchor:deviceLabel.bottomAnchor constant:4],
        [_devicePicker.leadingAnchor constraintEqualToAnchor:_devicePickerContainer.leadingAnchor],
        [_devicePicker.trailingAnchor constraintEqualToAnchor:_devicePickerContainer.trailingAnchor],
        [_devicePicker.heightAnchor constraintEqualToConstant:120],

        [iosLabel.topAnchor constraintEqualToAnchor:_devicePicker.bottomAnchor constant:8],
        [iosLabel.leadingAnchor constraintEqualToAnchor:_devicePickerContainer.leadingAnchor constant:16],

        [_iosPicker.topAnchor constraintEqualToAnchor:iosLabel.bottomAnchor constant:4],
        [_iosPicker.leadingAnchor constraintEqualToAnchor:_devicePickerContainer.leadingAnchor],
        [_iosPicker.trailingAnchor constraintEqualToAnchor:_devicePickerContainer.trailingAnchor],
        [_iosPicker.heightAnchor constraintEqualToConstant:120],

        [_devicePreviewLabel.topAnchor constraintEqualToAnchor:_iosPicker.bottomAnchor constant:8],
        [_devicePreviewLabel.leadingAnchor constraintEqualToAnchor:_devicePickerContainer.leadingAnchor constant:16],
        [_devicePreviewLabel.trailingAnchor constraintEqualToAnchor:_devicePickerContainer.trailingAnchor constant:-16],
        [_devicePreviewLabel.bottomAnchor constraintEqualToAnchor:_devicePickerContainer.bottomAnchor constant:-12],
    ]];

    [section addCellView:_devicePickerContainer];
    [_step2Stack addArrangedSubview:section];

    // Pre-select device/ios version
    if (_selectedDeviceIndex < (NSInteger)_deviceList.count) {
        [_devicePicker selectRow:_selectedDeviceIndex inComponent:0 animated:NO];
    }
    if (_selectedIOSIndex < (NSInteger)_iosVersionList.count) {
        [_iosPicker selectRow:_selectedIOSIndex inComponent:0 animated:NO];
    }
    [self updateDevicePreview];
}

#pragma mark - Identifiers Section

- (void)buildIdentifiersSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Privacy & Identifiers"];

    // DeviceCheck
    MiOSToggleCell *deviceCheckCell = [[MiOSToggleCell alloc]
        initWithTitle:@"DeviceCheck Bypass"
             subtitle:@"Block DeviceCheck token generation"
                 icon:@"checkmark.shield.fill"
                color:[UIColor systemRedColor]
                  key:@"spoofDeviceCheck"];
    deviceCheckCell.isOn = _spoofDeviceCheck;
    deviceCheckCell.delegate = self;
    [section addCellView:deviceCheckCell];
    [section addSeparator];

    // Vendor ID
    MiOSToggleCell *vendorCell = [[MiOSToggleCell alloc]
        initWithTitle:@"Vendor ID Spoof"
             subtitle:@"Spoof identifierForVendor"
                 icon:@"person.badge.key.fill"
                color:[UIColor systemIndigoColor]
                  key:@"spoofVendorID"];
    vendorCell.isOn = _spoofVendorID;
    vendorCell.delegate = self;
    [section addCellView:vendorCell];

    _vendorIDContainer = [self buildUUIDRowWithValue:_vendorID ?: @"Not generated"
                                          labelOut:&_vendorIDLabel
                                       generateSel:@selector(generateVendorID)];
    _vendorIDContainer.hidden = !_spoofVendorID;
    [section addCellView:_vendorIDContainer];
    [section addSeparator];

    // Advertising ID
    MiOSToggleCell *adCell = [[MiOSToggleCell alloc]
        initWithTitle:@"Advertising ID Spoof"
             subtitle:@"Spoof advertisingIdentifier"
                 icon:@"megaphone.fill"
                color:[UIColor systemOrangeColor]
                  key:@"spoofAdvertisingID"];
    adCell.isOn = _spoofAdvertisingID;
    adCell.delegate = self;
    [section addCellView:adCell];

    _advertisingIDContainer = [self buildUUIDRowWithValue:_advertisingID ?: @"Not generated"
                                               labelOut:&_advertisingIDLabel
                                            generateSel:@selector(generateAdvertisingID)];
    _advertisingIDContainer.hidden = !_spoofAdvertisingID;
    [section addCellView:_advertisingIDContainer];
    [section addSeparator];

    // iCloud Token
    MiOSToggleCell *cloudCell = [[MiOSToggleCell alloc]
        initWithTitle:@"iCloud Token Spoof"
             subtitle:@"Return nil for ubiquityIdentityToken"
                 icon:@"icloud.slash.fill"
                color:[UIColor systemGrayColor]
                  key:@"spoofCloudToken"];
    cloudCell.isOn = _spoofCloudToken;
    cloudCell.delegate = self;
    [section addCellView:cloudCell];

    [_step2Stack addArrangedSubview:section];
}

- (UIView *)buildUUIDRowWithValue:(NSString *)value labelOut:(UILabel **)outLabel generateSel:(SEL)sel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.text = value;
    valueLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    valueLabel.textColor = [MiOSTheme secondaryText];
    valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [row addSubview:valueLabel];
    if (outLabel) *outLabel = valueLabel;

    UIButton *genBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    genBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [genBtn setTitle:@"Generate" forState:UIControlStateNormal];
    genBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [genBtn setTitleColor:[MiOSTheme accentColor] forState:UIControlStateNormal];
    genBtn.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.12];
    genBtn.layer.cornerRadius = 8;
    genBtn.layer.cornerCurve = kCACornerCurveContinuous;
    genBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
    [genBtn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:genBtn];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:44],
        [valueLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [valueLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [valueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:genBtn.leadingAnchor constant:-8],
        [genBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [genBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];

    return row;
}

- (void)generateVendorID {
    _vendorID = [[NSUUID UUID] UUIDString];
    _vendorIDLabel.text = _vendorID;
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
}

- (void)generateAdvertisingID {
    _advertisingID = [[NSUUID UUID] UUIDString];
    _advertisingIDLabel.text = _advertisingID;
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
}

#pragma mark - Save Button

- (void)buildSaveButton {
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [saveBtn setTitle:@"Save Container" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    saveBtn.layer.cornerRadius = 14;
    saveBtn.layer.cornerCurve = kCACornerCurveContinuous;
    saveBtn.clipsToBounds = YES;
    [saveBtn addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [saveBtn.heightAnchor constraintEqualToConstant:50].active = YES;

    // We apply a gradient background via a sublayer
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect btnBounds = CGRectMake(0, 0, self.view.bounds.size.width - 32, 50);
        CAGradientLayer *grad = [MiOSTheme accentGradientForBounds:btnBounds];
        grad.cornerRadius = 14;
        [saveBtn.layer insertSublayer:grad atIndex:0];
    });

    [_step2Stack addArrangedSubview:saveBtn];
}

- (void)saveTapped {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [haptic impactOccurred];

    MiOSContainerConfig *config = _editingContainer ?: [[MiOSContainerConfig alloc] init];

    // If new, generate UUID
    if (!_editingContainer) {
        config.identifier = [[NSUUID UUID] UUIDString];
    }

    config.name = [_nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    config.apps = [[_selectedBundleIDs allObjects] mutableCopy];

    // GPS
    config.gpsEnabled = _gpsEnabled;
    config.latitude = [_latField.text doubleValue];
    config.longitude = [_lonField.text doubleValue];

    // Device
    config.deviceSpoofEnabled = _deviceSpoofEnabled;
    if (_deviceSpoofEnabled && _selectedDeviceIndex < (NSInteger)_deviceList.count) {
        MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
        config.deviceIdentifier = device.identifier;
        config.deviceName = device.displayName;
        config.hwModel = device.hwModel;
    }
    if (_deviceSpoofEnabled && _selectedIOSIndex < (NSInteger)_iosVersionList.count) {
        config.iosVersion = _iosVersionList[_selectedIOSIndex];
    }

    // Identifiers
    config.spoofDeviceCheck = _spoofDeviceCheck;
    config.spoofVendorID = _spoofVendorID;
    config.vendorID = _vendorID;
    config.spoofAdvertisingID = _spoofAdvertisingID;
    config.advertisingID = _advertisingID;
    config.spoofCloudToken = _spoofCloudToken;

    // Apply to system
    [config applyToSystem];

    // Save to list
    NSMutableArray<MiOSContainerConfig *> *all = [[MiOSContainerConfig loadAll] mutableCopy] ?: [NSMutableArray array];
    if (_editingContainer) {
        // Replace existing
        for (NSUInteger i = 0; i < all.count; i++) {
            if ([all[i].identifier isEqualToString:config.identifier]) {
                [all replaceObjectAtIndex:i withObject:config];
                break;
            }
        }
    } else {
        [all addObject:config];
    }
    [MiOSContainerConfig saveAll:all];
    [MiOSContainerConfig setActiveContainerID:config.identifier];

    if (_onSave) {
        _onSave();
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helper: Styled Text Field

- (UITextField *)createStyledTextFieldWithPlaceholder:(NSString *)placeholder keyboardType:(UIKeyboardType)type {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.font = [MiOSTheme bodyFont];
    field.textColor = [MiOSTheme primaryText];
    field.backgroundColor = [MiOSTheme secondaryBackground];
    field.layer.cornerRadius = 10;
    field.layer.cornerCurve = kCACornerCurveContinuous;
    field.layer.borderColor = [MiOSTheme separator].CGColor;
    field.layer.borderWidth = 0.5;
    field.keyboardType = type;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;

    UIView *lpad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    field.leftView = lpad;
    field.leftViewMode = UITextFieldViewModeAlways;
    UIView *rpad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    field.rightView = rpad;
    field.rightViewMode = UITextFieldViewModeAlways;

    return field;
}

#pragma mark - Device Picker Helpers

- (void)updateIOSVersionsForDevice {
    if (_selectedDeviceIndex < (NSInteger)_deviceList.count) {
        MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
        _iosVersionList = [MiOSDeviceDatabase supportedIOSVersionsForDevice:device];
    } else {
        _iosVersionList = [MiOSDeviceDatabase allIOSVersions];
    }
    _selectedIOSIndex = 0;
    [_iosPicker reloadAllComponents];
    if (_iosVersionList.count > 0) {
        [_iosPicker selectRow:0 inComponent:0 animated:YES];
    }
}

- (void)updateDevicePreview {
    NSString *deviceName = @"Unknown";
    NSString *iosVer = @"";

    if (_selectedDeviceIndex < (NSInteger)_deviceList.count) {
        deviceName = _deviceList[_selectedDeviceIndex].displayName;
    }
    if (_selectedIOSIndex < (NSInteger)_iosVersionList.count) {
        iosVer = _iosVersionList[_selectedIOSIndex];
    }

    _devicePreviewLabel.text = [NSString stringWithFormat:@"%@ - iOS %@", deviceName, iosVer];
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)_filteredApps.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MiOSAppCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kAppCellReuseID
                                                                           forIndexPath:indexPath];
    MiOSAppInfo *app = _filteredApps[indexPath.item];
    cell.iconView.image = app.icon;
    cell.nameLabel.text = app.name;
    cell.bundleLabel.text = app.bundleID;
    cell.isChecked = [_selectedBundleIDs containsObject:app.bundleID];
    return cell;
}

#pragma mark - UICollectionView Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];

    MiOSAppInfo *app = _filteredApps[indexPath.item];
    if ([_selectedBundleIDs containsObject:app.bundleID]) {
        [_selectedBundleIDs removeObject:app.bundleID];
    } else {
        [_selectedBundleIDs addObject:app.bundleID];
    }

    MiOSAppCollectionCell *cell = (MiOSAppCollectionCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.isChecked = [_selectedBundleIDs containsObject:app.bundleID];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    [self updateNextButtonTitle];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (collectionView.bounds.size.width - 8) / 2.0;
    return CGSizeMake(width, 80);
}

#pragma mark - UIPickerView DataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == 100) {
        return (NSInteger)_deviceList.count;
    }
    return (NSInteger)_iosVersionList.count;
}

#pragma mark - UIPickerView Delegate

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row
          forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel *label = (UILabel *)view;
    if (!label) {
        label = [[UILabel alloc] init];
        label.font = [MiOSTheme bodyFont];
        label.textColor = [MiOSTheme primaryText];
        label.textAlignment = NSTextAlignmentCenter;
    }

    if (pickerView.tag == 100 && row < (NSInteger)_deviceList.count) {
        MiOSDeviceModel *device = _deviceList[row];
        label.text = device.displayName;
    } else if (pickerView.tag == 200 && row < (NSInteger)_iosVersionList.count) {
        label.text = _iosVersionList[row];
    }

    return label;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (pickerView.tag == 100) {
        _selectedDeviceIndex = row;
        [self updateIOSVersionsForDevice];
    } else {
        _selectedIOSIndex = row;
    }
    [self updateDevicePreview];
}

#pragma mark - MiOSToggleCellDelegate

- (void)toggleCell:(id)cell didChangeValue:(BOOL)value forKey:(NSString *)key {
    if ([key isEqualToString:@"gpsEnabled"]) {
        _gpsEnabled = value;
        _gpsFieldsContainer.hidden = !value;
    } else if ([key isEqualToString:@"deviceSpoofEnabled"]) {
        _deviceSpoofEnabled = value;
        _devicePickerContainer.hidden = !value;
    } else if ([key isEqualToString:@"spoofDeviceCheck"]) {
        _spoofDeviceCheck = value;
    } else if ([key isEqualToString:@"spoofVendorID"]) {
        _spoofVendorID = value;
        _vendorIDContainer.hidden = !value;
        if (value && !_vendorID) {
            _vendorID = [[NSUUID UUID] UUIDString];
            _vendorIDLabel.text = _vendorID;
        }
    } else if ([key isEqualToString:@"spoofAdvertisingID"]) {
        _spoofAdvertisingID = value;
        _advertisingIDContainer.hidden = !value;
        if (value && !_advertisingID) {
            _advertisingID = [[NSUUID UUID] UUIDString];
            _advertisingIDLabel.text = _advertisingID;
        }
    } else if ([key isEqualToString:@"spoofCloudToken"]) {
        _spoofCloudToken = value;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterApps];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Segmented Control

- (void)segmentChanged {
    [self filterApps];
}

@end
