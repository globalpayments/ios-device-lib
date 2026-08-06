//
//  TransactionResponse.swift
//  ios-device-lib
//

import Foundation

public protocol TransactionResponse: Codable {
    var transactionResult: TransactionResult? { get set }
    var transactionId: String { get }
    var gatewayTransactionId: String? { get }
    var gatewayResponseText: String? { get }
    var gatewayResponseCode: String? { get }
    var approvedAmount: UInt? { get set }
    var transactionDescription: String { get }
    var transactionError: GMSError? { get set }
    var surchargeRequested: SurchargeEligibility? { get set }
    var surchargeFee: String? { get set }
    var surchargeAmount: String? { get set }
    var clientTxnID: String? { get set }
}

extension TransactionResponse {
    private var receipt: String? {
        guard let response = self as? CardTransactionResponse else {
            return nil
        }
        
        var receiptString =  """

                    \(response.merchantName.uppercased())
                    \(response.merchantAddress.uppercased())
                    \(Date().receiptFormattedDatetime?.uppercased() ?? "")

                    CREDIT - \(response.transactionType?.rawValue.uppercased() ?? "")

                    CARD # : XXXXXXXXXXXX\(response.maskedPan?.suffix(4) ?? "")
                    CARD TYPE : \(response.cardType?.rawValue.uppercased() ?? "")
                    ENTRY MODE : \(response.cardDataSourceType?.rawValue.uppercased() ?? "")
                    CARDHOLDER NAME : \(response.cardholderName ?? "")

                    """
        switch response.cardDataSourceType {
        case .contact, .quickChip, .contactless:
                receiptString = receiptString +
                        """
                                
                        AID : \(response.aid ?? "")
                        TSI : \(response.tsi ?? "")
                        APP LABEL : \(response.applicationLabel ?? "")
                        APP EFF : \("")
                        APP VERSION : \(response.applicationVersionNumber ?? "")
                        APP TRANS COUNTER : \(response.applicationTransactionCounter ?? "")
                        PAN SEQ # : \(response.applicationPANSequenceNumber ?? "")
                        CRYPTOGRAM : \(response.applicationCryptogram ?? "")
                        CVM : \(response.cvm ?? "")
                        IAD : \(response.iad ?? "")
                        TVR : \(response.tvr ?? "")
                        UNPREDICTABLE # : \(response.unpredictableNumber ?? "")
                        CID : \(response.cid ?? "")

                        """
            default: break
        }

        var tip: Decimal?

        switch self {
        case let response as AuthResponse:
            tip = response.tip?.amountInDecimal
        case let response as SaleResponse:
            tip = response.tip?.amountInDecimal
        case let response as CaptureResponse:
            tip = response.tipAmount?.amountInDecimal
        default: break
        }

        var subTotal: Decimal?

        if let authAmount = response.approvedAmount?.amountInDecimal {
            subTotal = authAmount - (tip ?? 0) - (response.tax?.amountInDecimal ?? 0)
        }

        return receiptString +
                    """

                    TRANSACTION ID : \(response.gatewayTransactionId ?? "")
                    CLIENT TRANSACTION ID : \(response.transactionId)

                    INVOICE NUMBER : \(response.invoiceNumber ?? "")
                    AUTH CODE : \(response.authCode ?? "")

                    Currency Code: 840
                    Currency : USD
                    Cashback Amount : $0
                    Subtotal : $\(subTotal?.stringValue ?? "0")
                    Tax : $\(response.tax?.amountInDollarString ?? "0")
                    Tip Amount: $\(tip?.stringValue ?? "0")
                    --------------------
                    Total : $\(response.approvedAmount?.amountInDollarString ?? "0")
                    --------------------

                    """
    }
    
    public var customerReceipt: String? {
        guard let response = self as? CardTransactionResponse else {
            return nil
        }
        let receiptString = receipt ?? ""
        return receiptString +
                """

                \(response.acknowledgement.uppercased())

                \(response.refundPolicy)

                \(response.gatewayResponseText?.uppercased() ?? "")

                CUSTOMER COPY
                """
    }
    
    public var merchantReceipt: String? {
        guard let response = self as? CardTransactionResponse else {
            return nil
        }
        var receiptString = receipt ?? ""
        if response.manualSignature {
            receiptString = receiptString +
                    """

                    \(response.signatureAgreement)

                    X___________________
                    \(response.cardholderName?.uppercased() ?? "CARDHOLDER")

                    """
        }
        
        return receiptString +
                """

                \(response.acknowledgement.uppercased())

                \(response.refundPolicy)

                \(response.gatewayResponseText?.uppercased() ?? "")

                MERCHANT COPY
                """
    }
}

protocol CardTransactionResponse: TransactionResponse {

    var hostProcessingResult: HostProcessingResult? { get set }
    var total: UInt? { get set }
    var tax: UInt? { get set }
    var invoiceNumber: String? { get set }
    var authCode: String? { get set }
    var cardholderName: String? { get set }
    var cardDataSourceType: EntryMode? { get set }
    var cardType: CardType? { get }
    var maskedPan: String? { get set }
    var aid: String? { get set }
    var applicationLabel: String? { get set }
    var cvm: String? { get set }
    var tsi: String? { get set }
    var tvr: String? { get set }
    var iac: String? { get set }
    var iad: String? { get set }
    var applicationCryptogram: String? { get set }
    var applicationCryptogramType: String? { get set }
    var applicationPANSequenceNumber: String? { get set }
    var applicationVersionNumber: String? { get set }
    var cid: String? { get set }
    var applicationTransactionCounter: String? { get set }
    var unpredictableNumber: String? { get set }
    var transactionSequenceCounter: String? { get set }
    var transactionType: TransactionType? { get set }
    var terminalType: String? { get set }
    var merchantName: String { get set }
    var merchantAddress: String { get set }
    var merchantNumber: String { get set }
    var manualSignature: Bool { get set }
    var signatureAgreement: String { get set }
    var acknowledgement: String { get set }
    var refundPolicy: String { get set }
}

/// Default implementation

extension CardTransactionResponse {
    var invoiceNumber: String? { get { "" } set {} }
    var authCode: String? { get { "" } set {} }
    var iac: String? { get { "" } set {} }
    var iad: String? { get { "" } set {} }
    var applicationCryptogram: String? { get { "" } set {} }
    var applicationCryptogramType: String? { get { "" } set {} }
    var applicationPANSequenceNumber: String? { get { "" } set {} }
    var applicationVersionNumber: String? { get { "" } set {} }
    var cid: String? { get { "" } set {} }
    var applicationTransactionCounter: String? { get { "" } set {} }
    var unpredictableNumber: String? { get { "" } set {} }
    var transactionSequenceCounter: String? { get { "" } set {} }
    var transactionType: TransactionType? { get { nil } set {} }
    var terminalType: String? { get { nil } set {} }
    var merchantName: String { get { "" } set {} }
    var merchantAddress: String { get { "" } set {} }
    var merchantNumber: String { get { "" } set {} }
    var manualSignature: Bool { get { true } set {} }
    internal var signatureAgreement: String { get { "" } set {} }
    internal var acknowledgement: String { get { "" } set {} }
    internal var refundPolicy: String { get { "" } set {} }
}

protocol GatewayReferenceTransactionResponse: TransactionResponse {
    // Add if any variables require here
}
