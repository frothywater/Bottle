//
//  Error.swift
//  Bottle
//
//  Created by Cobalt on 9/8/23.
//

import Foundation

enum AppError: Error {
    case invalidMetadata
    case invalidServer
    case badStatus(code: Int?, content: String?)
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidMetadata:
            return "Invalid metadata"
        case .invalidServer:
            return "Invalid server"
        case .badStatus(let code, let content):
            return "Bad status \(code?.description ?? ""): \(content ?? "(empty)")"
        }
    }
}
