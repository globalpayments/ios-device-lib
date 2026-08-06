//
//  SaleTransaction.swift
//  ios-device-lib
//

import Foundation

/// SaleTransaction Model, all amounts should be passed in Pennies format (no dollar amounts).
/// Surcharge not supported at present.
public struct SaleTransaction: CardTransaction {
    public var allowDuplicates: Bool?
    public var total: UInt?
    public var tip: UInt?
    public let tax: UInt?
    public let surcharge: UInt?
    public let clientTransactionId: String
    public let taxCategory: TaxCategory?
    public var posReferenceNumber: String?
    public var invoiceNumber: String?
    public var operatingUserId: String?
    public internal(set) var cardData: AnyCardData?
    public var requestMultiUseToken: Bool = false
    public var cardholderAddress: Address?
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
            if let clientTransactionIdValue = clientTransactionId, !clientTransactionIdValue.isEmpty {
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
    
    public static func sale(clientTransactionId: String?,
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
                            preTaxAmount: Decimal) -> SaleTransaction {
        return SaleTransaction(clientTransactionId: clientTransactionId,
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
    
    public static func sale(clientTransactionId: String?,
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
                            preTaxAmount: Decimal) -> SaleTransaction {
        var sale = SaleTransaction(clientTransactionId: clientTransactionId,
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
        sale.cardholderAddress = cardData.cardHolderAddress
        return sale
    }
    
    public static func sale(clientTransactionId: String?,
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
                            preTaxAmount: Decimal) -> SaleTransaction {
        return SaleTransaction(clientTransactionId: clientTransactionId,
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
