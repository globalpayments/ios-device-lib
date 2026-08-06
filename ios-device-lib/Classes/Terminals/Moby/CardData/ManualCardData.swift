//
//  ManualCardData.swift
//  ios-device-lib
//

import Foundation

public struct ManualCardData: CardData {

    public var cardEntryMode: EntryMode
    public var cardholderName: String?
    public let cardNumber: String
    public var maskedPAN: String?
    public let expirationDate: String
    public let cvv: String
    public var cardPresent: Bool
    public let readerPresent: Bool
    public var cardHolderAddress: Address?
    public var terminalType: TerminalType = .none

    private init(cardholderName: String,
                cardNumber: String,
                expirationDate: String,
                cvv: String,
                cardPresent: Bool,
                readerPresent: Bool,
                terminalType: TerminalType) {
        self.cardholderName = cardholderName
        self.cardNumber = cardNumber
        self.maskedPAN = cardNumber.masked
        self.expirationDate = expirationDate
        self.cvv = cvv
        self.cardPresent = cardPresent
        self.cardEntryMode = .manual
        self.readerPresent = readerPresent
        self.terminalType = terminalType
    }

    public static func cardData(cardholderName: String,
                                cardNumber: String,
                                expirationDate: String,
                                cvv: String,
                                cardPresent: Bool,
                                readerPresent: Bool,
                                terminalType: TerminalType) -> ManualCardData {
        return self.init(cardholderName: cardholderName,
                         cardNumber: cardNumber,
                         expirationDate: expirationDate,
                         cvv: cvv,
                         cardPresent: cardPresent,
                         readerPresent: readerPresent,
                         terminalType: terminalType)
    }
}
