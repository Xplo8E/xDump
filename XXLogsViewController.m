#import "XXLogsViewController.h"
#import "XXDecryptor.h"

@implementation XXLogsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"Decryption Logs";
    
    // Create a container view for better layout
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:containerView];
    
    // Add path label
    UILabel *pathLabel = [[UILabel alloc] init];
    pathLabel.text = [NSString stringWithFormat:@"Binary Path: %@", self.binaryPath];
    pathLabel.numberOfLines = 0;
    pathLabel.font = [UIFont systemFontOfSize:12];
    pathLabel.textColor = [UIColor secondaryLabelColor];
    pathLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:pathLabel];
    
    // Add logs text view
    self.logsTextView = [[UITextView alloc] init];
    self.logsTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logsTextView.editable = NO;
    self.logsTextView.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.logsTextView.backgroundColor = [UIColor systemGray6Color];
    self.logsTextView.layer.cornerRadius = 8;
    self.logsTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [containerView addSubview:self.logsTextView];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        // Container constraints
        [containerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20],
        
        // Path label constraints
        [pathLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [pathLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [pathLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        
        // Logs text view constraints
        [self.logsTextView.topAnchor constraintEqualToAnchor:pathLabel.bottomAnchor constant:10],
        [self.logsTextView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [self.logsTextView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [self.logsTextView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];
    
    // Add initial logs
    [self addLog:@"=== System Info ==="];
    [self addLog:[NSString stringWithFormat:@"Device: %@", [[UIDevice currentDevice] model]]];
    [self addLog:[NSString stringWithFormat:@"iOS Version: %@", [[UIDevice currentDevice] systemVersion]]];
    [self addLog:[NSString stringWithFormat:@"Binary Path: %@", self.binaryPath]];
    [self addLog:@"=== Ready for decryption ==="];
}

- (void)addLog:(NSString *)log {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [self currentTimestamp];
        NSString *formattedLog = [NSString stringWithFormat:@"[%@] %@\n", timestamp, log];
        self.logsTextView.text = [self.logsTextView.text stringByAppendingString:formattedLog];
        
        // Scroll to bottom
        NSRange range = NSMakeRange(self.logsTextView.text.length, 0);
        [self.logsTextView scrollRangeToVisible:range];
    });
}

- (NSString *)currentTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    return [formatter stringFromDate:[NSDate date]];
}

- (void)startDecryption {
    if (!self.binaryPath || [self.binaryPath length] == 0) {
        [self addLog:@"Error: No binary path specified"];
        return;
    }
    
    [self addLog:@"Starting decryption process..."];
    [self addLog:[NSString stringWithFormat:@"Target binary: %@", self.binaryPath]];
    
    // Create output path in Documents directory
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *outputDirectory = [documentDirectory stringByAppendingPathComponent:@"Decrypted"];
    NSString *outputPath = [outputDirectory stringByAppendingPathComponent:[self.binaryPath lastPathComponent]];
    
    [self addLog:[NSString stringWithFormat:@"Output path: %@", outputPath]];
    
    // Run decryption in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self addLog:@"Starting binary decryption..."];
        
        BOOL success = [XXDecryptor decryptBinary:self.binaryPath toPath:outputPath withLog:^(NSString *log) {
            [self addLog:log];
        }];
        
        if (success) {
            [self addLog:@"✅ Decryption completed successfully!"];
            [self addLog:[NSString stringWithFormat:@"Decrypted binary saved to: %@", outputPath]];
        } else {
            [self addLog:@"❌ Decryption failed"];
        }
    });
}

@end