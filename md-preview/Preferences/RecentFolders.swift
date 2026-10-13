//
//  RecentFolders.swift
//  md-preview
//
//  The folders last opened in the Project Navigator, newest first, for the
//  Welcome window. `NSDocumentController` only remembers files, so folders
//  are kept here as plain paths: the app already has read-only access to the
//  whole filesystem, so no bookmark is needed to open one again. Kept free of
//  AppKit so the SPM helper tests can exercise it without a GUI host.
//

import Foundation

enum RecentFolders {
    static let defaultsKey = "MarkdownPreview.recentFolderPaths"
    static let limit = 10

    /// The stored paths, newest first, whether or not they still exist.
    static func paths(from defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: defaultsKey) ?? []
    }

    /// The remembered folders that are still on disk, newest first.
    static func urls(from defaults: UserDefaults = .standard,
                     isExistingDirectory: (String) -> Bool = Self.isExistingDirectory) -> [URL] {
        paths(from: defaults)
            .filter(isExistingDirectory)
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Moves `url` to the front, dropping the oldest entry past `limit`.
    static func note(_ url: URL, in defaults: UserDefaults = .standard) {
        let path = normalizedPath(url)
        var stored = paths(from: defaults).filter { $0 != path }
        stored.insert(path, at: 0)
        defaults.set(Array(stored.prefix(limit)), forKey: defaultsKey)
    }

    static func remove(_ url: URL, in defaults: UserDefaults = .standard) {
        let path = normalizedPath(url)
        let stored = paths(from: defaults)
        let remaining = stored.filter { $0 != path }
        guard remaining.count != stored.count else { return }
        store(remaining, in: defaults)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }

    private static func store(_ paths: [String], in defaults: UserDefaults) {
        if paths.isEmpty {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(paths, forKey: defaultsKey)
        }
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    nonisolated private static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
