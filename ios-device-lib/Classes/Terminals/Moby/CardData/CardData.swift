//
//  CardData.swift
//  ios-device-lib
//

import Foundation

public protocol CardData: Codable {
    var cardEntryMode: EntryMode { get set }
    var cardholderName: String? { get set }
    var maskedPAN: String? { get set }
    var expirationDate: String? { get set }
    var terminalType: TerminalType { get set }
}

extension CardData {
    public var cardholderName: String? { get { nil } set {} }
    public var maskedPAN: String? { get { nil } set {} }
    public var expirationDate: String? { get { nil } set {} }
    public var terminalType: TerminalType { get { .none } set {} }
}

protocol MSRCard: CardData {
    var encryptedTrack1: String? { get set }
    var encryptedTrack2: String? { get set }
    var formatID: Int? { get set }
    var ksn: String? { get set }
    var serialNumber: String? { get set }
    var serviceCode: Int? { get set }
    var track1Length: Int? { get set }
    var track2Length: Int? { get set }
}

protocol EMVCard: CardData {
    var encryptedTrack1: String? { get set }
    var encryptedTrack2: String? { get set }
    var formatID: Int? { get set }
    var ksn: String? { get set }
    var serialNumber: String? { get set }
    var serviceCode: Int? { get set }
    var track1Length: Int? { get set }
    var track2Length: Int? { get set }
    var aid: String? { get set }
    var applicationLabel: String? { get set }
    var cvm: String? { get set }
    var tsi: String? { get set }
    var tvr: String? { get set }
    var tlvData: String { get set }
}
