//
//  TildesAPI.swift
//  Surfboard
//
//  Created by Théo Arrouye on 6/21/23.
//

import Foundation
import SwiftSoup
import SwiftUI
import Combine

class TildesAPI {
  static let baseURL: String = "https://tildes.net"

  static let dateFormatter = ISO8601DateFormatter()

  static var stashedUsername: String? = nil
  static var stashedCsrfToken: String? = nil {
    didSet {
      DLog("[TildesAPI] Stashed Set CSRF Token \(stashedCsrfToken ?? "nil")")
    }
  }

  static func stashCSRFToken(from doc: Document, skipUsername: Bool = false) {
    // csrf
    if let csrf = getCSRFToken(from: doc) {
      stashedCsrfToken = csrf
    }

    guard !skipUsername else { return }
    // username
    let decodedLoggedUsername = (
      try? doc.select(".logged-in-user-info")
        .select(".logged-in-user-username")
        .first()?.text()
    ) ?? ""

    let adjusteduser = decodedLoggedUsername.isEmpty ? nil : decodedLoggedUsername
    //AccountManager.shared.setLoggedInUser(adjusteduser)
    DLog("[TildesAPI] " + (decodedLoggedUsername.isEmpty ? "Not logged in" : "Logged in as: \(decodedLoggedUsername)"))
  }

  static func getCSRFToken(from doc: Document) -> String? {
    do {
      let csrf_token = try doc.select("meta[name=csrftoken]").attr("content")
      return csrf_token.isEmpty ? nil : csrf_token
    } catch {
      return nil
    }
  }

  static func getCSRFToken(for url: URL) async -> String? {
    do {
      var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
      request.httpMethod = "GET"
      let (data, _) = try await URLSession.shared.data(for: request)
      let html = String(decoding: data, as: UTF8.self)

      let doc = try SwiftSoup.parse(html)
      return getCSRFToken(from: doc)
    } catch {
      return nil
    }
  }

  // MARK: - Login
  static func logIntoAccount(
    username: String,
    password: String
  ) async -> String? {
    do {
      var url = URL(string: baseURL)!
      url.appendPathComponent("login")
      guard let csrf = await getCSRFToken(for: url) else {
        throw TildesAPIError.missingCsrfToken
      }
      DLog("[TildesAPI] -logIntoAccount- Got CSRF Token \(csrf)")
      var request = URLRequest(url: url)

      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

      let body = ["username": username, "password": password, "csrf_token": csrf]
      request.httpBody = body.map { key, value in
        "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"
      }.joined(separator: "&").data(using: .utf8)

      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
      request.addValue("true", forHTTPHeaderField: "X-IC-Request")
      request.addValue(url.absoluteString, forHTTPHeaderField: "referer")

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode
      let html = String(decoding: data, as: UTF8.self)

      let doc = try SwiftSoup.parse(html)

      let needsTwoFactor = try doc.select("[data-ic-post-to=\"/login_two_factor\"]").first() != nil
      if needsTwoFactor {
        stashedCsrfToken = csrf
        stashedUsername = username
        return "2fa"
      } else if statusCode != 200 {
        return html.count < 100 ? html : statusCode != nil ? "\(statusCode!)" : "An error occurred"
      } else { // success
        //AccountManager.shared.setLoggedInUser(username)

        return nil
      }
    } catch {
      return "Unable to post request"
    }
  }

  static func twoFactorLogin(_ code: String) async throws -> String? {
    var url = URL(string: baseURL)!
    url.appendPathComponent("login_two_factor")

    guard let csrf = stashedCsrfToken else {
      throw TildesAPIError.missingCsrfToken
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
    request.addValue(baseURL+"/login", forHTTPHeaderField: "referer")

    let body = ["code": code, "ic-request": "false", "csrf_token": csrf]
    request.httpBody = body.map { key, value in
      "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"
    }.joined(separator: "&").data(using: .utf8)

    let (data, response) = try await URLSession.shared.data(for: request)
    let statusCode = (response as? HTTPURLResponse)?.statusCode

    let html = String(decoding: data, as: UTF8.self)

    if statusCode != 200 {
      return html.count < 100 ? html : statusCode != nil ? "\(statusCode!)" : "An error occurred"
    } else { // success
      //AccountManager.shared.setLoggedInUser(stashedUsername)
      stashedUsername = nil

      return nil
    }
  }

  // MARK: Logout
  static func logout() async -> String? {
    do {
      var url = URL(string: baseURL)!
      url.appendPathComponent("logout")
      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }

      var request = URLRequest(url: url)

      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
      request.addValue(url.absoluteString, forHTTPHeaderField: "referer")
      let body = ["csrf_token": csrf]
      request.httpBody = body.map { key, value in
        "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"
      }.joined(separator: "&").data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      let html = String(decoding: data, as: UTF8.self)
      if statusCode != 200 && statusCode != 403 {
        return html
      } else { // 200 success / 403 access denied (we aren't logged in anyways)
        //AccountManager.shared.setLoggedInUser(nil)
        DLog("[TildesAPI] -logout- Success")
        return nil
      }
    } catch {
      return "[TildesAPI] -logout- Unable to post request"
    }
  }

  // MARK: Notifications
  static func loadNotifications(unread: Bool) async -> [SBNotification] {
    //guard AccountManager.shared.isLoggedIn else { return [] }
    do {
      let referrer = baseURL
      var url = URL(string: baseURL)!
      url.appendPathComponent("notifications")
      if unread {
        url.appendPathComponent("unread")
      }
      var request = URLRequest(url: url)
      request.addValue(referrer, forHTTPHeaderField: "referer")

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      guard statusCode == 200 else { return [] }

      let html = String(decoding: data, as: UTF8.self)
      let doc = try SwiftSoup.parse(html)

      stashCSRFToken(from: doc)

      var notifications: [SBNotification] = []
      let notificationsList = try doc.select(".post-listing-notifications").select("li")
      for notifElement in notificationsList {
        guard
          let heading = try notifElement.select(".heading-notification").first()?.html(),
          let article = try notifElement.select("article").first(),
          let comment = parseBasicComment(from: article)
        else {
          continue
        }
        let notification = SBNotification(
          id: UUID().uuidString,
          heading: MarkdownString(html: heading),
          comment: comment,
          isRead: !unread
        )
        notifications.append(notification)
      }
      return notifications
    } catch {
      return []
    }
  }

  // MARK: - Load Feed
  static func loadFeed(
    group: String?,
    order: FeedOrder,
    after: String?,
    period: FeedOrderPeriod? = nil,
    search: String? = nil,
    unfiltered: Bool = false
  ) async -> ([FeedItem], Bool?, String?) {
    var topics = [FeedItem]()

    do {
      var url = URL(string: baseURL)!
      if let group = group?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        url.appendPathComponent(group)
      }
      var queryItems: [URLQueryItem] = []
      if let search {
        url.appendPathComponent("search")
        queryItems.append(.init(name: "q", value: urlPrepSearch(search)!))
      }
      if let after {
        queryItems.append(.init(name: "after", value: after))
      }

      queryItems.append(.init(name: "order", value: order.apiName))

      if order.canSelectPeriod, let periodName = period?.apiName {
        queryItems.append(.init(name: "period", value: periodName))
      }
      if unfiltered {
        queryItems.append(.init(name: "unfiltered", value: "true"))
      }
      url.append(queryItems: queryItems)
      var request = URLRequest(url: url)
      request.addValue(baseURL, forHTTPHeaderField: "referer")

      let (data, _) = try await URLSession.shared.data(for: request)
      let html = String(decoding: data, as: UTF8.self)

      let doc = try SwiftSoup.parse(html)
      stashCSRFToken(from: doc)

      let empty = try doc.select(".empty-title").first()?.text()

      var isFiltered: Bool? = nil
      if let filterEl = try doc.select(".topic-listing-filter").first()?.text(), !filterEl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        isFiltered = filterEl.contains("View unfiltered list")
      }

      let topicList = try doc.select("ol.topic-listing")
      let listItems = try topicList.select(".topic")

      for listItem in listItems {
        if let topic = try? parseFeedItem(from: listItem, group: group) {
          topics.append(topic)
        }
      }
      return (topics, isFiltered, empty)
    } catch {
      return ([], nil, "An error occurred.")
    }
  }

  private static func parseFeedItem(from listItem: Element, group: String?) throws -> FeedItem {
    let id = try listItem.select("article").attr("id").firstMatch(of: /topic-(.*)/)!.1
    let titleT = try listItem.select(".topic-title")
    let title = try titleT.text()
    let topicLink = try titleT.select("a").attr("href")
    let parsedGroup = try listItem.select(".topic-group").text()
    let tags = (try? listItem.select(".label-topic-tag").compactMap { try? $0.select("a").text() }) ?? []
    let type = try? listItem.select(".topic-content-type").text()
    let commentsEl = try listItem.select(".topic-info-comments").select("a")
    let comments = try commentsEl.text().firstMatch(of: /(\d+)/)?.0 ?? "0"
    let newCommentsEl = try listItem.select(".topic-info-comments-new")
    let newComments = try newCommentsEl.text().firstMatch(of: /(\d+)/)?.0 ?? "0"
    let sourceEl = try listItem.select(".topic-info-source")
    let source = try sourceEl.text()
    let userLink = try? sourceEl.select(".link-user").attr("href")
    let datetime = try listItem.select(".time-responsive").attr("datetime")
    let date = dateFormatter.date(from: datetime)
    let votes = try listItem.select(".topic-voting-votes").text()
    let isUserVoted = try listItem.select("[data-ic-delete-from=\"https://tildes.net/api/web/topics/\(id)/vote\"]").first() != nil
    let isUserBookmarked = try listItem.select("[data-ic-delete-from=\"https://tildes.net/api/web/topics/\(id)/bookmark\"]").first() != nil
    let isUserIgnored = try listItem.select("[data-ic-delete-from=\"https://tildes.net/api/web/topics/\(id)/ignore\"]").first() != nil

    let isUserSource = userLink != nil && !userLink!.isEmpty

    let topic = FeedItem(
      id: String(id),
      title: title,
      topicLink: URL(string: topicLink),
      group: (parsedGroup.isEmpty && group != nil) ? group! : parsedGroup,
      tags: tags,
      type: type,
      comments: Int(comments) ?? 0,
      newComments: Int(newComments) ?? 0,
      source: source,
      isUserSource: isUserSource,
      date: date,
      votes: Int(votes) ?? 0,
      isUserVoted: isUserVoted,
      isUserBookmarked: isUserBookmarked,
      isUserIgnored: isUserIgnored
    )

    return topic
  }

  // MARK: - Load Post
  static func loadPost(id: String, group: String, commentOrder: CommentOrder) async -> (Post, [Comment])? {
    do {
      var url = URL(string: baseURL)!
      url.appendPathComponent(group)
      let referrer = url.absoluteString
      url.appendPathComponent(id)
      url.append(queryItems: [.init(name: "comment_order", value: commentOrder.apiName)])
      var request = URLRequest(url: url)
      request.addValue(referrer, forHTTPHeaderField: "referer")

      let (data, _) = try await URLSession.shared.data(for: request)
      //let statusCode = (response as? HTTPURLResponse)?.statusCode

      let html = String(decoding: data, as: UTF8.self)
      let doc = try SwiftSoup.parse(html)
      stashCSRFToken(from: doc, skipUsername: true)

      let topicBody = try doc.select(".topic-full")

      let title = try topicBody.select("header > h1").text()
      let tags = (try? topicBody.select(".topic-full-tags > a").compactMap { try? $0.text() }) ?? []
      let topicLink = try topicBody.select(".topic-full-link > a").attr("href")
      let commentsCountString = try topicBody.select(".topic-comments-header > h2").text().firstMatch(of: /(\d+)/)?.0 ?? "0"
      let commentsCount = Int(commentsCountString) ?? 0
      let user = try topicBody.select(".topic-full-byline > .link-user").text()
      let datetime = try topicBody.select(".time-responsive").attr("datetime")
      let date = dateFormatter.date(from: datetime)
      let votes = try topicBody.select(".topic-voting-votes").text()
      let isUserVoted = try topicBody.select("[data-ic-delete-from=\"https://tildes.net/api/web/topics/\(id)/vote\"]").first() != nil
      let isUserBookmarked = try topicBody.select("[data-ic-delete-from=\"https://tildes.net/api/web/topics/\(id)/bookmark\"]").first() != nil
      let isUserIgnored = try topicBody.select("[data-ic-delete-from=\"https://tildes.net/api/web/topics/\(id)/ignore\"]").first() != nil
      let body = try topicBody.select(".topic-full-text").html() // html

      var commentBag: [Comment] = []
      if let commentsTree = try doc.select(".comment-tree").first() {
        _ = try await parseComments(from: commentsTree, originalPoster: user, basePath: url.absoluteString, parent: nil, threadParent: nil, into: &commentBag)
      }

      let post = Post(
        id: id,
        group: group,
        title: title,
        body: MarkdownString(html: body),
        topicLink: URL(string: topicLink),
        tags: tags,
        source: !user.isEmpty ? user : "Automatically posted",
        isUserSource: !user.isEmpty,
        date: date,
        votes: Int(votes) ?? 0,
        isUserVoted: isUserVoted,
        isUserBookmarked: isUserBookmarked,
        isUserIgnored: isUserIgnored,
        commentsCount: commentsCount
      )
      return (post, commentBag)
    } catch {
      //
    }

    return nil
  }

//  static private func getMarkdownForComment(id: String, post: String, group: String) async -> String {
//    do {
//      let referrer: String
//      if post.isEmpty || group.isEmpty {
//        referrer = baseURL
//      } else {
//        referrer = URL(string: baseURL)!
//          .appendingPathComponent(group)
//          .appendingPathComponent(post)
//          .absoluteString
//      }
//
//      var url = URL(string: baseURL)!
//        .appendingPathComponent("api")
//        .appendingPathComponent("web")
//        .appendingPathComponent("comments")
//        .appendingPathComponent(id)
//
//      var queryItems: [URLQueryItem] = []
//      queryItems.append(.init(name: "ic-element-name", value: "markdown-source"))
//      queryItems.append(.init(name: "ic-trigger-name", value: "markdown-source"))
//      queryItems.append(.init(name: "ic-request", value: "true"))
//      queryItems.append(.init(name: "ic-id", value: "7"))
//      url.append(queryItems: queryItems)
//
//      var request = URLRequest(url: url)
//
//      guard let csrf = stashedCsrfToken else {
//        throw TildesAPIError.missingCsrfToken
//      }
//      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
//
//      request.httpMethod = "GET"
//      request.addValue(referrer, forHTTPHeaderField: "referer")
//      request.addValue("true", forHTTPHeaderField: "x-ic-request")
//
//      let (data, response) = try await URLSession.shared.data(for: request)
//      let statusCode = (response as? HTTPURLResponse)?.statusCode
//
//      guard statusCode == 200 else { return "" }
//
//      let html = String(decoding: data, as: UTF8.self)
//      let doc = try SwiftSoup.parse(html)
//
//      let markdownSource = try doc.select("[name=markdown-source]").first()?.text()
//      DLog(markdownSource)
//      return markdownSource ?? ""
//    } catch {
//      return ""
//    }
//  }

  struct BasicComment: Identifiable {
    let id: String
    let repliesCount: Int
    let depth: Int
    let isRemoved: Bool
    let removalReason: Comment.RemovalReason
    let canonicalLink: String
    let group: String
    let post: String
    let markdown: MarkdownString
    let user: String
    let createdDate: Date?
    let editedDate: Date?
    var votes: Int
    var isUserVoted: Bool
    var isUserBookmarked: Bool
    let isAlreadyCollapsed: Bool
    let isExemplary: Bool
    let isNew: Bool
  }

  static private func parseBasicComment(from comment: SwiftSoup.Element) -> BasicComment? {
    do {
      let article = try comment.select("article").first()!
      let id = try article.attr("data-comment-id36")
      let isNew = article.hasClass("is-comment-new")
      var isExemplary = article.hasClass("is-comment-exemplary")
      let repliesCountString = try article.attr("data-comment-replies")
      let depth = try article.attr("data-comment-depth")

      let isAlreadyCollapsed = try article.select(".is-comment-collapsed").first()?.attr("data-comment-id36") == id
      let commentItself = try comment.select(".comment-itself").first()!

      let commentLabels = try commentItself.select(".comment-labels")
      if !isExemplary, (try? commentLabels.select(".label-comment-exemplary").first()) != nil {
        isExemplary = true
      }

      let isRemoved = try commentItself.select(".is-comment-removed").first() != nil
      let isDeleted = try commentItself.select(".is-comment-deleted").first() != nil

      var commentLink: String = ""
      let commentLinks = try commentItself.select(".comment-nav-link")
      for l in commentLinks {
        let href = try l.attr("href")
        if href.hasSuffix(id) {
          commentLink = href
        }
      }

      let linkRegOutput = commentLink.firstMatch(of: /(~[a-zA-Z\.\-_]+)\/([a-zA-Z0-9]+)/)?.output

      let body = try commentItself.select(".comment-text").html() // html

      let user = try commentItself.select(".comment-header > .link-user").text()

      let postedTime = try commentItself.select(".comment-posted-time").attr("datetime")
      let editedTime = try commentItself.select(".comment-edited-time > .time-responsive").attr("datetime")
      let createdDate = dateFormatter.date(from: postedTime)
      let editedDate = dateFormatter.date(from: editedTime)

      let isUserVoted = try commentItself.select("[data-ic-delete-from=\"https://tildes.net/api/web/comments/\(id)/vote\"]").first() != nil
      let votesString: Substring
      if let x = try commentItself.select(".comment-votes").first?.text().firstMatch(of: /(\d+)/)?.0 {
        votesString = x
      } else {
        votesString = try commentItself.select(".btn-post").first()?.text().firstMatch(of: /(\d+)/)?.0 ?? "0"
      }
      let votes = Int(votesString) ?? 0
      let isUserBookmarked = try commentItself.select("[data-ic-delete-from=\"https://tildes.net/api/web/comments/\(id)/bookmark\"]").first() != nil

      let group = String(linkRegOutput!.1)
      let post = String(linkRegOutput!.2)

      let markdown = MarkdownString(html: body)

      return BasicComment(
        id: id,
        repliesCount: Int(repliesCountString) ?? 0,
        depth: Int(depth) ?? 0,
        isRemoved: isRemoved || isDeleted,
        removalReason: isRemoved ? .admin : .user,
        canonicalLink: baseURL + commentLink,
        group: group,
        post: post,
        markdown: markdown,
        user: user,
        createdDate: createdDate,
        editedDate: editedDate,
        votes: votes,
        isUserVoted: isUserVoted,
        isUserBookmarked: isUserBookmarked,
        isAlreadyCollapsed: isAlreadyCollapsed,
        isExemplary: isExemplary,
        isNew: isNew
      )
    } catch {
      return nil
    }
  }

  static func parseComments(from commentsTree: Element, originalPoster: String, basePath: String, parent: String?, threadParent: String?, into commentBag: inout [Comment]) async throws -> Int {
    let comments = try commentsTree.select("> .comment-tree-item")
    var returnCount: Int = 0
    for comment in comments {
      guard let basicComment = parseBasicComment(from: comment) else { continue }

      var count: Int = 1
      let indexBefore: Int = commentBag.count
      if let repliesHtml = try comment.select(".comment-tree-replies").first() {
        count += try await parseComments(from: repliesHtml, originalPoster: originalPoster, basePath: basePath, parent: basicComment.id, threadParent: threadParent ?? basicComment.id, into: &commentBag)
      }

      let comment = Comment(
        basicComment: basicComment,
        totalCount: count,
        isOriginalPoster: basicComment.user == originalPoster,
        isCollapsed: UserPreferences.shared.respectWebCollapsed && basicComment.isAlreadyCollapsed,
        parent: parent,
        threadParent: threadParent ?? basicComment.id
      )
      commentBag.insert(comment, at: indexBefore)
      returnCount += count
    }
    return returnCount
  }

  static func urlPrepSearch(_ text: String) -> String? {
    text
      .replacingOccurrences(of: " ", with: "+")
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
      .replacingOccurrences(of: "&", with: "%26")
  }

  static func urlPrepMarkdown(_ text: String) -> String? {
    text
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
      .replacingOccurrences(of: "+", with: "%2B")
      .replacingOccurrences(of: " ", with: "+")
      .replacingOccurrences(of: "&", with: "%26")
  }

  // MARK: - Create Post
  struct CreatePostResponse {
    let postID: String?
    let retryAfter: Int?

    var didSucceed: Bool {
      postID != nil
    }
  }

  static func createPost(group: String, title: String, link: String, markdown: String, tags: [String]) async -> CreatePostResponse {
    do {
      let groupURL = URL(string: baseURL)!.appendingPathComponent(group)
      let referrer = groupURL.absoluteString

      let url = groupURL.appendingPathComponent("topics")

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        DLog("[TildesAPI] Post in \(group) failed due to missing CSRF Token")
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")

      let body = [
        "title": title,
        "link": link,
        "markdown": urlPrepMarkdown(markdown)!,
        "tags": tags.joined(separator: ",")
      ]

      request.httpBody = body.map { key, value in
        "\(key)=\(value)"
      }.joined(separator: "&").data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        DLog("[TildesAPI] Post in \(group) missing HTTPResponse")
        throw TildesAPIError.nonHTTPUrlResponse
      }

      if let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"), let secs = Int(retryAfter) {
        DLog("[TildesAPI] Post in \(group) is rate limited for \(retryAfter) more seconds")
        return .init(postID: nil, retryAfter: secs)
      }

      let statusCode = httpResponse.statusCode
      guard statusCode == 200 else {
        DLog("[TildesAPI] Post in \(group) has a bad status code \(statusCode)")
        throw TildesAPIError.badStatusCode(statusCode)
      }
      
      guard let redirectURL = httpResponse.value(forHTTPHeaderField: "X-IC-Redirect") else {
        DLog("[TildesAPI] Post in \(group) didn't return a redirect URL")
        throw TildesAPIError.missingRedirectUrl
      }

      DLog("[TildesAPI] Post in \(group) returned redirect \(redirectURL)")

      let html = String(decoding: data, as: UTF8.self)
      guard html.isEmpty else {
        DLog("[TildesAPI] Post in \(group) had non-empty response \(html)")
        throw TildesAPIError.expectedEmptyResponse
      }

      // match tildes topic urls
      guard let match = redirectURL.firstMatch(of: Regexes.onlyGroupAndPost), match.output.1 == group else {
        DLog("[TildesAPI] Didn't like that redirect URL.")
        throw TildesAPIError.badRedirectUrl
      }
      let post = String(match.output.2)
      DLog("[TildesAPI] Successfully posted in \(group). New Post ID: \(post)")

      return .init(postID: post, retryAfter: nil)
    } catch {
      switch error {
      case let tError as TildesAPIError:
        switch tError {
        case .missingRedirectUrl, .badRedirectUrl, .expectedEmptyResponse:
          let doubleCheck = await getLatestPostFromFeed(group: group, checkTitle: title)
          return .init(postID: doubleCheck, retryAfter: nil)
        default:
          break
        }
      default:
        break
      }

      return .init(postID: nil, retryAfter: nil)
    }
  }

  private static func getLatestPostFromFeed(group: String, checkTitle: String) async -> String? {
    do {
      let url = URL(string: baseURL)!
        .appendingPathComponent(group)
        .appending(queryItems: [.init(name: "order", value: "new")])
      var request = URLRequest(url: url)
      request.addValue(baseURL, forHTTPHeaderField: "referer")

      let (data, _) = try await URLSession.shared.data(for: request)
      let html = String(decoding: data, as: UTF8.self)

      let doc = try SwiftSoup.parse(html)
      stashCSRFToken(from: doc)

      let topicList = try doc.select("ol.topic-listing")
      guard let myPost = try topicList.select(".is-topic-mine").first() else {
        return nil
      }

      let id = try? myPost.attr("id").firstMatch(of: /topic-(.*)/)?.1

      guard try myPost.select(".topic-title").text().trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == checkTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
        return nil
      }

      return id != nil ? String(id!) : nil
    } catch {
      return nil
    }
  }

  // MARK: Post Actions
  static func editPost(id: String, body: String) async -> (Int, String) {
    do {
      let referrer: String = baseURL

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("topics")
        .appendingPathComponent(id)

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "PATCH"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")

      let body = ["markdown": urlPrepMarkdown(body)!]
      request.httpBody = body.map { key, value in
        "\(key)=\(value)"
      }.joined(separator: "&").data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      let html = String(decoding: data, as: UTF8.self)

      return (statusCode ?? 404, html)
    } catch {
      return (404, "")
    }
  }

  static func replyToPost(id: String, group: String?, body: String) async -> (Int, BasicComment?) {
    do {
      let referrer: String
      if id.isEmpty || group == nil || group!.isEmpty {
        referrer = baseURL
      } else {
        referrer = URL(string: baseURL)!
          .appendingPathComponent(group!)
          .appendingPathComponent(id)
          .absoluteString
      }

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("topics")
        .appendingPathComponent(id)
        .appendingPathComponent("comments")

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      let body = ["markdown": urlPrepMarkdown(body)!]
      request.httpBody = body.map { key, value in
        "\(key)=\(value)"
      }.joined(separator: "&").data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      let html = String(decoding: data, as: UTF8.self)
      let doc = try SwiftSoup.parse(html)

      let article = try doc.select("article").first()
      let comment: BasicComment? = article != nil ? parseBasicComment(from: article!) : nil

      return (statusCode ?? 404, comment)
    } catch {
      return (404, nil)
    }
  }

  static func deletePost(id: String) async -> Bool {
    do {
      let referrer: String = baseURL

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("topics")
        .appendingPathComponent(id)

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "DELETE"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")

      let (_, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      if statusCode != 200 {
        DLog("[TildesAPI] Failed to delete post \(id)")
      }
      return statusCode == 200
    } catch {
      DLog("[TildesAPI] Failed to delete post \(id)\nError: \(error.localizedDescription)")
      return false
    }
  }

  static func putVoteOnPost(id: String, group: String?) async -> Bool {
    return await actOnPost(action: .vote, id: id, group: group, method: .put)
  }

  static func deleteVoteOnPost(id: String, group: String?) async -> Bool {
    return await actOnPost(action: .vote, id: id, group: group, method: .delete)
  }

  static func putBookmarkOnPost(id: String, group: String?) async -> Bool {
    return await actOnPost(action: .bookmark, id: id, group: group, method: .put)
  }

  static func deleteBookmarkOnPost(id: String, group: String?) async -> Bool {
    return await actOnPost(action: .bookmark, id: id, group: group, method: .delete)
  }

  static func putIgnoreOnPost(id: String, group: String?) async -> Bool {
    return await actOnPost(action: .ignore, id: id, group: group, method: .put)
  }

  static func deleteIgnoreOnPost(id: String, group: String?) async -> Bool {
    return await actOnPost(action: .ignore, id: id, group: group, method: .delete)
  }

  private enum PostAction: String {
    case ignore
    case bookmark
    case vote
  }

  private static func actOnPost(action: PostAction, id: String, group: String?, method: HTTPMethod) async -> Bool {
    do {
      let referrer: String
      if id.isEmpty || group == nil || group!.isEmpty {
        referrer = baseURL
      } else {
        referrer = URL(string: baseURL)!
          .appendingPathComponent(group!)
          .appendingPathComponent(id)
          .absoluteString
      }

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("topics")
        .appendingPathComponent(id)
        .appendingPathComponent(action.rawValue)

      var request = URLRequest(url: url)

      request.httpMethod = method.rawValue
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      let (_, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      if statusCode != 200 {
        DLog("[TildesAPI] Failed to \(method.rawValue) \(action.rawValue) on post \(id)")
      }
      return statusCode == 200
    } catch {
      DLog("[TildesAPI] Failed to \(method.rawValue) \(action.rawValue) on post \(id)\nError: \(error.localizedDescription)")
      return false
    }
  }

  // MARK: - Comment Actions
  static func editComment(id: String, body: String) async -> (Int, String?) {
    do {
      let referrer: String = baseURL

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("comments")
        .appendingPathComponent(id)

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "PATCH"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")

      let body = ["markdown": urlPrepMarkdown(body)!]
      request.httpBody = body.map { key, value in
        "\(key)=\(value)"
      }.joined(separator: "&").data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      let html = String(decoding: data, as: UTF8.self)
      let doc = try SwiftSoup.parse(html)

      let commentItself = try doc.select(".comment-itself").first()
      let newCommentBody = try commentItself?.select(".comment-text").html()

      return (statusCode ?? 404, newCommentBody)
    } catch {
      return (404, nil)
    }
  }

  static func deleteComment(id: String) async -> Bool {
    do {
      let referrer: String = baseURL

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("comments")
        .appendingPathComponent(id)

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "DELETE"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")

      let (_, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      if statusCode != 200 {
        DLog("[TildesAPI] Failed to delete comment \(id)")
      }
      return statusCode == 200
    } catch {
      DLog("[TildesAPI] Failed to delete comment \(id)\nError: \(error.localizedDescription)")
      return false
    }
  }

  static func replyToComment(id: String, postId: String, group: String?, body: String) async -> (Int, BasicComment?) {
    do {
      let referrer: String
      if postId.isEmpty || group == nil || group!.isEmpty {
        referrer = baseURL
      } else {
        referrer = URL(string: baseURL)!
          .appendingPathComponent(group!)
          .appendingPathComponent(postId)
          .absoluteString
      }

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("comments")
        .appendingPathComponent(id)
        .appendingPathComponent("replies")

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")

      let body = ["markdown": urlPrepMarkdown(body)!]
      request.httpBody = body.map { key, value in
        "\(key)=\(value)"
      }.joined(separator: "&").data(using: .utf8)

      let (data, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      let html = String(decoding: data, as: UTF8.self)
      let doc = try SwiftSoup.parse(html)

      let article = try doc.select("article").first()
      let comment: BasicComment? = article != nil ? parseBasicComment(from: article!) : nil

      return (statusCode ?? 404, comment)
    } catch {
      return (404, nil)
    }
  }

  private enum CommentAction: String {
    case vote
    case bookmark
    case markRead = "mark_read"
  }

  private enum HTTPMethod: String {
    case put = "PUT"
    case delete = "DELETE"
  }


  static func putVoteOnComment(id: String, postId: String, group: String?) async -> Bool {
    return await actOnComment(action: .vote, id: id, postId: postId, group: group, method: .put)
  }

  static func deleteVoteOnComment(id: String, postId: String, group: String?) async -> Bool {
    return await actOnComment(action: .vote, id: id, postId: postId, group: group, method: .delete)
  }

  static func putBookmarkOnComment(id: String, postId: String, group: String?) async -> Bool {
    return await actOnComment(action: .bookmark, id: id, postId: postId, group: group, method: .put)
  }

  static func deleteBookmarkOnComment(id: String, postId: String, group: String?) async -> Bool {
    return await actOnComment(action: .bookmark, id: id, postId: postId, group: group, method: .delete)
  }

  static func markCommentRead(id: String, postId: String, group: String?) async -> Bool {
    return await actOnComment(action: .markRead, id: id, postId: postId, group: group, method: .put)
  }

  private static func actOnComment(action: CommentAction, id: String, postId: String, group: String?, method: HTTPMethod) async -> Bool {
    do {
      let referrer: String
      if postId.isEmpty || group == nil || group!.isEmpty {
        referrer = baseURL
      } else {
        referrer = URL(string: baseURL)!
          .appendingPathComponent(group!)
          .appendingPathComponent(postId)
          .absoluteString
      }

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("comments")
        .appendingPathComponent(id)
        .appendingPathComponent(action.rawValue)

      var request = URLRequest(url: url)

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")
      request.addValue(method.rawValue, forHTTPHeaderField: "X-HTTP-Method-Override")

      let (_, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      if statusCode != 200 {
        DLog("[TildesAPI] Failed to \(method.rawValue) \(action.rawValue) on comment \(id)")
      }
      return statusCode == 200
    } catch {
      DLog("[TildesAPI] Failed to \(method.rawValue) \(action.rawValue) on comment \(id)\nError: \(error.localizedDescription)")
      return false
    }
  }

  // MARK: - Groups
  struct Group {
    let name: String
    let description: String
    let activity: String
    var isSubscribed: Bool
  }

  static func loadGroups() async -> [Group] {
    var groups = [Group]()

    do {
      let url = URL(string: baseURL)!.appendingPathComponent("groups")
      var request = URLRequest(url: url)
      request.addValue(baseURL, forHTTPHeaderField: "referer")

      let (data, _) = try await URLSession.shared.data(for: request)
      let html = String(decoding: data, as: UTF8.self)

      let doc = try SwiftSoup.parse(html)
      stashCSRFToken(from: doc)

      let groupList = try doc.select("ol.group-list")
      let subscribedGroups = try groupList.select(".group-list-item-subscribed")
      let unsubscribedGroups = try groupList.select(".group-list-item-not-subscribed")

      func parseGroupData(from item: Element, isSubscribed: Bool) throws -> Group {
        let name = try item.select(".link-group").text()
        let description = try item.select(".group-list-description").text()
        let activity = try item.select(".group-list-activity").text()

        let group = Group(name: name, description: description, activity: activity, isSubscribed: isSubscribed)
        return group
      }

      groups.append(contentsOf: subscribedGroups.compactMap { try? parseGroupData(from: $0, isSubscribed: true) })
      groups.append(contentsOf: unsubscribedGroups.compactMap { try? parseGroupData(from: $0, isSubscribed: false) })
      return groups
    } catch {
      return []
    }
  }

  private enum GroupAction: String {
    case subscribe
  }

  private static func actOnGroup(action: GroupAction, group: String, method: HTTPMethod) async -> Bool {
    do {
      let referrer = URL(string: baseURL)!.appendingPathComponent(group).absoluteString

      guard let csrf = stashedCsrfToken else {
        throw TildesAPIError.missingCsrfToken
      }

      let noTildeGroup = String(group.suffix(group.count - 1))

      let url = URL(string: baseURL)!
        .appendingPathComponent("api")
        .appendingPathComponent("web")
        .appendingPathComponent("group")
        .appendingPathComponent(noTildeGroup)
        .appendingPathComponent(action.rawValue)

      var request = URLRequest(url: url)

      request.httpMethod = method.rawValue
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      request.addValue(referrer, forHTTPHeaderField: "referer")
      request.addValue("true", forHTTPHeaderField: "x-ic-request")
      request.addValue(csrf, forHTTPHeaderField: "X-CSRF-Token")

      let (_, response) = try await URLSession.shared.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      if statusCode != 200 {
        DLog("[TildesAPI] Failed to \(method.rawValue) \(action.rawValue) on group \(noTildeGroup) (\(group))")
      }
      return statusCode == 200
    } catch {
      DLog("[TildesAPI] Failed to \(method.rawValue) \(action.rawValue) on group \(group)\nError: \(error.localizedDescription)")
      return false
    }
  }

  static func subscribeToGroup(_ group: String) async -> Bool {
    return await actOnGroup(action: .subscribe, group: group, method: .put)
  }

  static func unsubscribeFromGroup(_ group: String) async -> Bool {
    return await actOnGroup(action: .subscribe, group: group, method: .delete)
  }

  // MARK: - User Pages
  struct UserPageComment {
    var id: String { comment.id }
    let heading: MarkdownString
    var comment: TildesAPI.BasicComment
    var isCollapsed: Bool = false
  }

  struct UserBio {
    let username: String
    let joinDate: String
    var bio: MarkdownString?
  }

  enum UserPageType: String {
    case comment
    case topic
  }

  struct UserPageResponse {
    let bio: UserBio?
    let topics: [FeedItem]
    let comments: [UserPageComment]
  }

  static func loadUserPage(
    username: String,
    type: UserPageType?,
    after: String? = nil
  ) async -> UserPageResponse {
    var topics = [FeedItem]()
    var comments = [UserPageComment]()

    var userBio: UserBio? = nil

    do {
      var url = URL(string: baseURL)!.appendingPathComponent("user").appendingPathComponent(username)

      var queryItems: [URLQueryItem] = []
      if let type {
        queryItems.append(.init(name: "type", value: type.rawValue))
      }
      if let after {
        queryItems.append(.init(name: "after", value: after))
      }
      url.append(queryItems: queryItems)

      var request = URLRequest(url: url)
      request.addValue(baseURL, forHTTPHeaderField: "referer")

      let (data, _) = try await URLSession.shared.data(for: request)
      let html = String(decoding: data, as: UTF8.self)

      let doc = try SwiftSoup.parse(html)
      stashCSRFToken(from: doc)

      let sidebar = try doc.select("[id=\"sidebar\"]")
      let dds = try sidebar.select("dd")
      var registered: String? = nil
      var bio: String? = nil
      if dds.count > 0 {
        registered = try? dds[0].text()
      }
      if dds.count > 1 {
        bio = try? dds[1].html()
      }

      if let registered {
        userBio = UserBio(username: username, joinDate: registered, bio: nil)
      }

      if let bio {
        userBio?.bio = .init(html: bio)
      }

      let postList = try doc.select("ol.post-listing")
      let topicItems = try postList.select(".topic")
      let commentItems = try postList.select(".comment")

      for listItem in topicItems {
        if let topic = try? parseFeedItem(from: listItem, group: nil) {
          topics.append(topic)
        }
      }

      for listItem in commentItems {
        if
          let header = try? listItem.parent()?.select(".heading-post-listing").first()?.html(),
          let comment = parseBasicComment(from: listItem)
        {
          comments.append(UserPageComment(heading: .init(html: header), comment: comment))
        }
      }
    } catch {
     //
    }

    return UserPageResponse(bio: userBio, topics: topics, comments: comments)
  }
}

enum TildesAPIError: Error {
  case missingCsrfToken
  case nonHTTPUrlResponse
  case badStatusCode(_ statusCode: Int)
  case missingRedirectUrl
  case expectedEmptyResponse
  case badRedirectUrl
}
