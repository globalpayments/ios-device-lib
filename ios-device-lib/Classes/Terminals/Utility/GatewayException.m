//
//  GatewayException.m
//  ios-device-lib
//
//  Created by Ranu Dhurandhar on 19/12/25.
//

#import "GatewayException.h"

@implementation GatewayException

- (instancetype)message:(NSString *)message
                    gatewayResponseCode:(NSString *)gatewayResponseCode
                    gatewayResponseMessage:(NSString *)gatewayResponseMessage
                    responseCode:(NSString *)responseCode
                    responseText:(NSString *)responseText
                    errorCode:(NSString *)errorCode
                    errorMessage:(NSString *)errorMessage
                    transactionId:(NSString *)transactionId
                    rawResponse:(NSDictionary *)rawResponse {

            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                    if (rawResponse) userInfo[@"rawResponse"] = rawResponse;
                    if (gatewayResponseCode) userInfo[@"gatewayResponseCode"] = gatewayResponseCode;
                    if (gatewayResponseMessage) userInfo[@"gatewayResponseMessage"] = gatewayResponseMessage;
                    if (responseCode) userInfo[@"responseCode"] = responseCode;
                    if (responseText) userInfo[@"responseText"] = responseText;
                    if (errorCode) userInfo[@"errorCode"] = errorCode;
                    if (errorMessage) userInfo[@"errorMessage"] = errorMessage;
                    if (transactionId) userInfo[@"transactionId"] = transactionId;
            userInfo[NSLocalizedDescriptionKey] = message ?: @"Gateway Error";

            _gatewayResponseCode = [gatewayResponseCode copy];
            _gatewayResponseMessage = [gatewayResponseMessage copy];
            _responseCode = [responseCode copy];
            _responseText = [responseText copy];
            _errorCode = [errorCode copy];
            _errorMessage = [errorMessage copy];
            _transactionId = [transactionId copy];
            _rawResponse = [rawResponse copy];

            return self;
}

- (instancetype) exceptionWithMessage:(NSString *)message rawResponse:(NSDictionary *)rawResponse {
    
    NSString *errorCode = rawResponse[@"data"] ? ((NSDictionary *) rawResponse[@"data"])[@"cmdResult"][@"errorCode"] : nil;
    NSString *errorMessage = rawResponse[@"data"] ? ((NSDictionary *) rawResponse[@"data"])[@"cmdResult"][@"errorMessage"] : nil;
    NSString *gatewayResponseCode = rawResponse[@"data"] ? ((NSDictionary *) rawResponse[@"data"])[@"data"][@"host"][@"gatewayResponseCode"] : nil;
    NSString *gatewayResponseMessage = rawResponse[@"data"] ? ((NSDictionary *) rawResponse[@"data"])[@"data"][@"host"][@"gatewayResponseMessage"] : nil;
    NSString *responseCode = rawResponse[@"data"] ? ((NSDictionary *) rawResponse[@"data"])[@"data"][@"host"][@"responseCode"] : nil;
    NSString *responseText = rawResponse[@"data"] ? ((NSDictionary *) rawResponse[@"data"])[@"data"][@"host"][@"responseText"] : nil;

    return [self  message:message
                    gatewayResponseCode:gatewayResponseCode
                    gatewayResponseMessage:gatewayResponseMessage
                    responseCode:responseCode
                    responseText:responseText
                    errorCode:errorCode
                    errorMessage:errorMessage
                    transactionId:nil
                    rawResponse:rawResponse];
}

- (NSString *)description {
    return  [NSString stringWithFormat:@"%@: %@; responseCode=%@; errorCode=%@; rawResponse=%@",
    NSStringFromClass([self class]),
             self.reason ?: @"(no reason)",
    self.responseCode ?: @"(nil)",
    self.errorCode ?: @"(nil)",
    self.rawResponse ?: @"(nil)"];
}

@end
