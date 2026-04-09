#import <Foundation/Foundation.h>
#import "BatchDetailRecords.h"

@interface BatchRecord : NSObject

@property (nonatomic,strong)NSString* openTransactionId;
@property (nonatomic,strong)NSString* batchStatus;
@property (nonatomic,strong)NSString* totalCount;
@property (nonatomic,strong)NSString* batchId;
@property (nonatomic,strong)NSString* openUtcDateTime;
@property (nonatomic,strong)NSString* closeUtcDateTime;
@property (nonatomic,strong)NSString* batchTotalAmount;
@property (nonatomic,strong)NSString* batchSequenceNumber;
@property (nonatomic, strong)NSArray<BatchDetailRecords *> *batchDetailRecords;
@end
