#import "ObjcTestUtils.h"

#import <XCTest/XCTest.h>

@import OCMock;

@implementation ObjcTestUtils

+ (XCTestExpectation *_Nonnull)stubNetwork {
    return [self stubNetworkCapturingLogs:^(NSArray *logs) {
        // noop
    }];
}

+ (XCTestExpectation *_Nonnull)stubNetworkCapturingLogs:(void (^_Nonnull)(NSArray * _Nonnull logs))onDidLog {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *resBundlePath = [bundle pathForResource:@"Statsig_StatsigObjcTests" ofType:@"bundle"];
    NSBundle *resBundle = [NSBundle bundleWithPath:resBundlePath];
    NSString *jsonPath = [resBundle pathForResource:@"initialize" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:jsonPath];

    XCTestExpectation *requestExpectation = [[XCTestExpectation alloc] initWithDescription: @"Network Request"];

    id classMock = OCMClassMock([NSURLSession class]);
    OCMStub([classMock sharedSession]).andReturn(classMock);

    id mockURLResponse = OCMClassMock([NSHTTPURLResponse class]);
    OCMStub([mockURLResponse statusCode]).andReturn(200);

    id autoInvokeCompletion = [OCMArg invokeBlockWithArgs:data, mockURLResponse, [NSNull null], nil];
    id dataArg = [OCMArg checkWithBlock:^BOOL(NSURLRequest *obj) {
        if ([obj.URL.absoluteString containsString:@"/v1/rgstr"]) {
            id dict = [NSJSONSerialization JSONObjectWithData:obj.HTTPBody options:0 error:nil];
            onDidLog(dict[@"events"]);
        }

        return YES;
    }];

    OCMStub([classMock dataTaskWithRequest:dataArg
                         completionHandler:autoInvokeCompletion])
    .andFulfill(requestExpectation);

    return requestExpectation;
}

@end
