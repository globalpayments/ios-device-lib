#import <Foundation/Foundation.h>
#import "HpsBinaryDataScanner.h"
#import "HpsTerminalEnums.h"

@interface HpsPaxHostResponseCredential : NSObject

@property (nonatomic,strong) NSString *hostTID;
@property (nonatomic,strong) NSString *merchantID;

- (id)initWithBinaryReader: (HpsBinaryDataScanner*)br;

@end
