//
//  HpsAutoSubstantiation+toAutoSubstantiation.swift
//  ios_device_lib
//

import Foundation

extension HpsAutoSubstantiation {
    public func toAutoSubstantiation() -> AutoSubstantiation {
        var gAutoSubstantiation = AutoSubstantiation()
        gAutoSubstantiation.realTimeSubstantiation = self.realTimeSubstantiation as? Bool
        gAutoSubstantiation.merchantVerificationValue = self.merchantVerificationValue as String?
        if let amounts = self.amounts as? [String:String] {
            gAutoSubstantiation.amounts = amounts
        }
        return gAutoSubstantiation
    }
}
