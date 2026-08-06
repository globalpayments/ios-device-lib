//
//  TaxCategory.swift
//  ios-device-lib
//

import Foundation

public enum TaxCategory:String, CaseIterable, Codable, Equatable {
    case notUsed,
    sale,
    taxExempt
}
