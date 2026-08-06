//
//  TerminalType.swift
//  ios-device-lib
//


import Foundation

public enum TerminalType:
    String,
    Codable,
    Equatable,
    CaseIterable,

    CustomStringConvertible
{
    case none,
    bbpos_c2x,
    bbpos_wisecube,
    ingencio_moby3000,
    ingencio_g4x_g5x,
    ingencio_moby8500,  // (scheduled)
    ingencio_rp457bt,    // (TechRoadmap)
    unimag,
    ingenico_moby5500

    /// user-facing string
    public var description: String {
        switch self {
        case .none: return "none"
        case .bbpos_c2x: return "bbpos_c2x"
        case .bbpos_wisecube: return "bbpos_wisecube"
        case .ingencio_moby3000: return "ingencio_moby3000"
        case .ingencio_g4x_g5x: return "ingencio_g4x_g5x"
        case .ingencio_moby8500: return "ingencio_moby8500"
        case .ingencio_rp457bt: return "ingencio_rp457bt"
        case .unimag: return "unimag"
        case .ingenico_moby5500: return "ingenico_moby5500"
        }
    }
}
