#import "MiOSContainerDetailViewController.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"

static NSString *const kMiOSContainerDirName = @"___MiOS_Containers";
static NSString *const kMiOSContainerPrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.containerprefs.plist";

@interface MiOSContainerDetailViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *appDataPath;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *containers;
@property (nonatomic, copy) NSString *activeContainerID;
@end

@implementation MiOSContainerDetailViewController

- (instancetype)initWithBundleID:(NSString *)bundleID appDataPath:(NSString *)path {
    if (self = [super init]) {
        _bundleID = [bundleID copy];
        _appDataPath = [path copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _bundleID;
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    [self loadContainers];
    [self setupUI];
}

- (void)loadContainers {
    _containers = [NSMutableArray new];
    [_containers addObject:@{@"id": @"DEFAULT", @"name": @"Default"}];

    NSMutableDictionary *prefs = [[NSDictionary dictionaryWithContentsOfFile:kMiOSContainerPrefsPath] mutableCopy];
    NSDictionary *activeMap = prefs[@"activeContainers"];
    _activeContainerID = activeMap[_bundleID] ?: @"DEFAULT";

    NSString *containerDir = [_appDataPath stringByAppendingPathComponent:kMiOSContainerDirName];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = [fm contentsOfDirectoryAtPath:containerDir error:nil];
    for (NSString *dir in dirs) {
        NSString *metaPath = [[containerDir stringByAppendingPathComponent:dir]
                              stringByAppendingPathComponent:@".mios_container_meta.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *name = meta[@"name"] ?: dir;
        [_containers addObject:@{@"id": dir, @"name": name}];
    }
}

- (void)setupUI {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorColor = [MiOSTheme separator];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.view addSubview:_tableView];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                             target:self
                             action:@selector(addContainer)];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Containers" : @"Actions";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? _containers.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.backgroundColor = [MiOSTheme cardBackground];
    cell.textLabel.textColor = [MiOSTheme primaryText];
    cell.textLabel.font = [MiOSTheme bodyFont];

    if (indexPath.section == 0) {
        NSDictionary *container = _containers[indexPath.row];
        cell.textLabel.text = container[@"name"];
        BOOL isActive = [container[@"id"] isEqualToString:_activeContainerID];
        cell.accessoryType = isActive ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.tintColor = [MiOSTheme accentColor];

        if (isActive) {
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
            dot.backgroundColor = [MiOSTheme success];
            dot.layer.cornerRadius = 4;
            cell.imageView.image = [self circleImageWithColor:[MiOSTheme success] size:12];
        } else {
            cell.imageView.image = [self circleImageWithColor:[MiOSTheme separator] size:12];
        }
    } else {
        cell.textLabel.text = @"Delete All Containers";
        cell.textLabel.textColor = [MiOSTheme destructive];
        cell.imageView.image = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        NSDictionary *container = _containers[indexPath.row];
        _activeContainerID = container[@"id"];
        [self saveActiveContainer];
        [_tableView reloadData];
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [haptic impactOccurred];
    } else {
        [self confirmDeleteAll];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0 || indexPath.row == 0) return nil;

    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
        title:@"Delete" handler:^(UIContextualAction *action, UIView *srcView, void (^handler)(BOOL)) {
            [self deleteContainerAtIndex:indexPath.row];
            handler(YES);
        }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (void)addContainer {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Container"
                                                                  message:@"Enter a name for the new container"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Container name...";
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) return;
        [weakSelf createContainerWithName:name];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createContainerWithName:(NSString *)name {
    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *containerDir = [_appDataPath stringByAppendingPathComponent:kMiOSContainerDirName];
    NSString *containerPath = [containerDir stringByAppendingPathComponent:uuid];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *subdirs = @[@"Documents", @"Library", @"Library/Preferences", @"Library/Caches",
                         @"Library/Application Support", @"Library/SplashBoard", @"SystemData", @"tmp"];
    for (NSString *sub in subdirs) {
        [fm createDirectoryAtPath:[containerPath stringByAppendingPathComponent:sub]
      withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSDictionary *meta = @{@"name": name, @"createdAt": [NSDate date].description, @"bundleID": _bundleID};
    NSString *metaFile = [containerPath stringByAppendingPathComponent:@".mios_container_meta.plist"];
    [meta writeToFile:metaFile atomically:YES];

    [_containers addObject:@{@"id": uuid, @"name": name}];
    [_tableView reloadData];
}

- (void)deleteContainerAtIndex:(NSInteger)index {
    NSDictionary *container = _containers[index];
    NSString *containerDir = [_appDataPath stringByAppendingPathComponent:kMiOSContainerDirName];
    NSString *path = [containerDir stringByAppendingPathComponent:container[@"id"]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

    if ([_activeContainerID isEqualToString:container[@"id"]]) {
        _activeContainerID = @"DEFAULT";
        [self saveActiveContainer];
    }

    [_containers removeObjectAtIndex:index];
    [_tableView reloadData];
}

- (void)confirmDeleteAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete All Containers"
        message:[NSString stringWithFormat:@"This will delete all containers for %@. This cannot be undone.", _bundleID]
        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *containerDir = [weakSelf.appDataPath stringByAppendingPathComponent:kMiOSContainerDirName];
        [[NSFileManager defaultManager] removeItemAtPath:containerDir error:nil];
        weakSelf.activeContainerID = @"DEFAULT";
        [weakSelf saveActiveContainer];
        [weakSelf loadContainers];
        [weakSelf.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveActiveContainer {
    NSMutableDictionary *prefs = [[NSDictionary dictionaryWithContentsOfFile:kMiOSContainerPrefsPath] mutableCopy];
    if (!prefs) prefs = [NSMutableDictionary new];
    NSMutableDictionary *active = [prefs[@"activeContainers"] mutableCopy] ?: [NSMutableDictionary new];
    active[_bundleID] = _activeContainerID;
    prefs[@"activeContainers"] = active;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [kMiOSContainerPrefsPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [prefs writeToFile:kMiOSContainerPrefsPath atomically:YES];
}

- (UIImage *)circleImageWithColor:(UIColor *)color size:(CGFloat)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    [color setFill];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)];
    [path fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
