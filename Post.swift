//
//  Post.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/26/23.
//

import Foundation

struct Post {
  let id: String
  let group: String
  let title: String
  var body: MarkdownString
  let topicLink: URL?
  let tags: [String]
  let source: String
  let isUserSource: Bool
  let date: Date?
  var votes: Int
  var isUserVoted: Bool
  var isUserBookmarked: Bool
  var isUserIgnored: Bool
  let commentsCount: Int
}

extension Post {
  var shortPubDate: String {
    guard let date else { return "-" }
    return date.shortFormattedString()
  }

  var canonicalLink: String {
    TildesAPI.baseURL + "/\(group)/\(id)"
  }

  var linkIsImage: Bool {
    guard let topicLink else { return false }
    return ["png", "jpg", "jpeg"].contains(topicLink.pathExtension.lowercased())
  }
}
