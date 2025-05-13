#import <XCTest/XCTest.h>

#import "ObjcTestUtils.h"

@import Statsig;

@interface ObjcParameterStoreSpec : XCTestCase
@end

@implementation ObjcParameterStoreSpec {
    XCTestExpectation *_requestExpectation;
}

- (void)setUp {
    _requestExpectation = [ObjcTestUtils stubNetwork];
}

- (void)tearDown {
    [Statsig shutdown];
}

- (void)testGetParameterStore {
    [self initializeStatsig];
    
    ParameterStore *store = [Statsig getParameterStoreForName:@"test_param_store"];
    XCTAssertEqualObjects([store name], @"test_param_store");
    XCTAssertEqualObjects([store getStringForKey:@"string_key" defaultValue:@"default"], @"default");
}

- (void)testGetParameterStoreWithExposureLoggingDisabled {
    [self initializeStatsig];
    
    ParameterStore *store = [Statsig getParameterStoreWithExposureLoggingDisabled:@"test_param_store"];
    XCTAssertEqualObjects([store name], @"test_param_store");
    XCTAssertEqualObjects([store getStringForKey:@"string_key" defaultValue:@"default"], @"default");
}

- (void)testGetDictionary {
    [self initializeStatsig];
    
    ParameterStore *store = [Statsig getParameterStoreForName:@"test_param_store"];
    NSDictionary *defaultDict = @{@"key": @"value"};
    NSDictionary *result = [store getDictionaryForKey:@"dict_key" defaultValue:defaultDict];
    XCTAssertEqualObjects(result, defaultDict);
}

- (void)testGetArray {
    [self initializeStatsig];
    
    ParameterStore *store = [Statsig getParameterStoreForName:@"test_param_store"];
    NSArray *defaultArray = @[@"item1", @"item2"];
    NSArray *result = [store getArrayForKey:@"array_key" defaultValue:defaultArray];
    XCTAssertEqualObjects(result, defaultArray);
}

- (void)testParameterStoreOverrides {
    [self initializeStatsig];
    
    [Statsig overrideParameterStore:@"test_param_store" value:@{@"string_key": @"override_value"}];
    ParameterStore *store = [Statsig getParameterStoreForName:@"test_param_store"];
    XCTAssertEqualObjects([store getStringForKey:@"string_key" defaultValue:@"default"], @"override_value");
    
    [Statsig removeOverride:@"test_param_store"];
    store = [Statsig getParameterStoreForName:@"test_param_store"];
    XCTAssertEqualObjects([store getStringForKey:@"string_key" defaultValue:@"default"], @"default");
}

#pragma mark - Helpers

- (void)initializeStatsig
{
    [Statsig initializeWithSDKKey:@"client-"];
    [self waitForExpectations:@[_requestExpectation] timeout:1];
    [Statsig removeAllOverrides];
}

@end
