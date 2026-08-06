//
//  PorticoResponseHelper.swift
//  ios-device-lib
//

import Foundation
import GlobalPaymentsApi

// MARK: Constants
// Transaction flow approval codes
private let PorticoTransactionApprovalCode = "00"
private let PorticoTransactionPartialApprovalCode = "10"
private let PorticoTransactionApproval = "APPROVAL"
private let PorticoTransactionPartialApproval = "PARTIAL APPROVAL"
private let PorticoVerifyTransactionVisaApprovalCardOk = "CARD OK"
public let PorticoTransactionSurchargeAPIRequestTimeOut = "Surcharge API has faced a timeout error.\nWe won't charge the Surcharge Fee for this reason."

// Host approval codes
private let PorticoGatewayApproval = "APPROVAL"
private let PorticoGatewaySuccess = "Success"

// EMV Issuer Response Codes
private let EmvIssuerResponseApprovalCode = "00"
private let EmvIssuerResponsePartialApprovalCode = "10"
private let EmvIssuerResponseHonorWithIdentificationCode = "08"
private let EmvIssuerResponseDenialCode = "05"
private let EmvIssuerResponseTimeOutCode = "91"

// MARK: Sale Response Conversions
extension SaleTransaction {

    func buildSaleResponse(_ hostResponse: GPTransaction?, surchargeFee: Decimal? = nil) -> SaleResponse {
        var saleResponse = SaleResponse(clientTransactionId,
                                        gatewayTransactionId: hostResponse?.gatewayTransactionId)
        saleResponse.posReferenceNumber = posReferenceNumber
        saleResponse.invoiceNumber = invoiceNumber
        saleResponse.operatingUserId = operatingUserId
        saleResponse.cardDataSourceType = cardData?.cardEntryMode
        if let response = hostResponse {
            
            if let duplicateData = response.duplicateData {
                saleResponse.duplicateData = DuplicateDataResponse(from: duplicateData)
            }
            
            saleResponse.cardType = cardTypeFromHostResponse(response.cardType)
            saleResponse.gatewayResponseText = response.responseMessage
            saleResponse.authCode = response.transactionReference.authCode
            saleResponse.cvvResponseCode = response.cvnResponseCode
            saleResponse.cvvResponseMessage = response.cvnResponseMessage
            saleResponse.avsResponseCode = response.avsResponseCode
            saleResponse.avsResponseMessage = response.avsResponseMessage
            saleResponse.isApproved = isTransactionApprovedFromHost(response.responseMessage)
            saleResponse.clientTxnID = clientTransactionId
            saleResponse.bankRespCode = response.bankRespCode
            
            if saleResponse.isApproved {
                // We are in the presense of Partial Transaction
                if response.authorizedAmount != nil &&
                    !response.authorizedAmount.isEmpty {
                    
                    saleResponse.approvedAmount = response.authorizedAmount.amountInPennies
                    saleResponse.isPartialApproval = true
                    saleResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
                } else {
                   
                    // Portico does not return approved amount unless partial transaction is in place
                    saleResponse.approvedAmount = total
                    saleResponse.gatewayResponseCode = PorticoTransactionApprovalCode
                }

                saleResponse.total = total
                saleResponse.tax = tax
                saleResponse.tip = tip
                saleResponse.authCodeData = PorticoTransactionApprovalCode
                
                if response.surchargeAmtInfo != nil {
                    
                    saleResponse.surchargeFee = SurchargeUtility.surchargeFee.amountInDollarString
                    saleResponse.surchargeAmount = response.surchargeAmtInfo
                } else if surchargeAmtInfo != nil {
                    saleResponse.surchargeFee = surchargeFee?.stringValue ?? SurchargeUtility.surchargeFee.amountInDollarString
                    saleResponse.surchargeAmount = surchargeAmtInfo
                }
            }

            if let token = response.token, token.count > 0 {
                var tokenizedCard = TokenizedCardData(token: token)
                tokenizedCard.cardType = saleResponse.cardType

                saleResponse.tokenizedCard = tokenizedCard
            }

            // Host Processing Result
            if response.emvIssuerResponse != nil &&
                !response.emvIssuerResponse.isEmpty {
                var hostProcessingResult = HostProcessingResult()

                if saleResponse.isApproved || saleResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                var issuerAuthData: TLVObject? = nil
                let tlvObjects = TLVDecoder.decode(withTLVString: response.emvIssuerResponse)

                tlvObjects?.forEach({ (obj) in
                    // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                    // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                    if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                        obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                        hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                    }

                    // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                    if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                        hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                        issuerAuthData = obj
                    }
                })

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: issuerAuthData)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    
                    if emvIssuerResponseCode.count == 8 && emvIssuerResponseCode.prefix(2) == "8A" {
                        let code = String(emvIssuerResponseCode.suffix(4))
                        saleResponse.emvIssuerRspCode = TLVUtility.hexToAscii(code)
                    } else {
                        saleResponse.emvIssuerRspCode = emvIssuerResponseCode
                    }
                    
                    saleResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }

                saleResponse.hostProcessingResult = hostProcessingResult
            } else {
                var hostProcessingResult = HostProcessingResult()

                if saleResponse.isApproved || saleResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: nil)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    
                    if emvIssuerResponseCode.count == 8 && emvIssuerResponseCode.prefix(2) == "8A" {
                        let code = String(emvIssuerResponseCode.suffix(4))
                        saleResponse.emvIssuerRspCode = TLVUtility.hexToAscii(code)
                    } else {
                        saleResponse.emvIssuerRspCode = emvIssuerResponseCode
                    }
                
                    saleResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }
                saleResponse.bankRespCode = response.bankRespCode
                saleResponse.hostProcessingResult = hostProcessingResult
            }
        }

        return saleResponse
    }

    func buildSaleResponse(_ summary: GPTransactionSummary) -> SaleResponse {
        var saleResponse = SaleResponse(clientTransactionId,
                                        gatewayTransactionId: summary.transactionId)
        saleResponse.posReferenceNumber = posReferenceNumber
        saleResponse.invoiceNumber = invoiceNumber
        saleResponse.operatingUserId = operatingUserId
        saleResponse.cardDataSourceType = cardData?.cardEntryMode
        saleResponse.cardType = cardTypeFromHostResponse(summary.cardType)
        saleResponse.authCode = summary.authCode
        saleResponse.isApproved = isTransactionApprovedFromHost(summary.issuerResponseMessage)
        saleResponse.gatewayResponseText = summary.issuerResponseMessage
        saleResponse.clientTxnID = clientTransactionId
        
        if saleResponse.isApproved {
            if summary.authorizedAmount.count > 0 {
                // We are in presence of a partial approval
                saleResponse.approvedAmount = summary.authorizedAmount.amountInPennies
                saleResponse.isPartialApproval = true
                saleResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                saleResponse.approvedAmount = total
                saleResponse.gatewayResponseCode = PorticoTransactionApprovalCode
            }

            saleResponse.total = total
            saleResponse.tax = tax
            saleResponse.tip = tip
            saleResponse.authCodeData = PorticoTransactionApprovalCode
            
            if summary.surchargeAmount != nil {
                saleResponse.surchargeAmount = summary.surchargeAmount
                saleResponse.surchargeFee = SurchargeUtility.surchargeFee.amountInDollarString
            }
        }

        // Host Processing Result
        if summary.emvIssuerResponse != nil &&
            !summary.emvIssuerResponse.isEmpty {
            var hostProcessingResult = HostProcessingResult()

            if saleResponse.isApproved || saleResponse.isPartialApproval {
                hostProcessingResult.transactionState = .onlineApproved
            }

            var issuerAuthData: TLVObject? = nil
            let tlvObjects = TLVDecoder.decode(withTLVString: summary.emvIssuerResponse)

            tlvObjects?.forEach({ (obj) in
                // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                    obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                    hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                }

                // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                    hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                    issuerAuthData = obj
                }
            })

            let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                responseCode: summary.issuerResponseCode,
                                                                                issuerAuthData: issuerAuthData)

            if !emvIssuerResponseCode.isEmpty {
                hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
               
                if emvIssuerResponseCode.count == 8 && emvIssuerResponseCode.prefix(2) == "8A" {
                    let code = String(emvIssuerResponseCode.suffix(4))
                    saleResponse.emvIssuerRspCode = TLVUtility.hexToAscii(code)
                } else {
                    saleResponse.emvIssuerRspCode = emvIssuerResponseCode
                }
                
                saleResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
            }

            saleResponse.hostProcessingResult = hostProcessingResult
        }

        return saleResponse
    }
}

// MARK: Verify Response Conversions
extension VerifyTransaction {

    func buildVerifyResponse(_ hostResponse: GPTransaction?) -> VerifyResponse {
        var verifyResponse = VerifyResponse(clientTransactionId,
                                        gatewayTransactionId: hostResponse?.transactionReference.transactionId)
        verifyResponse.posReferenceNumber = posReferenceNumber
        verifyResponse.invoiceNumber = invoiceNumber
        verifyResponse.operatingUserId = operatingUserId
        verifyResponse.cardDataSourceType = cardData?.cardEntryMode

        if let response = hostResponse {
            verifyResponse.referenceNumber = response.referenceNumber
            verifyResponse.recurringDataCode = response.recurringDataCode
            verifyResponse.cpcInd = response.commercialIndicator
            verifyResponse.hostRspDateTime = response.hostResponseDate
            verifyResponse.cardType = cardTypeFromHostResponse(response.cardType)
            verifyResponse.cvvResponseCode = response.cvnResponseCode
            verifyResponse.cvvResponseMessage = response.cvnResponseMessage
            verifyResponse.avsResponseCode = response.avsResponseCode
            verifyResponse.avsResponseMessage = response.avsResponseMessage
            verifyResponse.authCode = response.transactionReference.authCode
            verifyResponse.isApproved = isTransactionApprovedFromHost(response.responseMessage)
            verifyResponse.gatewayResponseText = response.responseMessage
            
            if verifyResponse.isApproved {
                verifyResponse.total = 0
                verifyResponse.tip = 0
                verifyResponse.approvedAmount = 0
                verifyResponse.authCodeData = PorticoTransactionApprovalCode
                
                verifyResponse.gatewayResponseCode = PorticoTransactionApprovalCode
            }

            if let token = response.token, token.count > 0 {
                var tokenizedCard = TokenizedCardData(token: token)
                tokenizedCard.cardType = verifyResponse.cardType

                verifyResponse.tokenizedCard = tokenizedCard
            }

            // Host Processing Result
            if response.emvIssuerResponse != nil &&
                !response.emvIssuerResponse.isEmpty {
                var hostProcessingResult = HostProcessingResult()

                if verifyResponse.isApproved || verifyResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                var issuerAuthData: TLVObject? = nil
                let tlvObjects = TLVDecoder.decode(withTLVString: response.emvIssuerResponse)

                tlvObjects?.forEach({ (obj) in
                    // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                    // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                    if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                        obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                        hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                    }

                    // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                    if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                        hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                        issuerAuthData = obj
                    }
                })

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: issuerAuthData)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    verifyResponse.emvIssuerRspCode = emvIssuerResponseCode
                    verifyResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }

                verifyResponse.hostProcessingResult = hostProcessingResult
            } else {
                var hostProcessingResult = HostProcessingResult()

                if verifyResponse.isApproved || verifyResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: nil)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    verifyResponse.emvIssuerRspCode = emvIssuerResponseCode
                    verifyResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }
                verifyResponse.hostProcessingResult = hostProcessingResult
            }
        }

        return verifyResponse
    }

    func buildVerifyResponse(_ summary: GPTransactionSummary) -> VerifyResponse {
        var verifyResponse = VerifyResponse(clientTransactionId,
                                        gatewayTransactionId: summary.transactionId)
        verifyResponse.posReferenceNumber = posReferenceNumber
        verifyResponse.invoiceNumber = invoiceNumber
        verifyResponse.operatingUserId = operatingUserId
        verifyResponse.cardDataSourceType = cardData?.cardEntryMode
        verifyResponse.cardType = cardTypeFromHostResponse(summary.cardType)
        verifyResponse.authCode = summary.authCode
        verifyResponse.isApproved = isTransactionApprovedFromHost(summary.issuerResponseMessage)
        verifyResponse.referenceNumber = summary.referenceNumber
        verifyResponse.recurringDataCode = summary.recurringDataCode
        verifyResponse.hostRspDateTime = summary.responseDate
        verifyResponse.gatewayResponseText = summary.issuerResponseMessage
        
        if verifyResponse.isApproved {
            verifyResponse.total = 0
            verifyResponse.tip = 0
            verifyResponse.approvedAmount = 0
            verifyResponse.authCodeData = PorticoTransactionApprovalCode
            
            verifyResponse.gatewayResponseCode = PorticoTransactionApprovalCode
        }

        // Host Processing Result
        if summary.emvIssuerResponse != nil &&
            !summary.emvIssuerResponse.isEmpty {
            var hostProcessingResult = HostProcessingResult()

            if verifyResponse.isApproved || verifyResponse.isPartialApproval {
                hostProcessingResult.transactionState = .onlineApproved
            }

            var issuerAuthData: TLVObject? = nil
            let tlvObjects = TLVDecoder.decode(withTLVString: summary.emvIssuerResponse)

            tlvObjects?.forEach({ (obj) in
                // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                    obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                    hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                }

                // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                    hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                    issuerAuthData = obj
                }
            })

            let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                responseCode: summary.issuerResponseCode,
                                                                                issuerAuthData: issuerAuthData)

            if !emvIssuerResponseCode.isEmpty {
                hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                verifyResponse.emvIssuerRspCode = emvIssuerResponseCode
                verifyResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
            }

            verifyResponse.hostProcessingResult = hostProcessingResult
        }

        return verifyResponse
    }
}

// MARK: Auth Response Conversions
extension AuthTransaction {

    func buildAuthResponse(_ hostResponse: GPTransaction?, surchargeFee: Decimal? = nil) -> AuthResponse {
        var authResponse = AuthResponse(clientTransactionId,
                                        gatewayTransactionId: hostResponse?.transactionReference.transactionId)
        authResponse.posReferenceNumber = posReferenceNumber
        authResponse.invoiceNumber = invoiceNumber
        authResponse.operatingUserId = operatingUserId
        authResponse.cardDataSourceType = cardData?.cardEntryMode

        if let response = hostResponse {
            authResponse.cardType = cardTypeFromHostResponse(response.cardType)
            authResponse.gatewayResponseText = response.responseMessage
            authResponse.authCode = response.transactionReference.authCode
            authResponse.cvvResponseCode = response.cvnResponseCode
            authResponse.cvvResponseMessage = response.cvnResponseMessage
            authResponse.avsResponseCode = response.avsResponseCode
            authResponse.avsResponseMessage = response.avsResponseMessage
            authResponse.isApproved = isTransactionApprovedFromHost(response.responseMessage)
            authResponse.clientTxnID = clientTransactionId
            
            if authResponse.isApproved {
                // We are in the presense of Partial Transaction
                if response.authorizedAmount != nil &&
                    !response.authorizedAmount.isEmpty {
                    authResponse.approvedAmount = response.authorizedAmount.amountInPennies
                    authResponse.isPartialApproval = true
                    authResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
                    
                } else {
                    // Portico does not return approved amount unless partial transaction is in place
                    authResponse.approvedAmount = total
                    authResponse.gatewayResponseCode = PorticoTransactionApprovalCode
                }

                authResponse.total = total
                authResponse.tax = tax
                authResponse.tip = tip
                authResponse.authCodeData = PorticoTransactionApprovalCode
                
                if response.surchargeAmtInfo != nil {
                    
                    authResponse.surchargeFee = SurchargeUtility.surchargeFee.amountInDollarString
                    authResponse.surchargeAmount = response.surchargeAmtInfo
                } else if surchargeAmtInfo != nil {
                    authResponse.surchargeFee = surchargeFee?.stringValue ?? SurchargeUtility.surchargeFee.amountInDollarString
                    authResponse.surchargeAmount = surchargeAmtInfo
                }
            }

            if let token = response.token, token.count > 0 {
                var tokenizedCard = TokenizedCardData(token: token)
                tokenizedCard.cardType = authResponse.cardType

                authResponse.tokenizedCard = tokenizedCard
            }

            // Host Processing Result
            if response.emvIssuerResponse != nil &&
                !response.emvIssuerResponse.isEmpty {
                var hostProcessingResult = HostProcessingResult()

                if authResponse.isApproved || authResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                var issuerAuthData: TLVObject? = nil
                let tlvObjects = TLVDecoder.decode(withTLVString: response.emvIssuerResponse)

                tlvObjects?.forEach({ (obj) in
                    // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                    // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                    if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                        obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                        hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                    }

                    // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                    if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                        hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                        issuerAuthData = obj
                    }
                })

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: issuerAuthData)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    
                    if emvIssuerResponseCode.count == 8 && emvIssuerResponseCode.prefix(2) == "8A" {
                        let code = String(emvIssuerResponseCode.suffix(4))
                        authResponse.emvIssuerRspCode = TLVUtility.hexToAscii(code)
                    } else {
                        authResponse.emvIssuerRspCode = emvIssuerResponseCode
                    }
                    
                    authResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }

                authResponse.hostProcessingResult = hostProcessingResult
            }
        }

        return authResponse
    }

    func buildAuthResponse(_ summary: GPTransactionSummary) -> AuthResponse {
        var authResponse = AuthResponse(clientTransactionId,
                                        gatewayTransactionId: summary.transactionId)
        authResponse.posReferenceNumber = posReferenceNumber
        authResponse.invoiceNumber = invoiceNumber
        authResponse.operatingUserId = operatingUserId
        authResponse.cardDataSourceType = cardData?.cardEntryMode
        authResponse.cardType = cardTypeFromHostResponse(summary.cardType)
        authResponse.gatewayResponseText = summary.issuerResponseMessage
        authResponse.authCode = summary.authCode
        authResponse.isApproved = isTransactionApprovedFromHost(summary.issuerResponseMessage)

        if authResponse.isApproved {
            if summary.authorizedAmount.count > 0 {
                // We are in presence of a partial approval
                authResponse.approvedAmount = summary.authorizedAmount.amountInPennies
                authResponse.isPartialApproval = true
                authResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                authResponse.approvedAmount = total
                authResponse.gatewayResponseCode = PorticoTransactionApprovalCode
            }

            authResponse.total = total
            authResponse.tax = tax
            authResponse.tip = tip
            authResponse.authCodeData = PorticoTransactionApprovalCode
            authResponse.clientTxnID = clientTransactionId
        }

        // Host Processing Result
        if summary.emvIssuerResponse != nil &&
            !summary.emvIssuerResponse.isEmpty {
            var hostProcessingResult = HostProcessingResult()

            if authResponse.isApproved || authResponse.isPartialApproval {
                hostProcessingResult.transactionState = .onlineApproved
            }

            var issuerAuthData: TLVObject? = nil
            let tlvObjects = TLVDecoder.decode(withTLVString: summary.emvIssuerResponse)

            tlvObjects?.forEach({ (obj) in
                // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                    obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                    hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                }

                // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                    hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                    issuerAuthData = obj
                }
            })

            let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                responseCode: summary.issuerResponseCode,
                                                                                issuerAuthData: issuerAuthData)

            if !emvIssuerResponseCode.isEmpty {
                hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                
                if emvIssuerResponseCode.count == 8 && emvIssuerResponseCode.prefix(2) == "8A" {
                    let code = String(emvIssuerResponseCode.suffix(4))
                    authResponse.emvIssuerRspCode = TLVUtility.hexToAscii(code)
                } else {
                    authResponse.emvIssuerRspCode = emvIssuerResponseCode
                }
                
                authResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
            }

            authResponse.hostProcessingResult = hostProcessingResult
        }

        return authResponse
    }
}

// MARK: Return Response Conversions
extension ReturnTransaction {

    func buildReturnResponse(_ hostResponse: GPTransaction?) -> ReturnResponse {
        var returnResponse = ReturnResponse(clientTransactionId,
                                            gatewayTransactionId: hostResponse?.transactionReference.transactionId)
        returnResponse.posReferenceNumber = posReferenceNumber
        returnResponse.invoiceNumber = invoiceNumber
        returnResponse.operatingUserId = operatingUserId
        returnResponse.cardDataSourceType = cardData?.cardEntryMode

        if let response = hostResponse {
            returnResponse.cardType = cardTypeFromHostResponse(response.cardType)
            returnResponse.gatewayResponseText = response.responseMessage
            returnResponse.authCode = response.transactionReference.authCode
            returnResponse.cvvResponseCode = response.cvnResponseCode
            returnResponse.cvvResponseMessage = response.cvnResponseMessage
            returnResponse.avsResponseCode = response.avsResponseCode
            returnResponse.avsResponseMessage = response.avsResponseMessage
            returnResponse.isApproved = isGatewayApprovedFromResponseMessage(response.responseMessage)

            if returnResponse.isApproved {
                // We are in the presense of Partial Transaction
                if response.authorizedAmount != nil &&
                    !response.authorizedAmount.isEmpty {
                    returnResponse.approvedAmount = response.authorizedAmount.amountInPennies
                    returnResponse.isPartialApproval = true
                    returnResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
                } else {
                    // Portico does not return approved amount unless partial transaction is in place
                    returnResponse.approvedAmount = total
                    returnResponse.gatewayResponseCode = PorticoTransactionApprovalCode
                }

                returnResponse.total = total
                returnResponse.tax = tax
                returnResponse.tip = tip
                returnResponse.authCodeData = PorticoTransactionApprovalCode
            }

            // Host Processing Result
            if response.emvIssuerResponse != nil &&
                !response.emvIssuerResponse.isEmpty {
                var hostProcessingResult = HostProcessingResult()

                if returnResponse.isApproved || returnResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                var issuerAuthData: TLVObject? = nil
                let tlvObjects = TLVDecoder.decode(withTLVString: response.emvIssuerResponse)

                tlvObjects?.forEach({ (obj) in
                    // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                    // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                    if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                        obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                        hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                    }

                    // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                    if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                        hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                        issuerAuthData = obj
                    }
                })

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: issuerAuthData)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    returnResponse.emvIssuerRspCode = emvIssuerResponseCode
                    returnResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }

                returnResponse.hostProcessingResult = hostProcessingResult
            } else {
                var hostProcessingResult = HostProcessingResult()

                if returnResponse.isApproved || returnResponse.isPartialApproval {
                    hostProcessingResult.transactionState = .onlineApproved
                }

                let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                    responseCode: response.responseCode,
                                                                                    issuerAuthData: nil)

                if !emvIssuerResponseCode.isEmpty {
                    hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                    returnResponse.emvIssuerRspCode = emvIssuerResponseCode
                    returnResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
                }
                returnResponse.hostProcessingResult = hostProcessingResult
            }
        }

        return returnResponse
    }

    func buildReturnResponse(_ summary: GPTransactionSummary) -> ReturnResponse {
        var returnResponse = ReturnResponse(clientTransactionId,
                                            gatewayTransactionId: summary.transactionId)
        returnResponse.posReferenceNumber = posReferenceNumber
        returnResponse.invoiceNumber = invoiceNumber
        returnResponse.operatingUserId = operatingUserId
        returnResponse.cardDataSourceType = cardData?.cardEntryMode
        returnResponse.cardType = cardTypeFromHostResponse(summary.cardType)
        returnResponse.gatewayResponseText = summary.issuerResponseMessage
        returnResponse.authCode = summary.authCode
        returnResponse.isApproved = isGatewayApprovedFromResponseMessage(summary.issuerResponseMessage)

        if returnResponse.isApproved {
            if summary.authorizedAmount.count > 0 {
                // We are in presence of a partial approval
                returnResponse.approvedAmount = summary.authorizedAmount.amountInPennies
                returnResponse.isPartialApproval = true
                returnResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                returnResponse.approvedAmount = total
            }

            returnResponse.total = total
            returnResponse.tax = tax
            returnResponse.tip = tip
            returnResponse.authCodeData = PorticoTransactionApprovalCode
            returnResponse.gatewayResponseCode = PorticoTransactionApprovalCode
        }

        // Host Processing Result
        if summary.emvIssuerResponse != nil &&
            !summary.emvIssuerResponse.isEmpty {
            var hostProcessingResult = HostProcessingResult()

            if returnResponse.isApproved || returnResponse.isPartialApproval {
                hostProcessingResult.transactionState = .onlineApproved
            }

            var issuerAuthData: TLVObject? = nil
            let tlvObjects = TLVDecoder.decode(withTLVString: summary.emvIssuerResponse)

            tlvObjects?.forEach({ (obj) in
                // EMV Issuer Scripts => EMV_TAG_ISSUER_SCRIPT_TEMPLATE_1 = 0x71 or
                // EMV_TAG_ISSUER_SCRIPT_TEMPLATE_2 = 0x72

                if obj.tag.caseInsensitiveCompare("71") == .orderedSame ||
                    obj.tag.caseInsensitiveCompare("72") == .orderedSame {
                    hostProcessingResult.emvIssuerScripts = TLVObject.generateHexString(from: obj)
                }

                // EMV Issuer Auth Data => EMV_TAG_ISSUER_AUTHENTICATION_DATA = 0x91
                if obj.tag.caseInsensitiveCompare("91") == .orderedSame {
                    hostProcessingResult.emvIssuerAuthenticationData = TLVObject.generateHexString(from: obj)
                    issuerAuthData = obj
                }
            })

            let emvIssuerResponseCode = getEmvIssuerResponseCodeFromTransaction(self,
                                                                                responseCode: summary.issuerResponseCode,
                                                                                issuerAuthData: issuerAuthData)

            if !emvIssuerResponseCode.isEmpty {
                hostProcessingResult.emvIssuerAuthCode = emvIssuerResponseCode
                returnResponse.emvIssuerRspCode = emvIssuerResponseCode
                returnResponse.emvIssuerResponse = hostProcessingResult.emvIssuerAuthenticationData ?? nil
            }

            returnResponse.hostProcessingResult = hostProcessingResult
        }

        return returnResponse
    }
}

// MARK: Capture Response Conversion
extension CaptureTransaction {

    func buildCaptureResponse(_ hostResponse: GPTransaction?) -> CaptureResponse {
        var captureResponse = CaptureResponse(clientTransactionId,
                                              gatewayTransactionId: hostResponse?.transactionReference.transactionId)
        captureResponse.posReferenceNumber = posReferenceNumber
        captureResponse.invoiceNumber = invoiceNumber

        guard let response = hostResponse else {
            return captureResponse
        }

        captureResponse.gatewayResponseText = response.responseMessage
        captureResponse.isApproved = isGatewayApprovedFromResponseMessage(response.responseMessage)

        if captureResponse.isApproved {
            // We are in the presense of Partial Transaction
            if response.authorizedAmount != nil &&
                !response.authorizedAmount.isEmpty {
                captureResponse.approvedAmount = response.authorizedAmount.amountInPennies
                captureResponse.isPartialApproval = true
                captureResponse.emvIssuerResponse = nil
                captureResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                // Portico does not return approved amount unless partial transaction is in place
                captureResponse.approvedAmount = total
                captureResponse.gatewayResponseCode = PorticoTransactionApprovalCode
            }

            captureResponse.total = total
            captureResponse.tax = tax
            captureResponse.tipAmount = tip
            captureResponse.authCodeData = PorticoTransactionApprovalCode
        }

        return captureResponse
    }
}

// MARK: TipAdjust Response Conversion
extension TipAdjustTransaction {

    func buildTipAdjustResponse(_ hostResponse: GPTransaction?) -> TipAdjustResponse {
        var tipAdjustResponse = TipAdjustResponse(clientTransactionId,
                                                gatewayTransactionId: hostResponse?.transactionReference.transactionId)
        tipAdjustResponse.posReferenceId = posReferenceNumber
        tipAdjustResponse.invoiceNumber = invoiceNumber

        guard let response = hostResponse else {
            return tipAdjustResponse
        }

        tipAdjustResponse.gatewayResponseText = response.responseMessage
       
        tipAdjustResponse.isApproved = isGatewayApprovedFromResponseMessage(response.responseMessage)

        if tipAdjustResponse.isApproved {
            // We are in the presense of Partial Transaction
            if response.authorizedAmount != nil &&
                !response.authorizedAmount.isEmpty {
                tipAdjustResponse.approvedAmount = response.authorizedAmount.amountInPennies
                tipAdjustResponse.isPartialApproval = true
                tipAdjustResponse.emvIssuerResponse = response.emvIssuerResponse
                tipAdjustResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                // Portico does not return approved amount unless partial transaction is in place
                tipAdjustResponse.approvedAmount = total
            }

            tipAdjustResponse.tipAmount = tip
            tipAdjustResponse.authCodeData = PorticoTransactionApprovalCode
            tipAdjustResponse.gatewayResponseCode = PorticoTransactionApprovalCode
        }

        return tipAdjustResponse
    }
}

// MARK: Void Response Conversion
extension VoidTransaction {

    func buildVoidResponse(_ hostResponse: GPTransaction) -> VoidResponse {
        var voidResponse = VoidResponse(clientTransactionId,
                                        gatewayTransactionId: hostResponse.transactionReference.transactionId)
        voidResponse.posReferenceNumber = posReferenceNumber
        voidResponse.invoiceNumber = invoiceNumber
        voidResponse.gatewayResponseText = hostResponse.responseMessage
        voidResponse.isApproved = isGatewayApprovedFromResponseMessage(hostResponse.responseMessage)

        if voidResponse.isApproved {
            // We are in the presense of Partial Transaction
            if hostResponse.authorizedAmount != nil &&
                !hostResponse.authorizedAmount.isEmpty {
                voidResponse.approvedAmount = hostResponse.authorizedAmount.amountInPennies
                voidResponse.isPartialApproval = true
                voidResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                // Portico does not return approved amount unless partial transaction is in place
                voidResponse.approvedAmount = total
            }

            voidResponse.tipAmount = tip
            voidResponse.authCodeData = PorticoTransactionApprovalCode
            voidResponse.gatewayResponseCode = PorticoTransactionApprovalCode
        }

        return voidResponse
    }
}

// MARK: Reversal Response Conversion
extension ReversalTransaction {

    func buildReversalResponse(_ hostResponse: GPTransaction?) -> ReversalResponse {
        var reversalResponse = ReversalResponse(clientTransactionId,
                                        gatewayTransactionId: hostResponse?.transactionReference.transactionId)
        reversalResponse.posReferenceNumber = posReferenceNumber

        guard let hostResponse = hostResponse else {
            return reversalResponse
        }

        reversalResponse.gatewayResponseText = hostResponse.responseMessage
        
        reversalResponse.isApproved = isGatewayApprovedFromResponseMessage(hostResponse.responseMessage)

        if reversalResponse.isApproved {
            // We are in the presense of Partial Transaction
            if hostResponse.authorizedAmount != nil &&
                !hostResponse.authorizedAmount.isEmpty {
                reversalResponse.approvedAmount = hostResponse.authorizedAmount.amountInPennies
                reversalResponse.isPartialApproval = true
                reversalResponse.gatewayResponseCode = PorticoTransactionPartialApprovalCode
            } else {
                // Portico does not return approved amount unless partial transaction is in place
                reversalResponse.approvedAmount = total
            }

            reversalResponse.tipAmount = tip
            reversalResponse.authCodeData = PorticoTransactionApprovalCode
            reversalResponse.gatewayResponseCode = PorticoTransactionApprovalCode
        }

        return reversalResponse
    }
}

extension TokenizationTransaction {

    func buildTokenizedResponse(_ hostResponse: GPTransaction?) -> TokenizationResponse {
        var tokenizationResponse = TokenizationResponse(hostResponse?.transactionReference.transactionId,
                                                        transactionId: clientTransactionId)
        tokenizationResponse.operatingUserId = operatingUserId
        tokenizationResponse.invoiceNumber = invoiceNumber
        tokenizationResponse.posReferenceNumber = posReferenceNumber

        guard let hostResponse = hostResponse else {
            return tokenizationResponse
        }

        var tokenizedCard = TokenizedCardData(token: hostResponse.token)
        tokenizedCard.cardType = cardTypeFromHostResponse(hostResponse.cardType)

        tokenizationResponse.tokenizedCard = tokenizedCard

        return tokenizationResponse
    }
}



// MARK: Internal Methods
func isGatewayApprovedFromResponseMessage(_ responseMessage: String?) -> Bool {
    guard let response = responseMessage else { return false }

    return response.caseInsensitiveCompare(PorticoGatewayApproval) == .orderedSame ||
        response.caseInsensitiveCompare(PorticoGatewaySuccess) == .orderedSame
}

func isTransactionApprovedFromHost(_ responseMessage: String?) -> Bool {
    guard let response = responseMessage else { return false }

    return response.caseInsensitiveCompare(PorticoTransactionApproval) == .orderedSame ||
        response.caseInsensitiveCompare(PorticoTransactionPartialApproval) == .orderedSame ||
        response.caseInsensitiveCompare(PorticoVerifyTransactionVisaApprovalCardOk) == .orderedSame
}

func isTransactionResponseSuccessFromHost(_ responseCode: String?) -> Bool {
    guard let response = responseCode else { return false }

    return response.caseInsensitiveCompare(PorticoTransactionApprovalCode) == .orderedSame ||
        response.caseInsensitiveCompare(PorticoTransactionPartialApprovalCode) == .orderedSame
}

func getEmvIssuerResponseCodeFromTransaction(_ transaction: Transaction,
                                                     responseCode: String?,
                                                     issuerAuthData: TLVObject?) -> String {
    if let cardTransaction = transaction as? CardTransaction {
        if cardTransaction.cardData?.cardType == .amex {
            // For AMEX cards, the EMV issuer response code must be taken from the last 2 bytes
            // of Tag 91 if present.
            if issuerAuthData != nil {
                let issuerDataHex = TLVObject.generateHexString(from: issuerAuthData)

                if let hexValue = issuerDataHex, hexValue.count >= 4 {
                    // 8A --> Emv Issuer Auth Code Tag, 02 --> Length of Value, last 4 digits --> Approval Hex Value
                    return "8A02" + hexValue.suffix(4)
                }
            }
        }
    }

    // In the absence of Tag 91 for AMEX, or in general for all other card brands, the EMV
    // issuer response code is just the HEX value of the <RespCode> field of the gateway
    // response.

    if let responseCode = responseCode, !responseCode.isEmpty {
        if responseCode.caseInsensitiveCompare(EmvIssuerResponseApprovalCode) != .orderedSame &&
            responseCode.caseInsensitiveCompare(EmvIssuerResponsePartialApprovalCode) != .orderedSame &&
            responseCode.caseInsensitiveCompare(EmvIssuerResponseHonorWithIdentificationCode) != .orderedSame {
            // All decline codes must be set to "05"(HEX 3035)
            // 8A --> Emv Issuer Auth Code Tag, 02 --> Length of Value, 3035 --> Denial Hex Value
            return "8A023035"
        } else {
            // 8A --> Emv Issuer Auth Code Tag, 02 --> Length of Value, 3030 --> Approval Hex Value
            return "8A023030"
        }
    }

    return ""
}

func cardTypeFromHostResponse(_ cardTypeString: String?) -> CardType {
    if let cardType = cardTypeString {
        if cardType.caseInsensitiveCompare("Visa") == .orderedSame {
            return .visa
        } else if cardType.caseInsensitiveCompare("Mc") == .orderedSame {
            return .masterCard
        } else if cardType.caseInsensitiveCompare("Disc") == .orderedSame {
            return .discover
        } else if cardType.caseInsensitiveCompare("Amex") == .orderedSame {
            return .amex
        }
    }

    return .unknown
}
