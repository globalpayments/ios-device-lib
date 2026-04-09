#import <Foundation/Foundation.h>

@interface OpenTabDetail : NSObject

@property (nonatomic, strong) NSString *referenceNumber;
@property (nonatomic, strong) NSString *cardType;
@property (nonatomic, strong) NSString *authorizedAmount;
@property (nonatomic, strong) NSString *clerkId;
@property (nonatomic, strong) NSString *maskedPan;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end
