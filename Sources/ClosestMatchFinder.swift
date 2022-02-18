//
//  File.swift
//  
//
//  Created by Marek Slaninka on 18/02/2022.
//

import Foundation
class ClosestMatchFinder {
    // Find best match for a given string in a list of options
    func bestMatches(for query: String, in options: [String]) -> [String] {
        let lowercaseQuery = query.lowercased()
        // Sort matches by Levenshtein edit distance
        return options
            .compactMap { option -> (String, Int)? in
                let lowercaseOption = option.lowercased()
                let distance = editDistance(lowercaseOption, lowercaseQuery)
                guard distance <= lowercaseQuery.count / 2 ||
                        !lowercaseOption.commonPrefix(with: lowercaseQuery).isEmpty
                else {
                    return nil
                }
                return (option, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }
    
    /// The Levenshtein edit-distance between two strings
    func editDistance(_ lhs: String, _ rhs: String) -> Int {
        var dist = [[Int]]()
        for i in 0 ... lhs.count {
            dist.append([i])
        }
        for j in 1 ... rhs.count {
            dist[0].append(j)
        }
        for i in 1 ... lhs.count {
            let lhs = lhs[lhs.index(lhs.startIndex, offsetBy: i - 1)]
            for j in 1 ... rhs.count {
                if lhs == rhs[rhs.index(rhs.startIndex, offsetBy: j - 1)] {
                    dist[i].append(dist[i - 1][j - 1])
                } else {
                    dist[i].append(min(dist[i - 1][j] + 1, dist[i][j - 1] + 1, dist[i - 1][j - 1] + 1))
                }
            }
        }
        return dist[lhs.count][rhs.count]
    }
}
