//
//  IngenicoEnums.swift
//  ios-device-lib
//

import Foundation

public enum ProgressMessage: UInt {
    case unknown = 0
    case configurationComplete
    case presentCard
    case insertCard
    case removeCard
    case confirmAmount
    case swipeDetected
    case waitingForCardSwipe
    case waitingForDevice
    case decodingStarted  // 10 in original (0-indexed = 9)
    case iccErrorSwipeCard
    case swipeErrorReswipe
    case magCardDataInsertCard
    case cardInserted
    case cardReadError
    case deviceBusy
    case errorReadingContactlessCard
    case multipleContactlessCardsDetected
    case swipeErrorReswipeMagStripe
    case updatingFirmware // 20 in original (0-indexed = 19)
    case tapDetected
    case contactlessCardStillInField
    case pleaseSeePhone
    case contactlessInterfaceFailedTryContact
    case presentCardAgain
    case cardRemoved
    case cardBlocked
    case notAuthorized
    case completeCardRemove
    case insertOrSwipeCard // 30 in original (0-indexed = 29)
    case transactionVoid
    case cardReadOkRemoveCard
    case processingTransaction
    case cardHolderBypassedPIN
    case notAccepted
    case processingDoNotRemoveCard
    case authorizing
    case notAcceptedRemoveCard
    case cardError
    case cardErrorRemoveCard // 40 in original (0-indexed = 39)
    case cancelled
    case cancelledRemoveCard
    case transactionVoidRemoveCard
    case unknownAID
    case reinsertCard
    case approved
    case completeRemoveCard
    case complete
    case waitingForFallbackSwipe // 50 in original (0-indexed = 48)
    case waitingForFallbackChip
    case goOnlineRequested
    case reversalRequested
    case postAuthChipDecline
}

public enum TerminalTransactionType: UInt {
    case sale = 0
    case `return`
    case void
    case auth
    case capture
    case batchClose
    case verify
    case tokenize
    case tipAdjust
    case processSaf
    case listSaf
}
