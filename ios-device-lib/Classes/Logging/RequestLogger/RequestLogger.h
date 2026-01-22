//
//  RequestLogger.h
//  ios-device-lib
//

@protocol RequestLogger <NSObject>
-(void)requestSent:(id)request;
-(void)responseReceived:(NSString*)response;
@end
