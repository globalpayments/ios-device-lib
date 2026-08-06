//
//  FormatHelper.swift
//  ios-device-lib
//

import Foundation

extension Decimal {

    var stringValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 2

        return formatter.string(for: self) ?? "0.00"
    }
    
    var stringValueSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = "."

        return formatter.string(for: self) ?? "0.00"
    }

    var penniesValue: Int {
        let decimal = NSDecimalNumber(decimal: self)
            let handler = NSDecimalNumberHandler(roundingMode: .plain,
                               scale: 2,
                               raiseOnExactness: false,
                               raiseOnOverflow: false,
                               raiseOnUnderflow: false,
                               raiseOnDivideByZero: false)
            let rounded = decimal.rounding(accordingToBehavior: handler).multiplying(byPowerOf10: 2)
            return Int(truncating: rounded)
    }
    
    var penniesValueUInt: UInt {
        return UInt(abs(penniesValue))
    }
    
    func rounded(_ scale: Int, _ mode: NSDecimalNumber.RoundingMode = .bankers) -> Decimal {
        var value = self
        var roundedValue = Decimal()
        NSDecimalRound(&roundedValue, &value, scale, mode)
        return roundedValue
    }
}

extension UInt {

    var amountInDecimal: Decimal {
        if self == 0 {
            return Decimal.zero
        }

        return NSDecimalNumber(value: self).multiplying(byPowerOf10: -2).decimalValue
    }

    var amountInDollarString: String {
        
        return nsDecimalNumber.stringValue
    }

    var nsDecimalNumber: NSDecimalNumber {
        if self == 0 {
            return NSDecimalNumber.zero
        }

        return NSDecimalNumber(value: self).multiplying(byPowerOf10: -2)
    }
}

extension Int {
    var decimalValue: Decimal {
        let amount = Double(self) / 100

        return Decimal(amount)
    }
}

extension String {

    var amountInPennies: UInt {
        if self.isEmpty {
            return 0
        }

        return NSDecimalNumber(string: self).multiplying(byPowerOf10: 2).uintValue
    }

    func trimmingTrailingCharacters(`in` set: CharacterSet) -> String {
        var copyString = Substring(self)
        while let range = copyString.rangeOfCharacter(from: set, options: [.anchored, .backwards]) {
            copyString = copyString[..<range.lowerBound]
        }
        return String(copyString)
    }
    
    var masked: String {
        var resultString = ""
        var firstDigits = 6
        var lastDigits = 4
        
        if count == 19 {
            firstDigits = 8
            lastDigits = 5
        } else if count == 15 {
            firstDigits = 5
            lastDigits = 4
        }
        
        enumerated().forEach { (index, character) in
            if (index >= firstDigits) && (index < (count - lastDigits)) {
                resultString += "*"
            } else {
                resultString.append(character)
            }
        }
        
        return resultString
    }
}

extension Date {
    var receiptFormattedDatetime: String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
}
