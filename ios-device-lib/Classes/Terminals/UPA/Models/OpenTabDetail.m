#import "OpenTabDetail.h"

@implementation OpenTabDetail

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        self.referenceNumber = dict[@"referenceNumber"] ;
        self.cardType = dict[@"cardType"];
        self.authorizedAmount = dict[@"authorizedAmount"];
        self.clerkId = dict[@"clerkId"] ;
        self.maskedPan = dict[@"maskedPan"];
    }
    return self;
}

@end
