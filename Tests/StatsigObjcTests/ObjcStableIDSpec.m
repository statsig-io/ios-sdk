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
    [Statsig startWithSDKKey:@"client-key"
                     options:[[StatsigOptions alloc]
                              initWithOverrideStableID:@"custom_stable_id"]];

    CheckStringEqual([Statsig getStableID], @"custom_stable_id");
}

- (void)testPersistingOverShutdown {
    [Statsig startWithSDKKey:@"client-key"
                     options:[[StatsigOptions alloc]
                              initWithOverrideStableID:@"persisted_stable_id"]];

    [Statsig shutdown];
    [Statsig startWithSDKKey:@"client-key"];
    CheckStringEqual([Statsig getStableID], @"persisted_stable_id");
}

@end
