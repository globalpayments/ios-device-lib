//
//  TransactionFlowStep.swift
//  ios-device-lib
//

import Foundation

enum TransactionFlowStep: UInt {
    case idle,
         waitingForCard,
         waitingForCardRemoval,
         waitingForAmount,
         waitingForNfc,
         startEmv,
         setAmount,
         confirmAmount,
         selectAid,
         onlineProcesssing,
         finishing,
         waitingForSurchargeConfirmation
}
