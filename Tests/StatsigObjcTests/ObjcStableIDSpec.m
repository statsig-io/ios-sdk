#import <XCTest/XCTest.h>
#import "ObjcTestUtils.h"

@import Statsig;

@interface ObjcStableIDSpec : XCTestCase
@end

static inline void CheckStringEqual(NSString *left, NSString *right) {
    XCTAssertTrue([left isEqualToString:right], @"Strings are not equal %@ %@", left, right);
}

@implementation ObjcStableIDSpec {
    XCTestExpectation *_userUpdatedExpectation;
}

- (void)setUp {
    [ObjcTestUtils stubNetwork];
}

- (void)tearDown {
    [Statsig shutdown];
}

- (void)testOverridingStableID {
    StatsigOptions *opts = [[StatsigOptions alloc]
                            initWithArgs:@{@"overrideStableID": @"custom_stable_id"}];
    [Statsig initializeWithSDKKey:@"client-key" options:opts];

    CheckStringEqual([Statsig getStableID], @"custom_stable_id");
}

- (void)testPersistingOverShutdown {
    StatsigOptions *opts = [[StatsigOptions alloc]
                            initWithArgs:@{@"overrideStableID": @"persisted_stable_id"}];
    [Statsig initializeWithSDKKey:@"client-key" options:opts];

    [Statsig shutdown];
    [Statsig initializeWithSDKKey:@"client-key"];
    CheckStringEqual([Statsig getStableID], @"persisted_stable_id");
}

@end
