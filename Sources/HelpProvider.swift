//
//  File.swift
//  
//
//  Created by Marek Slaninka on 18/02/2022.
//

import Foundation

class HelpProvider {
    
    lazy var closestMatchFInder = ClosestMatchFinder()

    func getHelp(with arg: String?) throws -> String {
        guard let arg = arg else {
            let width = Command.allCases.map { $0.rawValue.count }.max(by: <) ?? 0
            return """
            Available commands:
            
            \(Command.allCases.map {
                "   \($0.rawValue.addingTrailingSpace(toWidth: width))   \($0.help)"
            }.joined(separator: "\n"))
            
            (Type 'tribute help [command]' for more information)
            """
        }
        guard let command = Command(rawValue: arg) else {
            let commands = Command.allCases.map { $0.rawValue }
            if let closest = closestMatchFInder.bestMatches(for: arg, in: commands).first {
                throw TributeError("Unrecognized command '\(arg)'. Did you mean '\(closest)'?")
            }
            throw TributeError("Unrecognized command '\(arg)'.")
        }
        let detailedHelp: String
        switch command {
            case .help:
                detailedHelp = """
               [command]  The command to display help for.
            """
            case .export:
                detailedHelp = """
               [filepath]   Path to the file that the licenses should be exported to. If omitted
                            then the licenses will be written to stdout.
            
               --exclude    One or more directories to be excluded from the library search.
                            Paths should be relative to the current directory, and may include
                            wildcard/glob syntax.
            
               --skip       One or more libraries to be skipped. Use this for libraries that do
                            not require attribution, or which are used in the build process but
                            are not actually shipped to the end-user.
            
               --allow      A list of libraries that should be included even if their licenses
                            are not supported/recognized.
            
               --template   A template string or path to a template file to use for generating
                            the licenses file. The template should contain one or more of the
                            following placeholder strings:
            
                            $name        The name of the library
                            $type        The license type (e.g. MIT, Apache, BSD)
                            $text        The text of the license itself
                            $start       The start of the license template (after the header)
                            $end         The end of the license template (before the footer)
                            $separator   A delimiter to be included between each license
            
               --format     How the output should be formatted (JSON, XML or text). If omitted
                            this will be inferred automatically from the template contents.
            
               --spmcache   Path to the Swift Package Manager cache (where SPM stores downloaded
                            libraries). If omitted the standard derived data path will be used.
            """
            case .check:
                detailedHelp = """
               [filepath]   The path to the licenses file that will be compared against the
                            libraries found in the project (required). An error will be returned
                            if any libraries are missing from the file, or if the format doesn't
                            match the other parameters.
            
               --exclude    One or more directories to be excluded from the library search.
                            Paths should be relative to the current directory, and may include
                            wildcard/glob syntax.
            
               --skip       One or more libraries to be skipped. Use this for libraries that do
                            not require attribution, or which are used in the build process but
                            are not actually shipped to the end-user.
            """
            case .checkUnsuported:
                detailedHelp = """
               --exclude       One or more directories to be excluded from the library search.
                               Paths should be relative to the current directory, and may include
                               wildcard/glob syntax.
            
               --skip          One or more libraries to be skipped. Use this for libraries that do
                               not require attribution, or which are used in the build process but
                               are not actually shipped to the end-user.
            
               --unsuported    One or more licencies that are considered unsuported. All used licences
                               in the project, will be compared against these.
                               Default values: [AGPL, LGPL, GPL]
            """
            case .list, .version:
                return command.help
        }
        
        return command.help + ".\n\n" + detailedHelp + "\n"
    }
    
}



private extension String {
    func addingTrailingSpace(toWidth width: Int) -> String {
        self + String(repeating: " ", count: width - count)
    }
}
