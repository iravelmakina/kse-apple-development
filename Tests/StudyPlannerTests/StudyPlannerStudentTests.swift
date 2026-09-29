import XCTest
@testable import StudyPlanner

private func makeItem(
    id: String,
    title: String = "Title",
    minutes: Int = 10,
    category: StudyCategory = .reading,
    isCompleted: Bool = false
) throws -> StudyItem {
    try StudyItem(
        id: id,
        title: title,
        estimatedMinutes: minutes,
        category: category,
        isCompleted: isCompleted
    )
}

private func assertThrows<T>(
    _ expression: @autoclosure () throws -> T,
    _ expected: StudyPlanError,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        XCTAssertEqual(error as? StudyPlanError, expected, file: file, line: line)
    }
}

final class StudyItemValidationTests: XCTestCase {
    func testBlankTitleIsReportedBeforeNonPositiveMinutes() {
        assertThrows(try makeItem(id: "a", title: "   ", minutes: 0), .blankTitle)
    }

    func testZeroMinutesIsRejected() {
        assertThrows(try makeItem(id: "a", minutes: 0), .nonPositiveEstimatedMinutes)
    }

    func testNegativeMinutesIsRejected() {
        assertThrows(try makeItem(id: "a", minutes: -15), .nonPositiveEstimatedMinutes)
    }

    func testTabAndNewlineOnlyTitlesAreRejected() {
        assertThrows(try makeItem(id: "a", title: "\t\n "), .blankTitle)
    }

    func testTitleIsStoredExactlyAsProvided() throws {
        let item = try makeItem(id: "a", title: "  Read Swift  ")
        XCTAssertEqual(item.title, "  Read Swift  ")
    }

    func testNewItemDefaultsToIncomplete() throws {
        XCTAssertFalse(try makeItem(id: "a").isCompleted)
    }
}

final class StudyPlanDecodingTests: XCTestCase {
    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    func testDecodesTopLevelJSONArrayFixture() throws {
        let plan = try StudyPlan.decode(from: fixtureData("study-items"))

        XCTAssertEqual(plan.items.map(\.id), ["planner-milestone", "collections-drill", "swift-chapter-1"])
        XCTAssertEqual(plan.incompleteMinutes(), 135)
    }

    func testDecodesKeyedPlanJSON() throws {
        let plan = try JSONDecoder().decode(StudyPlan.self, from: fixtureData("keyed-plan"))

        XCTAssertEqual(plan.items.map(\.id), ["b"])
    }

    func testDecodingBlankTitleThrowsDomainError() throws {
        let data = try fixtureData("invalid-blank-title")

        assertThrows(try StudyPlan.decode(from: data), .blankTitle)
    }

    func testDecodingNonPositiveMinutesThrowsDomainError() throws {
        let data = try fixtureData("invalid-zero-minutes")

        assertThrows(try StudyPlan.decode(from: data), .nonPositiveEstimatedMinutes)
    }

    func testDecodingUnknownCategoryThrows() throws {
        let data = try fixtureData("invalid-unknown-category")

        XCTAssertThrowsError(try StudyPlan.decode(from: data))
    }

    func testDecodingOmittedIsCompletedDefaultsToFalse() throws {
        let plan = try StudyPlan.decode(from: fixtureData("omitted-is-completed"))

        XCTAssertFalse(try XCTUnwrap(plan.items.first).isCompleted)
    }
}

final class StudyPlanOrderingTests: XCTestCase {
    func testFirstDuplicateIDIsReported() throws {
        let items = [
            try makeItem(id: "dup", title: "A"),
            try makeItem(id: "other", title: "B"),
            try makeItem(id: "dup", title: "C")
        ]

        assertThrows(try StudyPlan(items: items), .duplicateID("dup"))
    }

    func testItemsAreOrderedByTitleThenID() throws {
        let items = [
            try makeItem(id: "z", title: "Same"),
            try makeItem(id: "b", title: "Zebra"),
            try makeItem(id: "a", title: "Same"),
            try makeItem(id: "c", title: "Alpha")
        ]
        let plan = try StudyPlan(items: items)

        XCTAssertEqual(plan.items.map(\.id), ["c", "a", "z", "b"])
    }
}

final class StudyPlanQueryTests: XCTestCase {
    private func samplePlan() throws -> StudyPlan {
        try StudyPlan(items: [
            try makeItem(id: "r1", title: "Read one", minutes: 10, category: .reading),
            try makeItem(id: "p1", title: "Practice one", minutes: 20, category: .practice, isCompleted: true),
            try makeItem(id: "r2", title: "Read two", minutes: 30, category: .reading)
        ])
    }

    func testItemsInCategoryReturnsOnlyThatCategory() throws {
        XCTAssertEqual(try samplePlan().items(in: .reading).map(\.id), ["r1", "r2"])
    }

    func testItemsInEmptyCategoryReturnsNoItems() throws {
        XCTAssertTrue(try samplePlan().items(in: .project).isEmpty)
    }

    func testIncompleteMinutesSkipsCompletedItems() throws {
        XCTAssertEqual(try samplePlan().incompleteMinutes(), 40)
    }

    func testMarkCompletedUnknownIDThrows() throws {
        var plan = try samplePlan()
        assertThrows(try plan.markCompleted(id: "ghost"), .unknownID("ghost"))
    }

    func testMarkCompletedIsIdempotent() throws {
        var plan = try samplePlan()

        try plan.markCompleted(id: "r1")
        try plan.markCompleted(id: "r1")

        XCTAssertEqual(plan.incompleteMinutes(), 30)
    }
}

final class StudyPlanImportMergingTests: XCTestCase {
    private func basePlan() throws -> StudyPlan {
        try StudyPlan(items: [
            try makeItem(id: "m2", title: "Beta"),
            try makeItem(id: "m1", title: "Alpha")
        ])
    }

    func testDuplicateIncomingIDsAreRejectedWithoutChangingThePlan() throws {
        var plan = try basePlan()
        let before = plan.items
        let incoming = [try makeItem(id: "x", title: "X"), try makeItem(id: "x", title: "X again")]

        assertThrows(try plan.importMerging(incoming), .duplicateID("x"))
        XCTAssertEqual(plan.items, before)
    }

    func testExistingIDsAreReplacedAtTheirCurrentPositions() throws {
        var plan = try basePlan()
        let untouched = try XCTUnwrap(plan.items.first)
        let replacement = try makeItem(
            id: "m2",
            title: "Beta revised",
            minutes: 99,
            category: .project,
            isCompleted: true
        )

        try plan.importMerging([replacement])

        XCTAssertEqual(plan.items.map(\.id), ["m1", "m2"])
        XCTAssertEqual(plan.items.last, replacement)
        XCTAssertEqual(plan.items.first, untouched)
    }

    func testNewIDsAreAppendedInAscendingIDOrder() throws {
        var plan = try basePlan()

        try plan.importMerging([try makeItem(id: "z9", title: "Zed"), try makeItem(id: "a0", title: "Aardvark")])

        XCTAssertEqual(plan.items.map(\.id), ["m1", "m2", "a0", "z9"])
    }
}
