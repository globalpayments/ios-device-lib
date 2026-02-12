//
//  UpaPhoneOrder.swift
//  ios-device-lib
//
//  Created by Ranu Dhurandhar on 27/01/26.
//


public struct UpaPhoneOrder: Codable {
    public var message: String
    public let data: UpaPhoneOrderCommandData?
    
    public init(message: String = "MSG", data: UpaPhoneOrderCommandData?) {
        self.message = message
        self.data = data
    }
}

public struct UpaPhoneOrderCommandData: Codable {
    public var command: String
    public let EcrId, requestId: String?
    public let data: UpaPhoneOrderData?
    
    public init(command: String = "PhoneOrder", EcrId: String?,
                requestId: String?, data: UpaPhoneOrderData?) {
        self.command = command
        self.EcrId = EcrId
        self.requestId = requestId
        self.data = data
    }
}

public struct UpaPhoneOrderData: Codable {
    public let params: UpaPhoneOrderParam?
    public let transaction: UpaPhoneOrderTransaction?
    
    public init(params: UpaPhoneOrderParam? = nil, transaction: UpaPhoneOrderTransaction? = nil) {
        self.params = params
        self.transaction = transaction
    }
}

public struct UpaPhoneOrderTransaction: Codable {
    public let baseAmount: String?
    public let allowDuplicate: String?
    
    public init(baseAmount: String? = nil, allowDuplicate: String? = nil) {
        self.baseAmount = baseAmount
        self.allowDuplicate = allowDuplicate
    }
}

public struct UpaPhoneOrderParam: Codable {
    public let clerkId: String?
    public init(clerkId: String? = nil) {
        self.clerkId = clerkId
    }
}
