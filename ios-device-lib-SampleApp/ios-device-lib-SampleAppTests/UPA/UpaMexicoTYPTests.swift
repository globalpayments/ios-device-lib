import XCTest
@testable import ios_device_lib

// MARK: - Helpers

/// Encodes a Codable value to a JSON string.
private func encode<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}

final class UpaMexicoTYPTests: XCTestCase {

    private var device: HpsUpaDevice!

    override func setUp() {
        super.setUp()
        let config = HpsConnectionConfig()
        config.ipAddress = "192.168.71.118"
        config.port = "8081"
        config.timeout = 120
        config.connectionMode = HpsConnectionModes.TCP_IP.rawValue
        device = HpsUpaDevice(config: config)
    }

    override func tearDown() {
        super.tearDown()
        Thread.sleep(forTimeInterval: 3)
    }

    // MARK: - Sale: POSITIVE

    func test_Sale_WithTYP_FieldsAreMapped() throws {
        try requireTypMode("enabled")

        let expectation = XCTestExpectation(description: "Sale with TYP")

        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Could not create sale builder"); return
        }
        builder.ecrId = "13"
        builder.clerkId = "1234"
        builder.amount = NSDecimalNumber(string: "10.00")
        builder.gratuity = 0

        builder.execute{ response, _, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            XCTAssertEqual("00", response?.responseCode)
            XCTAssertNotNil(response?.redeemId, "redeemId missing")
            XCTAssertNotNil(response?.redeemStatus, "redeemStatus missing")
            XCTAssertNotNil(response?.currencyAmountRedeemed, "currencyAmountRedeemed missing")
            XCTAssertNotNil(response?.pointsRedeemed, "pointsRedeemed missing")
            XCTAssertNotNil(response?.discountAmountRedeemed, "discountAmountRedeemed missing")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 600)
    }

    // MARK: - Sale: NEGATIVE

    func test_Sale_WithoutTYP_FieldsAreNil() throws {
        try requireTypMode("disabled")

        let expectation = XCTestExpectation(description: "Sale without TYP")

        guard let builder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Could not create sale builder"); return
        }
        builder.ecrId = "13"
        builder.clerkId = "1234"
        builder.amount = NSDecimalNumber(string: "10.00")
        builder.gratuity = 0

        builder.execute{ response, _, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            XCTAssertEqual("00", response?.responseCode)
            XCTAssertNil(response?.redeemId, "redeemId should be nil when no TYP")
            XCTAssertNil(response?.redeemStatus, "redeemStatus should be nil when no TYP")
            XCTAssertNil(response?.currencyAmountRedeemed, "currencyAmountRedeemed should be nil when no TYP")
            XCTAssertNil(response?.pointsRedeemed, "pointsRedeemed should be nil when no TYP")
            XCTAssertNil(response?.discountAmountRedeemed, "discountAmountRedeemed should be nil when no TYP")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 600)
    }

    // MARK: - Void: POSITIVE

    func test_Void_WithTYP_FieldsAreMapped() throws {
        try requireTypMode("enabled")

        // Step 1: Sale
        let saleExpectation = XCTestExpectation(description: "Sale before void")
        var saleTransactionId: String?

        guard let saleBuilder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Could not create sale builder"); return
        }
        saleBuilder.ecrId = "13"
        saleBuilder.clerkId = "1234"
        saleBuilder.amount = NSDecimalNumber(string: "10.00")
        saleBuilder.gratuity = 0

        saleBuilder.execute{ response, _, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response?.transactionId)
            saleTransactionId = response?.transactionId
            saleExpectation.fulfill()
        }

        wait(for: [saleExpectation], timeout: 600)
        Thread.sleep(forTimeInterval: 10)

        // Step 2: Void
        let voidExpectation = XCTestExpectation(description: "Void with TYP")

        guard let voidBuilder = HpsUpaVoidBuilder(device: device) else {
            XCTFail("Could not create void builder"); return
        }
        voidBuilder.ecrId = "13"
        voidBuilder.transactionId = saleTransactionId

        voidBuilder.execute { response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            XCTAssertNotNil(response?.voidRedeemId, "voidRedeemId missing")
            XCTAssertNotNil(response?.voidRedeemStatus, "voidRedeemStatus missing")
            XCTAssertNotNil(response?.voidCurrencyAmountRedeemed, "voidCurrencyAmountRedeemed missing")
            XCTAssertNotNil(response?.voidPointsRedeemed, "voidPointsRedeemed missing")
            XCTAssertNotNil(response?.voidDiscountAmountRedeemed, "voidDiscountAmountRedeemed missing")
            XCTAssertEqual(response?.voidCurrencyAmountRedeemed, response?.voicCurrencyAmountRedeemed,
                           "voicCurrencyAmountRedeemed alias must equal voidCurrencyAmountRedeemed")
            voidExpectation.fulfill()
        }

        wait(for: [voidExpectation], timeout: 600)
    }

    // MARK: - Void: NEGATIVE

    func test_Void_WithoutTYP_FieldsAreNil() throws {
        try requireTypMode("disabled")

        // Step 1: Sale
        let saleExpectation = XCTestExpectation(description: "Sale before void")
        var saleTransactionId: String?

        guard let saleBuilder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Could not create sale builder"); return
        }
        saleBuilder.ecrId = "13"
        saleBuilder.clerkId = "1234"
        saleBuilder.amount = NSDecimalNumber(string: "10.00")
        saleBuilder.gratuity = 0

        saleBuilder.execute{ response, _, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response?.transactionId)
            saleTransactionId = response?.transactionId
            saleExpectation.fulfill()
        }

        wait(for: [saleExpectation], timeout: 600)
        Thread.sleep(forTimeInterval: 10)

        // Step 2: Void
        let voidExpectation = XCTestExpectation(description: "Void without TYP")

        guard let voidBuilder = HpsUpaVoidBuilder(device: device) else {
            XCTFail("Could not create void builder"); return
        }
        voidBuilder.ecrId = "13"
        voidBuilder.transactionId = saleTransactionId

        voidBuilder.execute { response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            XCTAssertNil(response?.voidRedeemId, "voidRedeemId should be nil when no TYP")
            XCTAssertNil(response?.voidRedeemStatus, "voidRedeemStatus should be nil when no TYP")
            XCTAssertNil(response?.voidCurrencyAmountRedeemed, "voidCurrencyAmountRedeemed should be nil when no TYP")
            XCTAssertNil(response?.voidPointsRedeemed, "voidPointsRedeemed should be nil when no TYP")
            XCTAssertNil(response?.voidDiscountAmountRedeemed, "voidDiscountAmountRedeemed should be nil when no TYP")
            XCTAssertNil(response?.voicCurrencyAmountRedeemed, "voicCurrencyAmountRedeemed alias should also be nil")
            voidExpectation.fulfill()
        }

        wait(for: [voidExpectation], timeout: 600)
    }

    // MARK: - Reversal: POSITIVE

    func test_Reversal_WithTYP_FieldsAreMapped() throws {
        try requireTypMode("enabled")

        // Step 1: Sale
        let saleExpectation = XCTestExpectation(description: "Sale before reversal")
        var saleTerminalRefNumber: String?

        guard let saleBuilder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Could not create sale builder"); return
        }
        saleBuilder.ecrId = "13"
        saleBuilder.clerkId = "1234"
        saleBuilder.amount = NSDecimalNumber(string: "10.00")
        saleBuilder.gratuity = 0

        saleBuilder.execute{ response, _, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response?.terminalRefNumber)
            saleTerminalRefNumber = response?.terminalRefNumber
            saleExpectation.fulfill()
        }

        wait(for: [saleExpectation], timeout: 600)
        Thread.sleep(forTimeInterval: 10)

        // Step 2: Reversal
        let reversalExpectation = XCTestExpectation(description: "Reversal with TYP")

        guard let reversalBuilder = HpsUpaReversalBuilder(device: device) else {
            XCTFail("Could not create reversal builder"); return
        }
        reversalBuilder.ecrId = "13"
        reversalBuilder.terminalRefNumber = saleTerminalRefNumber
        reversalBuilder.authorizedAmount  = NSDecimalNumber(string: "10.00")

        reversalBuilder.execute { response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            XCTAssertNotNil(response?.voidRedeemId, "voidRedeemId missing")
            XCTAssertNotNil(response?.voidRedeemStatus, "voidRedeemStatus missing")
            XCTAssertNotNil(response?.voidCurrencyAmountRedeemed, "voidCurrencyAmountRedeemed missing")
            XCTAssertNotNil(response?.voidPointsRedeemed, "voidPointsRedeemed missing")
            XCTAssertNotNil(response?.voidDiscountAmountRedeemed,"voidDiscountAmountRedeemed missing")
            reversalExpectation.fulfill()
        }

        wait(for: [reversalExpectation], timeout: 600)
    }

    // MARK: - Reversal: NEGATIVE

    func test_Reversal_WithoutTYP_FieldsAreNil() throws {
        try requireTypMode("disabled")

        // Step 1: Sale
        let saleExpectation = XCTestExpectation(description: "Sale before reversal")
        var saleTerminalRefNumber: String?

        guard let saleBuilder = HpsUpaSaleBuilder(device: device) else {
            XCTFail("Could not create sale builder"); return
        }
        saleBuilder.ecrId = "13"
        saleBuilder.clerkId = "1234"
        saleBuilder.amount = NSDecimalNumber(string: "10.00")
        saleBuilder.gratuity = 0

        saleBuilder.execute { response, _, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response?.terminalRefNumber)
            saleTerminalRefNumber = response?.terminalRefNumber
            saleExpectation.fulfill()
        }

        wait(for: [saleExpectation], timeout: 600)
        Thread.sleep(forTimeInterval: 10)

        // Step 2: Reversal
        let reversalExpectation = XCTestExpectation(description: "Reversal without TYP")

        guard let reversalBuilder = HpsUpaReversalBuilder(device: device) else {
            XCTFail("Could not create reversal builder"); return
        }
        reversalBuilder.ecrId = "13"
        reversalBuilder.terminalRefNumber = saleTerminalRefNumber
        reversalBuilder.authorizedAmount = NSDecimalNumber(string: "10.00")

        reversalBuilder.execute { response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(response)
            XCTAssertEqual("Success", response?.result)
            XCTAssertNil(response?.voidRedeemId, "voidRedeemId should be nil when no TYP")
            XCTAssertNil(response?.voidRedeemStatus, "voidRedeemStatus should be nil when no TYP")
            XCTAssertNil(response?.voidCurrencyAmountRedeemed, "voidCurrencyAmountRedeemed should be nil when no TYP")
            XCTAssertNil(response?.voidPointsRedeemed, "voidPointsRedeemed should be nil when no TYP")
            XCTAssertNil(response?.voidDiscountAmountRedeemed, "voidDiscountAmountRedeemed should be nil when no TYP")
            reversalExpectation.fulfill()
        }

        wait(for: [reversalExpectation], timeout: 600)
    }

    // MARK: - Summary Report: POSITIVE (with TYP params)

    func test_SummaryReport_WithTYP_ParamsEncoded() {
        let param = UpaBatchParam(
            reportOutput: "ReturnData",
            reportType: "summary",
            reportSubType: "1",
            bothReports: "0",
            clerkId: "12",
            previousBatchReport: "0"
        )
        let request = UpaGetBatchDetail(data: UpaBatchCommandData(
            EcrId: "13", requestId: "2001",
            data: UpaBatchData(params: param)
        ))

        guard let json = encode(request) else {
            XCTFail("Failed to encode summary report request"); return
        }

        XCTAssertTrue(json.contains("\"reportType\":\"summary\""),"reportType missing")
        XCTAssertTrue(json.contains("\"reportSubType\":\"1\""), "reportSubType missing")
        XCTAssertTrue(json.contains("\"bothReports\":\"0\""), "bothReports missing")
        XCTAssertTrue(json.contains("\"clerkId\":\"12\""), "clerkId missing")
        XCTAssertTrue(json.contains("\"previousBatchReport\":\"0\""), "previousBatchReport missing")
        XCTAssertTrue(json.contains("\"command\":\"GetBatchDetails\""), "command missing")
    }

    // MARK: - Summary Report: NEGATIVE (optional TYP params omitted)

    func test_SummaryReport_WithoutTYP_ParamsOmitted() {
        let param = UpaBatchParam(batch: "1009830", reportOutput: "ReturnData")
        let request = UpaGetBatchDetail(data: UpaBatchCommandData(
            EcrId: "13", requestId: "2003",
            data: UpaBatchData(params: param)
        ))

        guard let json = encode(request) else {
            XCTFail("Failed to encode minimal report request"); return
        }

        // Core fields must be present
        XCTAssertTrue(json.contains("\"command\":\"GetBatchDetails\""), "command missing")
        XCTAssertTrue(json.contains("\"batch\":\"1009830\""), "batch missing")

        // TYP-specific params must not appear when not supplied
        XCTAssertFalse(json.contains("\"reportSubType\""), "reportSubType should be absent")
        XCTAssertFalse(json.contains("\"bothReports\""), "bothReports should be absent")
        XCTAssertFalse(json.contains("\"clerkId\""), "clerkId should be absent")
        XCTAssertFalse(json.contains("\"previousBatchReport\""), "previousBatchReport should be absent")
    }

    // MARK: - Detail Report: POSITIVE (with TYP params)

    func test_DetailReport_WithTYP_ParamsEncoded() {
        let param = UpaBatchParam(
            reportOutput: "ReturnData",
            reportType: "detail",
            reportSubType: "2",
            bothReports: "1",
            clerkId: "99",
            previousBatchReport: "1"
        )
        let request = UpaGetBatchDetail(data: UpaBatchCommandData(
            EcrId: "13", requestId: "2002",
            data: UpaBatchData(params: param)
        ))

        guard let json = encode(request) else {
            XCTFail("Failed to encode detail report request"); return
        }

        XCTAssertTrue(json.contains("\"reportType\":\"detail\""), "reportType missing")
        XCTAssertTrue(json.contains("\"reportSubType\":\"2\""), "reportSubType missing")
        XCTAssertTrue(json.contains("\"bothReports\":\"1\""), "bothReports missing")
        XCTAssertTrue(json.contains("\"clerkId\":\"99\""), "clerkId missing")
        XCTAssertTrue(json.contains("\"previousBatchReport\":\"1\""), "previousBatchReport missing")
        XCTAssertTrue(json.contains("\"command\":\"GetBatchDetails\""), "command missing")
    }

    // MARK: - Detail Report: NEGATIVE (all optional TYP params explicitly nil)

    func test_DetailReport_WithoutTYP_ParamsOmitted() {
       
        let param = UpaBatchParam(
            batch: "1009830",
            reportOutput: "ReturnData",
            reportType: nil,
            reportSubType: nil,
            bothReports: nil,
            clerkId: nil,
            previousBatchReport: nil
        )
        let request = UpaGetBatchDetail(data: UpaBatchCommandData(
            EcrId: "13", requestId: "2004",
            data: UpaBatchData(params: param)
        ))

        guard let json = encode(request) else {
            XCTFail("Failed to encode detail report request with nil TYP params"); return
        }

        XCTAssertTrue(json.contains("\"command\":\"GetBatchDetails\""), "command missing")
        XCTAssertTrue(json.contains("\"batch\":\"1009830\""), "batch missing")

        // TYP-specific params must not appear when nil
        XCTAssertFalse(json.contains("\"reportSubType\""), "reportSubType should be absent")
        XCTAssertFalse(json.contains("\"bothReports\""), "bothReports should be absent")
        XCTAssertFalse(json.contains("\"clerkId\""), "clerkId should be absent")
        XCTAssertFalse(json.contains("\"previousBatchReport\""), "previousBatchReport should be absent")
    }

    // MARK: - Private Helpers

    /// Skips the test if UPA_TYP_MODE env var is not set or does not match expectedMode.
    /// Set UPA_TYP_MODE=enabled for positive TYP tests, UPA_TYP_MODE=disabled for negative.
    private func requireTypMode(_ expectedMode: String) throws {
        let mode = ProcessInfo.processInfo.environment["UPA_TYP_MODE"]?.lowercased() ?? ""
        guard ["enabled", "disabled"].contains(mode) else {
            throw XCTSkip("Set UPA_TYP_MODE=enabled or UPA_TYP_MODE=disabled for deterministic TYP assertions.")
        }
        guard mode == expectedMode else {
            throw XCTSkip("Skipping: requires UPA_TYP_MODE=\(expectedMode), current=\(mode).")
        }
    }
}
