#import <UIKit/UIKit.h>

@interface XXLogsViewController : UIViewController

@property (nonatomic, strong) NSString *binaryPath;
@property (nonatomic, strong) UITextView *logsTextView;

- (void)addLog:(NSString *)log;
- (void)startDecryption;

@end
