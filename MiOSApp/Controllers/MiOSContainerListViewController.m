#import "MiOSContainerListViewController.h"
#import "MiOSContainerDetailViewController.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"

static NSString *const kMiOSContainerPrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.containerprefs.plist";

@interface MiOSContainerListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *apps;
@property (nonatomic, strong) NSMutableDictionary *containerPrefs;
@end

@implementation MiOSContainerListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Containers";
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    [self loadApps];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadApps];
    [_tableView reloadData];
}

- (void)loadApps {
    _containerPrefs = [[NSMutableDictionary dictionaryWithContentsOfFile:kMiOSContainerPrefsPath] mutableCopy];
    if (!_containerPrefs) _containerPrefs = [NSMutableDictionary new];

    _apps = [NSMutableArray new];
    NSString *appPath = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *uuids = [fm contentsOfDirectoryAtPath:appPath error:nil];

    for (NSString *uuid in uuids) {
        NSString *metaPath = [[appPath stringByAppendingPathComponent:uuid]
                              stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *bid = meta[@"MCMMetadataIdentifier"];
        if (!bid) continue;

        NSString *containerDir = [[appPath stringByAppendingPathComponent:uuid]
                                  stringByAppendingPathComponent:@"___MiOS_Containers"];
        NSArray *containers = [fm contentsOfDirectoryAtPath:containerDir error:nil];
        NSUInteger count = containers.count;

        [_apps addObject:@{
            @"bundleID": bid,
            @"path": [appPath stringByAppendingPathComponent:uuid],
            @"containerCount": @(count),
        }];
    }

    [_apps sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"bundleID"] compare:b[@"bundleID"]];
    }];
}

- (void)setupUI {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorColor = [MiOSTheme separator];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AppCell"];
    [self.view addSubview:_tableView];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"info.circle"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(showInfo)];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _apps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppCell" forIndexPath:indexPath];

    NSDictionary *app = _apps[indexPath.row];
    cell.textLabel.text = app[@"bundleID"];
    cell.textLabel.font = [MiOSTheme bodyFont];
    cell.textLabel.textColor = [MiOSTheme primaryText];
    cell.backgroundColor = [MiOSTheme cardBackground];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    NSUInteger count = [app[@"containerCount"] unsignedIntegerValue];
    if (count > 0) {
        UILabel *badge = [[UILabel alloc] init];
        badge.text = [NSString stringWithFormat:@"%lu", (unsigned long)count];
        badge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        badge.textColor = [UIColor whiteColor];
        badge.backgroundColor = [MiOSTheme accentColor];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 10;
        badge.layer.masksToBounds = YES;
        [badge sizeToFit];
        badge.frame = CGRectMake(0, 0, MAX(badge.frame.size.width + 12, 20), 20);
        cell.accessoryView = badge;
    } else {
        cell.accessoryView = nil;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *app = _apps[indexPath.row];
    MiOSContainerDetailViewController *vc = [[MiOSContainerDetailViewController alloc] initWithBundleID:app[@"bundleID"] appDataPath:app[@"path"]];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showInfo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Containers"
        message:@"Containers let you run separate instances of an app with isolated data. Each container has its own Documents, Library, and Caches.\n\nSelect an app to manage its containers."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
