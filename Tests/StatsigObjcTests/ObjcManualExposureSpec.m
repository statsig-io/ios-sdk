#import <XCTest/XCTest.h>

#import "ObjcTestUtils.h"

@import Statsig;

@interface ObjcManualExposureSpec : XCTestCase
@end

@implementation ObjcManualExposureSpec {
    XCTestExpectation *_requestExpectation;
    StatsigUser *_user;
    StatsigOptions *_options;
    void (^_completion)(NSString * _Nullable);
    NSArray *_logs;
}

- (void)setUp {
    _logs = [NSMutableArray array];

    _requestExpectation = [ObjcTestUtils stubNetworkCapturingLogs:^(NSArray * _Nonnull logs) {
        _logs = [_logs arrayByAddingObjectsFromArray:logs];
    }];

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
}

- (void)tearDown {
    [Statsig shutdown];
}

- (void)testManualGateExposure {
    [self initializeStatsig];

    FeatureGate *gate = [Statsig getFeatureGateWithExposureLoggingDisabled:@"test_public"];
    NSData *encoded = [gate toData];

    FeatureGate *decoded = [FeatureGate fromData:encoded];
    [Statsig manuallyLogExposureWithFeatureGate:decoded];

    [self shutdownStatsig];
    XCTAssertEqual(_logs.count, 1);
    XCTAssertEqualObjects(_logs[0][@"eventName"], @"statsig::gate_exposure");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"gate"], @"test_public");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"isManualExposure"], @"true");
}

- (void)testManualConfigExposure {
    [self initializeStatsig];

    DynamicConfig *config = [Statsig getConfigWithExposureLoggingDisabled:@"test_disabled_config"];
    NSData *encoded = [config toData];

    DynamicConfig *decoded = [DynamicConfig fromData:encoded];
    [Statsig manuallyLogExposureWithDynamicConfig:decoded];

    [self shutdownStatsig];
    XCTAssertEqual(_logs.count, 1);
    XCTAssertEqualObjects(_logs[0][@"eventName"], @"statsig::config_exposure");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"config"], @"test_disabled_config");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"isManualExposure"], @"true");
}

- (void)testManualLayerExposure {
    [self initializeStatsig];

    Layer *layer = [Statsig getLayerWithExposureLoggingDisabled:@"layer_with_many_params"];
    NSData *encoded = [layer toData];

    Layer *decoded = [Layer fromData:encoded];
    [Statsig manuallyLogExposureWithLayer:decoded parameterName:@"a_string"];

    [self shutdownStatsig];
    XCTAssertEqual(_logs.count, 1);
    XCTAssertEqualObjects(_logs[0][@"eventName"], @"statsig::layer_exposure");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"config"], @"layer_with_many_params");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"parameterName"], @"a_string");
    XCTAssertEqualObjects(_logs[0][@"metadata"][@"isManualExposure"], @"true");
}

#pragma mark - Helpers

- (void)initializeStatsig
{
    [Statsig startWithSDKKey:@"client-"];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
}

- (void)shutdownStatsig
{
    [Statsig shutdown];
    __block id expectation = [[XCTestExpectation alloc] initWithDescription:@"Wait"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:1];
}

@end

