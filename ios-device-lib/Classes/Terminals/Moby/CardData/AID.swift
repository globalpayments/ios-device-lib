//
//  AID.swift
//  ios-device-lib
//

import Foundation

@objcMembers
public class AID: NSObject, Codable {

    public var rid: String?
    public var pix: String?
    public var applicationIdentifier: String?
    public var tlv: String?
    public var index: Int?
    public var label: String?
    public var preferredName: String?

    public override init() {}

    public convenience init(rid: String?,
                            pix: String?,
                            applicationIdentifier: String,
                            tlv: String?,
                            index: Int?,
                            label: String?,
                            preferredName: String?) {
        self.init()

        self.rid = rid
        self.pix = pix
        self.applicationIdentifier = applicationIdentifier
        self.tlv = tlv
        self.index = index
        self.label = label
        self.preferredName = preferredName
    }
}
