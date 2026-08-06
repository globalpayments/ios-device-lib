//
//  KeyPathMapping.swift
//  ios-device-lib
//

import Foundation

internal protocol KeyPathMapping: CodingKey, CaseIterable {
    var keyPath: AnyKeyPath { get }
}

extension KeyPathMapping {
    static func keyPath(for key: String)
    -> AnyKeyPath? { Self(stringValue: key)?.keyPath }
}
