#import "ErrorBoundary.h"

@interface ErrorBoundary()

@property (nonatomic, strong) NSString *clientKey;
@property (nonatomic, strong) NSDictionary *deviceEnvironment;
@property (nonatomic, strong) NSMutableSet *seen;

@end

@implementation ErrorBoundary

+ (instancetype)boundaryWithKey:(NSString *)clientKey
              deviceEnvironment:(NSDictionary* _Nullable)deviceEnvironment {
    ErrorBoundary *it = [ErrorBoundary new];
    it.clientKey = clientKey;
    it.deviceEnvironment = deviceEnvironment;
    it.seen = [NSMutableSet new];
    return it;
}

- (void)capture:(void (^_Nonnull)(void))task {
    [self capture:task withRecovery:nil];
}

- (void)capture:(void (^_Nonnull)(void))task
   withRecovery:(void (^_Nullable)(void))recovery {
    @try {
        task();
    }
    @catch (NSException *exception) {
        NSLog(@"[Statsig]: An unexpected exception occurred.");
        NSLog(@"%@", exception);

        if (![self.seen containsObject:exception.name]) {
            [self.seen addObject:exception.name];
            [self logException:exception];
        }

        if (recovery != nil) {
            recovery();
        }
    }
}

- (void)logException:(NSException *)exception {
    @try {
        NSURL *url = [NSURL URLWithString:@"https://statsigapi.net/v1/sdk_exception"];
        NSMutableURLRequest *request =
        [[NSMutableURLRequest alloc] initWithURL: url];

        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];

        NSDictionary *body =
        @{
            @"exception": exception.name,
            @"info": exception.debugDescription,
            @"statsigMetadata": self.deviceEnvironment ?: @{}
        };

        NSError *error;
        NSData *jsonData =
        [NSJSONSerialization
         dataWithJSONObject:body
         options:0
         error:&error];

        if (error) {
            return;
        }

        NSString *length = [NSString stringWithFormat:@"%lu", [jsonData length]];
        [request setValue:length forHTTPHeaderField:@"Content-length"];

        if (self.clientKey) {
            [request setValue:self.clientKey forHTTPHeaderField:@"STATSIG-API-KEY"];
        }

        [request setHTTPBody:jsonData];

        [[NSURLSession.sharedSession dataTaskWithRequest:request] resume];
    }
    @catch (id e) {}
}

@end
