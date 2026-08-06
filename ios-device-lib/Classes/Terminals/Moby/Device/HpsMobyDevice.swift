import Foundation
import TemLibrary

@available(iOS 13.0, *)
@objcMembers
public class HpsMobyDevice: GMSDevice, IC2xDeviceInterface {
    
    let ruaHelper: RUAHelper = RUAHelper.sharedInstance
    
    var ruaDevice: RuaDevice?
    
    public init(config: HpsConnectionConfig, connectionInterface: RUACommunicationInterface? = nil) {
        super.init(
            config: config,
            entryModes: [
                .contact,
                .chipFallback,
                .contactless,
                .msr,
                .manual,
                .quickChip,
            ],
            terminalType: .ingenico_moby5500,
            connectionInterface: connectionInterface
        )
    }
    
    public func searchDevice(searchFinishBlock: @escaping ([RuaDevice]) -> Void) {
        self.deviceDelegate = ruaHelper
        self.scan()
    }
    
    public func printReceipt(response: HpsTerminalResponse, headerDetail: ReceiptHelperDetail) -> UIImage {
        return ReceiptHelper.createReceiptImage(transaction: response, headerDetail: headerDetail)
    }
}
