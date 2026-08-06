//
//  ConnectionListener.swift
//  ios-device-lib
//

import Foundation

protocol ConnectionListener: AnyObject {
    func onDeviceConnected()
    func onDeviceConnectionFailed()
    func onDeviceConnectionCancelled()
}
