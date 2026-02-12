//
//  UpaPhoneOrderBuilder.swift
//  ios-device-lib
//
//  Created by Ranu Dhurandhar on 27/01/26.
//

import Foundation

public class UpaPhoneOrderBuilder {
    
    private var upaDevice: HpsUpaDevice
    
    init(upaDevice: HpsUpaDevice) {
        self.upaDevice = upaDevice
    }
    
    public func execute(request: UpaPhoneOrder, response: @escaping (IHPSDeviceResponse?, String?, Error?) -> Void) {
        let encoder = JSONEncoder()

        let json = try? encoder.encode(request)

        guard let json else { return }
        
        upaDevice.processTransaction(withJSONString: String(data: json, encoding: .utf8), withResponseBlock: response)
    }
}
