//
//  AppState.swift
//  Bottle
//
//  Created by Cobalt on 12/31/23.
//

import Foundation

struct AppState {
    var metadata: AppMetadata?
    var feeds = [Feed]()
    
    var communityFeeds: [(String, [Feed])] {
        var result = [(String, [Feed])]()
        for feed in feeds {
            if let index = result.firstIndex(where: { $0.0 == feed.community }) {
                result[index].1.append(feed)
            } else {
                result.append((feed.community, [feed]))
            }
        }
        result.sort { $0.0 < $1.0 }
        return result
    }
}
