#import "HpsConnectionConfig.h"
#import <ios_device_lib/ios_device_lib-Swift.h>

@implementation HpsConnectionConfig

-(id)init {
     if (self = [super init])  {
         self.timeout = 30; //Seconds
     }
     return self;
}

- (void)setLogger:(id<HpsInterfaceLogging>)logger {
    _logger = logger;
    [_logger willLogHPSInterfaceWithConfig:self];
}

@end
