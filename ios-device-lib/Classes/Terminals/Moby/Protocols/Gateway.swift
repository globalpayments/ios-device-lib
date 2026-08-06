//
//  Gateway.swift
//  ios-device-lib
//

import Foundation
import GlobalPaymentsApi

public enum GatewayType: String,
                         Codable,
                         CaseIterable,
                         Equatable {
    case Portico, ProPay, TransIT

    public var configType: GatewayConfig.Type {
        switch self {
        case .ProPay: break//return PropayConfig.self
        case .Portico: return PorticoConfig.self
        case .TransIT: break//return TransITConfig.self
        }
        return PorticoConfig.self
    }
}

protocol Gateway {
    var delegate: GatewayDelegate? { get set }
    var gatewayConfig: GatewayConfig { get }

    init?<C: GatewayConfig>(config: C)

    func sale(transaction: SaleTransaction)
    func auth(transaction: AuthTransaction)
    func tipAdjust(transaction: TipAdjustTransaction)
    func capture(transaction: CaptureTransaction)
    func void(transaction: VoidTransaction)
    func reverse(transaction: ReversalTransaction)
    func `return`(transaction: ReturnTransaction)
    func batchClose(transaction: BatchCloseTransaction)
    func tokenize(transaction: TokenizationTransaction)
    func verify(transaction: VerifyTransaction)
    func binCardCheck(transaction: CardTransaction,
                      cardData: AnyCardData,
                      completion: @escaping ((_ response: SurchargeRequestedResponse?,
                                              _ error: Error?) -> Void))
    
    func getTransactionDetail(transactionId: String, completion: @escaping ((_ response: GPTransactionSummary?,
                                                                             _ error: Error?) -> Void))
}
