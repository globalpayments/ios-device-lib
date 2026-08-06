//
//  CardDataEnums.swift
//  ios-device-lib
//

import Foundation

public enum TagClass: UInt {
    case universal      = 0x00
    case application    = 0x40
    case contextSpecific = 0x80
    case contextPrivate = 0xC0
}

public enum TagType: UInt {
    case primitive   = 0x00
    case constructed = 0x20
}

public enum TagIdentifier: UInt {
    case leadingOctetLongIdentifier         = 0x1F
    case trailingIdentifierOctetHasNext     = 0x80
    case trailingIdentifierOctetIsLast      = 0x00
}

public enum BerLengthType: UInt {
    case definiteShort  = 0
    case definiteLong   = 1
    case indefinite     = 2
}

public enum ParserPosition: UInt {
    case tag    = 0
    case length = 1
    case value  = 2
}

public enum CardholderInteractionType: UInt {
    case emvApplicationSelection  = 0
    case finalAmountConfirmation  = 1
    case commercialCardDataEntry  = 2
}
