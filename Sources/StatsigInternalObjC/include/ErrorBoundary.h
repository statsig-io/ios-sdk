#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ErrorBoundary : NSObject

+ (instancetype)boundaryWithKey:(NSString *)clientKey
              deviceEnvironment:(NSDictionary* _Nullable)deviceEnvironment;

- (void)capture:(void (^_Nonnull)(void))task;
- (void)capture:(void (^_Nonnull)(void))task
   withRecovery:(void (^_Nullable)(void))recovery;

@end

NS_ASSUME_NONNULL_END
