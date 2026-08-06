//
//  Address.swift
//  ios-device-lib
//

import Foundation

public struct Address: Codable, Equatable {

    public var addressLine1: String?
    public var addressLine2: String?
    public var postalCode: String?
    public var city: String?
    public var state: String?

    public init() {
        
    }
}
