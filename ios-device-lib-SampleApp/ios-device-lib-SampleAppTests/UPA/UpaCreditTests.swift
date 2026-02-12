import XCTest
@testable import ios_device_lib

final class UpaCreditTests: XCTestCase {

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

    // Test sale followed by a reference-based refund using the terminal reference to ensure the refund process works correctly with the original transaction reference.
    func testUpaSaleRefundWithReferenceNumber() {
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
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.transactionId = payload?.transactionId
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
    
    // Test sale followed by a reference-based refund using the TransIT reference to ensure the refund process works correctly with the original transaction reference.
    func testUpaSaleRefundWithBaseAmount() {
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
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.baseAmount = payload?.baseAmount
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
    
    func testUpaSaleRefundWithTipAmount() {
        let expectation = XCTestExpectation(description: "Wait for execution...")

        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }

        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        builder.amount = 10.00
        builder.gratuity = 2.50
        builder.ecrId = "1"
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.tipAmount = payload?.tipAmount
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
    
    func testUpaSaleRefundWithTaxAmount() {
        let expectation = XCTestExpectation(description: "Wait for execution...")

        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }

        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        builder.amount = 10.00
        builder.gratuity = 0.00
        builder.ecrId = "1"
        builder.taxAmount = 1.00
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.taxAmount = 1.00
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
    
    func testUpaSaleRefundWithSurchargeAmount() {
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
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.surchargeAmount = 1.00
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
    
    func testUpaSaleRefundWithInvoiceNbr() {
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
        
        let details = HpsTransactionDetails()
        details.invoiceNumber = "001234"
        builder.details = details;
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.details = details;
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
    
    func testUpaSaleRefundWithAllowDuplicate() {
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
        
        let details = HpsTransactionDetails()
        details.invoiceNumber = "001234"
        builder.details = details;
        
        builder.execute { payload, error in
            XCTAssertNil(error)
            XCTAssertEqual("00", payload?.responseCode)
            XCTAssertNotNil(payload)
            
            sleep(1)
            
            //Return
            guard let rbuilder = HpsUpaReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            rbuilder.ecrId = "1"
            rbuilder.amount = payload?.transactionAmount
            rbuilder.allowDuplicate = 1
            rbuilder.details = details;
            
            rbuilder.execute { vpayload, verror in
                XCTAssertNil(verror)
                XCTAssertEqual("00", vpayload?.responseCode)
                XCTAssertNotNil(vpayload)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 600.0)
    }
   
    func testUPAForceSale() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaForceSaleBuilder(upaDevice: device)
        let param = UpaForceSaleParam(clerkId: "1234")
        let transaction = UpaForceSaleTransaction(
            baseAmount: "12345.67",
            taxAmount: "1234.56",
            tipAmount: "1234.56",
            taxIndicator: "0",
            invoiceNbr: "123456789012345",
            allowDuplicate: "1"
        )
        let data = UpaForceSaleData(params: param, transaction: transaction)
        let commandData = UpaForceSaleCommandData(EcrId: "13", requestId: "122", data: data)
        let request = UpaForceSale(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1000.0)
    }

    func testUPAPhoneOrder() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        
        let builder = UpaPhoneOrderBuilder(upaDevice: device)
        let param = UpaPhoneOrderParam()
        let transaction = UpaPhoneOrderTransaction(
            baseAmount: "1.00",
            allowDuplicate: "1"
        )
        let data = UpaPhoneOrderData(params: param, transaction: transaction)
        let commandData = UpaPhoneOrderCommandData(EcrId: "13", requestId: "3", data: data)
        let request = UpaPhoneOrder(data: commandData)
        
        builder.execute(request: request) { payload, _, error in
            let response = payload as? HpsUpaResponse
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1000.0)
    }
}
