#import "XXRootViewController.h"
#import "XXLogsViewController.h"
#import <UIKit/UIKit.h>
#import <UIKit/UIImage+Private.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <AltList/LSApplicationProxy+AltList.h>

@interface XXBottomSheetViewController : UIViewController
@property (nonatomic, strong) NSString *appName;
@property (nonatomic, strong) NSString *appPath;
- (instancetype)initWithAppName:(NSString *)appName appPath:(NSString *)appPath;
@end

@interface XXRootViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) LSApplicationWorkspace *workspace;
@property (nonatomic, strong) NSArray *installedApps;
@end

@implementation XXRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Installed Apps";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.workspace = [LSApplicationWorkspace defaultWorkspace];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"AppCell"];
    [self.view addSubview:self.tableView];
    
    [self loadInstalledApps];
}

-  (void)loadInstalledApps {
	NSArray *applications = [self.workspace atl_allInstalledApplications];
	NSMutableArray *apps = [NSMutableArray array];

	for (LSApplicationProxy *proxy in applications) {
		if(![proxy atl_isHidden]) {
			[apps addObject:@{
				@"proxy":proxy,
				@"bundleID":proxy.atl_bundleIdentifier ?: @"",
				@"name":[proxy atl_nameToDisplay] ?: proxy.atl_bundleIdentifier ?: @"Unknown",
				@"bundlePath":[proxy bundleURL].path ?: @""
			}];
		}
	}
// if proxy atl_nameToDisplay contains hdfc, nslog proxy
	for (NSDictionary *app in apps) {
		if ([[app[@"name"] lowercaseString] containsString:@"compass"]) {
			NSLog(@"H3ck - app: %@", app);
		}
	}
	self.installedApps = [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *app1, NSDictionary *app2) {
		return [app1[@"name"] compare:app2[@"name"] options:NSCaseInsensitiveSearch];
	}];

	[self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.installedApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppCell" forIndexPath:indexPath];
	NSDictionary *app = self.installedApps[indexPath.row];
	LSApplicationProxy *proxy = app[@"proxy"];

	UIListContentConfiguration *config = [UIListContentConfiguration valueCellConfiguration];
	config.text = [NSString stringWithFormat:@"%@ \n %@", app[@"name"], app[@"bundleID"]];
	config.secondaryText = app[@"bundlePath"];
	// config.thirdText = app[@"bundlePath"];

	NSString *bundlePath = [proxy bundleURL].path;
 	NSString *iconPath = [bundlePath stringByAppendingPathComponent:@"AppIcon60x60@2x.png"];
    UIImage *icon = [UIImage imageWithContentsOfFile:iconPath];

// if (!icon) then we will use `+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(MIIconVariant)format scale:(CGFloat)scale;`
// UIKit/UIImages.h
    if (!icon) { 
        icon = [UIImage _applicationIconImageForBundleIdentifier:app[@"bundleID"] format:2 scale:2.0];
        NSLog(@"H3ck - new iconPath for app %@: %@", app[@"name"], icon);
    }
    // if (!icon) {
    //     iconPath = [bundlePath stringByAppendingPathComponent:@"Icon-60@2x.png"];
    //     icon = [UIImage imageWithContentsOfFile:iconPath];
	// 	NSLog(@"H3ck - new iconPath for app %@: %@", app[@"name"], iconPath);
    // }

	if (icon) {
        config.image = icon;
    } else {
        config.image = [UIImage systemImageNamed:@"app.fill"];
    }
    
    config.imageProperties.maximumSize = CGSizeMake(40, 40);
    config.imageProperties.cornerRadius = 8;
    
    cell.contentConfiguration = config;
    return cell;
}

// show bottomsheet when click on table cell

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *app = self.installedApps[indexPath.row];
    NSString *appName = app[@"name"];
    NSString *appPath = app[@"bundlePath"];
    
    XXBottomSheetViewController *bottomSheet = [[XXBottomSheetViewController alloc] initWithAppName:appName appPath:appPath];
    
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = bottomSheet.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent]
            ];
            sheet.prefersGrabberVisible = YES;
        }
    } else {
        // Fallback for iOS 14: Present as a regular modal
        bottomSheet.modalPresentationStyle = UIModalPresentationFormSheet;
        bottomSheet.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    
    [self presentViewController:bottomSheet animated:YES completion:nil];
}

@end

@implementation XXBottomSheetViewController

- (instancetype)initWithAppName:(NSString *)appName appPath:(NSString *)appPath {
    self = [super init];
    if (self) {
        _appName = appName;
        _appPath = appPath;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Add container view for content
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:containerView];
    
    // Add label
    UILabel *label = [[UILabel alloc] init];
    label.text = self.appName;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:label];
    
    // Add button
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"Decrypt Binary" forState:UIControlStateNormal];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:@selector(showLogs) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:button];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [containerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        
        [label.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [label.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        
        [button.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:20],
        [button.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        
        [containerView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [containerView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [containerView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor]
    ]];
}

- (void)showLogs {
    XXLogsViewController *logsVC = [[XXLogsViewController alloc] init];
    
    // Get the app name from the bundle path to find the binary
    NSString *appName = [self.appPath lastPathComponent];
    NSString *binaryName = [appName stringByDeletingPathExtension];
    NSString *binaryPath = [self.appPath stringByAppendingPathComponent:binaryName];
    
    logsVC.binaryPath = binaryPath;
    NSLog(@"H3ck - Binary Path: %@", binaryPath);
    
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = logsVC.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent largeDetent]
            ];
            sheet.prefersGrabberVisible = YES;
        }
    } else {
        // Fallback for iOS 14: Present as a regular modal
        logsVC.modalPresentationStyle = UIModalPresentationFormSheet;
        logsVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    
    [self presentViewController:logsVC animated:YES completion:^{
        // Start decryption automatically when view is presented
        [logsVC startDecryption];
    }];
}


@end