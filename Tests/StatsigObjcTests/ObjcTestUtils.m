#import "ObjcTestUtils.h"

#import <XCTest/XCTest.h>

@import OCMock;

@implementation ObjcTestUtils

+ (XCTestExpectation *_Nonnull)stubNetwork{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *resBundlePath = [bundle pathForResource:@"Statsig_StatsigObjcTests" ofType:@"bundle"];
    NSBundle *resBundle = [NSBundle bundleWithPath:resBundlePath];
    NSString *jsonPath = [resBundle pathForResource:@"initialize" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:jsonPath];

    XCTestExpectation *requestExpectation = [[XCTestExpectation alloc] initWithDescription: @"Network Request"];

    id classMock = OCMClassMock([NSURLSession class]);
    OCMStub([classMock sharedSession]).andReturn(classMock);

    id mockUrlResponse = OCMClassMock([NSHTTPURLResponse class]);
    OCMStub([mockUrlResponse statusCode]).andReturn(200);

    id autoInvokeCompletion = [OCMArg invokeBlockWithArgs:data, mockUrlResponse, [NSNull null], nil];

    OCMStub([classMock dataTaskWithRequest:[OCMArg any]
                         completionHandler:autoInvokeCompletion])
    .andFulfill(requestExpectation);

    return requestExpectation;
}

@end
