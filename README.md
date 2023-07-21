# SurfboardAPI
A Swift implementation of a basic API for Tildes.net

## Warnings

**This is an incomplete and imperfect implementation.** 
As long as this message is still here, no support is guaranteed, and breaking changes may happen at any point. 
**Documentation is incomplete.** Some parts may be broken or incomplete because this was ripped from a larger project and has not been properly modularized yet. 

## Implementation

### Data Structures

- `Comment`
- `BasicComment`
- `FeedItem`
- `Post`
- `MarkdownString`
- `FeedOrder`
- `FeedOrderPeriod`
- `CommentOrder`
- `SBNotification`
- `CreatePostResponse`
- `UserPageType`
- `UserPageResponse`

### Interface

#### Login/Logout
- `logIntoAccount` `async`
  - parameters: `username: String`, `password: String`
  - returns: `error: String?`
    - if `error` == `2fa`, you should followup with a call to `twoFactorLogin`
    - if `error` is `nil`, the login was successful
    - if `error` is not `nil` and not `2fa`, then some error occurrred.
- `twoFactorLogin` `async`
  - parameters: `code: String`
  - returns: `error: String?`
    - if `error` is `nil`, the login was successful
    - if `error` is not `nil`, some error occurred.
- `logout` `async`
  - returns: `error: String?`

#### Notifications
- `loadNotifications` `async`
  - parameters: `unread: Bool` -> `false` means load read notifications, `true` means load unread notifications
  - returns: `notifications: [SBNotification]`
    - WARNING: Currently this only fetches the first page

#### Feeds
- `loadFeed` `async`
  - parameters: `group: String?`, `order: FeedOrder`, `period: FeedOrderPeriod?`, `after: String?`, `search: String?`, `unfiltered: Bool`
  - returns: `(items: [FeedItem], isFiltered: Bool?, error: String?)`

#### Posts
- `loadPost` `async`
  - parameters: `id: String`, `group: String`, `commentOrder: CommentOrder`
  - returns: `(post: Post, comments: [Comment])?`

- `createPost` `async`
  - parameters: `group: String`, `title: String`, `link: String`, `markdown: String`, `tags: [String]`
  - returns: `CreatePostResponse`

- `editPost` `async`
  - parameters: `id: String`, `body: String`
  - returns: `(statusCode: Int, newBody: String)`
  - WARNING: Currently this can only edit the post BODY

- `replyToPost` `async`

- `deletePost` `async` 

- `putVoteOnPost` `async`
- `deleteVoteOnPost` `async` 
- `putBookmarkOnPost` `async`
- `deleteBookmarkOnPost` `async` 
- `putIgnoreOnPost` `async`
- `deleteIgnoreOnPost` `async` 

#### Comments
- `editComment` `async`
- `deleteComment` `async`
- `replyToComment` `async`
- `putVoteOnComment` `async`
- `deleteVoteOnComment` `async`
- `putBookmarkOnComment` `async`
- `deleteBookmarkOnComment` `async`
- `markCommentRead` `async`

#### Groups
- `loadGroups` `async`
- `subscribeToGroup` `async`
- `unsubscribeFromGroup` `async`

#### User Pages
- `loadUserPage` `async`
  - paginated
