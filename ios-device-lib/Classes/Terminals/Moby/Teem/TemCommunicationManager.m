//
//  TemCommunicationManager.m
//  ROAMreaderUnifiedAPI
//
//  Created by Occ Mobility on 09/05/2022.
//  Copyright © 2022 ROAM. All rights reserved.
//

#import "TemCommunicationManager.h"

@interface TemCommunicationManager ()

@property (nonatomic, strong) Sandbox *sandbox;

@end

@implementation TemCommunicationManager

+ (TemCommunicationManager *)getInstance {
    static TemCommunicationManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TemCommunicationManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sandbox = [[Sandbox alloc] init];
    }
    return self;
}

- (void)initTemWithIp:(NSString *)ip
              andport:(int)port
       andResultBlock:(void (^)(SandboxStatus))resultBlock {
    [_sandbox initSandboxSwiftWithApplicationId:@""
                             applicationVersion:@""
                                             ip:ip
                                           port:(int32_t)port
                                  callingMethod:0
                          authorizedActivities:0
                           offlineInstallMode:0
                               contractNumber:@""
                                          SSL:0
                                    certClient:@""
                                     keyClient:@""
                                      certServ:@""
                          resultCompletionBlock:resultBlock];
}

- (void)createReaderContext:(NSString *)readerStateJson
        AndCompletionBlock:(void (^)(int))completionBlock {
    [_sandbox initReaderContextWithReaderStateJson:readerStateJson
                              resultCompletionBlock:^(int32_t result) {
        completionBlock((int)result);
    }];
}

- (void)updateReaderStateJson:(NSString *)readerStateJson
           AndCompletionBlock:(void (^)(int))completionBlock {
    [_sandbox updateReaderStateJsonWithReaderStateJson:readerStateJson
                                 resultCompletionBlock:^(int32_t result) {
        completionBlock((int)result);
    }];
}

- (void)pollForUpdate:(void (^)(int))completionBlock {
    [_sandbox performCallWithReasonForCalling:ReasonForCallingMANUAL
                         resultCompletionBlock:^(int32_t result) {
        completionBlock((int)result);
    }];
}

- (void)reportFirmwareStatus:(void (^)(int))completionBlock {
    [_sandbox performCallWithReasonForCalling:ReasonForCallingREPORT
                         resultCompletionBlock:^(int32_t result) {
        completionBlock((int)result);
    }];
}

- (void)isUpdateAvailable:(NSString *)deviceSerialNumber
           andResultBlock:(void (^)(BOOL))resultBlock {
    [_sandbox isUpdateAvailableWithDeviceSerialNumber:deviceSerialNumber
                                 resultCompletionBlock:resultBlock];
}

- (void)getUpdateFilePath:(NSString *)deviceSerialNumber
           andResultBlock:(void (^)(NSString *))resultBlock {
    [_sandbox getUpdateFilePathWithDeviceSerialNumber:deviceSerialNumber
                                 resultCompletionBlock:resultBlock];
}

- (void)getRkiFileName:(NSString *)deviceSerialNumber
        andResultBlock:(void (^)(NSString *))resultBlock {
    [_sandbox getRkiFileNameWithDeviceSerialNumber:deviceSerialNumber
                              resultCompletionBlock:resultBlock];
}

@end
