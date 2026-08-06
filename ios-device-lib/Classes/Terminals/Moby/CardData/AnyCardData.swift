//
//  AnyCardData.swift
//  ios-device-lib
//

import Foundation

public struct AnyCardData: CardData {
    
    public var cardData: CardData
    let cardType: CardType
    public var cardEntryMode: EntryMode
    public var terminalType: TerminalType {
        cardData.terminalType
    }

    enum CodingKeys: String, CodingKey {
        case contact,
        contactless,
        manual,
        msr,
        msrFallback,
        quickChip,
        cardEntryMode,
        tokenized,
        cardType
    }

    public init(cardData: CardData) {
        let unwrappedCardData = (cardData as? AnyCardData)?.cardData ?? cardData
        self.cardData = unwrappedCardData
        self.cardEntryMode = unwrappedCardData.cardEntryMode
        self.cardType = .unknown
    }
        
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(ContactCardData.self, forKey: .contact) {
            cardData = value
            cardEntryMode = .contact

            if let pan = value.maskedPAN {
                cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: pan)
            } else {
                cardType = .unknown
            }
        } else if let value = try container.decodeIfPresent(ContactlessCardData.self, forKey: .contactless) {
            cardData = value
            cardEntryMode = .contactless

            if let pan = value.maskedPAN {
                cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: pan)
            } else {
                cardType = .unknown
            }
        } else if let value = try container.decodeIfPresent(ManualCardData.self, forKey: .manual) {
            cardData = value
            cardEntryMode = .manual
            cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: value.cardNumber)
        } else if let value = try container.decodeIfPresent(MSRCardData.self, forKey: .msr) {
            cardData = value
            cardEntryMode = .msr

            if let pan = value.maskedPAN {
                cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: pan)
            } else {
                cardType = .unknown
            }
        } else if let value = try container.decodeIfPresent(MSRFallbackCardData.self, forKey: .msrFallback) {
            cardData = value
            cardEntryMode = .chipFallback

            if let pan = value.maskedPAN {
                cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: pan)
            } else {
                cardType = .unknown
            }
        } else if let value = try container.decodeIfPresent(QuickChipCardData.self, forKey: .quickChip) {
            cardData = value
            cardEntryMode = .quickChip

            if let pan = value.maskedPAN {
                cardType = CreditCardHelper().getCardTypeFromRedactedPan(cardNumber: pan)
            } else {
                cardType = .unknown
            }
        } else if let value = try container.decodeIfPresent(TokenizedCardData.self, forKey: .tokenized) {
            cardData = value
            cardEntryMode = .token
            cardType = .tokenizedCard
        }
        else {
            throw CardDataError.decodeFailed(debugMessage: "Expected key not found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch cardData {
        case let value as ContactCardData:
            try container.encode(value, forKey: .contact)
        case let value as ContactlessCardData:
            try container.encode(value, forKey: .contactless)
        case let value as ManualCardData:
            try container.encode(value, forKey: .manual)
        case let value as MSRCardData:
            try container.encode(value, forKey: .msr)
        case let value as MSRFallbackCardData:
            try container.encode(value, forKey: .msrFallback)
        case let value as QuickChipCardData:
            try container.encode(value, forKey: .quickChip)
        case let value as TokenizedCardData:
            try container.encode(value, forKey: .tokenized)
        default:
            throw CardDataError.encodeFailed(debugMessage: "unsupported card data type \(cardData.self)")
        }

        try container.encode(cardEntryMode, forKey: .cardEntryMode)
        try container.encode(cardType, forKey: .cardType)
    }
    
    public enum CardDataError: Error {
        case decodeFailed(debugMessage: String),
        encodeFailed(debugMessage: String)
    }
}

extension AnyCardData {
    public var maskedPan: String {
        switch cardData {
        case (let card as ManualCardData):
            return card.cardNumber.masked
        case (let card as MSRCard):
            return card.maskedPAN?.masked ?? ""
        default:
            return ""
        }
    }
    
    public var cardholderName: String? {
        switch cardData {
        case (let card as ManualCardData):
            return card.cardholderName
        case (let card as MSRCard):
            return card.cardholderName ?? ""
        default:
            return ""
        }
    }
}
