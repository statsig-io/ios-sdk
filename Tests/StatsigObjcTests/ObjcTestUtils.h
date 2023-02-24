#import <Foundation/Foundation.h>

@class XCTestExpectation;

@interface ObjcTestUtils: NSObject
+ (XCTestExpectation *_Nonnull)stubNetwork;
@end
