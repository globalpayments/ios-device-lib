//
//  EntryMode.swift
//  ios-device-lib
//

import Foundation

public enum EntryMode: String, CaseIterable, Codable {
    case msr,
    chipFallback,
    contact,
    contactless,
    manual,
    quickChip,
    token
}
