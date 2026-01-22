//
//  SampleRequestLogger.m
//  ios-device-lib
//

#import <Foundation/Foundation.h>
#import "SampleRequestLogger.h"

@implementation SampleRequestLogger : NSObject

- (void)requestSent:(id)request {
    if (request) {
        NSLog(@"request: %@", [request description]);
    }
}

- (void)responseReceived:(NSString *)response {
    if (response != nil) {
        NSLog(@"response: %@", response);
    }
}

@end
