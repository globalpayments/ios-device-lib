//
//  TransactionState.swift
//  ios-device-lib
//

import Foundation

public enum TransactionState: Equatable {
    case waitingForConfiguration,
    configuringTerminal(completed: Int, total: Int),
    configurationFailedTryAgain,
    ready,
    started,
    waitingForCard,
    insertCard,
    removeCard,
    cardRemoved,
    pleaseWait,
    pleaseSeePhone,
    useMagstripe, // Equivalent to Manual Entry incase of Terminals that doesn't support MSR entry mode.
    tryAgain,
    swipeErrorReSwipe,
    noEmvApps,
    applicationExpired,
    cardReadError,
    processing,
    processingDoNotRemoveCard,
    presentCard,
    presentCardAgain,
    insertSwipeOrTryAnotherCard,
    insertOrSwipeCard,
    multipleCardDetected,
    contactlessCardStillInField,
    transactionTerminated,
    waitingForTerminal,
    terminalDeclined,
    cardDetected,
    cardBlocked,
    notAuthorized,
    notAcceptedRemoveCard,
    fallbackToMSR,
    fallbackToChip,
    waitingForAmountConfirmation,
    waitingForAidSelection,
    waitingForPostalCode,
    waitingForSafApproval,
    cardHolderBypassedPIN,
    processingSaf(completed: Int, total: Int),
    requestingOnlineProcessing,
    reversal,
    reversalInProgress,
    complete,
    cancel,
    cancelling,
    cancelled,
    error,
    unknown,
    waitingForSurchargeAcceptance
}
