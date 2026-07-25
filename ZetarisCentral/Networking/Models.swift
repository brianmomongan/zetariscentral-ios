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
}

struct FeedResponse: Codable {
    let posts: [Post]
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
