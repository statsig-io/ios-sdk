#import <Foundation/Foundation.h>

@class XCTestExpectation;

@interface ObjcTestUtils: NSObject
+ (XCTestExpectation *_Nonnull)stubNetwork;
+ (XCTestExpectation *_Nonnull)stubNetworkCapturingLogs:(void (^_Nonnull)(NSArray * _Nonnull logs))onDidLog;
@end
