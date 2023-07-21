//
//  FeedOrderPeriod.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/26/23.
//

import Foundation

enum FeedOrderPeriod: Int, CaseIterable {
  case websiteDefault = 0
  case lastHour = 1
  case lastTwelveHours = 2
  case lastDay = 3
  case lastThreeDays = 4
  case lastWeek = 5
  case lastMonth = 6
  case lastSixMonth = 7
  case lastYear = 8
  case allTime = 9

  var apiName: String? {
    switch self {
    case .lastHour: return "1h"
    case .lastTwelveHours: return "12h"
    case .lastDay: return "24h"
    case .lastThreeDays: return "3d"
    case .lastWeek: return "7d"
    case .lastMonth: return "30d"
    case .lastSixMonth: return "182d"
    case .lastYear: return "365d"
    case .allTime: return "all"
    case .websiteDefault: return nil
    }
  }

  var displayName: String {
    switch self {
    case .lastHour: return "Hour"
    case .lastTwelveHours: return "12 Hours"
    case .lastDay: return "Day"
    case .lastThreeDays: return "Three Days"
    case .lastWeek: return "Week"
    case .lastMonth: return "Month"
    case .lastSixMonth: return "½ Year"
    case .lastYear: return "Year"
    case .allTime: return "All Time"
    case .websiteDefault: return "Unspecified"
    }
  }

  static var displayedCases: [FeedOrderPeriod] = [
    .lastHour, .lastDay, .lastWeek, .lastMonth, .lastSixMonth, .lastYear, .allTime
  ]
}

extension FeedOrderPeriod: PickerValue {
  var pickerId: Int { rawValue }
  var pickerLabel: String { displayName }
}
