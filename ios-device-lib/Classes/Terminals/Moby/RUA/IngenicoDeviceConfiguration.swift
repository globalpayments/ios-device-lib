//
//  IngenicoDeviceConfiguration.swift
//  ios-device-lib
//

import Foundation

// MARK: - RUAMobyDeviceType Enum

public enum RUAMobyDeviceType: Int {
    case MOBY3000  = 0
    case RP450c    = 1
    case RP750x    = 2
    case RP45BT    = 3
    case MOBY8500  = 4
    case MOBY6500  = 5
    case MOBY5500  = 6
    case unknown   = 7
}

// MARK: - IngenicoDeviceConfiguration

public class IngenicoDeviceConfiguration: NSObject {

    // MARK: - Public Properties

    public var currentPublicKeyIndex: Int32 = 0
    public var initialized: Bool = false
    public var connectedDeviceSerialNumber: String = ""
    public var productionMode: Bool = false

    public var publicKeyList: [Any] = []
    public var amountDOL: [Any] = []
    public var onlineDOL: [Any] = []
    public var responseDOL: [Any] = []
    public var aidsList: [Any] = []
    public var contactlessAIDsList: [Any] = []
    public var contactlessAIDsResponseList: [Any] = []
    public var contactlessResponseDOL: [Any] = []
    public var contactlessOnlineDOL: [Any] = []
    public var magStripeDOLList: [Any] = []

    // MARK: - Initializer

    public init(productionMode: Bool, deviceType: RUAMobyDeviceType) {
        super.init()
        self.productionMode = productionMode
        _ = loadDictionaryFromJSON()
        _ = fetchAndStoreJSON()

        // Public Keys
        if deviceType == .MOBY5500 {
            publicKeyList = getPublicKeysList()
        } else {
            publicKeyList = productionMode ? generateProdPublicKeyList() : generateTestPublicKeyList()
        }

        currentPublicKeyIndex = 0

        // DOLs and AIDs
        if deviceType == .MOBY5500 {
            amountDOL           = getAmountDolsList()
            aidsList            = getAIDsList()
            onlineDOL           = getOnlineDolsList()
            responseDOL         = getResponseDolsList()
            contactlessOnlineDOL   = getContactlessOnlineDolsList()
            contactlessAIDsList    = getContactlessAIDsList()
            contactlessResponseDOL = getContactlessResponseDolsList()
            magStripeDOLList    = getMagStripeDolsList()
        } else {
            amountDOL  = generateAmountDOL()
            aidsList   = generateAidsList()
            onlineDOL  = generateOnlineDOL()
            responseDOL = generateResponseDOL()
        }
    }

    // MARK: - DOL Generators

    private func generateOnlineDOL() -> [NSNumber] {
        return [
            NSNumber(value: RUAParameter.additionalTerminalCapabilities.rawValue),    // 9F40
            NSNumber(value: RUAParameter.amountAuthorizedNumeric.rawValue),           // 9F02
            NSNumber(value: RUAParameter.amountOtherNumeric.rawValue),                // 9F03
            NSNumber(value: RUAParameter.applicationCryptogram.rawValue),             // 9F26
            NSNumber(value: RUAParameter.applicationIdentifier.rawValue),             // 4F
            NSNumber(value: RUAParameter.applicationInterchangeProfile.rawValue),     // 82
            NSNumber(value: RUAParameter.applicationLabel.rawValue),                  // 50
            NSNumber(value: RUAParameter.applicationPriorityIndicator.rawValue),
            NSNumber(value: RUAParameter.applicationTransactionCounter.rawValue),
            NSNumber(value: RUAParameter.applicationUsageControl.rawValue),
            NSNumber(value: RUAParameter.applicationVersionNumber.rawValue),
            NSNumber(value: RUAParameter.cardholderVerificationMethodResult.rawValue),
            NSNumber(value: RUAParameter.cryptogramInformationData.rawValue),         // 9F27
            NSNumber(value: RUAParameter.dedicatedFileName.rawValue),
            NSNumber(value: RUAParameter.interfaceDeviceSerialNumber.rawValue),
            NSNumber(value: RUAParameter.issuerActionCodeDefault.rawValue),
            NSNumber(value: RUAParameter.issuerActionCodeDenial.rawValue),
            NSNumber(value: RUAParameter.issuerActionCodeOnline.rawValue),
            NSNumber(value: RUAParameter.issuerApplicationData.rawValue),
            NSNumber(value: RUAParameter.issuerCountryCode.rawValue),
            NSNumber(value: RUAParameter.PAN.rawValue),                               // 5A
            NSNumber(value: RUAParameter.panSequenceNumber.rawValue),                 // 5F34
            NSNumber(value: RUAParameter.posEntryMode.rawValue),                      // 9F39
            NSNumber(value: RUAParameter.terminalApplicationIdentifier.rawValue),
            NSNumber(value: RUAParameter.terminalApplicationVersionNumber.rawValue),
            NSNumber(value: RUAParameter.terminalCapabilities.rawValue),              // 9F33
            NSNumber(value: RUAParameter.terminalCountryCode.rawValue),               // 9F1A
            NSNumber(value: RUAParameter.terminalType.rawValue),                      // 9F35
            NSNumber(value: RUAParameter.terminalVerificationResults.rawValue),       // 95
            NSNumber(value: RUAParameter.track2EquivalentData.rawValue),              // 57
            NSNumber(value: RUAParameter.transactionCategoryCode.rawValue),
            NSNumber(value: RUAParameter.transactionCurrencyCode.rawValue),           // 5F2A
            NSNumber(value: RUAParameter.transactionDate.rawValue),                   // 9A
            NSNumber(value: RUAParameter.transactionSequenceCounter.rawValue),
            NSNumber(value: RUAParameter.transactionStatusInformation.rawValue),      // 9B
            NSNumber(value: RUAParameter.transactionTime.rawValue),
            NSNumber(value: RUAParameter.transactionType.rawValue),                   // 9C
            NSNumber(value: RUAParameter.unpredictableNumber.rawValue),
        ]
    }

    private func generateAmountDOL() -> [NSNumber] {
        return [
            NSNumber(value: RUAParameter.applicationIdentifier.rawValue),             // 4F
            NSNumber(value: RUAParameter.applicationLabel.rawValue),                  // 50
            NSNumber(value: RUAParameter.track2EquivalentData.rawValue),              // 57
            NSNumber(value: RUAParameter.PAN.rawValue),                               // 5A
            NSNumber(value: RUAParameter.terminalApplicationIdentifier.rawValue),     // 9F06
            NSNumber(value: RUAParameter.posEntryMode.rawValue),                      // 9F39
            NSNumber(value: RUAParameter.applicationPriorityIndicator.rawValue),      // 87
            NSNumber(value: RUAParameter.panSequenceNumber.rawValue),                 // 5F34
            NSNumber(value: RUAParameter.amountAuthorizedNumeric.rawValue),           // 9F02
            NSNumber(value: RUAParameter.applicationPreferredName.rawValue),          // 9F12
            NSNumber(value: RUAParameter.applicationTransactionCounter.rawValue),     // 9F36
            NSNumber(value: RUAParameter.applicationEffectiveDate.rawValue),          // EF25
            NSNumber(value: RUAParameter.applicationExpirationDate.rawValue),         // EF24
        ]
    }

    private func generateResponseDOL() -> [NSNumber] {
        return [
            NSNumber(value: RUAParameter.applicationIdentifier.rawValue),             // 4F
            NSNumber(value: RUAParameter.applicationLabel.rawValue),                  // 50
            NSNumber(value: RUAParameter.track2EquivalentData.rawValue),              // 57
            NSNumber(value: RUAParameter.PAN.rawValue),                               // 5A
            NSNumber(value: RUAParameter.applicationInterchangeProfile.rawValue),     // 82
            NSNumber(value: RUAParameter.dedicatedFileName.rawValue),                 // 84
            NSNumber(value: RUAParameter.applicationPriorityIndicator.rawValue),      // 87
            NSNumber(value: RUAParameter.terminalVerificationResults.rawValue),       // 95
            NSNumber(value: RUAParameter.transactionStatusInformation.rawValue),      // 9B
            NSNumber(value: RUAParameter.transactionDate.rawValue),                   // 9A
            NSNumber(value: RUAParameter.transactionType.rawValue),                   // 9C
            NSNumber(value: RUAParameter.cardHolderName.rawValue),                    // 5F20
            NSNumber(value: RUAParameter.applicationExpirationDate.rawValue),         // 5F24
            NSNumber(value: RUAParameter.applicationEffectiveDate.rawValue),          // 5F25
            NSNumber(value: RUAParameter.issuerCountryCode.rawValue),                 // 5F28
            NSNumber(value: RUAParameter.transactionCurrencyCode.rawValue),           // 5F2A
            NSNumber(value: RUAParameter.panSequenceNumber.rawValue),                 // 5F34
            NSNumber(value: RUAParameter.amountAuthorizedNumeric.rawValue),           // 9F02
            NSNumber(value: RUAParameter.amountOtherNumeric.rawValue),                // 9F03
            NSNumber(value: RUAParameter.terminalApplicationIdentifier.rawValue),     // 9F06
            NSNumber(value: RUAParameter.applicationUsageControl.rawValue),           // 9F07
            NSNumber(value: RUAParameter.applicationVersionNumber.rawValue),          // 9F08
            NSNumber(value: RUAParameter.issuerActionCodeDefault.rawValue),           // 9F0D
            NSNumber(value: RUAParameter.issuerActionCodeDenial.rawValue),            // 9F0E
            NSNumber(value: RUAParameter.issuerActionCodeOnline.rawValue),            // 9F0F
            NSNumber(value: RUAParameter.issuerApplicationData.rawValue),             // 9F10
            NSNumber(value: RUAParameter.applicationPreferredName.rawValue),          // 9F12
            NSNumber(value: RUAParameter.terminalCountryCode.rawValue),               // 9F1A
            NSNumber(value: RUAParameter.interfaceDeviceSerialNumber.rawValue),       // 9F1E
            NSNumber(value: RUAParameter.applicationCryptogram.rawValue),             // 9F26
            NSNumber(value: RUAParameter.cryptogramInformationData.rawValue),         // 9F27
            NSNumber(value: RUAParameter.terminalCapabilities.rawValue),              // 9F33
            NSNumber(value: RUAParameter.cardholderVerificationMethodResult.rawValue),// 9F34
            NSNumber(value: RUAParameter.terminalType.rawValue),                      // 9F35
            NSNumber(value: RUAParameter.applicationTransactionCounter.rawValue),     // 9F36
            NSNumber(value: RUAParameter.unpredictableNumber.rawValue),               // 9F37
            NSNumber(value: RUAParameter.posEntryMode.rawValue),                      // 9F39
            NSNumber(value: RUAParameter.additionalTerminalCapabilities.rawValue),    // 9F40
            NSNumber(value: RUAParameter.transactionSequenceCounter.rawValue),        // 9F41
            NSNumber(value: RUAParameter.transactionCategoryCode.rawValue),           // 9F53
            NSNumber(value: RUAParameter.cvmouTresult.rawValue),                      // DF38
        ]
    }

    // MARK: - Public Key Lists

    private func generateProdPublicKeyList() -> [RUAPublicKey] {
        return [
            RUAPublicKey(rid: "A000000003", withCAPublicKeyIndex: "08", withPublicKey: "D9FD6ED75D51D0E30664BD157023EAA1FFA871E4DA65672B863D255E81E137A51DE4F72BCC9E44ACE12127F87E263D3AF9DD9CF35CA4A7B01E907000BA85D24954C2FCA3074825DDD4C0C8F186CB020F683E02F2DEAD3969133F06F7845166ACEB57CA0FC2603445469811D293BFEFBAFAB57631B3DD91E796BF850A25012F1AE38F05AA5C4D6D03B1DC2E568612785938BBC9B3CD3A910C1DA55A5A9218ACE0F7A21287752682F15832A678D6E1ED0B", withExponentOfPublicKey: "03", withChecksum: "20D213126955DE205ADC2FD2822BD22DE21CF9A8"),
            RUAPublicKey(rid: "A000000003", withCAPublicKeyIndex: "09", withPublicKey: "9D912248DE0A4E39C1A7DDE3F6D2588992C1A4095AFBD1824D1BA74847F2BC4926D2EFD904B4B54954CD189A54C5D1179654F8F9B0D2AB5F0357EB642FEDA95D3912C6576945FAB897E7062CAA44A4AA06B8FE6E3DBA18AF6AE3738E30429EE9BE03427C9D64F695FA8CAB4BFE376853EA34AD1D76BFCAD15908C077FFE6DC5521ECEF5D278A96E26F57359FFAEDA19434B937F1AD999DC5C41EB11935B44C18100E857F431A4A5A6BB65114F174C2D7B59FDF237D6BB1DD0916E644D709DED56481477C75D95CDD68254615F7740EC07F330AC5D67BCD75BF23D28A140826C026DBDE971A37CD3EF9B8DF644AC385010501EFC6509D7A41", withExponentOfPublicKey: "03", withChecksum: "1FF80A40173F52D7D27E0F26A146A1C8CCB29046"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "05", withPublicKey: "B8048ABC30C90D976336543E3FD7091C8FE4800DF820ED55E7E94813ED00555B573FECA3D84AF6131A651D66CFF4284FB13B635EDD0EE40176D8BF04B7FD1C7BACF9AC7327DFAA8AA72D10DB3B8E70B2DDD811CB4196525EA386ACC33C0D9D4575916469C4E4F53E8E1C912CC618CB22DDE7C3568E90022E6BBA770202E4522A2DD623D180E215BD1D1507FE3DC90CA310D27B3EFCCD8F83DE3052CAD1E48938C68D095AAC91B5F37E28BB49EC7ED597", withExponentOfPublicKey: "03", withChecksum: "EBFA0D5D06D8CE702DA3EAE890701D45E274C845"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "06", withPublicKey: "CB26FC830B43785B2BCE37C81ED334622F9622F4C89AAE641046B2353433883F307FB7C974162DA72F7A4EC75D9D657336865B8D3023D3D645667625C9A07A6B7A137CF0C64198AE38FC238006FB2603F41F4F3BB9DA1347270F2F5D8C606E420958C5F7D50A71DE30142F70DE468889B5E3A08695B938A50FC980393A9CBCE44AD2D64F630BB33AD3F5F5FD495D31F37818C1D94071342E07F1BEC2194F6035BA5DED3936500EB82DFDA6E8AFB655B1EF3D0D7EBF86B66DD9F29F6B1D324FE8B26CE38AB2013DD13F611E7A594D675C4432350EA244CC34F3873CBA06592987A1D7E852ADC22EF5A2EE28132031E48F74037E3B34AB747F", withExponentOfPublicKey: "03", withChecksum: "F910A1504D5FFB793D94F3B500765E1ABCAD72D9"),
            RUAPublicKey(rid: "A000000025", withCAPublicKeyIndex: "0F", withPublicKey: "C8D5AC27A5E1FB89978C7C6479AF993AB3800EB243996FBB2AE26B67B23AC482C4B746005A51AFA7D2D83E894F591A2357B30F85B85627FF15DA12290F70F05766552BA11AD34B7109FA49DE29DCB0109670875A17EA95549E92347B948AA1F045756DE56B707E3863E59A6CBE99C1272EF65FB66CBB4CFF070F36029DD76218B21242645B51CA752AF37E70BE1A84FF31079DC0048E928883EC4FADD497A719385C2BBBEBC5A66AA5E5655D18034EC5", withExponentOfPublicKey: "03", withChecksum: "A73472B3AB557493A9BC2179CC8014053B12BAB4"),
            RUAPublicKey(rid: "A000000025", withCAPublicKeyIndex: "10", withPublicKey: "CF98DFEDB3D3727965EE7797723355E0751C81D2D3DF4D18EBAB9FB9D49F38C8C4A826B99DC9DEA3F01043D4BF22AC3550E2962A59639B1332156422F788B9C16D40135EFD1BA94147750575E636B6EBC618734C91C1D1BF3EDC2A46A43901668E0FFC136774080E888044F6A1E65DC9AAA8928DACBEB0DB55EA3514686C6A732CEF55EE27CF877F110652694A0E3484C855D882AE191674E25C296205BBB599455176FDD7BBC549F27BA5FE35336F7E29E68D783973199436633C67EE5A680F05160ED12D1665EC83D1997F10FD05BBDBF9433E8F797AEE3E9F02A34228ACE927ABE62B8B9281AD08D3DF5C7379685045D7BA5FCDE58637", withExponentOfPublicKey: "03", withChecksum: "C729CF2FD262394ABC4CC173506502446AA9B9FD"),
            RUAPublicKey(rid: "A000000065", withCAPublicKeyIndex: "12", withPublicKey: "ADF05CD4C5B490B087C3467B0F3043750438848461288BFEFD6198DD576DC3AD7A7CFA07DBA128C247A8EAB30DC3A30B02FCD7F1C8167965463626FEFF8AB1AA61A4B9AEF09EE12B009842A1ABA01ADB4A2B170668781EC92B60F605FD12B2B2A6F1FE734BE510F60DC5D189E401451B62B4E06851EC20EBFF4522AACC2E9CDC89BC5D8CDE5D633CFD77220FF6BBD4A9B441473CC3C6FEFC8D13E57C3DE97E1269FA19F655215B23563ED1D1860D8681", withExponentOfPublicKey: "03", withChecksum: "874B379B7F607DC1CAF87A19E400B6A9E25163E8"),
            RUAPublicKey(rid: "A000000065", withCAPublicKeyIndex: "14", withPublicKey: "AEED55B9EE00E1ECEB045F61D2DA9A66AB637B43FB5CDBDB22A2FBB25BE061E937E38244EE5132F530144A3F268907D8FD648863F5A96FED7E42089E93457ADC0E1BC89C58A0DB72675FBC47FEE9FF33C16ADE6D341936B06B6A6F5EF6F66A4EDD981DF75DA8399C3053F430ECA342437C23AF423A211AC9F58EAF09B0F837DE9D86C7109DB1646561AA5AF0289AF5514AC64BC2D9D36A179BB8A7971E2BFA03A9E4B847FD3D63524D43A0E8003547B94A8A75E519DF3177D0A60BC0B4BAB1EA59A2CBB4D2D62354E926E9C7D3BE4181E81BA60F8285A896D17DA8C3242481B6C405769A39D547C74ED9FF95A70A796046B5EFF36682DC29", withExponentOfPublicKey: "03", withChecksum: "C0D15F6CD957E491DB56DCDD1CA87A03EBE06B7B"),
            RUAPublicKey(rid: "A000000152", withCAPublicKeyIndex: "04", withPublicKey: "8EEEC0D6D3857FD558285E49B623B109E6774E06E9476FE1B2FB273685B5A235E955810ADDB5CDCC2CB6E1A97A07089D7FDE0A548BDC622145CA2DE3C73D6B14F284B3DC1FA056FC0FB2818BCD7C852F0C97963169F01483CE1A63F0BF899D412AB67C5BBDC8B4F6FB9ABB57E95125363DBD8F5EBAA9B74ADB93202050341833DEE8E38D28BD175C83A6EA720C262682BEABEA8E955FE67BD9C2EFF7CB9A9F45DD5BDA4A1EEFB148BC44FFF68D9329FD", withExponentOfPublicKey: "03", withChecksum: "17F971CAF6B708E5B9165331FBA91593D0C0BF66"),
            RUAPublicKey(rid: "A000000152", withCAPublicKeyIndex: "05", withPublicKey: "E1200E9F4428EB71A526D6BB44C957F18F27B20BACE978061CCEF23532DBEBFAF654A149701C14E6A2A7C2ECAC4C92135BE3E9258331DDB0967C3D1D375B996F25B77811CCCC06A153B4CE6990A51A0258EA8437EDBEB701CB1F335993E3F48458BC1194BAD29BF683D5F3ECB984E31B7B9D2F6D947B39DEDE0279EE45B47F2F3D4EEEF93F9261F8F5A571AFBFB569C150370A78F6683D687CB677777B2E7ABEFCFC8F5F93501736997E8310EE0FD87AFAC5DA772BA277F88B44459FCA563555017CD0D66771437F8B6608AA1A665F88D846403E4C41AFEEDB9729C2B2511CFE228B50C1B152B2A60BBF61D8913E086210023A3AA499E423", withExponentOfPublicKey: "03", withChecksum: "12BCD407B6E627A750FDF629EE8C2C9CC7BA636A"),
            RUAPublicKey(rid: "A000000333", withCAPublicKeyIndex: "02", withPublicKey: "A3767ABD1B6AA69D7F3FBF28C092DE9ED1E658BA5F0909AF7A1CCD907373B7210FDEB16287BA8E78E1529F443976FD27F991EC67D95E5F4E96B127CAB2396A94D6E45CDA44CA4C4867570D6B07542F8D4BF9FF97975DB9891515E66F525D2B3CBEB6D662BFB6C3F338E93B02142BFC44173A3764C56AADD202075B26DC2F9F7D7AE74BD7D00FD05EE430032663D27A57", withExponentOfPublicKey: "03", withChecksum: "03BB335A8549A03B87AB089D006F60852E4B8060"),
            RUAPublicKey(rid: "A000000333", withCAPublicKeyIndex: "03", withPublicKey: "B0627DEE87864F9C18C13B9A1F025448BF13C58380C91F4CEBA9F9BCB214FF8414E9B59D6ABA10F941C7331768F47B2127907D857FA39AAF8CE02045DD01619D689EE731C551159BE7EB2D51A372FF56B556E5CB2FDE36E23073A44CA215D6C26CA68847B388E39520E0026E62294B557D6470440CA0AEFC9438C923AEC9B2098D6D3A1AF5E8B1DE36F4B53040109D89B77CAFAF70C26C601ABDF59EEC0FDC8A99089140CD2E817E335175B03B7AA33D", withExponentOfPublicKey: "03", withChecksum: "87F0CD7C0E86F38F89A66F8C47071A8B88586F26"),
            RUAPublicKey(rid: "A000000333", withCAPublicKeyIndex: "04", withPublicKey: "BC853E6B5365E89E7EE9317C94B02D0ABB0DBD91C05A224A2554AA29ED9FCB9D86EB9CCBB322A57811F86188AAC7351C72BD9EF196C5A01ACEF7A4EB0D2AD63D9E6AC2E7836547CB1595C68BCBAFD0F6728760F3A7CA7B97301B7E0220184EFC4F653008D93CE098C0D93B45201096D1ADFF4CF1F9FC02AF759DA27CD6DFD6D789B099F16F378B6100334E63F3D35F3251A5EC78693731F5233519CDB380F5AB8C0F02728E91D469ABD0EAE0D93B1CC66CE127B29C7D77441A49D09FCA5D6D9762FC74C31BB506C8BAE3C79AD6C2578775B95956B5370D1D0519E37906B384736233251E8F09AD79DFBE2C6ABFADAC8E4D8624318C27DAF1", withExponentOfPublicKey: "03", withChecksum: "F527081CF371DD7E1FD4FA414A665036E0F5E6E5"),
        ]
    }

    private func generateTestPublicKeyList() -> [RUAPublicKey] {
        return [
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "FE", withPublicKey: "A653EAC1C0F786C8724F737F172997D63D1C3251C44402049B865BAE877D0F398CBFBE8A6035E24AFA086BEFDE9351E54B95708EE672F0968BCD50DCE40F783322B2ABA04EF137EF18ABF03C7DBC5813AEAEF3AA7797BA15DF7D5BA1CBAF7FD520B5A482D8D3FEE105077871113E23A49AF3926554A70FE10ED728CF793B62A1", withExponentOfPublicKey: "03", withChecksum: "9A295B05FB390EF7923F57618A9FDA2941FC34E0"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "F3", withPublicKey: "98F0C770F23864C2E766DF02D1E833DFF4FFE92D696E1642F0A88C5694C6479D16DB1537BFE29E4FDC6E6E8AFD1B0EB7EA0124723C333179BF19E93F10658B2F776E829E87DAEDA9C94A8B3382199A350C077977C97AFF08FD11310AC950A72C3CA5002EF513FCCC286E646E3C5387535D509514B3B326E1234F9CB48C36DDD44B416D23654034A66F403BA511C5EFA3", withExponentOfPublicKey: "03", withChecksum: "A69AC7603DAF566E972DEDC2CB433E07E8B01A9A"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "FA", withPublicKey: "A90FCD55AA2D5D9963E35ED0F440177699832F49C6BAB15CDAE5794BE93F934D4462D5D12762E48C38BA83D8445DEAA74195A301A102B2F114EADA0D180EE5E7A5C73E0C4E11F67A43DDAB5D55683B1474CC0627F44B8D3088A492FFAADAD4F42422D0E7013536C3C49AD3D0FAE96459B0F6B1B6056538A3D6D44640F94467B108867DEC40FAAECD740C00E2B7A8852D", withExponentOfPublicKey: "03", withChecksum: "5BED4068D96EA16D2D77E03D6036FC7A160EA99C"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "F1", withPublicKey: "A0DCF4BDE19C3546B4B6F0414D174DDE294AABBB828C5A834D73AAE27C99B0B053A90278007239B6459FF0BBCD7B4B9C6C50AC02CE91368DA1BD21AAEADBC65347337D89B68F5C99A09D05BE02DD1F8C5BA20E2F13FB2A27C41D3F85CAD5CF6668E75851EC66EDBF98851FD4E42C44C1D59F5984703B27D5B9F21B8FA0D93279FBBF69E090642909C9EA27F898959541AA6757F5F624104F6E1D3A9532F2A6E51515AEAD1B43B3D7835088A2FAFA7BE7", withExponentOfPublicKey: "03", withChecksum: "D8E68DA167AB5A85D8C3D55ECB9B0517A1A5B4BB"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "EF", withPublicKey: "A191CB87473F29349B5D60A88B3EAEE0973AA6F1A082F358D849FDDFF9C091F899EDA9792CAF09EF28F5D22404B88A2293EEBBC1949C43BEA4D60CFD879A1539544E09E0F09F60F065B2BF2A13ECC705F3D468B9D33AE77AD9D3F19CA40F23DCF5EB7C04DC8F69EBA565B1EBCB4686CD274785530FF6F6E9EE43AA43FDB02CE00DAEC15C7B8FD6A9B394BABA419D3F6DC85E16569BE8E76989688EFEA2DF22FF7D35C043338DEAA982A02B866DE5328519EBBCD6F03CDD686673847F84DB651AB86C28CF1462562C577B853564A290C8556D818531268D25CC98A4CC6A0BDFFFDA2DCCA3A94C998559E307FDDF915006D9A987B07DDAEB3B", withExponentOfPublicKey: "03", withChecksum: "21766EBB0EE122AFB65D7845B73DB46BAB65427A"),
            RUAPublicKey(rid: "A000000004", withCAPublicKeyIndex: "F8", withPublicKey: "A1F5E1C9BD8650BD43AB6EE56B891EF7459C0A24FA84F9127D1A6C79D4930F6DB1852E2510F18B61CD354DB83A356BD190B88AB8DF04284D02A4204A7B6CB7C5551977A9B36379CA3DE1A08E69F301C95CC1C20506959275F41723DD5D2925290579E5A95B0DF6323FC8E9273D6F849198C4996209166D9BFC973C361CC826E1", withExponentOfPublicKey: "03", withChecksum: "F06ECC6D2AAEBF259B7E755A38D9A9B24E2FF3DD"),
            RUAPublicKey(rid: "A000000025", withCAPublicKeyIndex: "C9", withPublicKey: "B362DB5733C15B8797B8ECEE55CB1A371F760E0BEDD3715BB270424FD4EA26062C38C3F4AAA3732A83D36EA8E9602F6683EECC6BAFF63DD2D49014BDE4D6D603CD744206B05B4BAD0C64C63AB3976B5C8CAAF8539549F5921C0B700D5B0F83C4E7E946068BAAAB5463544DB18C63801118F2182EFCC8A1E85E53C2A7AE839A5C6A3CABE73762B70D170AB64AFC6CA482944902611FB0061E09A67ACB77E493D998A0CCF93D81A4F6C0DC6B7DF22E62DB", withExponentOfPublicKey: "03", withChecksum: "8E8DFF443D78CD91DE88821D70C98F0638E51E49"),
            RUAPublicKey(rid: "A000000025", withCAPublicKeyIndex: "CA", withPublicKey: "C23ECBD7119F479C2EE546C123A585D697A7D10B55C2D28BEF0D299C01DC65420A03FE5227ECDECB8025FBC86EEBC1935298C1753AB849936749719591758C315FA150400789BB14FADD6EAE2AD617DA38163199D1BAD5D3F8F6A7A20AEF420ADFE2404D30B219359C6A4952565CCCA6F11EC5BE564B49B0EA5BF5B3DC8C5C6401208D0029C3957A8C5922CBDE39D3A564C6DEBB6BD2AEF91FC27BB3D3892BEB9646DCE2E1EF8581EFFA712158AAEC541C0BBB4B3E279D7DA54E45A0ACC3570E712C9F7CDF985CFAFD382AE13A3B214A9E8E1E71AB1EA707895112ABC3A97D0FCB0AE2EE5C85492B6CFD54885CDD6337E895CC70FB3255E3", withExponentOfPublicKey: "03", withChecksum: "6BDA32B1AA171444C7E8F88075A74FBFE845765F"),
            RUAPublicKey(rid: "A000000152", withCAPublicKeyIndex: "01", withPublicKey: "8D1727AB9DC852453193EA0810B110F2A3FD304BE258338AC2650FA2A040FA10301EA53DF18FD9F40F55C44FE0EE7C7223BC649B8F9328925707776CB86F3AC37D1B22300D0083B49350E09ABB4B62A96363B01E4180E158EADDD6878E85A6C9D56509BF68F0400AFFBC441DDCCDAF9163C4AACEB2C3E1EC13699D23CDA9D3AD", withExponentOfPublicKey: "03", withChecksum: "E0C2C1EA411DB24EC3E76A9403F0B7B6F406F398"),
            RUAPublicKey(rid: "A000000152", withCAPublicKeyIndex: "5C", withPublicKey: "833F275FCF5CA4CB6F1BF880E54DCFEB721A316692CAFEB28B698CAECAFA2B2D2AD8517B1EFB59DDEFC39F9C3B33DDEE40E7A63C03E90A4DD261BC0F28B42EA6E7A1F307178E2D63FA1649155C3A5F926B4C7D7C258BCA98EF90C7F4117C205E8E32C45D10E3D494059D2F2933891B979CE4A831B301B0550CDAE9B67064B31D8B481B85A5B046BE8FFA7BDB58DC0D7032525297F26FF619AF7F15BCEC0C92BCDCBC4FB207D115AA65CD04C1CF982191", withExponentOfPublicKey: "03", withChecksum: "60154098CBBA350F5F486CA31083D1FC474E31F8"),
            RUAPublicKey(rid: "A000000065", withCAPublicKeyIndex: "11", withPublicKey: "A2583AA40746E3A63C22478F576D1EFC5FB046135A6FC739E82B55035F71B09BEB566EDB9968DD649B94B6DEDC033899884E908C27BE1CD291E5436F762553297763DAA3B890D778C0F01E3344CECDFB3BA70D7E055B8C760D0179A403D6B55F2B3B083912B183ADB7927441BED3395A199EEFE0DEBD1F5FC3264033DA856F4A8B93916885BD42F9C1F456AAB8CFA83AC574833EB5E87BB9D4C006A4B5346BD9E17E139AB6552D9C58BC041195336485", withExponentOfPublicKey: "03", withChecksum: "D9FD62C9DD4E6DE7741E9A17FB1FF2C5DB948BCB"),
            RUAPublicKey(rid: "A000000152", withCAPublicKeyIndex: "5B", withPublicKey: "D3F45D065D4D900F68B2129AFA38F549AB9AE4619E5545814E468F382049A0B9776620DA60D62537F0705A2C926DBEAD4CA7CB43F0F0DD809584E9F7EFBDA3778747BC9E25C5606526FAB5E491646D4DD28278691C25956C8FED5E452F2442E25EDC6B0C1AA4B2E9EC4AD9B25A1B836295B823EDDC5EB6E1E0A3F41B28DB8C3B7E3E9B5979CD7E079EF024095A1D19DD", withExponentOfPublicKey: "03", withChecksum: "4DC5C6CAB6AE96974D9DC8B2435E21F526BC7A60"),
            RUAPublicKey(rid: "A000000003", withCAPublicKeyIndex: "95", withPublicKey: "BE9E1FA5E9A803852999C4AB432DB28600DCD9DAB76DFAAA47355A0FE37B1508AC6BF38860D3C6C2E5B12A3CAAF2A7005A7241EBAA7771112C74CF9A0634652FBCA0E5980C54A64761EA101A114E0F0B5572ADD57D010B7C9C887E104CA4EE1272DA66D997B9A90B5A6D624AB6C57E73C8F919000EB5F684898EF8C3DBEFB330C62660BED88EA78E909AFF05F6DA627B", withExponentOfPublicKey: "03", withChecksum: "EE1511CEC71020A9B90443B37B1D5F6E703030F6"),
            RUAPublicKey(rid: "A000000003", withCAPublicKeyIndex: "92", withPublicKey: "996AF56F569187D09293C14810450ED8EE3357397B18A2458EFAA92DA3B6DF6514EC060195318FD43BE9B8F0CC669E3F844057CBDDF8BDA191BB64473BC8DC9A730DB8F6B4EDE3924186FFD9B8C7735789C23A36BA0B8AF65372EB57EA5D89E7D14E9C7B6B557460F10885DA16AC923F15AF3758F0F03EBD3C5C2C949CBA306DB44E6A2C076C5F67E281D7EF56785DC4D75945E491F01918800A9E2DC66F60080566CE0DAF8D17EAD46AD8E30A247C9F", withExponentOfPublicKey: "03", withChecksum: "429C954A3859CEF91295F663C963E582ED6EB253"),
            RUAPublicKey(rid: "A000000003", withCAPublicKeyIndex: "94", withPublicKey: "ACD2B12302EE644F3F835ABD1FC7A6F62CCE48FFEC622AA8EF062BEF6FB8BA8BC68BBF6AB5870EED579BC3973E121303D34841A796D6DCBC41DBF9E52C4609795C0CCF7EE86FA1D5CB041071ED2C51D2202F63F1156C58A92D38BC60BDF424E1776E2BC9648078A03B36FB554375FC53D57C73F5160EA59F3AFC5398EC7B67758D65C9BFF7828B6B82D4BE124A416AB7301914311EA462C19F771F31B3B57336000DFF732D3B83DE07052D730354D297BEC72871DCCF0E193F171ABA27EE464C6A97690943D59BDABB2A27EB71CEEBDAFA1176046478FD62FEC452D5CA393296530AA3F41927ADFE434A2DF2AE3054F8840657A26E0FC617", withExponentOfPublicKey: "03", withChecksum: "C4A3C43CCF87327D136B804160E47D43B60E6E0F"),
            RUAPublicKey(rid: "A000000003", withCAPublicKeyIndex: "99", withPublicKey: "AB79FCC9520896967E776E64444E5DCDD6E13611874F3985722520425295EEA4BD0C2781DE7F31CD3D041F565F747306EED62954B17EDABA3A6C5B85A1DE1BEB9A34141AF38FCF8279C9DEA0D5A6710D08DB4124F041945587E20359BAB47B7575AD94262D4B25F264AF33DEDCF28E09615E937DE32EDC03C54445FE7E382777", withExponentOfPublicKey: "03", withChecksum: "4ABFFD6B1C51212D05552E431C5B17007D2F5E6D"),
        ]
    }

    // MARK: - AID List Generator

    private func generateAidsList() -> [RUAApplicationIdentifier] {
        return [
            // Visa Credit - A0000000031010
            RUAApplicationIdentifier(rid: "A000000003", withPIX: "1010", withAID: "A0000000031010",
                withApplicationLabel: nil, withTerminalApplicationVersion: "008C",
                withLowestSupportedICCApplicationVersion: "008C", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // Visa Electron (Credit) - A0000000032010
            RUAApplicationIdentifier(rid: "A000000003", withPIX: "2010", withAID: "A0000000032010",
                withApplicationLabel: nil, withTerminalApplicationVersion: "008C",
                withLowestSupportedICCApplicationVersion: "008C", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // VISA Interlink - A0000000033010
            RUAApplicationIdentifier(rid: "A000000003", withPIX: "3010", withAID: "A0000000033010",
                withApplicationLabel: nil, withTerminalApplicationVersion: "008C",
                withLowestSupportedICCApplicationVersion: "008C", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // MasterCard Credit - A0000000041010
            RUAApplicationIdentifier(rid: "A000000004", withPIX: "1010", withAID: "A0000000041010",
                withApplicationLabel: nil, withTerminalApplicationVersion: "0002",
                withLowestSupportedICCApplicationVersion: "0002", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // Maestro (Debit) - A0000000043060
            RUAApplicationIdentifier(rid: "A000000004", withPIX: "3060", withAID: "A0000000043060",
                withApplicationLabel: nil, withTerminalApplicationVersion: "0002",
                withLowestSupportedICCApplicationVersion: "0002", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // Discover/Diners credit - A0000001523010
            RUAApplicationIdentifier(rid: "A000000152", withPIX: "3010", withAID: "A0000001523010",
                withApplicationLabel: nil, withTerminalApplicationVersion: "0001",
                withLowestSupportedICCApplicationVersion: "0001", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // American Express credit - A00000002501
            RUAApplicationIdentifier(rid: "A000000025", withPIX: "01", withAID: "A00000002501",
                withApplicationLabel: nil, withTerminalApplicationVersion: "0001",
                withLowestSupportedICCApplicationVersion: "0001", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
            // JCB J Smart Credit - A0000000651010
            RUAApplicationIdentifier(rid: "A000000065", withPIX: "1010", withAID: "A0000000651010",
                withApplicationLabel: nil, withTerminalApplicationVersion: "0020",
                withLowestSupportedICCApplicationVersion: "0200", withPriorityIndex: "00",
                withApplicationSelectionFlags: "01"),
        ]
    }

    // MARK: - Moby5500 JSON Configuration

    @discardableResult
    private func fetchAndStoreJSON() -> [String: Any]? {
        let urlString = productionMode
            ? "https://raw.githubusercontent.com/hps/Moby-5500-Config/main/provisionProd.json"
            : "https://raw.githubusercontent.com/hps/Moby-5500-Config/main/provisionTest.json"

        print("URL STRING USED TO FETCH JSON - CONFIG DEVICE \(urlString)")

        guard let url = URL(string: urlString) else { return nil }

        var resultDict: [String: Any]?
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { semaphore.signal(); return }

            if let error = error {
                print("Error fetching JSON: \(error.localizedDescription)")
                resultDict = self.loadDictionaryFromJSON()
                semaphore.signal()
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Error parsing JSON")
                resultDict = self.loadDictionaryFromJSON()
                semaphore.signal()
                return
            }

            resultDict = json

            // Version check
            let remoteVersion = ((json["processor_profile_config_list"] as? [[String: Any]])?.first)?["dynamic_conf_cust_str_ver"] as? String
            let stored = self.loadDictionaryFromDefaultsJSON()

            if !stored.isEmpty,
               let configList = stored["processor_profile_config_list"] as? [[String: Any]],
               !configList.isEmpty {
                let localVersion = configList[0]["dynamic_conf_cust_str_ver"] as? String
                if remoteVersion != localVersion {
                    UserDefaults.standard.set(json, forKey: "storedJSON")
                    print("JSON updated in UserDefaults.")
                } else {
                    print("Version is the same. No update needed.")
                }
            } else {
                UserDefaults.standard.set(json, forKey: "storedJSON")
            }

            semaphore.signal()
        }.resume()

        semaphore.wait()
        return resultDict
    }

    private func loadDictionaryFromDefaultsJSON() -> [String: Any] {
        return UserDefaults.standard.dictionary(forKey: "storedJSON") ?? [:]
    }

    @discardableResult
    private func loadDictionaryFromJSON() -> [String: Any]? {
        let cloudDict = fetchAndStoreJSON()
        if let cloudDict = cloudDict {
            UserDefaults.standard.set(cloudDict, forKey: "storedJSON")
            return cloudDict
        }

        // Fallback to local bundle JSON
        let fileName = productionMode ? "provisionProd_5500" : "provisionTest_5500"
        if !productionMode { print("DEBUG PROVISION TEST WERE USED") }

        guard let bundle = Bundle(identifier: "com.heartland.Heartland-iOS-SDK"),
              let path = bundle.path(forResource: fileName, ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("Cannot find json")
            return nil
        }

        do {
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let dict = dict {
                UserDefaults.standard.set(dict, forKey: "storedJSON")
            }
            return dict
        } catch {
            print("Cannot serialize json due to \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - JSON-Based Getters (Moby5500)

    public func getAIDsList() -> [RUAApplicationIdentifier] {
        let json = loadDictionaryFromDefaultsJSON()
        guard let configList = (json["processor_profile_config_list"] as? [[String: Any]])?.first,
              let contactList = configList["contact_list"] as? [[String: Any]] else { return [] }

        return contactList.compactMap { dic in
            RUAApplicationIdentifier(
                rid:                                        dic["rid"] as? String,
                withPIX:                                    dic["pix"] as? String,
                withAID:                                    nil,
                withApplicationLabel:                       nil,
                withTerminalApplicationVersion:             dic["terminal_application_version"] as? String,
                withLowestSupportedICCApplicationVersion:   dic["lowest_supported_icc_application_version"] as? String,
                withPriorityIndex:                          dic["priority_index"] as? String,
                withApplicationSelectionFlags:              dic["application_selection_flags"] as? String
            )
        }
    }

    public func getContactlessAIDsList() -> [RUAApplicationIdentifier] {
        let json = loadDictionaryFromDefaultsJSON()
        guard let configList = (json["processor_profile_config_list"] as? [[String: Any]])?.first,
              let contactlessList = configList["contactless_list"] as? [[String: Any]] else { return [] }

        return contactlessList.compactMap { dic in
            RUAApplicationIdentifier(
                rid:                                        dic["rid"] as? String,
                withPIX:                                    dic["pix"] as? String,
                withAID:                                    dic["aid"] as? String,
                withApplicationLabel:                       nil,
                withTerminalApplicationVersion:             dic["terminal_application_version"] as? String,
                withLowestSupportedICCApplicationVersion:   dic["lowest_supported_icc_application_version"] as? String,
                withPriorityIndex:                          dic["priority_index"] as? String,
                withApplicationSelectionFlags:              dic["application_selection_flags"] as? String,
                withCVMLimit:                               dic["cvm_limit"] as? String,
                withFloorLimit:                             dic["floor_limit"] as? String,
                withTLVData:                                dic["tlv_data"] as? String,
                withTermCaps:                               dic["term_caps"] as? String,
                withTxnLimit:                               dic["txn_limit"] as? String
            )
        }
    }

    public func getPublicKeysList() -> [RUAPublicKey] {
        let json = loadDictionaryFromDefaultsJSON()
        guard let configList = (json["processor_profile_config_list"] as? [[String: Any]])?.first,
              let keysArray = configList["public_keys"] as? [[String: Any]] else { return [] }

        return keysArray.compactMap { dic in
            RUAPublicKey(
                rid:                    dic["rid"] as? String,
                withCAPublicKeyIndex:   dic["ca_public_key_index"] as? String,
                withPublicKey:          dic["public_key"] as? String,
                withExponentOfPublicKey: dic["exponent_of_public_key"] as? String,
                withChecksum:           dic["checksum"] as? String
            )
        }
    }

    public func getAmountDolsList() -> [NSNumber] {
        return dolsList(forKey: "Amount")
    }

    public func getOnlineDolsList() -> [NSNumber] {
        return dolsList(forKey: "Online")
    }

    public func getResponseDolsList() -> [NSNumber] {
        return dolsList(forKey: "Response")
    }

    public func getContactlessResponseDolsList() -> [NSNumber] {
        return dolsList(forKey: "ContactlessResponse")
    }

    public func getContactlessOnlineDolsList() -> [NSNumber] {
        return dolsList(forKey: "ContactlessOnline")
    }

    public func getMagStripeDolsList() -> [NSNumber] {
        return dolsList(forKey: "MagStripe")
    }

    // MARK: - Private DOL Helper

    private func dolsList(forKey key: String) -> [NSNumber] {
        let json = loadDictionaryFromDefaultsJSON()
        guard let configList = (json["processor_profile_config_list"] as? [[String: Any]])?.first,
              let dols = configList["dols"] as? [String: Any],
              let names = dols[key] as? [String] else { return [] }

        return names.map { name in
            NSNumber(value: RUAEnumerationHelper.ruaParameter_(toEnumeration: name).rawValue)
        }
    }
}
