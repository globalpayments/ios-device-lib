//
//  CreditCardHelper.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class CreditCardHelper: NSObject {

    /// Helper function to convert redacted PAN to payment Card Type
    ///
    /// - Parameter cardNumber: PAN to convert
    /// - Returns: converted CardType
    public func getCardTypeFromRedactedPan(cardNumber: String) -> CardType {
        // Replace occurrences of 'X' or 'x' with '0'
        var pan = cardNumber.replacingOccurrences(of: "X", with: "0")
        pan = pan.replacingOccurrences(of: "x", with: "0")

        var result = CardType.unknown

        // grab the integers at the given length
        // done this way because the regex for the >= and <= would have been
        // much less legible
        let length = pan.count
        let firstOne = (length >= 1) ? Int(pan.prefix(1)) ?? 0 : 0
        let firstTwo = (length >= 2) ? Int(pan.prefix(2)) ?? 0 : 0
        let firstThree = (length >= 3) ? Int(pan.prefix(3)) ?? 0 : 0
        let firstFour = (length >= 4) ? Int(pan.prefix(4)) ?? 0 : 0
        let firstFive = (length >= 5) ? Int(pan.prefix(5)) ?? 0 : 0
        let firstSix = (length >= 6) ? Int(pan.prefix(6)) ?? 0 : 0

        // after 4 digits, it's possible that we're getting a masked card
        // number. We should still try to identify it as the first four may give
        // us a match.

        if (firstOne == 4) {
            result = .visa
        } else if (firstTwo == 34 || firstTwo == 37) {
            result = .amex
        } else if (firstTwo >= 51 && firstTwo <= 58) {
            result = .masterCard
        } else if ((firstThree >= 300 && firstThree <= 305) || firstTwo == 36
            || firstFour == 3095 || firstTwo == 38 || firstTwo == 39) {
            result = .dinersClub
        } else if ((firstFive == 60110)
            || (firstFive >= 60112 && firstFive <= 60114)
            || (firstSix == 601175 && firstSix == 601177)
            || (firstSix >= 601186 && firstSix <= 601199)
            || (firstThree >= 644 && firstThree <= 659)
            // this line will cause false positives, but TSYS wanted it. Be
            // aware.
            || (firstThree >= 600 && firstThree <= 699)) {
            result = .discover
        } else if ((firstFour >= 3528 && firstFour <= 3589)) {
            result = .jcb
        } else if (firstFour == 5018 || firstFour == 5020 || firstFour == 5038
            || firstFour == 6304 || firstFour == 6759 || firstFour == 6761
            || firstFour == 6763) {
            result = .maestro
        } else if ((firstSix >= 622126 && firstSix <= 622925)
            || (firstFour >= 6240 && firstFour <= 6269)
            || (firstFour >= 6282 && firstFour <= 6288)) {
            result = .unionPay
        }

        return result
    }
}
