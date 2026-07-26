import Foundation

// Codable models mirroring the /api/v1 JSON shapes.

struct SessionUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let title: String?
    let avatarUrl: String?
    let role: String
}

struct LoginResponse: Codable {
    let token: String
    let user: SessionUser
}

struct Author: Codable {
    let id: String
    let name: String
    let title: String?
    let avatarUrl: String?
}

struct ReactionCount: Codable {
    let type: String
    let count: Int
}

struct Reactions: Codable {
    let total: Int
    let mine: String?
    let byType: [ReactionCount]
}

struct Audience: Codable {
    let kind: String       // PRIVATE | GROUP | PEOPLE
    let label: String?
}

struct LinkCard: Codable {
    let url: String
    let title: String?
    let description: String?
    let image: String?
    let domain: String?
}

struct Post: Codable, Identifiable {
    let id: String
    let content: String
    let createdAt: Date
    let editedAt: Date?
    let author: Author
    let images: [String]
    let videos: [String]
    let link: LinkCard?
    let audience: Audience?
    let pinned: Bool
    let isAnnouncement: Bool
    let reactions: Reactions
    let commentCount: Int
    let bookmarkedByMe: Bool
    let comments: [Comment]?   // present only on the post-detail endpoint
}

struct Comment: Codable, Identifiable {
    let id: String
    let content: String
    let createdAt: Date
    let editedAt: Date?
    let author: Author
    let images: [String]
    let likeCount: Int
    let likedByMe: Bool
    let replies: [Comment]?    // present only on root comments
}

struct FeedResponse: Codable {
    let posts: [Post]
}

struct PostDetailResponse: Codable {
    let post: Post
}

struct ReactResponse: Codable {
    let mine: String?
}

struct BookmarkResponse: Codable {
    let bookmarked: Bool
}

struct LikeResponse: Codable {
    let liked: Bool
}

struct CreatedComment: Codable {
    let id: String
    let content: String
    let parentId: String?
    let createdAt: Date
}

struct CommentResponse: Codable {
    let comment: CreatedComment
}

// MARK: - Messages

struct Member: Codable, Identifiable {
    let id: String
    let name: String
    let email: String?
    let username: String?
    let avatarUrl: String?
}

struct ConversationSummary: Codable, Identifiable {
    let id: String
    let isGroup: Bool
    let title: String
    let members: [Member]
    let lastMessage: String?
    let lastMessageAt: Date
    let unread: Int
}

struct ConversationsResponse: Codable {
    let conversations: [ConversationSummary]
}

struct ChatFile: Codable {
    let id: String
    let name: String
    let size: Int?
    let mimeType: String?
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let body: String
    let imageUrl: String?
    let createdAt: Date
    let senderId: String
    let sender: Member
    let file: ChatFile?
}

struct ConversationDetail: Codable {
    let id: String
    let isGroup: Bool
    let name: String?
    let title: String
    let members: [Member]
    let readReceipt: Date?
    let messages: [ChatMessage]
}

struct ConversationResponse: Codable {
    let conversation: ConversationDetail
}

struct MessagesResponse: Codable {
    let messages: [ChatMessage]
}

// MARK: - Notifications

struct NotificationEvent: Codable {
    let id: String
    let title: String
}

struct AppNotification: Codable, Identifiable {
    let id: String
    let type: String
    let read: Bool
    let createdAt: Date
    let actor: Author
    let postId: String?
    let conversationId: String?
    let eventId: String?
    let event: NotificationEvent?
}

struct NotificationsResponse: Codable {
    let notifications: [AppNotification]
    let unread: Int
}

// MARK: - Spaces & events

struct SpaceSummary: Codable, Identifiable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let visibility: String
    let memberCount: Int
    let isMember: Bool
}

struct SpacesResponse: Codable {
    let spaces: [SpaceSummary]
}

struct SpaceDetail: Codable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let visibility: String
    let ownerId: String
    let memberCount: Int
    let isMember: Bool
    let isOwner: Bool
    let canPost: Bool
}

struct SpaceMemberView: Codable, Identifiable {
    let id: String
    let name: String
    let username: String?
    let avatarUrl: String?
    let isOwner: Bool
}

struct RsvpCounts: Codable {
    let GOING: Int
    let MAYBE: Int
    let NO: Int
}

struct SpaceRef: Codable {
    let slug: String
    let name: String
}

struct EventListItem: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let location: String?
    let startAt: Date
    let endAt: Date?
    let host: Author
    let isHost: Bool
    let space: SpaceRef?
    let counts: RsvpCounts
    let myStatus: String?
}

struct EventsResponse: Codable {
    let events: [EventListItem]
}

struct EventAttendees: Codable {
    let GOING: [Member]
    let MAYBE: [Member]
    let NO: [Member]
}

struct EventDetail: Codable {
    let id: String
    let title: String
    let description: String?
    let location: String?
    let startAt: Date
    let endAt: Date?
    let host: Author
    let isHost: Bool
    let space: SpaceRef?
    let canRsvp: Bool
    let counts: RsvpCounts
    let myStatus: String?
    let attendees: EventAttendees
}

struct EventResponse: Codable {
    let event: EventDetail
}

struct SpaceDetailResponse: Codable {
    let space: SpaceDetail
    let posts: [Post]
    let members: [SpaceMemberView]
    let events: [EventListItem]
}

// MARK: - Profile

struct Profile: Codable {
    let id: String
    let name: String
    let username: String?
    let title: String?
    let bio: String?
    let department: String?
    let team: String?
    let location: String?
    let avatarUrl: String?
    let startDate: Date?
    let postCount: Int
    let followerCount: Int
    let followingCount: Int
    let isFollowing: Bool
    let isMe: Bool
}

struct ProfileResponse: Codable {
    let profile: Profile
    let posts: [Post]
}

struct FollowResponse: Codable {
    let following: Bool
}

struct CreatedPost: Codable {
    let id: String
    let content: String
    let createdAt: Date
}

struct CreatePostResponse: Codable {
    let post: CreatedPost
}

/// Error body returned by the API on 4xx/5xx: `{ "error": "..." }`.
struct APIErrorBody: Codable {
    let error: String
}
