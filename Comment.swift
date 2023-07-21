//
//  Comment.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/26/23.
//

import Foundation

struct Comment: Identifiable {
  let id: String
  var markdown: MarkdownString
  let createdDate: Date?
  var editedDate: Date?
  let user: String
  let repliesCount: Int
  let totalCount: Int // recursive replies count + 1 for self
  var votes: Int
  var isUserVoted: Bool
  var isUserBookmarked: Bool
  let depth: Int
  let isOriginalPoster: Bool
  var isCollapsed: Bool
  var isRemoved: Bool
  let removalReason: RemovalReason
  let canonicalLink: String
  let group: String
  let post: String
  let parent: String?
  let threadParent: String
  let isExemplary: Bool
  let isNew: Bool

  enum RemovalReason {
    case admin
    case user
  }
}

extension Comment {
  init(
    basicComment: TildesAPI.BasicComment,
    totalCount: Int = 1,
    isOriginalPoster: Bool,
    isCollapsed: Bool = false,
    parent: String?,
    threadParent: String,
    depthOverride: Int? = nil
  ) {
    self.id = basicComment.id
    self.markdown = basicComment.markdown
    self.createdDate = basicComment.createdDate
    self.editedDate = basicComment.editedDate
    self.user = basicComment.user
    self.repliesCount = basicComment.repliesCount
    self.totalCount = totalCount
    self.votes = basicComment.votes
    self.isUserVoted = basicComment.isUserVoted
    self.isUserBookmarked = basicComment.isUserBookmarked
    self.depth = depthOverride ?? basicComment.depth
    self.isOriginalPoster = isOriginalPoster
    self.isCollapsed = isCollapsed
    self.isRemoved = basicComment.isRemoved
    self.removalReason = basicComment.removalReason
    self.canonicalLink = basicComment.canonicalLink
    self.group = basicComment.group
    self.post = basicComment.post
    self.parent = parent
    self.threadParent = threadParent
    self.isExemplary = basicComment.isExemplary
    self.isNew = basicComment.isNew
  }
}

extension TildesAPI.BasicComment {
  var shortCreatedDate: String {
    createdDate?.shortFormattedString() ?? "-"
  }

  var shortEditedDate: String? {
    guard let date = editedDate else { return nil }

    return date.shortFormattedString()
  }
}

extension Comment {
  var shortCreatedDate: String {
    createdDate?.shortFormattedString() ?? "-"
  }

  var shortEditedDate: String? {
    guard let date = editedDate else { return nil }

    return date.shortFormattedString()
  }

  var isLoggedInUser: Bool {
    user == AccountManager.shared.loggedInUser
  }

  var labels: [CommentLabel] {
    var labs: [CommentLabel] = []
    if isNew { labs.append(.new) }
    if isExemplary { labs.append(.exemplary) }
    return labs
  }
}


extension TildesAPI.BasicComment {
  init(
    comment: Comment
  ) {
    self.id = comment.id
    self.markdown = comment.markdown
    self.createdDate = comment.createdDate
    self.editedDate = comment.editedDate
    self.user = comment.user
    self.repliesCount = comment.repliesCount
    self.votes = comment.votes
    self.isUserVoted = comment.isUserVoted
    self.isUserBookmarked = comment.isUserBookmarked
    self.depth = comment.depth
    self.isRemoved = comment.isRemoved
    self.removalReason = comment.removalReason
    self.canonicalLink = comment.canonicalLink
    self.group = comment.group
    self.post = comment.post
    self.isAlreadyCollapsed = false
    self.isExemplary = comment.isExemplary
    self.isNew = comment.isNew
  }
}
