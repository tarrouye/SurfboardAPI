//
//  CommentOrder.swift
//  Surfboard
//
//  Created by Théo Arrouye on 7/21/23.
//

import Foundation

enum CommentOrder: Int, CaseIterable {
  case votes = 0
  case newestFirst = 1
  case oldestFirst = 2
  case relevance = 3

  var apiName: String {
    switch self {
    case .votes: return "votes"
    case .newestFirst: return "newest"
    case .oldestFirst: return "oldest"
    case .relevance: return "relevance"
    }
  }

  var displayName: String {
    switch self {
    case .votes: return "Votes"
    case .newestFirst: return "Newest First"
    case .oldestFirst: return "Order Posted"
    case .relevance: return "Relevance"
    }
  }
}

extension CommentOrder: PickerValue {
  var pickerId: Int { rawValue }
  var pickerLabel: String { displayName}
}
