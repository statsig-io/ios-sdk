#import <XCTest/XCTest.h>

#import "ObjcTestUtils.h"

@import Statsig;

@interface ObjcStatsigUser : XCTestCase
@end

@implementation ObjcStatsigUser {
    StatsigUser *_userWithUserID;
    StatsigUser *_userWithCustomIDs;
}

- (void)setUp {
    _userWithUserID = [[StatsigUser alloc]
             initWithUserID:@"a-user"
             email:@"a-user@mail.com"
             ip:@"1.2.3.4"
             country:@"NZ"
             locale:@"en_NZ"
             appVersion:@"1.0.0"
             custom:@{@"isEmployee": @true}
             privateAttributes:@{@"secret_key": @"secret_value"}];

    _userWithCustomIDs = [[StatsigUser alloc] initWithCustomIDs:@{@"EmployeeID": @"Number1"}];
}

- (void)testGettingUserID {
    XCTAssertEqual([_userWithUserID getUserID], @"a-user");
    XCTAssertNil([_userWithCustomIDs getUserID]);
}

- (void)testGettingCustomIDs {
    XCTAssertNil([_userWithUserID getCustomIDs]);
    XCTAssertEqualObjects([_userWithCustomIDs getCustomIDs], @{@"EmployeeID": @"Number1"});
}

- (void)testGettingAsDictionary {
    NSDictionary *dict = [_userWithUserID toDictionary];
    XCTAssertEqual([dict count], 9);
    XCTAssertEqual(dict[@"userID"], @"a-user");
    XCTAssertEqual(dict[@"email"], @"a-user@mail.com");
    XCTAssertEqual(dict[@"ip"], @"1.2.3.4");
    XCTAssertEqual(dict[@"country"], @"NZ");
    XCTAssertEqual(dict[@"locale"], @"en_NZ");
    XCTAssertEqual(dict[@"appVersion"], @"1.0.0");
    XCTAssertEqualObjects(dict[@"custom"], @{@"isEmployee": @true});
    XCTAssertEqualObjects(dict[@"privateAttributes"], @{@"secret_key": @"secret_value"});
    XCTAssertEqualObjects(dict[@"statsigEnvironment"], @{});

    dict = [_userWithCustomIDs toDictionary];
    XCTAssertEqual([dict count], 2);
    XCTAssertEqualObjects(dict[@"customIDs"], @{@"EmployeeID": @"Number1"});
    XCTAssertEqualObjects(dict[@"statsigEnvironment"], @{});
}

@end

