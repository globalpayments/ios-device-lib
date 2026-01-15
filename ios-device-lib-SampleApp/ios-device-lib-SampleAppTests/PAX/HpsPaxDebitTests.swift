//
//  HpsPaxDebitTests.swift
//  ios-device-lib-SampleAppTests
//

import XCTest

@testable import ios_device_lib

final class HpsPaxDebitTests: XCTestCase {

    var device: HpsPaxDevice?
    
    private func setupDevice() -> HpsPaxDevice? {
        let config = HpsConnectionConfig()
        config.username = ""
        config.password = ""
        config.developerID = ""
        config.versionNumber = ""
        config.licenseID = ""
        config.siteID = ""
        config.deviceID = ""
        config.sdkNameVersion = ""
        config.connectionMode = HpsConnectionModes.TCP_IP.rawValue
        return HpsPaxDevice(config: config)
    }
    
    func testPaxDebitSale() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        device = self.setupDevice()
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        guard let builder = HpsPaxDebitSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        
        builder.amount = 1.0
        builder.referenceNumber = 5
        builder.allowDuplicates = true
        
        builder.execute { response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("00", response?.responseCode)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1000)
    }
    
    func testPaxDebitReturn() {
        let expectation = XCTestExpectation(description: "Wait for execution...")
        
        device = self.setupDevice()
        guard let device = self.device else {
            XCTFail("Device is nil")
            return
        }
        guard let builder = HpsPaxDebitSaleBuilder(device: device) else {
            XCTFail("Builder is nil")
            return
        }
        
        builder.amount = 11.0
        builder.referenceNumber = 5
        builder.allowDuplicates = true
        
        builder.execute { response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("00", response?.responseCode)
            
            sleep(5)
            
            guard let abuilder = HpsPaxDebitReturnBuilder(device: device) else {
                XCTFail("Builder is nil")
                return
            }
            
            abuilder.amount = 10.0
            abuilder.execute { response, error in
                XCTAssertNil(error)
                XCTAssertNotNil(response)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1000)
    }
}
