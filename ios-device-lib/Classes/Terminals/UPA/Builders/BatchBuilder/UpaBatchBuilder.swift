//
//  UpaBatchBuilder.swift
//  ios-device-lib
//

import Foundation

public class UpaBatchBuilder {
    
    private var upaDevice: HpsUpaDevice
    
    init(with device: HpsUpaDevice) {
        upaDevice = device
    }
    
    public func execute(request: UpaGetBatchDetail, response: @escaping (IHPSDeviceResponse?, String?, Error?) -> Void) {
        let encoder = JSONEncoder()

        let json = try? encoder.encode(request)

        guard let json else { return }
        
        upaDevice.processTransaction(withJSONString: String(data: json, encoding: .utf8), withResponseBlock: response)
    }
}
