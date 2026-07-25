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
