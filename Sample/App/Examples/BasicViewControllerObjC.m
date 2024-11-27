#import "BasicViewControllerObjC.h"
#import "StatsigSamples-Swift.h"

@import Statsig;

@implementation BasicViewControllerObjC

- (void)viewDidLoad {
    [super viewDidLoad];

    StatsigUser *user =
    [[StatsigUser alloc]
     initWithUserID:@"a-user"
     email:nil
     ip:nil
     country:nil
     locale:nil
     appVersion:nil
     custom:@{
        @"name": @"jkw",
        @"speed": @1.2,
        @"verified": @true,
        @"visits": @3,
        @"tags": @[@"cool", @"rad", @"neat"],
    }
     privateAttributes:nil];

    [Statsig
     startWithSDKKey:Constants.CLIENT_SDK_KEY
     user:user
     completion:^(StatsigClientError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error %@", error);
            return;
        }

        Boolean gate = [Statsig checkGateForName:@"a_gate"];

        NSLog(@"Result: %@", gate ? @"Pass" : @"Fail");
        self.view.backgroundColor = gate ? UIColor.systemGreenColor : UIColor.systemRedColor;
    }];

    [Statsig logEvent:@"statsig_init_start"];
    [Statsig logEvent:@"statsig_init_time" doubleValue:[[NSDate now] timeIntervalSince1970] * 1000];
}

@end
