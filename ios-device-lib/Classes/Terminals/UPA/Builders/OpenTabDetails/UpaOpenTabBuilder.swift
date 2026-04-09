//
//  UpaOpenTabBuilder.swift
//  ios-device-lib
//

import Foundation
public class UpaOpenTabBuilder {
    
    private var upaDevice: HpsUpaDevice
    
    init(with device: HpsUpaDevice) {
        upaDevice = device
    }
    
    public func execute(request: UpaOpenTabDetails, response: @escaping (IHPSDeviceResponse?, String?, Error?) -> Void) {
        let encoder = JSONEncoder()

        let json = try? encoder.encode(request)

        guard let json else { return }
        
        upaDevice.processTransaction(withJSONString: String(data: json, encoding: .utf8), withResponseBlock: response)
    }
}
