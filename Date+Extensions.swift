//
//  Date+Extensions.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/26/23.
//

import Foundation

extension Date {
  func shortFormattedString() -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 1
    formatter.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute]
    formatter.allowsFractionalUnits = true

    return formatter.string(from: self, to: Date()) ?? "-"
  }
}
