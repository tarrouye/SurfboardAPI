//
//  FeedItem.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/26/23.
//

import Foundation

struct FeedItem: Identifiable {
  let id: String
  let title: String
  let topicLink: URL?
  let group: String
  let tags: [String]
  let type: String?
  let comments: Int
  var newComments: Int
  let source: String
  let isUserSource: Bool
  let date: Date?
  var votes: Int
  var isUserVoted: Bool
  var isUserBookmarked: Bool
  var isUserIgnored: Bool
}

extension FeedItem {
  var fullPubDate: String {
    guard let date else { return "Date unavailable" }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "M/d/yyyy · h:mm a"

    return shortPubDate + " · " + dateFormatter.string(from: date)
  }

  var shortPubDate: String {
    date?.shortFormattedString() ?? "-"
  }

  var canonicalLink: String {
    TildesAPI.baseURL + "/\(group)/\(id)"
  }
}
