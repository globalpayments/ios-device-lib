//
//  UpaScanBuilder.swift
//  ios-device-lib
//

import Foundation

public class UpaScanBuilder {
    
    private var upaDevice: HpsUpaDevice
    
    init(upaDevice: HpsUpaDevice) {
        self.upaDevice = upaDevice
    }
    
    public func execute(request: UpaScan, response: @escaping (IHPSDeviceResponse?, String?, Error?) -> Void) {
        let encoder = JSONEncoder()

        let json = try? encoder.encode(request)

        guard let json else { return }
        
        upaDevice.processTransaction(withJSONString: String(data: json, encoding: .utf8), withResponseBlock: response)
    }
}
