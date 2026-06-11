#import "HpsUpaResponse.h"
#import "HpsHpaSharedParams.h"
#import "NSString+HexParser.h"
#import "GatewayException.h"
#import "OpenTabDetail.h"

@interface HpsUpaResponse()

@property (readwrite,retain) NSMutableDictionary *params;

@end

static int IsFieldEnable;

@implementation HpsUpaResponse

-(id)init{
    if(self = [super init])
        {
        IsFieldEnable = NO;
        [HpsHpaSharedParams getInstance].class_type = RESPONSE;

        }
    return self;
}

-(id)initWithJSONDoc:(JsonDoc*)response
{
    self = [self init];

    JsonDoc* cmdData = [response get:@"data"];

    if ([cmdData has:@"EcrId"]) {
        self.ecrId = [cmdData getValueAsString:@"EcrId"];
    }

    if ([cmdData has:@"requestId"]) {
        self.requestId = [cmdData getValueAsString:@"requestId"];
    }

    if ([cmdData has:@"response"]) {
        self.transactionType = [cmdData getValueAsString:@"response"];
    }

    if ([cmdData has:@"cmdResult"]) {
        JsonDoc* cmdResult = [cmdData get:@"cmdResult"];
        
        if ([cmdData has:@"cmdResult"]) {
            self.result = [cmdResult getValueAsString:@"result"];
            self.status = [cmdResult getValueAsString:@"result"];
            self.deviceResponseCode = [cmdResult getValueAsString:@"errorCode"];
            self.deviceResponseMessage = [cmdResult getValueAsString:@"errorMessage"];
        }
        
        
        if ([self.result isEqualToString:@"Failed"]) {
            
            NSDictionary *fullMessage = nil;
            NSString *jsonString = [response toString];
            if (jsonString.length > 0) {
                NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                NSError *err = nil;
                
                id parsed = [NSJSONSerialization JSONObjectWithData:jsonData
                                                            options:0
                                                              error:&err];
                if (!err && [parsed isKindOfClass:[NSDictionary class]]) {
                    fullMessage = parsed;
                }
            }
            
            // Absolute safety fallback
            if (!fullMessage) {
                fullMessage = @{ @"note": @"raw response unavailable" };
            }
            self.exceptionGateway = [[GatewayException alloc] exceptionWithMessage:@"Unexpected Device Response"
                                            rawResponse:fullMessage];
        }
    }

    if (![cmdData has:@"data"]) {
        return self;
    }

    JsonDoc* data = [cmdData get:@"data"];

    self.multipleMessage = [data getValueAsString:@"multipleMessage"];
    self.deviceSerialNumber = [data getValueAsString:@"deviceSerialNum"];
    self.upaAppVersion = [data getValueAsString:@"appVersion"];
    self.upaOsVersion = [data getValueAsString:@"OsVersion"];
    self.upaEmvSdkVersion = [data getValueAsString:@"EmvSdkVersion"];
    self.upaContactlessSdkVersion = [data getValueAsString:@"CTLSSdkVersion"];
    self.scanData = [data getValueAsString:@"scanData"];
    self.signatureData = [data getValueAsString:@"signatureData"];
    self.merchantName = [data getValueAsString:@"merchantName"];
    self.terminalId = [data getValueAsString:@"terminalId"];
    self.terminalNumber = [data getValueAsString:@"terminalNumber"];

    if ([data has:@"host"]) {
        JsonDoc* host = [data get:@"host"];

        self.transactionId = [host getValueAsString:@"responseId"];
        self.transactionTime = [host getValueAsString:@"respDateTime"];
        self.gatewayRspMsg = [host getValueAsString:@"gatewayResponseMessage"];
        self.gatewayRspCode = [host getValueAsString:@"gatewayResponseCode"];
        self.responseCode = [host getValueAsString:@"responseCode"];
        self.responseText = [host getValueAsString:@"responseText"];
        self.terminalRefNumber = [host getValueAsString:@"tranNo"];
        self.issuerRefNumber = [host getValueAsString:@"referenceNumber"];
        self.referenceNumber = [host getValueAsString:@"referenceNumber"];
        self.approvalCode = [host getValueAsString:@"approvalCode"];
        self.avsResultCode = [host getValueAsString:@"AvsResultCode"];
        self.avsResultText = [host getValueAsString:@"AvsResultText"];
        self.cvvResponseCode = [host getValueAsString:@"CvvResultCode"];
        self.cvvResponseText = [host getValueAsString:@"CvvResultText"];
        self.authorizedAmount = [host getValueAsString:@"authorizedAmount"];
        self.partialApproval = [host getValueAsString:@"partialApproval"];
        self.batchId = [host getValueAsString:@"batchId"];
        self.cardBrandTransactionId = [host getValueAsString:@"cardBrandTransId"];
        
        if ([host has:@"clientTxnId"]) {
            self.clientTxnId = [host getValueAsString:@"clientTxnId"];;
        }

        if ([host has:@"cashbackAmount"]) {
            self.cashBackAmount = [NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"cashbackAmount"]];
        }

        if ([host has:@"totalAmount"]) {
            self.transactionAmount = [NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"totalAmount"]];
        }

        if ([host has:@"surcharge"]) {
            self.merchantFee = [NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"surcharge"]];
        }

        if ([host has:@"balanceDue"]) {
            self.balanceAmount = [NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"balanceDue"]];
            self.balanceDueAmount = [host getValueAsString:@"balanceDue"];
        }
        
        if ([host has:@"baseAmount"]) {
            self.baseAmount = [NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"baseAmount"]];
        }

        if ([host has:@"tipAmount"] || [host has:@"additionalTipAmount"]) {
            NSDecimalNumber* tip = [NSDecimalNumber decimalNumberWithString:@"0.00"];

            if ([host has:@"tipAmount"]) {
                tip = [tip decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"tipAmount"]]];
            }

            if ([host has:@"additionalTipAmount"]) {
                tip = [tip decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"additionalTipAmount"]]];
            }

            self.tipAmount = tip;
        } else {
            if ([data has:@"transaction"]) {
                NSDecimalNumber* tip = [NSDecimalNumber decimalNumberWithString:@"0.00"];
                NSDecimalNumber* transactionAmount = [NSDecimalNumber decimalNumberWithString:@"0.00"];
                NSDecimalNumber* surchargeAmount = [NSDecimalNumber decimalNumberWithString:@"0.00"];
                
                JsonDoc* transaction = [data get:@"transaction"];
                if ([transaction has:@"tipAmount"]) {
                    tip = [tip decimalNumberByAdding:[NSDecimalNumber decimalNumberWithString:[transaction getValueAsString:@"tipAmount"]]];
                    
                    if (tip > self.tipAmount) {
                        self.tipAmount = tip;
                    }
                }
                
                if ([transaction has:@"totalAmount"]) {
                    transactionAmount = [NSDecimalNumber decimalNumberWithString:[transaction getValueAsString:@"totalAmount"]];
                    
                    if (transactionAmount > self.transactionAmount) {
                        self.transactionAmount = transactionAmount;
                    }
                }
                
                if ([host has:@"surcharge"]) {
                    surchargeAmount = [NSDecimalNumber decimalNumberWithString:[host getValueAsString:@"surcharge"]];
                    
                    if(surchargeAmount > self.merchantFee) {
                        self.merchantFee = surchargeAmount;
                    }
                }
            }
        }

        if ([host has:@"tokenValue"]) {
            self.tokenData = [[HpsTokenData alloc] init];
            self.tokenData.tokenValue = [host getValueAsString:@"tokenValue"];
        }

        // TYP Sale Extra Fields
        self.redeemId               = [host getValueAsString:@"redeemId"];
        self.redeemStatus           = [host getValueAsString:@"redeemStatus"];
        self.currencyAmountRedeemed = [host getValueAsString:@"currencyAmountRedeemed"];
        self.pointsRedeemed         = [host getValueAsString:@"pointsRedeemed"];
        self.discountAmountRedeemed = [host getValueAsString:@"discountAmountRedeemed"];

        // TYP Void/Reversal Extra Fields
        self.voidRedeemId               = [host getValueAsString:@"voidRedeemId"];
        self.voidRedeemStatus           = [host getValueAsString:@"voidRedeemStatus"];
        // Fallback: some terminals send the typo key "voicCurrencyAmountRedeemed" instead of "voidCurrencyAmountRedeemed"
        NSString *voidCAR               = [host getValueAsString:@"voidCurrencyAmountRedeemed"];
        if (!voidCAR) { voidCAR         = [host getValueAsString:@"voicCurrencyAmountRedeemed"]; }
        self.voidCurrencyAmountRedeemed = voidCAR;
        self.voidPointsRedeemed         = [host getValueAsString:@"voidPointsRedeemed"];
        self.voidDiscountAmountRedeemed = [host getValueAsString:@"voidDiscountAmountRedeemed"];

    }

    if ([data has:@"payment"]) {
        JsonDoc* payment = [data get:@"payment"];
        self.cardType = [payment getValueAsString:@"cardType"];
        self.paymentType = [payment getValueAsString:@"paymentType"];
        self.entryMethod = [payment getValueAsString:@"cardAcquisition"];
        self.maskedCardNumber = [payment getValueAsString:@"maskedPan"];
        self.signatureLine = [payment getValueAsString:@"signatureLine"];
        self.pinVerified = [payment getValueAsString:@"PinVerified"];
        self.storeAndForward = [payment getValueAsString:@"storeAndForward"];
        self.invoiceNbr = [payment getValueAsString:@"invoiceNbr"];
        self.cardholderName = [payment getValueAsString:@"cardHolderName"];
        self.signatureData = [payment getValueAsString:@"signatureData"];
        self.clerkId = [payment getValueAsString:@"clerkId"];
        self.cardGroup = [payment getValueAsString:@"cardGroup"];
        self.expiryDate = [payment getValueAsString:@"expiryDate"];
        self.paymentTransactionType = [payment getValueAsString:@"transactionType"];
        self.fallback = @([[payment getValueAsString:@"fallback"] intValue]);
    }

    if ([data has:@"emv"]) {
        JsonDoc* emv = [data get:@"emv"];
        self.applicationName = [[emv getValueAsString:@"50"] convertedFromHexadecimal];
        self.applicationId = [emv getValueAsString:@"9F06"];
        self.applicationPrefferedName = [[emv getValueAsString:@"9F12"] convertedFromHexadecimal];
        self.applicationCrytptogram = [emv getValueAsString:@"9F26"];

        NSString* cryptotype = [emv getValueAsString:@"9F27"];
        if ([cryptotype isEqualToString:@"0"]) {
            self.applicationCryptogramType = AAC;
            self.applicationCryptogramTypeS = [HpsTerminalEnums applicationCryptogramTypeToString:self.applicationCryptogramType];
        } else if ([cryptotype isEqualToString:@"40"]) {
            self.applicationCryptogramType = TC;
            self.applicationCryptogramTypeS = [HpsTerminalEnums applicationCryptogramTypeToString:self.applicationCryptogramType];
        } else if ([cryptotype isEqualToString:@"80"]) {
            self.applicationCryptogramType = ARQC;
            self.applicationCryptogramTypeS = [HpsTerminalEnums applicationCryptogramTypeToString:self.applicationCryptogramType];
        }
        
        NSString *emvTSI = [emv getValueAsString:@"9B"];
        self.emvTSI = emvTSI;
        
        NSString *emvTVR = [emv getValueAsString:@"95"];
        self.emvTVR = emvTVR;
    }
    
    if ([data has:@"duplicate"]) {
        JsonDoc* duplicate = [data get:@"duplicate"];
        self.duplicate = [[HpsTransactionDuplicate alloc] init];
        self.duplicate.duplicateCardType = [duplicate getValueAsString:@"cardType"];
        self.duplicate.duplicateTotalAmount = [duplicate getValueAsString:@"totalAmount"];
        self.duplicate.duplicateApprovalCode = [duplicate getValueAsString:@"approvalCode"];
        self.duplicate.duplicateReferenceNumber = [duplicate getValueAsString:@"referenceNumber"];
        self.duplicate.duplicateTranDate = [duplicate getValueAsString:@"tranDate"];
        self.duplicate.duplicatePanLast4 = [duplicate getValueAsString:@"panLast4"];
        self.duplicateFound = YES;
    }

    // Parse OpenTabDetails array into model objects
    if ([data has:@"OpenTabDetails"]) {
        id openTabDetailsObj = [data getValue:@"OpenTabDetails"];
        if ([openTabDetailsObj isKindOfClass:[NSArray class]]) {
            NSMutableArray<OpenTabDetail *> *detailsArray = [NSMutableArray array];
            for (id item in (NSArray *)openTabDetailsObj) {
                NSDictionary *dict = nil;
                if ([item isKindOfClass:[NSDictionary class]]) {
                    dict = item;
                } else if ([item isKindOfClass:[JsonDoc class]]) {
                    dict = [(JsonDoc *)item finalize];
                }
                if (dict) {
                    OpenTabDetail *detail = [[OpenTabDetail alloc] initWithDictionary:dict];
                    [detailsArray addObject:detail];
                }
            }
            self.openTabDetails = [detailsArray copy];
        }
    }

    if ([data has:@"batchRecord"]) {
        JsonDoc* batchRecord = [data get:@"batchRecord"];
        self.batchRecord = [[BatchRecord alloc] init];
        self.batchRecord.openTransactionId = [batchRecord getValueAsString:@"openTnxId"];
        self.batchRecord.batchStatus = [batchRecord getValueAsString:@"batchStatus"];
        self.batchRecord.totalCount = [batchRecord getValueAsString:@"totalCnt"];
        self.batchRecord.batchId = [batchRecord getValueAsString:@"batchId"];
        self.batchRecord.openUtcDateTime = [batchRecord getValueAsString:@"openUtcDateTime"];
        self.batchRecord.closeUtcDateTime = [batchRecord getValueAsString:@"closeUtcDateTime"];
        self.batchRecord.batchTotalAmount = [batchRecord getValueAsString:@"totalAmount"];
        self.batchRecord.batchSequenceNumber = [batchRecord getValueAsString:@"batchSeqNbr"];
        
        // Parse OpenTabDetails array into model objects
        if ([batchRecord has:@"batchDetailRecords"]) {
            id batchDetailRecordsObj = [batchRecord getValue:@"batchDetailRecords"];
            if ([batchDetailRecordsObj isKindOfClass:[NSArray class]]) {
                NSMutableArray<BatchDetailRecords *> *batchDetailRecordsArray = [NSMutableArray array];
                for (id item in (NSArray *)batchDetailRecordsObj) {
                    NSDictionary *dict = nil;
                    if ([item isKindOfClass:[NSDictionary class]]) {
                        dict = item;
                    } else if ([item isKindOfClass:[JsonDoc class]]) {
                        dict = [(JsonDoc *)item finalize];
                    }
                    if (dict) {
                        BatchDetailRecords *detail = [[BatchDetailRecords alloc] initWithDictionary:dict];
                        [batchDetailRecordsArray addObject:detail];
                    }
                }
                self.batchRecord.batchDetailRecords = [batchDetailRecordsArray copy];
            }
        }
    }
    
    return self;
}

// Alias — voicCurrencyAmountRedeemed matches the typo in the story acceptance criteria.
// Both names resolve to the same value so callers using either name work correctly.
- (NSString *)voicCurrencyAmountRedeemed {
    return self.voidCurrencyAmountRedeemed;
}

-(void)setTransactionSummaryRecord:(TransactionSummaryRecord *)TransactionSummaryRecord{
    if (TransactionSummaryRecord) {
        [[HpsHpaSharedParams getInstance]addTranasactionSummaryRecords:TransactionSummaryRecord];
    }
}

-(void)setCardSummaryRecord:(CardSummaryRecord *)CardSummaryRecord{
    if (CardSummaryRecord) {
        [[HpsHpaSharedParams getInstance]addCardSummaryRecords:CardSummaryRecord];
    }
}

-(void)setLastResponse:(HpsLastResponse *)LastResponse{
    if (LastResponse) {
        [[HpsHpaSharedParams getInstance]setLastResponseData:LastResponse];
    }
}

-(void)setRecord:(Record *)Record
{
    if (Record.TableCategory) {
            //        NSLog(@"TableCategory = %@",Record.TableCategory);
            //        NSLog(@"Fields = %@", Record.Fields);
        [[HpsHpaSharedParams getInstance]addParaMeter:Record.TableCategory withValues:Record.Fields];
        [[HpsHpaSharedParams getInstance]addParamInArray:Record.TableCategory withValues:Record.FieldsArray];
    }else {
            //NSLog(@"Extra Fields = %@", Record.Fields);
        [[HpsHpaSharedParams getInstance]addParaMeter:Record.TableCategory withValues:Record.Fields];
        [[HpsHpaSharedParams getInstance]addParamInArray:Record.TableCategory withValues:Record.FieldsArray];
    }
}

// MARK: General

/// if a response failed
- (BOOL)isSuccess {
    return [self.status isEqualToString:@"Success"];
}

/// combines device response code & message
- (NSString *)responseDescription {
    NSMutableArray *parts = [NSMutableArray new];
    if (self.deviceResponseCode) [parts addObject:self.deviceResponseCode];
    if (self.deviceResponseMessage) [parts addObject:self.deviceResponseMessage];
    return ![parts count] ? nil : [parts componentsJoinedByString:@" - "];
}

// MARK: Error

/// message should be in the format:
///     "Transaction was rejected because it is a duplicate. Subject '200034100740'."
- (NSString *)duplicateTransactionId {
    if (![self isDuplicateTransactionError]) return nil;
    // check gateway message exists
    NSString *message = self.gatewayRspMsg;
    if (![message length]) return nil;
    // find last word of message (should be id in quotes)
    NSArray *parts = [message componentsSeparatedByString:@" "];
    NSString *transactionId = [parts lastObject];
    if (!transactionId) return nil;
    // strip down to a number value
    transactionId = [[transactionId componentsSeparatedByCharactersInSet:
                      [[NSCharacterSet decimalDigitCharacterSet] invertedSet]]
                     componentsJoinedByString:@""];
    // check number value left
    return [transactionId integerValue] ? transactionId : nil;
}

/// if a response indicates the host
/// flagged a transaction as a duplicate
- (BOOL)isDuplicateTransactionError {
    return ([self.deviceResponseCode isEqualToString:@"HOST001"]
            && [self.responseCode isEqualToString:@"2"]);
}

/// if a response indicates that the UPA terminal
/// did not receive a response from the host
- (BOOL)isHostCommunicationError {
    return [self.deviceResponseCode isEqualToString:@"HOST002"];
}

/// failed UPA terminal response formatted
/// as an error object
- (NSError *_Nullable)responseError {
    if ([self isSuccess]) { return nil; }
    NSString *domain = @"com.mobilebytes.upa";
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    [userInfo setValue:[self responseDescription] forKey:NSLocalizedDescriptionKey];
    [userInfo setValue:self.gatewayRspMsg forKey:NSLocalizedFailureReasonErrorKey];
    return [NSError errorWithDomain:domain code:1 userInfo:userInfo];
}

@end
