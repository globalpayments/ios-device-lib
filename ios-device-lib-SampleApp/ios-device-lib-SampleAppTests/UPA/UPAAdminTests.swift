import XCTest
@testable import ios_device_lib

final class UPAAdminTests: XCTestCase {
    
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
        return HpsUpaDevice(config: config)
    }
    
    func testUpaCancel() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.cancel { payload in
            let response = payload as? HpsUpaResponse
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUpaPing() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.upaPing { payload in
            let response = payload as? HpsUpaResponse
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUpaPingFail() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.upaPing { payload in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(response)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testAppRestart() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.upaAppRestart { payload in
            let response = payload as? HpsUpaResponse
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testRebootDevice() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.upaRebootDevice { payload in
            let response = payload as? HpsUpaResponse
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPALineItemWithLeft() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.lineItem("Toothpaste") { payload, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testUPALineItemWithLeftAndRight() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.lineItem("Toothpaste", withRightText: "10") { payload, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testUPAScan() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaScanBuilder(upaDevice: device)
        let param = UpaScanParam(header: "SCAN",
                                    prompt1: "SCAN QR CODE",
                                    prompt2: "ALIGN THE QR CODE WITHIN THE FRAME TO SCAN")
        let data = UpaScanData(params: param)
        let commandData = UpaCommandData(EcrId: "12", requestId: "132", data: data)
        let request = UpaScan(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPAScanWithTimeOut() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaScanBuilder(upaDevice: device)
        let param = UpaScanParam(header: "SCAN",
                                    prompt1: "SCAN QR CODE",
                                    prompt2: "ALIGN THE QR CODE WITHIN THE FRAME TO SCAN")
        let data = UpaScanData(params: param)
        let commandData = UpaCommandData(EcrId: "12", requestId: "132", timeOut: 180.0, data: data)
        let request = UpaScan(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testUPAScanWithDisplayOption() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaScanBuilder(upaDevice: device)
        let param = UpaScanParam(header: "SCAN",
                                    prompt1: "SCAN QR CODE",
                                    prompt2: "ALIGN THE QR CODE WITHIN THE FRAME TO SCAN",
                                    displayOption: DisplayOption.NO_SCREEN_CHANGE)
        let data = UpaScanData(params: param)
        let commandData = UpaCommandData(EcrId: "12", requestId: "132", data: data)
        let request = UpaScan(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testGetSignature() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        device.getSignatureData("1234", andRequestId: "1234") { responseSignature, error in
            XCTAssertNil(error)
            XCTAssertNotNil(responseSignature)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
}
