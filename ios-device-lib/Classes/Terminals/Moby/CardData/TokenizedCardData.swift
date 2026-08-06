//
//  TokenizedCardData.swift
//  ios-device-lib
//

import Foundation

public struct TokenizedCardData: CardData {

    public var cardEntryMode: EntryMode
    public var token: String?
    public var payerID: Int? //For Propay
    public var cardType: CardType?
    public var maskedPAN: String?
    public var cardholderName: String?
    public var expirationDate: String?
    public var isCardPresent: Bool?
    public var isReaderPresent: Bool?
    public var cvv2: String?
    public var cvv2Status: String?
    public var postalCode: String?
    public var emailAddress: String?
    public var terminalType: TerminalType = .none

    public init(token: String?) {
        self.cardEntryMode = .token
        self.token = token
        self.cardType = .tokenizedCard
    }
}
