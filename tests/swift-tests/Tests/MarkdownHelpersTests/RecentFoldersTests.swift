import Foundation
import XCTest
@testable import MarkdownHelpers

final class RecentFoldersTests: XCTestCase {
    func testNothingStoredByDefault() throws {
        let defaults = try makeDefaults()

        XCTAssertEqual(RecentFolders.paths(from: defaults), [])
        XCTAssertEqual(RecentFolders.urls(from: defaults, isExistingDirectory: { _ in true }), [])
    }

    func testNewestFolderComesFirst() throws {
        let defaults = try makeDefaults()

        RecentFolders.note(URL(fileURLWithPath: "/tmp/a"), in: defaults)
        RecentFolders.note(URL(fileURLWithPath: "/tmp/b"), in: defaults)

        XCTAssertEqual(RecentFolders.paths(from: defaults), ["/tmp/b", "/tmp/a"])
    }

    func testReopeningAFolderMovesItToTheFrontWithoutDuplicating() throws {
        let defaults = try makeDefaults()

        RecentFolders.note(URL(fileURLWithPath: "/tmp/a"), in: defaults)
        RecentFolders.note(URL(fileURLWithPath: "/tmp/b"), in: defaults)
        RecentFolders.note(URL(fileURLWithPath: "/tmp/a/"), in: defaults)

        XCTAssertEqual(RecentFolders.paths(from: defaults), ["/tmp/a", "/tmp/b"])
    }

    func testListIsCappedAtTheLimitDroppingTheOldest() throws {
        let defaults = try makeDefaults()

        for index in 0..<(RecentFolders.limit + 3) {
            RecentFolders.note(URL(fileURLWithPath: "/tmp/\(index)"), in: defaults)
        }

        let paths = RecentFolders.paths(from: defaults)
        XCTAssertEqual(paths.count, RecentFolders.limit)
        XCTAssertEqual(paths.first, "/tmp/\(RecentFolders.limit + 2)")
        XCTAssertFalse(paths.contains("/tmp/0"))
    }

    func testMissingFoldersAreLeftOutButStayStored() throws {
        let defaults = try makeDefaults()
        RecentFolders.note(URL(fileURLWithPath: "/tmp/gone"), in: defaults)
        RecentFolders.note(URL(fileURLWithPath: "/tmp/here"), in: defaults)

        let urls = RecentFolders.urls(from: defaults, isExistingDirectory: { $0 == "/tmp/here" })

        XCTAssertEqual(urls.map(\.path), ["/tmp/here"])
        XCTAssertEqual(RecentFolders.paths(from: defaults), ["/tmp/here", "/tmp/gone"])
    }

    func testRemoveDropsOnlyThatFolder() throws {
        let defaults = try makeDefaults()
        RecentFolders.note(URL(fileURLWithPath: "/tmp/a"), in: defaults)
        RecentFolders.note(URL(fileURLWithPath: "/tmp/b"), in: defaults)

        RecentFolders.remove(URL(fileURLWithPath: "/tmp/a"), in: defaults)

        XCTAssertEqual(RecentFolders.paths(from: defaults), ["/tmp/b"])
    }

    func testRemovingTheLastFolderLeavesNoKey() throws {
        let defaults = try makeDefaults()
        RecentFolders.note(URL(fileURLWithPath: "/tmp/a"), in: defaults)

        RecentFolders.remove(URL(fileURLWithPath: "/tmp/a"), in: defaults)

        XCTAssertNil(defaults.object(forKey: RecentFolders.defaultsKey))
    }

    func testClearForgetsEveryFolder() throws {
        let defaults = try makeDefaults()
        RecentFolders.note(URL(fileURLWithPath: "/tmp/a"), in: defaults)

        RecentFolders.clear(in: defaults)

        XCTAssertEqual(RecentFolders.paths(from: defaults), [])
    }

    func testUrlsAreDirectoryURLs() throws {
        let defaults = try makeDefaults()
        RecentFolders.note(URL(fileURLWithPath: "/tmp/a"), in: defaults)

        let urls = RecentFolders.urls(from: defaults, isExistingDirectory: { _ in true })

        XCTAssertEqual(urls.first?.hasDirectoryPath, true)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "RecentFoldersTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
