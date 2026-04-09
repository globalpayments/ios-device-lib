#import "BatchDetailRecords.h"

@implementation BatchDetailRecords

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if(self) {
        self.tipAmount = dict[@"tipAmount"];
        self.maskedPan = dict[@"maskedPan"];
        self.responseText = dict[@"responseText"];
        self.transactionStatus = dict[@"transactionStatus"];
        self.clerkId = dict[@"clerkId"];
        self.totalAmount = dict[@"totalAmount"];
        self.baseAmount = dict[@"baseAmount"];
        self.referenceNumber = dict[@"referenceNumber"];
        self.settleAmount = dict[@"settleAmount"];
        self.approvalCode = dict[@"approvalCode"];
        self.transactionTime = dict[@"transactionTime"];
        self.authorizedAmount = dict[@"authorizedAmount"];
        self.cardType = dict[@"cardType"];
        self.cardSwiped = dict[@"cardSwiped"];
        self.requestedAmount = dict[@"requestedAmount"];
        self.responseCode = dict[@"responseCode"];
        self.gatewayTransactionId = dict[@"gatewayTxnId"];
        self.transactionType = dict[@"transactionType"];
        self.taxAmount = dict[@"taxAmount"];
    }
    return self;
}
@end

