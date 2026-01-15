//
//  GatewayException.h
//  ios-device-lib
//
//  Created by Ranu Dhurandhar on 19/12/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GatewayException : NSException

@property (nonatomic,strong) NSString *gatewayResponseCode;
@property (nonatomic,strong) NSString *gatewayResponseMessage;
@property (nonatomic,strong) NSString *responseCode;
@property (nonatomic,strong) NSString *responseText;
@property (nonatomic,strong) NSString *errorCode;
@property (nonatomic,strong) NSString *errorMessage;
@property (nonatomic,strong) NSString *transactionId;

// full raw response dictionary (if available)
@property (nonatomic, strong) NSDictionary *rawResponse;

// Designated initializer
- (instancetype)message:(NSString *)message
                            gatewayResponseCode:(nullable NSString *)gatewayResponseCode
                            gatewayResponseMessage:(nullable NSString *)gatewayResponseMessage
                            responseCode:(nullable NSString *)responseCode
                            responseText:(nullable NSString *)responseText
                            errorCode:(nullable NSString *)errorCode
                            errorMessage:(nullable NSString *)errorMessage
                            transactionId:(nullable NSString *)transactionId
                    rawResponse:(nullable NSDictionary *)rawResponse;


// Convenience
- (instancetype) exceptionWithMessage:(NSString *)message rawResponse:(nullable NSDictionary *)rawResponse;

@end

NS_ASSUME_NONNULL_END
