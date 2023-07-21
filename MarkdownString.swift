//
//  MarkdownString.swift
//  Surfboard
//
//  Created by Théo Arrouye on 7/21/23.
//

import Foundation

struct MarkdownString {
  let originalContent: String
  let markdownContent: String

  init(html originalContent: String) {
    self.originalContent = originalContent
    self.markdownContent = originalContent//.htmlToMarkdown()
    // TODO: Also Publish the HTML -> Markdown Parser
  }

  init(markdown: String) {
    self.originalContent = markdown
    self.markdownContent = markdown
  }
}
