//
//  AuthTransaction.swift
//  ios-device-lib
//

import Foundation

/// AuthTransaction Model, all amounts should be passed in Pennies format (no dollar amounts).
/// Surcharge not supported at present.
public struct AuthTransaction: CardTransaction {
    public var allowDuplicates: Bool?
    public var total: UInt?
    public var tip: UInt?
    public let tax: UInt?
    public let surcharge: UInt?
    public let clientTransactionId: String
    public internal(set) var taxCategory: TaxCategory?
    public var posReferenceNumber: String?
    public var invoiceNumber: String?
    public var operatingUserId: String?
    public internal(set) var cardData: AnyCardData?
    public var requestMultiUseToken: Bool = false
    public var cardholderAddress: Address?
    public var customerReceiptEmail: String?
    public var allowPartialAuth: Bool?
    public var cpcReq: Bool?
    public var autoSubstantiation: AutoSubstantiation?
    public var isSurchargeEnabled: Bool?
    public var surchargeAmtInfo: String?
    public var surchargeRequested: SurchargeEligibility?
    public var surchargeFee: Decimal?
    public var preTaxAmount: Decimal?
    
    private init(
        clientTransactionId: String?,
        total: UInt?,
        tax: UInt?,
        tip: UInt?,
        surcharge: UInt?,
        taxCategory: TaxCategory?,
        posReferenceNumber: String?,
        invoiceNumber: String?,
        operatingUserId: String?,
        cardData: AnyCardData?,
        requestMultiUseToken: Bool,
        allowPartialAuth: Bool?,
        cpcReq: Bool?,
        autoSubstantiation: AutoSubstantiation?,
        isSurchargeEnabled: Bool?,
        allowDuplicates: Bool?,
        surchargeFee: Decimal,
        preTaxAmount: Decimal) {
            
        self.total = total
        self.tax = tax
        self.tip = tip
        self.surcharge = surcharge
        self.taxCategory = taxCategory
        self.posReferenceNumber = posReferenceNumber
        self.invoiceNumber = invoiceNumber
        self.operatingUserId = operatingUserId
        self.cardData = cardData
        if let clientTransactionIdValue = clientTransactionId,
           !clientTransactionIdValue.isEmpty {
            self.clientTransactionId = clientTransactionIdValue
        } else {
            self.clientTransactionId = UUID().uuidString
        }
        self.requestMultiUseToken = requestMultiUseToken
        self.allowPartialAuth = allowPartialAuth
        self.cpcReq = cpcReq
        self.autoSubstantiation = autoSubstantiation
        self.isSurchargeEnabled = isSurchargeEnabled
        self.allowDuplicates = allowDuplicates
        self.surchargeFee = surchargeFee
        self.preTaxAmount = preTaxAmount
    }
    
    static public func auth(clientTransactionId: String?,
                            total: UInt?,
                            tax: UInt?,
                            tip: UInt?,
                            surcharge: UInt?,
                            taxCategory: TaxCategory?,
                            posReferenceNumber: String?,
                            invoiceNumber: String?,
                            operatingUserId: String?,
                            requestMultiUseToken: Bool,
                            allowPartialAuth: Bool?,
                            cpcReq: Bool?,
                            autoSubstantiation: AutoSubstantiation?,
                            isSurchargeEnabled: Bool?,
                            allowDuplicates: Bool?,
                            surchargeFee: Decimal,
                            preTaxAmount: Decimal) -> AuthTransaction {
        return AuthTransaction(clientTransactionId: clientTransactionId,
                               total: total,
                               tax: tax,
                               tip: tip,
                               surcharge: surcharge,
                               taxCategory: taxCategory,
                               posReferenceNumber: posReferenceNumber,
                               invoiceNumber: invoiceNumber,
                               operatingUserId: operatingUserId,
                               cardData: nil,
                               requestMultiUseToken: requestMultiUseToken,
                               allowPartialAuth: allowPartialAuth,
                               cpcReq: cpcReq,
                               autoSubstantiation: autoSubstantiation,
                               isSurchargeEnabled: isSurchargeEnabled,
                               allowDuplicates: allowDuplicates,
                               surchargeFee: surchargeFee,
                               preTaxAmount: preTaxAmount)
    }
    
    static public func auth(clientTransactionId: String?,
                            total: UInt?,
                            tax: UInt?,
                            tip: UInt?,
                            surcharge: UInt?,
                            taxCategory: TaxCategory?,
                            posReferenceNumber: String?,
                            invoiceNumber: String?,
                            operatingUserId: String?,
                            cardData: ManualCardData,
                            requestMultiUseToken: Bool,
                            allowPartialAuth: Bool?,
                            cpcReq: Bool?,
                            autoSubstantiation: AutoSubstantiation?,
                            isSurchargeEnabled: Bool?,
                            allowDuplicates: Bool?,
                            surchargeFee: Decimal,
                            preTaxAmount: Decimal) -> AuthTransaction {
        var auth = AuthTransaction(clientTransactionId: clientTransactionId,
                                   total: total,
                                   tax: tax,
                                   tip: tip,
                                   surcharge: surcharge,
                                   taxCategory: taxCategory,
                                   posReferenceNumber: posReferenceNumber,
                                   invoiceNumber: invoiceNumber,
                                   operatingUserId: operatingUserId,
                                   cardData: AnyCardData(cardData: cardData),
                                   requestMultiUseToken: requestMultiUseToken,
                                   allowPartialAuth: allowPartialAuth,
                                   cpcReq: cpcReq,
                                   autoSubstantiation: autoSubstantiation,
                                   isSurchargeEnabled: isSurchargeEnabled,
                                   allowDuplicates: allowDuplicates,
                                   surchargeFee: surchargeFee,
                                   preTaxAmount: preTaxAmount)
        auth.cardholderAddress = cardData.cardHolderAddress

        return auth
    }

    static public func auth(clientTransactionId: String?,
                            total: UInt?,
                            tax: UInt?,
                            tip: UInt?,
                            surcharge: UInt?,
                            taxCategory: TaxCategory?,
                            posReferenceNumber: String?,
                            invoiceNumber: String?,
                            operatingUserId: String?,
                            cardData: TokenizedCardData,
                            allowPartialAuth: Bool?,
                            cpcReq: Bool?,
                            autoSubstantiation: AutoSubstantiation?,
                            isSurchargeEnabled: Bool?,
                            allowDuplicates: Bool?,
                            surchargeFee: Decimal,
                            preTaxAmount: Decimal) -> AuthTransaction {
        return AuthTransaction(clientTransactionId: clientTransactionId,
                               total: total,
                               tax: tax,
                               tip: tip,
                               surcharge: surcharge,
                               taxCategory: taxCategory,
                               posReferenceNumber: posReferenceNumber,
                               invoiceNumber: invoiceNumber,
                               operatingUserId: operatingUserId,
                               cardData: AnyCardData(cardData: cardData),
                               requestMultiUseToken: false,
                               allowPartialAuth: allowPartialAuth,
                               cpcReq: cpcReq,
                               autoSubstantiation: autoSubstantiation,
                               isSurchargeEnabled: isSurchargeEnabled,
                               allowDuplicates: allowDuplicates,
                               surchargeFee: surchargeFee,
                               preTaxAmount: preTaxAmount)
    }
}
