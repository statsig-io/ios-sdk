#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ErrorBoundary : NSObject

+ (instancetype)boundaryWithKey:(NSString *)clientKey
              deviceEnvironment:(NSDictionary *_Nullable)deviceEnvironment;

#pragma mark - Capture

- (void)capture:(NSString *)tag
           task:(void (^_Nonnull)(void))task;

#pragma mark - Capture and Recover

- (void)capture:(NSString *)tag
           task:(void (^_Nonnull)(void))task
   withRecovery:(void (^_Nullable)(void))recovery;

@end

NS_ASSUME_NONNULL_END
