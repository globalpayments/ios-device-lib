#import "HpsPaxHostResponseCredential.h"

@implementation HpsPaxHostResponseCredential

- (id)initWithBinaryReader: (HpsBinaryDataScanner*)br {
    self = [super init];
    if (!self) return nil;
    
    NSString *values = [br readStringUntilDelimiter:HpsControlCodes_FS];
    NSArray *items = [values componentsSeparatedByString:[HpsTerminalEnums controlCodeString:HpsControlCodes_US]];
    
    int i = 0;
    for (NSString* value in items) {
        switch (i) {
            case 0:
                self.hostTID = value;
                break;
                
            case 1:
                self.merchantID = value;
                break;
                
            default:
                break;
        }
        i++;
    }
    
    return self;
}

@end
