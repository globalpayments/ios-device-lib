//
//  EncryptionType.swift
//  ios-device-lib
//

import Foundation

public enum EncryptionType: Int, Codable {
    case TDES,
    DUKPT,
    voltage,
    IDT_TDES,
    none
}
