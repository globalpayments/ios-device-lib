import XCTest
@testable import ios_device_lib

final class UPABatchTests: XCTestCase {

    var device: HpsUpaDevice!
    
    override func setUp() {
        device = setupDevice(ipAddress: "192.168.1.2")
    }
    
    func setupDevice(ipAddress: String) -> HpsUpaDevice {
        let config = HpsConnectionConfig()
        config.username = ""
        config.password = ""
        config.licenseID = "";
        config.siteID = "";
        config.deviceID = "";
        config.ipAddress = ipAddress
        config.port = "8081"
        
        config.connectionMode = HpsConnectionModes.TCP_IP.rawValue
        config.timeout = 1000
        config.requestLogger = SampleRequestLogger()
        return HpsUpaDevice(config: config)
    }
    
    func testGetBatchDetails() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaBatchBuilder(with: device)
        let param = UpaBatchParam(batch: "1299477", reportOutput: "Print|ReturnData", reportType: "summary")
        let data = UpaBatchData(params: param)
        let commandData = UpaBatchCommandData(EcrId: "3", requestId: "541042233", data: data)
        let request = UpaGetBatchDetail(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testOpenTabDetailsReport() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaOpenTabBuilder(with: device)
        let commandData = UpaOpenTabCommandData(EcrId: "3", requestId: "541042234")
        let request = UpaOpenTabDetails(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
}
