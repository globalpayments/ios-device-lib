//
//  ObjC+CatchException.swift
//  ios-device-lib-SampleAppTests
//

import Foundation

extension ObjC {
    static func catchException(_ block: () throws -> Void) throws {
        try __catchException { (errorPointer: NSErrorPointer) in
            do {
                try block()
            } catch {
                errorPointer?.pointee = error as NSError
            }
        }
    }
}
