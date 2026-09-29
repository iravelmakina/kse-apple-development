import Foundation

public enum StudyCategory: String, Codable, CaseIterable {
    case reading, practice, project
}

public enum StudyPlanError: Error, Equatable {
    case blankTitle
    case nonPositiveEstimatedMinutes
    case duplicateID(String)
    case unknownID(String)
}

public struct StudyItem: Codable, Equatable {
    public let id: String
    public let title: String
    public let estimatedMinutes: Int
    public let category: StudyCategory
    public private(set) var isCompleted: Bool

    private enum CodingKeys: String, CodingKey {
        case id, title, estimatedMinutes, category, isCompleted
    }

    public init(
        id: String,
        title: String,
        estimatedMinutes: Int,
        category: StudyCategory,
        isCompleted: Bool = false
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyPlanError.blankTitle
        }
        guard estimatedMinutes > 0 else {
            throw StudyPlanError.nonPositiveEstimatedMinutes
        }

        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.category = category
        self.isCompleted = isCompleted
    }

    // Decoding delegates to the validating initializer so JSON cannot bypass validation.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            estimatedMinutes: container.decode(Int.self, forKey: .estimatedMinutes),
            category: container.decode(StudyCategory.self, forKey: .category),
            isCompleted: container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        )
    }

    mutating func complete() {
        isCompleted = true
    }
}

public struct StudyPlan: Codable, Equatable {
    public private(set) var items: [StudyItem]

    private enum CodingKeys: String, CodingKey {
        case items
    }

    public init(items: [StudyItem]) throws {
        self.items = try Self.normalized(items)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(items: container.decode([StudyItem].self, forKey: .items))
    }

    public static func decode(from data: Data) throws -> StudyPlan {
        let decoder = JSONDecoder()
        do {
            return try StudyPlan(items: decoder.decode([StudyItem].self, from: data))
        } catch let DecodingError.typeMismatch(_, context) where context.codingPath.isEmpty {
            return try decoder.decode(StudyPlan.self, from: data)
        }
    }

    public func items(in category: StudyCategory) -> [StudyItem] {
        items.filter { $0.category == category }
    }

    public func incompleteMinutes() -> Int {
        items.filter { !$0.isCompleted }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    public mutating func markCompleted(id: String) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw StudyPlanError.unknownID(id)
        }
        items[index].complete()
    }

    public mutating func importMerging(_ importedItems: [StudyItem]) throws {
        var incomingIDs = Set<String>()
        for item in importedItems {
            guard incomingIDs.insert(item.id).inserted else {
                throw StudyPlanError.duplicateID(item.id)
            }
        }

        var merged = items
        var newcomers: [StudyItem] = []
        for item in importedItems {
            if let index = merged.firstIndex(where: { $0.id == item.id }) {
                merged[index] = item
            } else {
                newcomers.append(item)
            }
        }
        merged.append(contentsOf: newcomers.sorted { $0.id < $1.id })

        // Single assignment at the end keeps a failed import from changing the plan.
        items = merged
    }

    private static func normalized(_ items: [StudyItem]) throws -> [StudyItem] {
        var seenIDs = Set<String>()
        for item in items {
            guard seenIDs.insert(item.id).inserted else {
                throw StudyPlanError.duplicateID(item.id)
            }
        }

        return items.sorted { lhs, rhs in
            lhs.title == rhs.title ? lhs.id < rhs.id : lhs.title < rhs.title
        }
    }
}
