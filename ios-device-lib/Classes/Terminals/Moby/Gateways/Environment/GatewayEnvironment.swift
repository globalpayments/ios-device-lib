//
//  GatewayEnvironment.swift
//  ios-device-lib
//

import Foundation

public enum GatewayEnvironment: Codable, Equatable {
    case production,
    certification,
    custom(url: URL),
    mock
    
    enum CodingKeys: String, CodingKey {
        case production,
        certification,
        custom,
        mock
    }
    
    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try container.decodeIfPresent(String.self, forKey: .production)) != nil {
            self = .production
        } else if (try container.decodeIfPresent(String.self, forKey: .certification)) != nil {
            self = .certification
        } else if let value = try container.decodeIfPresent(Data.self, forKey: .custom) {
            guard let url = URL(dataRepresentation: value, relativeTo: nil) else {
                throw URLError(URLError.Code.badURL)
            }
            self = .custom(url: url)
        } else {
            throw ConfigurationError.decodeFailed(debugMessage: "Expected key not found")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .production:
            try container.encode(CodingKeys.production.rawValue, forKey: .production)
        case .certification:
            try container.encode(CodingKeys.certification.rawValue, forKey: .certification)
        case .custom(let url):
            try container.encode(url.dataRepresentation, forKey: .custom)
        case .mock:
            try container.encode(CodingKeys.mock.rawValue, forKey: .mock)
        }
    }
    
    public enum ConfigurationError: Error {
        case decodeFailed(debugMessage: String)
    }
}
