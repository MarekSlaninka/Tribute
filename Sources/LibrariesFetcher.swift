//
//  File.swift
//  
//
//  Created by Marek Slaninka on 18/02/2022.
//

import Foundation

struct Library {
    var name: String
    var licensePath: String
    var licenseType: LicenseType
    var licenseText: String
}

class LibrariesFetcher {
    func fetchLibraries(in directory: URL,
                        excluding: [Glob],
                        spmCache: URL?,
                        includingPackages: Bool = true) throws -> [Library]
    {
        let standardizedDirectory = directory.standardized
        let directoryPath = standardizedDirectory.path
        
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: standardizedDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            throw TributeError("Unable to process directory at \(directoryPath).")
        }
        
        // Fetch libraries
        var libraries = [Library]()
        
        
        for case let licenceFile as URL in enumerator {
            try? autoreleasepool {
                
                if excluding.contains(where: { $0.matches(licenceFile.path) }) {
                    return
                }
                let licensePath = licenceFile.path.dropFirst(directoryPath.count)
                if includingPackages {
                    if licenceFile.lastPathComponent == "Package.resolved" {
                        libraries += try fetchLibraries(forResolvedPackageAt: licenceFile, spmCache: spmCache)
                        return
                    }
                }
                let name = licenceFile.deletingLastPathComponent().lastPathComponent
                if libraries.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    return
                }
                let ext = licenceFile.pathExtension
                let fileName = licenceFile.deletingPathExtension().lastPathComponent.lowercased()
                guard ["license", "licence"].contains(fileName),
                      ["", "text", "txt", "md"].contains(ext)
                else {
                    return
                }
                var isDirectory: ObjCBool = false
                _ = manager.fileExists(atPath: licenceFile.path, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    return
                }
                do {
                    let licenseText = try String(contentsOf: licenceFile)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let library = Library(
                        name: name,
                        licensePath: String(licensePath),
                        licenseType: LicenseType(licenseText: licenseText),
                        licenseText: licenseText
                    )
                    libraries.append(library)
                } catch {
                    throw TributeError("Unable to read license file at \(licensePath).")
                }
            }
        }
        return libraries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    func fetchLibraries(forResolvedPackageAt url: URL, spmCache: URL?) throws -> [Library] {
        struct Pin: Decodable {
            let package: String
            let repositoryURL: URL
        }
        struct Object: Decodable {
            let pins: [Pin]
        }
        struct Resolved: Decodable {
            let object: Object
        }
        let filter: Set<String>
        do {
            let data = try Data(contentsOf: url)
            let resolved = try JSONDecoder().decode(Resolved.self, from: data)
            filter = Set(resolved.object.pins.flatMap {
                [
                    $0.package.lowercased(),
                    $0.repositoryURL.deletingPathExtension().lastPathComponent.lowercased(),
                ]
            })
        } catch {
            throw TributeError("Unable to read Swift Package file at \(url.path).")
        }
        let directory: URL
        if let spmCache = spmCache {
            directory = spmCache
        } else if let derivedDataDirectory = FileManager.default
                    .urls(for: .libraryDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("Developer/Xcode/DerivedData")
        {
            directory = derivedDataDirectory
        } else {
            throw TributeError("Unable to locate ~/Library/Developer/Xcode/DerivedData directory.")
        }
        let libraries = try fetchLibraries(
            in: directory,
            excluding: [],
            spmCache: nil,
            includingPackages: false
        )
        return libraries.filter { filter.contains($0.name.lowercased()) }
    }
}
