//
//  FeedOrder.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/26/23.
//

import Foundation

enum FeedOrder: Int, CaseIterable {
  case activity = 0
  case votes = 1
  case comments = 2
  case new = 3
  case allActivity = 4

  var apiName: String {
    switch self {
    case .activity: return "activity"
    case .votes: return "votes"
    case .comments: return "comments"
    case .allActivity: return "all_activity"
    case .new: return "new"
    }
  }

  var iconName: String {
    switch self {
    case .votes: return "arrow.up"
    case .comments: return "bubble.left"
    case .new: return "clock"
    case .activity: return "trophy"
    case .allActivity: return "arrow.up.and.down.text.horizontal"
    }
  }

  var displayName: String {
    switch self {
    case .votes: return "Votes"
    case .comments: return "Comments"
    case .activity: return "Activity"
    case .new: return "New"
    case .allActivity: return "All Activity"
    }
  }

  var canSelectPeriod: Bool {
    switch self {
    case .new:
      return false
    default:
      return true
    }
  }
}

extension FeedOrder: PickerValue {
  var pickerId: Int { rawValue }
  var pickerLabel: String { displayName }
}
