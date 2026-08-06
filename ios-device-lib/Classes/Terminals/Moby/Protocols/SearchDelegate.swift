//
//  SearchDelegate.swift
//  ios-device-lib
//

import Foundation

public protocol SearchDelegate: AnyObject {
    func deviceFound(terminalInfo: TerminalInfo)
    func onSearchComplete()
    func onError(error: SearchError)
}
