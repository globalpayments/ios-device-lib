//
//  DevicesView.swift
//  ios-device-lib
//
//

import SwiftUI
import ExternalAccessory
import os.log

@available(iOS 16.0, *)
public struct MobyDevicesView: View {
    
    @State private var showToastLoading = false
    @State var listDevices: [RuaDevice] = []
    
    @State private var device: RuaDevice? = nil
    
    @State private var mobyDevice: HpsMobyDevice?
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var siteID: String = ""
    @State private var developerID: String = ""
    @State private var versionNumber: String = ""
    @State private var licenseID: String = ""
    @State private var deviceID: String = ""
    
    @State private var showViewForCredentials: Bool = true
    @State private var navigateToUSBDetail: Bool = false
    @State private var usbDevice: RuaDevice? = nil
    @State private var usbDeviceNotFound: Bool = false
    
    @Environment(\.dismiss) private var dismiss

    var connectionInterface: RUACommunicationInterface?
    
    public init(_ connectionInterface: RUACommunicationInterface? = nil ) {
        self.connectionInterface = connectionInterface
    }
    
    public var body: some View {
        if showViewForCredentials {
            Group {
                if navigateToUSBDetail, let device = usbDevice {
                    MobyDeviceDetailView(deviceSelected: device, onBack: {
                        dismiss()
                    })
                } else {
                    credentialsView
                }
            }
            .alert("MOBY5500 USB Device Not Found", isPresented: $usbDeviceNotFound) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No MOBY5500 detected via USB. \n Checklist:\n• Reinstall the app (iOS caches supported protocols — a rebuild alone is not enough).\n• Confirm UISupportedExternalAccessoryProtocols is in the app target's Info.plist.\n• Check the cable is fully seated and the device is powered on.")
            }
            .onAppear {
                // Register early so connectedAccessories is fully populated
                // by the time the user taps START.
                EAAccessoryManager.shared().registerForLocalNotifications()
            }
        } else {
            NavigationSplitView(columnVisibility: .constant(NavigationSplitViewVisibility.all)) {
                if(!listDevices.isEmpty){
                    ScrollView {
                        ForEach(listDevices, id: \.self) { device in
                            VStack {
                                Divider()
                                NavigationLink(
                                    destination: MobyDeviceDetailView(deviceSelected: device),
                                    label: {
                                        Text("\(device.deviceName)")
                                    })
                                .navigationViewStyle(StackNavigationViewStyle())
                            }
                            .frame(maxWidth: .infinity, maxHeight: 50)
                            
                            Spacer()
                        }
                    }
                    .padding(0)
                } else {
                    VStack {
                        Text("No Devices Found!")
                            .foregroundColor(.primary)
                            .font(.title3)
                    }
                }
            } detail: {
                if let device, let mobyDevice {
                    MobyDeviceDetailView(deviceSelected: device)
                }
            }
            .navigationSplitViewStyle(.balanced)
            .navigationSplitViewColumnWidth(ideal: 250)
            .navigationSplitViewColumnWidth(250)
            .navigationBarTitle("Moby Connection")
            .navigationBarHidden(false)
            .toolbarRole(.navigationStack)
            .toolbar(.hidden, for: .tabBar, .bottomBar)
            .navigationBarBackButtonHidden(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                launchDeviceSearching()
            }
        }
    }
    
    var credentialsView: some View {
           VStack{
               Text("Credentials").font(.headline.bold()).underline().padding()
               HStack(spacing: 2) {
                   
                   Spacer()
                   
                   VStack {
                       TextField(
                           "Username",
                           text: $username
                       )
                       .autocapitalization(.none)
                       .disableAutocorrection(false)
                       .padding(.top, 20)
                       
                       Divider()
                       
                       SecureField(
                           "Password",
                           text: $password
                       )
                       .padding(.top, 20)
                       
                       Divider()
                       
                       TextField(
                           "SiteID",
                           text: $siteID
                       )
                       .autocapitalization(.none)
                       .disableAutocorrection(false)
                       .padding(.top, 20)
                       
                       Divider()
                       
                       TextField(
                           "LicenseID",
                           text: $licenseID
                       )
                       .autocapitalization(.none)
                       .disableAutocorrection(false)
                       .padding(.top, 20)
                       
                       Divider()
                       
                       TextField(
                           "DeveloperID",
                           text: $developerID
                       )
                       .autocapitalization(.none)
                       .disableAutocorrection(false)
                       .padding(.top, 20)
                       
                       Divider()
                       
                       TextField(
                           "VersionNumber",
                           text: $versionNumber
                       )
                       .autocapitalization(.none)
                       .disableAutocorrection(false)
                       .padding(.top, 20)
                       
                       Divider()
                       
                       TextField(
                           "DeviceID",
                           text: $deviceID
                       )
                       .autocapitalization(.none)
                       .disableAutocorrection(false)
                       .padding(.top, 20)
                       
                   }
                   
               }
               
               HStack {
                   Button(action: {
                       if self.connectionInterface == RUACommunicationInterfaceUSB {
                           if let device = discoverConnectedUSBDevice() {
                               usbDevice = device
                               launchDevice()
                               navigateToUSBDetail = true
                           } else {
                               usbDeviceNotFound = true
                           }
                       } else {
                           launchDeviceSearching()
                           self.showViewForCredentials = false
                       }
                   }){
                       Text("START")
                           .padding(20)
                           .foregroundColor(.red)
                   }
                   .buttonStyle(BlueButtonStyle(width: .infinity))
                   .disabled(showToastLoading)
                   
                   Spacer()
                   
                   Button(action: {
                       self.showViewForCredentials = false
                   }){
                       Text("CANCEL")
                           .foregroundStyle(.red)
                           .padding(20)
                   }
                   .buttonStyle(BlueButtonStyle(width: .infinity))
                   .disabled(!showToastLoading)
                   
               }
               
           }.padding()
               .background(
                   RoundedRectangle(cornerRadius: 10).foregroundColor(Color(UIColor.systemBackground))
                       .shadow(color: .gray, radius: 8, x: 2, y: 2)
               )
       }
    
    func launchDeviceSearching(searchEnded: (() -> Void)? = nil) -> Void {
        showToastLoading = true
        
        let timeout = 120

        let config = HpsConnectionConfig()
        config.username = self.username
        config.password = self.password
        config.siteID = self.siteID
        config.deviceID = self.deviceID
        config.licenseID = self.licenseID
        
        config.developerID = self.developerID
        config.versionNumber = self.versionNumber
        
        config.timeout = timeout
    
        RUAHelper.sharedInstance.initializeWith(config: config) { result1, result2 in
            print(result1)
            print(result2)
        } releaseCompletionBlock: { isConnected in
            os_log("releaseCompletionBlock")
            showToastLoading = RUAHelper.sharedInstance.showLoadingScreen
        }

        RUAHelper.sharedInstance.startSearchingDevices { devices in
            listDevices = devices
            showToastLoading = RUAHelper.sharedInstance.showLoadingScreen
            if(searchEnded != nil){
                searchEnded!()
            }
        }
    }
    
    func launchDevice() {
        let timeout = 120

        let config = HpsConnectionConfig()
        config.username = self.username
        config.password = self.password
        config.siteID = self.siteID
        config.deviceID = self.deviceID
        config.licenseID = self.licenseID
        
        config.developerID = self.developerID
        config.versionNumber = self.versionNumber
        
        config.timeout = timeout
    
        RUAHelper.sharedInstance.initializeWith(config: config, connectionInterface: connectionInterface) { result1, result2 in
            print(result1)
            print(result2)
        } releaseCompletionBlock: { isConnected in
            os_log("releaseCompletionBlock")
            showToastLoading = RUAHelper.sharedInstance.showLoadingScreen
        }
    }
    
    private func discoverConnectedUSBDevice() -> RuaDevice? {
        EAAccessoryManager.shared().registerForLocalNotifications()

        let allAccessories = EAAccessoryManager.shared().connectedAccessories

        // --- Diagnostic output (visible in Xcode console) ---
        if allAccessories.isEmpty {
            os_log("[MobyUSB] ⚠️  EAAccessoryManager.connectedAccessories is EMPTY.")
            os_log("[MobyUSB] Checklist:")
            os_log("[MobyUSB]  1. REINSTALL the app — iOS caches UISupportedExternalAccessoryProtocols; a rebuild alone is not enough.")
            os_log("[MobyUSB]  2. UISupportedExternalAccessoryProtocols must be in the HOST APP's Info.plist (not only the framework).")
            os_log("[MobyUSB]  3. The provisioning profile must have the com.apple.developer.accessory-protocols entitlement.")
            os_log("[MobyUSB]  4. Confirm the USB-C cable is fully seated and the MOBY5500 is powered on.")
        } else {
            os_log("[MobyUSB] \(allAccessories.count) EAAccessory(ies) connected:")
            for acc in allAccessories {
                os_log("[MobyUSB]  • name='\(acc.name)' | serial='\(acc.serialNumber)' | manufacturer='\(acc.manufacturer)' | protocols=\(acc.protocolStrings)")
            }
        }

        // Strategy 1 — exact protocol string match (most reliable)
        let knownProtocols: Set<String> = [
            "com.landicorp.USBdatapath",
            "com.landicorp.datapath",
            "com.landi.datapath",
            "com.smartpos.datapath"
        ]
        if let acc = allAccessories.first(where: {
            $0.protocolStrings.contains(where: { knownProtocols.contains($0) })
        }) {
            os_log("[MobyUSB] ✅ Strategy 1 (protocol match): '\(acc.name)' serial='\(acc.serialNumber)'")
            return RuaDevice(deviceName: acc.name, deviceSerialNumber: acc.serialNumber)
        }

        // Strategy 2 — device name / manufacturer keyword match
        // Handles devices that advertise a protocol string variant not yet in our list.
        let keywords = ["mob", "moby", "ingenico", "landi"]
        if let acc = allAccessories.first(where: { accessory in
            let name = accessory.name.lowercased()
            let mfr  = accessory.manufacturer.lowercased()
            return keywords.contains(where: { name.contains($0) || mfr.contains($0) })
        }) {
            os_log("[MobyUSB] ✅ Strategy 2 (name/manufacturer match): '\(acc.name)' serial='\(acc.serialNumber)'")
            return RuaDevice(deviceName: acc.name, deviceSerialNumber: acc.serialNumber)
        }

        // Strategy 3 — only one accessory connected and user confirmed it is the MOBY5500
        if allAccessories.count == 1, let acc = allAccessories.first {
            os_log("[MobyUSB] ✅ Strategy 3 (sole connected accessory): '\(acc.name)' serial='\(acc.serialNumber)'")
            return RuaDevice(deviceName: acc.name, deviceSerialNumber: acc.serialNumber)
        }

        os_log("[MobyUSB] ❌ No compatible accessory found. Total connected: \(allAccessories.count)")
        return nil
    }
}
