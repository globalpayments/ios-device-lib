//
//  UpaForceSale.swift
//  ios-device-lib
//
//  Created by Ranu Dhurandhar on 23/01/26.
//

import Foundation

public struct UpaForceSale: Codable {
    public var message: String
    public let data: UpaForceSaleCommandData?
    
    public init(message: String = "MSG", data: UpaForceSaleCommandData?) {
        self.message = message
        self.data = data
    }
}

public struct UpaForceSaleCommandData: Codable {
    public var command: String
    public let EcrId, requestId: String?
    public let data: UpaForceSaleData?
    
    public init(command: String = "ForceSale", EcrId: String?,
                requestId: String?, data: UpaForceSaleData?) {
        self.command = command
        self.EcrId = EcrId
        self.requestId = requestId
        self.data = data
    }
}

public struct UpaForceSaleData: Codable {
    public let params: UpaForceSaleParam?
    public let transaction: UpaForceSaleTransaction? // Added transaction property

    public init(params: UpaForceSaleParam?, transaction: UpaForceSaleTransaction? = nil) {
        self.params = params
        self.transaction = transaction
    }
}

public struct UpaForceSaleTransaction: Codable {
    public let baseAmount: String?
    public let taxAmount: String?
    public let tipAmount: String?
    public let taxIndicator: String?
    public let invoiceNbr: String?
    public let allowDuplicate: String?
    
    public init(baseAmount: String? = nil, taxAmount: String? = nil, tipAmount: String? = nil, taxIndicator: String? = nil, invoiceNbr: String? = nil, allowDuplicate: String? = nil) {
        self.baseAmount = baseAmount
        self.taxAmount = taxAmount
        self.tipAmount = tipAmount
        self.taxIndicator = taxIndicator
        self.invoiceNbr = invoiceNbr
        self.allowDuplicate = allowDuplicate
    }
}

public struct UpaForceSaleParam: Codable {
    public let clerkId: String?
    public init(clerkId: String? = nil) {
        self.clerkId = clerkId
    }
}
