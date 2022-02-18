//
//  Tribute.swift
//  Tribute
//
//  Created by Nick Lockwood on 30/11/2020.
//

import Foundation

struct TributeError: Error, CustomStringConvertible {
    
    enum ErrorType {
        case unknownLicence
        case unsuportedLicence
        case unknown
    }
    
    
    let description: String
    let type: ErrorType
    
    init(_ message: String, type: ErrorType = .unknown) {
        self.description = message
        self.type = type
    }
}

enum Argument: String, CaseIterable {
    case anonymous = ""
    case allow
    case skip
    case exclude
    case template
    case format
    case spmcache
    case unsuported
}

enum Command: String, CaseIterable {
    case export
    case list
    case check
    case help
    case version
    case checkUnsuported
    
    var help: String {
        switch self {
            case .help: return "Display general or command-specific help"
            case .list: return "Display list of libraries and licenses found in project"
            case .export: return "Export license information for project"
            case .check: return "Check that exported license info is correct"
            case .checkUnsuported: return "Check that all licences are suported or known"
            case .version: return "Display the current version of Tribute"
        }
    }
}


class Tribute {
    
    lazy var helpProvider = HelpProvider()
    lazy var librariesFetcher = LibrariesFetcher()
    lazy var closestMatchFInder = ClosestMatchFinder()
    
  
    
    // Parse a flat array of command-line arguments into a dictionary of flags and values
    func preprocessArguments(_ args: [String]) throws -> [Argument: [String]] {
        let arguments = Argument.allCases
        let argumentNames = arguments.map { $0.rawValue }
        var namedArgs: [Argument: [String]] = [:]
        var name: Argument?
        for arg in args {
            if arg.hasPrefix("--") {
                // Long argument names
                let key = String(arg.unicodeScalars.dropFirst(2))
                guard let argument = Argument(rawValue: key) else {
                    guard let match = closestMatchFInder.bestMatches(for: key, in: argumentNames).first else {
                        throw TributeError("Unknown option --\(key).")
                    }
                    throw TributeError("Unknown option --\(key). Did you mean --\(match)?")
                }
                name = argument
                namedArgs[argument] = namedArgs[argument] ?? []
                continue
            } else if arg.hasPrefix("-") {
                // Short argument names
                let flag = String(arg.unicodeScalars.dropFirst())
                guard let match = arguments.first(where: { $0.rawValue.hasPrefix(flag) }) else {
                    throw TributeError("Unknown flag -\(flag).")
                }
                name = match
                namedArgs[match] = namedArgs[match] ?? []
                continue
            }
            var arg = arg
            let hasTrailingComma = arg.hasSuffix(",") && arg != ","
            if hasTrailingComma {
                arg = String(arg.dropLast())
            }
            let existing = namedArgs[name ?? .anonymous] ?? []
            namedArgs[name ?? .anonymous] = existing + [arg]
        }
        return namedArgs
    }
    
  
    
    
    func listLibraries(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let globs = (arguments[.exclude] ?? []).map { expandGlob($0, in: directory) }
        let spmCache = arguments[.spmcache]?.first
        
        // Directories
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheURL = spmCache.map { expandPath($0, in: directory) }
        let libraries = try librariesFetcher.fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheURL)
        
        // Output
        let nameWidth = libraries.map { $0.name.count }.max() ?? 0
        return libraries.map {
            let name = $0.name + String(repeating: " ", count: nameWidth - $0.name.count)
            var type = ($0.licenseType.rawValue)
            type += String(repeating: " ", count: 7 - type.count)
            return "\(name)  \(type)  \($0.licensePath)"
        }.joined(separator: "\n")
    }
    
    func check(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let skip = (arguments[.skip] ?? []).map { $0.lowercased() }
        let globs = (arguments[.exclude] ?? []).map { expandGlob($0, in: directory) }
        let spmCache = arguments[.spmcache]?.first
        
        // Directory
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheURL = spmCache.map { expandPath($0, in: directory) }
        var libraries = try librariesFetcher.fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheURL)
        let libraryNames = libraries.map { $0.name.lowercased() }
        
        if let name = skip.first(where: { !libraryNames.contains($0) }) {
            if let closest = closestMatchFInder.bestMatches(for: name.lowercased(), in: libraryNames).first {
                throw TributeError("Unknown library '\(name)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unknown library '\(name)'.")
        }
        
        // Filtering
        libraries = libraries.filter { !skip.contains($0.name.lowercased()) }
        
        // File path
        let anon = arguments[.anonymous] ?? []
        guard let inputURL = (anon.count > 2 ? anon[2] : nil).map({
            expandPath($0, in: directory)
        }) else {
            throw TributeError("Missing path to licenses file. \(anon)")
        }
        
        // Check
        guard var licensesText = try? String(contentsOf: inputURL) else {
            throw TributeError("Unable to read licenses file at \(inputURL.path).")
        }
        licensesText = licensesText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if let library = libraries.first(where: { !licensesText.contains($0.name) }) {
            throw TributeError("License for '\(library.name)' is missing from licenses file.")
        }
        return "Licenses file is up-to-date."
    }
    
    func checkUnsuported(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let skip = (arguments[.skip] ?? []).map { $0.lowercased() }
        let unsuported = (arguments[.unsuported] ?? ["AGPL", "LGPL", "GPL"]).map { $0.uppercased() }
        let globs = (arguments[.exclude] ?? []).map { expandGlob($0, in: directory) }
        let spmCache = arguments[.spmcache]?.first
        
        // Directory
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheURL = spmCache.map { expandPath($0, in: directory) }
        var libraries = try librariesFetcher.fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheURL)
        let libraryNames = libraries.map { $0.name.lowercased() }
        
        if let name = skip.first(where: { !libraryNames.contains($0) }) {
            if let closest = closestMatchFInder.bestMatches(for: name.lowercased(), in: libraryNames).first {
                throw TributeError("Unknown library '\(name)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unknown library '\(name)'.")
        }
        
        // Filtering
        libraries = libraries.filter { !skip.contains($0.name.lowercased()) }
        
        // Check if unknown
        let unknownLicencesLibraries = libraries
            .filter{$0.licenseType == .UNKNOWN}
        
        guard unknownLicencesLibraries.isEmpty else {
            let errorText: String = unknownLicencesLibraries.map({"\($0.name)"}).joined(separator: "\n")
            throw TributeError("Unknown licence libraries '\(errorText)'", type: .unknownLicence)
        }
        
        // Check if unsuported
        let unsuportedLicencies: [LicenseType] = try unsuported
            .map { name in
                guard let licence = LicenseType.init(rawValue: name) else {
                    if let closest = closestMatchFInder.bestMatches(for: name.lowercased(), in: LicenseType.allRawValues()).first {
                        throw TributeError("Unknown library '\(name)'. Did you mean '\(closest)'?")
                    } else {
                        throw TributeError("Unknown licence '\(name)'")
                    }
                    
                }
                return licence
            }
        
        let unsuportedLicencesLibraries = libraries
            .filter({unsuportedLicencies.contains($0.licenseType)})
        
        guard unsuportedLicencesLibraries.isEmpty else {
            let errorText: String = unsuportedLicencesLibraries.map({"\($0.name) -> \($0.licenseType.rawValue)"}).joined(separator: "\n")
            throw TributeError("Unsuported licence libraries '\(errorText)'", type: .unknownLicence)
        }
        
        return "All licences are okay"
    }
    
    func export(in directory: String, with args: [String]) throws -> String {
        let arguments = try preprocessArguments(args)
        let allow = (arguments[.allow] ?? []).map { $0.lowercased() }
        let skip = (arguments[.skip] ?? []).map { $0.lowercased() }
        let globs = (arguments[.exclude] ?? []).map { expandGlob($0, in: directory) }
        let rawFormat = arguments[.format]?.first
        let cache = arguments[.spmcache]?.first
        
        // File
        let anon = arguments[.anonymous] ?? []
        let outputURL = (anon.count > 2 ? anon[2] : nil).map { expandPath($0, in: directory) }
        
        // Template
        let template: Template
        if let pathOrTemplate = arguments[.template]?.first {
            if pathOrTemplate.contains("$name") {
                template = Template(rawValue: pathOrTemplate)
            } else {
                let templateFile = expandPath(pathOrTemplate, in: directory)
                let templateText = try String(contentsOf: templateFile)
                template = Template(rawValue: templateText)
            }
        } else {
            template = .default(
                for: rawFormat.flatMap(Format.init) ??
                   outputURL.flatMap { .infer(from: $0) } ?? .text
            )
        }
        
        // Format
        let format: Format
        if let rawFormat = rawFormat {
            guard let _format = Format(rawValue: rawFormat) else {
                let formats = Format.allCases.map { $0.rawValue }
                if let closest = closestMatchFInder.bestMatches(for: rawFormat, in: formats).first {
                    throw TributeError("Unsupported output format '\(rawFormat)'. Did you mean '\(closest)'?")
                }
                throw TributeError("Unsupported output format '\(rawFormat)'.")
            }
            format = _format
        } else {
            format = .infer(from: template)
        }
        
        // Directory
        let path = "."
        let directoryURL = expandPath(path, in: directory)
        let cacheDirectory: URL?
        if let cache = cache {
            cacheDirectory = expandPath(cache, in: directory)
        } else {
            cacheDirectory = nil
        }
        var libraries = try librariesFetcher.fetchLibraries(in: directoryURL, excluding: globs, spmCache: cacheDirectory)
        let libraryNames = libraries.map { $0.name.lowercased() }
        
        if let name = (allow + skip).first(where: { !libraryNames.contains($0) }) {
            if let closest = closestMatchFInder.bestMatches(for: name.lowercased(), in: libraryNames).first {
                throw TributeError("Unknown library '\(name)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unknown library '\(name)'.")
        }
        
        // Filtering
        libraries = try libraries.filter { library in
            if skip.contains(library.name.lowercased()) {
                return false
            }
            let name = library.name
            guard allow.contains(name.lowercased()) || library.licenseType != nil else {
                let escapedName = (name.contains(" ") ? "\"\(name)\"" : name).lowercased()
                throw TributeError(
                    "Unrecognized license at \(library.licensePath). "
                    + "Use '--allow \(escapedName)' or '--skip \(escapedName)' to bypass."
                )
            }
            return true
        }
        
        // Output
        let result = try template.render(libraries, as: format)
        if let outputURL = outputURL {
            do {
                try result.write(to: outputURL, atomically: true, encoding: .utf8)
                return "License data successfully written to \(outputURL.path)."
            } catch {
                throw TributeError("Unable to write output to \(outputURL.path). \(error).")
            }
        } else {
            return result
        }
    }
    
    func run(in directory: String, with args: [String] = CommandLine.arguments) throws -> String {
        let arg = args.count > 1 ? args[1] : Command.help.rawValue
        guard let command = Command(rawValue: arg) else {
            let commands = Command.allCases.map { $0.rawValue }
            if let closest = closestMatchFInder.bestMatches(for: arg, in: commands).first {
                throw TributeError("Unrecognized command '\(arg)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unrecognized command '\(arg)'.")
        }
        switch command {
            case .help:
                return try helpProvider.getHelp(with: args.count > 2 ? args[2] : nil)
            case .list:
                return try listLibraries(in: directory, with: args)
            case .export:
                return try export(in: directory, with: args)
            case .check:
                return try check(in: directory, with: args)
            case .checkUnsuported:
                return try checkUnsuported(in: directory, with: args)
            case .version:
                return "0.4.0"
        }
    }
}

