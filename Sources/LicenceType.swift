//
//  File.swift
//  
//
//  Created by Marek Slaninka on 18/02/2022.
//

import Foundation


enum LicenseType: String, CaseIterable, Equatable {
    case bsd = "BSD"
    case mit = "MIT"
    case isc = "ISC"
    case zlib = "Zlib"
    case apache = "Apache"
    case agpl = "AGPL"
    case lgpl = "LGPL"
    case gpl = "GPL"
    case UNKNOWN = "unknown"
    
    private var matchStrings: [String] {
        switch self {
            case .bsd:
                return [
                    "BSD License",
                    "Redistribution and use in source and binary forms, with or without modification",
                    "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR",
                ]
            case .mit:
                return [
                    "The MIT License",
                    "Permission is hereby granted, free of charge, to any person",
                    "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR",
                ]
            case .isc:
                return [
                    "Permission to use, copy, modify, and/or distribute this software for any",
                ]
            case .zlib:
                return [
                    "Altered source versions must be plainly marked as such, and must not be",
                ]
            case .apache:
                return [
                    "Apache License",
                ]
            case .UNKNOWN:
                return [
                    
                ]
            case .agpl:
                return [
                    "GNU AFFERO GENERAL PUBLIC LICENSE",
                ]
            case .lgpl:
                return [
                    "GNU LESSER GENERAL PUBLIC LICENSE",
                ]
            case .gpl:
                return [
                    "GNU GENERAL PUBLIC LICENSE",
                ]
                
        }
    }
    
    init(licenseText: String) {
        let preprocessedText = Self.preprocess(licenseText)
        guard let type =
                Self
                .allCases
                .filter({$0 != .UNKNOWN})
                .first(where: {
                    $0.matches(preprocessedText: preprocessedText)
                }) else {
                    self = .UNKNOWN
                    return
                }
        self = type
    }
    
    func matches(_ licenseText: String) -> Bool {
        matches(preprocessedText: Self.preprocess(licenseText))
    }
    
    private func matches(preprocessedText: String) -> Bool {
        matchStrings.contains {
            preprocessedText.range(of: $0, options: .caseInsensitive) != nil
        }
    }
    
    private static func preprocess(_ licenseText: String) -> String {
        licenseText.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    static func allRawValues() -> [String] {
        return Self.allCases.map({$0.rawValue})
    }
    
}
