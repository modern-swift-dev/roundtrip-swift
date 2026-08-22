import Foundation

/// Generic wrapper for paginated API responses.
/// Handles next page URLs and determines if more results are available.
///
/// Example:
/// ```swift
/// let page: PagedResults<Item> = try await client.execute(request)
/// if page.hasNext {
///     let nextPage = try await client.getNextPage(page)
/// }
/// ```
public struct PagedResults<T: Codable & Sendable>: Codable, Sendable {
    /// Total count of items available, if provided by API
    public let count: Int?

    /// URL for the next page of results, if available
    public let next: URL?

    /// Array of items in the current page
    public let results: [T]

    /// Indicates if there are more pages available
    /// - Note: This is determined by checking if both `next` URL exists and current `results` are not empty
    public let hasNext: Bool

    /// Initialize with optional count and next URL
    /// - Parameters:
    ///   - count: Total number of items available
    ///   - next: URL for next page
    ///   - hasNext: Override for hasNext determination
    ///   - results: Items in this page
    public init(count: Int? = nil, next: URL?, hasNext: Bool? = nil, results: [T]) {
        self.count = count
        self.next = next
        self.results = results
        self.hasNext = hasNext ?? ((next != nil) && !results.isEmpty)
    }

    /// Initialize with just results (single page)
    /// - Parameter results: Items in this page
    public init(results: [T]) {
        count = results.count
        next = nil
        hasNext = false
        self.results = results
    }

    public enum CodingKeys: String, CodingKey {
        case count
        case next
        case results
        case hasNext
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: PagedResults<T>.CodingKeys.self)
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(next, forKey: .next)
        try container.encode(results, forKey: .results)
    }

    public init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<PagedResults<T>.CodingKeys> = try decoder.container(keyedBy: PagedResults<T>.CodingKeys.self)
        count = try container.decodeIfPresent(Int.self, forKey: PagedResults<T>.CodingKeys.count)
        next = try container.decodeIfPresent(URL.self, forKey: PagedResults<T>.CodingKeys.next)
        results = try container.decode([T].self, forKey: PagedResults<T>.CodingKeys.results)
        hasNext = (next != nil) && !results.isEmpty
    }
}
