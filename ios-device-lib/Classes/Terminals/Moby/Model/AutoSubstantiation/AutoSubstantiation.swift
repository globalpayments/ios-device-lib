//
//  AutoSubstantiation.swift
//  ios-device-lib
//

import Foundation

public enum AutoSubstantiationType: Int {
    case TOTAL_HEALTHCARE_AMT = 0
    case SUBTOTAL_PRESCRIPTION_AMT = 1
    case SUBTOTAL_VISION__OPTICAL_AMT = 2
    case SUBTOTAL_CLINIC_OR_OTHER_AMT = 3
    case SUBTOTAL_DENTAL_AMT = 4
}

public struct AutoSubstantiation: Codable {
    public var realTimeSubstantiation: Bool?
    public var merchantVerificationValue: String?
    public var amounts: [String: String]
    
    public init() {
        self.amounts = [:]
        self.amounts["TOTAL_HEALTHCARE_AMT"] = "0.00"
    }
    
    private mutating func setTotalHealthCareAmount(value: NSDecimalNumber) {
        var valueForTotalHealthcareAmt: NSDecimalNumber = 0;
        if (self.amounts["TOTAL_HEALTHCARE_AMT"] != nil) {
            if let valueForKey: String = self.amounts["TOTAL_HEALTHCARE_AMT"] {
                valueForTotalHealthcareAmt = NSDecimalNumber(string: valueForKey)
            }
        }
        valueForTotalHealthcareAmt.adding(value)
        self.amounts["TOTAL_HEALTHCARE_AMT"] = "\(valueForTotalHealthcareAmt)"
    }
    
    public func isRealTimeSubstantiation() -> Bool {
        return realTimeSubstantiation ?? false;
    }
    
    public mutating func setVisionSubTotal(value: NSDecimalNumber) {
        self.amounts["SUBTOTAL_VISION__OPTICAL_AMT"] = "\(value)"
        self.setTotalHealthCareAmount(value: value)
    }
    
    public mutating func setClinicSubTotal(value: NSDecimalNumber) {
        self.amounts["SUBTOTAL_CLINIC_OR_OTHER_AMT"] = "\(value)"
        self.setTotalHealthCareAmount(value: value)
    }
    
    public mutating func setDentalSubTotal(value: NSDecimalNumber) {
        self.amounts["SUBTOTAL_DENTAL_AMT"] = "\(value)"
        self.setTotalHealthCareAmount(value: value)
    }
    
    public mutating func setPrescriptionSubTotal(value: NSDecimalNumber) {
        self.amounts["SUBTOTAL_PRESCRIPTION_AMT"] = "\(value)"
        self.setTotalHealthCareAmount(value: value)
    }
}
