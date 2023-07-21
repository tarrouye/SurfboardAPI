//
//  SBNotification.swift
//  Surfboard
//
//  Created by Théo Arrouye on 7/21/23.
//

import Foundation

struct SBNotification {
  let id: String
  let heading: MarkdownString
  var comment: TildesAPI.BasicComment
  var isRead: Bool
  var isCollapsed: Bool = false
}
