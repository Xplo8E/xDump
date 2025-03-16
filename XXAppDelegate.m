#import "XXAppDelegate.h"
#import "XXRootViewController.h"

@implementation XXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

	XXRootViewController *rootViewController = [[XXRootViewController alloc] init];
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:rootViewController];

	self.window.rootViewController = navigationController;
	[self.window makeKeyAndVisible];
	return YES;
}

@end
