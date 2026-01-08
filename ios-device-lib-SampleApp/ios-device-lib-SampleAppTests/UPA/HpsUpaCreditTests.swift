import XCTest
@testable import ios_device_lib

final class HpsUpaCreditTests: XCTestCase {

    var device: HpsUpaDevice!
    
    override func setUp() {
        device = setupDevice(ipAddress: "192.168.1.4")
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
    
    func testUPASaleVoidWithTerminalRefNumber() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        builder.amount = 1.00
        builder.gratuity = 0.00
        builder.ecrId = "1"
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Void
            guard let vbuilder = HpsUpaVoidBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            vbuilder.ecrId = "1"
            vbuilder.terminalRefNumber = payload?.terminalRefNumber
            
            vbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPASaleVoidWithTransactionId() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        builder.amount = 1.00
        builder.gratuity = 0.00
        builder.ecrId = "1"
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Void
            guard let vbuilder = HpsUpaVoidBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            vbuilder.ecrId = "1"
            vbuilder.transactionId = payload?.transactionId
            
            vbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    // Test that attempting to void a transaction without providing a terminal reference number
    // or transaction ID throws the expected GatewayException
    func testUPASaleVoidWithoutTransactionIdOrTerminalRefNumber() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let vbuilder = HpsUpaVoidBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        vbuilder.ecrId = "1"
        
        vbuilder.execute { vpayload, verror in
            XCTAssertNil(verror)
            XCTAssertEqual("NO TRANNO OR REFERENCENUMBER SUPPLIED", vpayload?.deviceResponseMessage)
            XCTAssertNotNil(vpayload)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPASaleReversal() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        builder.amount = 1.00
        builder.gratuity = 0.00
        builder.ecrId = "1"
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Reversal
            guard let rbuilder = HpsUpaReversalBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.terminalRefNumber = payload?.terminalRefNumber
            
            rbuilder.execute { rpayload, rerror in
                XCTAssertNil(rerror)
                XCTAssertEqual("00", rpayload?.responseCode)
                XCTAssertNotNil(rpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPASaleReversalInvalidTerminalRefNumber() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let rbuilder = HpsUpaReversalBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        rbuilder.ecrId = "1"
        rbuilder.terminalRefNumber = "1234"
        
        rbuilder.execute { rpayload, rerror in
            XCTAssertNil(rerror)
            XCTAssertEqual("TRANSACTION NOT FOUND", rpayload?.deviceResponseMessage);
            XCTAssertNotNil(rpayload)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPARefundVoidWithTerminalRefNumber() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        rbuilder.amount = 1.00
        rbuilder.ecrId = "1"
        
        rbuilder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Void
            guard let vbuilder = HpsUpaVoidBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            vbuilder.ecrId = "1"
            vbuilder.terminalRefNumber = payload?.terminalRefNumber
            
            vbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPARefundVoidTransactionId() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        rbuilder.amount = 1.00
        rbuilder.ecrId = "1"
        
        rbuilder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Void
            guard let vbuilder = HpsUpaVoidBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            vbuilder.ecrId = "1"
            vbuilder.transactionId = payload?.transactionId
            
            vbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testUPARefundwithZeroamount() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        rbuilder.amount = 0.00
        rbuilder.ecrId = "1"
        
        rbuilder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("TRANSACTION CANCELLED DUE TO INVALID BASE AMOUNT", payload?.deviceResponseMessage)
            XCTAssertNotNil(payload)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 120.0)
    }
}
