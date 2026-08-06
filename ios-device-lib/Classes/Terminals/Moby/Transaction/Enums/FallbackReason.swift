//
//  FallbackReason.swift
//  ios-device-lib
//

import Foundation

public enum GMSFallbackReason: Int, Codable {
    case emptyCandidateList,
    iccError,
    other,
    none
}
