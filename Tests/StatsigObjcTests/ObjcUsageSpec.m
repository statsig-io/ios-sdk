#import <XCTest/XCTest.h>

#import "ObjcTestUtils.h"

@import Statsig;

@interface ObjcUsageSpec : XCTestCase
@end

@implementation ObjcUsageSpec {
    XCTestExpectation *_requestExpectation;
    StatsigUser *_user;
    StatsigOptions *_options;
    void (^_completion)(NSString * _Nullable);
    void (^_completionWithResult)(StatsigClientError * _Nullable);
}

- (void)setUp {
    _requestExpectation = [ObjcTestUtils stubNetwork];
    _user = [[StatsigUser alloc]
             initWithUserID:@"a-user"
             email:@""
             ip:nil
             country:nil
             locale:nil
             appVersion:nil
             custom:nil
             privateAttributes:nil];

    _options = [[StatsigOptions alloc] initWithArgs:@{@"initTimeout": @2}];
    _completion = ^(NSString * _Nullable err) {};
    _completionWithResult = ^(StatsigClientError * _Nullable err) {};
}

- (void)tearDown {
    [Statsig shutdown];
}

- (void)testStartWithKey __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-"];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyOptions __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" options:_options];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyCompletion __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" completion:_completion];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyUser __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" user:_user];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyUserCompletion __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" user:_user completion:_completion];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyUserOptions __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" user:_user options:_options];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyOptionsCompletion __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" options:_options completion:_completion];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testStartWithKeyUserOptionsCompletion __attribute((deprecated("Testing deprecated function"))) {
    [Statsig startWithSDKKey:@"client-" user:_user options:_options completion:_completion];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKey {
    [Statsig initializeWithSDKKey:@"client-"];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyOptions {
    [Statsig initializeWithSDKKey:@"client-" options:_options];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyCompletion {
    [Statsig initializeWithSDKKey:@"client-" completion:_completionWithResult];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyUser {
    [Statsig initializeWithSDKKey:@"client-" user:_user];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyUserCompletion {
    [Statsig initializeWithSDKKey:@"client-" user:_user completion:_completionWithResult];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyUserOptions {
    [Statsig initializeWithSDKKey:@"client-" user:_user options:_options];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyOptionsCompletion {
    [Statsig initializeWithSDKKey:@"client-" options:_options completion:_completionWithResult];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testInitializeWithKeyUserOptionsCompletion {
    [Statsig initializeWithSDKKey:@"client-" user:_user options:_options completion:_completionWithResult];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)testCheckGate {
    [self initializeStatsig];

    BOOL result = [Statsig checkGateForName:@"test_public"];
    XCTAssertTrue(result);
}

- (void)testGetConfig {
    [self initializeStatsig];

    DynamicConfig *result = [Statsig getConfigForName:@"test_disabled_config"];
    XCTAssertEqualObjects([result getStringForKey:@"default" defaultValue:@"err"], @"disabled but default");
}

- (void)testGetExperiment {
    [self initializeStatsig];

    DynamicConfig *result = [Statsig getExperimentForName:@"experiment_with_many_params"];
    XCTAssertEqualObjects([result getStringForKey:@"a_string" defaultValue:@"err"], @"layer");
}

- (void)testGetLayer {
    [self initializeStatsig];

    Layer *result = [Statsig getLayerForName:@"layer_with_many_params"];
    XCTAssertEqualObjects([result getStringForKey:@"another_string" defaultValue:@"err"], @"layer_default");
}


#pragma mark - Helpers

- (void)initializeStatsig
{
    [Statsig initializeWithSDKKey:@"client-"];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

@end

