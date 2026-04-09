#import <Foundation/Foundation.h>

@interface BatchDetailRecords : NSObject

@property (nonatomic,strong)NSString* tipAmount;
@property (nonatomic,strong)NSString* maskedPan;
@property (nonatomic,strong)NSString* responseText;
@property (nonatomic,strong)NSString* transactionStatus;
@property (nonatomic,strong)NSString* clerkId;
@property (nonatomic,strong)NSString* totalAmount;
@property (nonatomic,strong)NSString* baseAmount;
@property (nonatomic,strong)NSString* referenceNumber;
@property (nonatomic,strong)NSString* settleAmount;
@property (nonatomic,strong)NSString* approvalCode;
@property (nonatomic,strong)NSString* transactionTime;
@property (nonatomic,strong)NSString* authorizedAmount;
@property (nonatomic,strong)NSString* cardType;
@property (nonatomic,strong)NSString* cardSwiped;
@property (nonatomic,strong)NSString* requestedAmount;
@property (nonatomic,strong)NSString* responseCode;
@property (nonatomic,strong)NSNumber* gatewayTransactionId;
@property (nonatomic,strong)NSString* transactionType;
@property (nonatomic,strong)NSString* taxAmount;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end
