//
//  WelcomeView.swift
//  md-preview
//
//  The Welcome screen: fills the document area of a window that has nothing
//  open yet (see `DocumentWindowController+Welcome`). Lists the folders and
//  files opened last, with Open File, Open Folder and New Document
//  alongside; whatever is picked loads into that same window. It is drawn
//  with the app's own chrome — the rows of the Search for Document palette,
//  the sidebar's file icons and accent — rather than as a rendered document.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model

/// What the screen lists, reloaded when it appears, when the app comes back
/// to the front, and when the recents are cleared.
@MainActor
@Observable
final class WelcomeModel {
    struct Item: Identifiable, Hashable {
        let url: URL
        var id: URL { url }
        var name: String { url.lastPathComponent }
        /// The containing folder, with the home folder shortened to `~`.
        var location: String {
            let path = url.deletingLastPathComponent().path
            if path == WelcomeModel.realHomePath { return "~" }
            if path.hasPrefix(WelcomeModel.realHomePath + "/") {
                return "~" + path.dropFirst(WelcomeModel.realHomePath.count)
            }
            return path
        }
    }

    /// The reader's actual home: inside the sandbox `NSHomeDirectory()` is
    /// the app container, which no recent path starts with.
    nonisolated static let realHomePath: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }()

    private(set) var folders: [Item] = []
    private(set) var files: [Item] = []

    static let fileLimit = 10

    func reload() {
        folders = RecentFolders.urls().map { Item(url: $0) }
        files = NSDocumentController.shared.recentDocumentURLs
            .filter { url in
                url.isFileURL
                    && ProjectFileIndex.markdownExtensions.contains(url.pathExtension.lowercased())
                    && FileManager.default.fileExists(atPath: url.path)
            }
            .prefix(Self.fileLimit)
            .map { Item(url: $0) }
    }

    func forgetFolder(_ item: Item) {
        RecentFolders.remove(item.url)
        reload()
    }

    func forgetFile(_ item: Item) {
        (NSDocumentController.shared as? MarkdownDocumentController)?
            .removeRecentDocumentURL(item.url)
        reload()
    }
}

// MARK: - Style

/// The app's chrome restated for SwiftUI, taken from the Project Navigator
/// and the Search for Document palette so the three read as one.
private struct WelcomeStyle {
    /// The sidebar's selection color: the theme's link color when the reader
    /// set one, the system accent otherwise.
    let accent: Color

    init(colorScheme: ColorScheme) {
        let scheme: ThemeColorScheme = colorScheme == .dark ? .dark : .light
        accent = ThemeColorsSetting.current.color(.linkColor, scheme).map(Color.init(nsColor:))
            ?? .accentColor
    }

    let title = Font.system(size: 26, weight: .bold)
    /// The palette's section label.
    let sectionLabel = Font.system(size: 11, weight: .semibold)
    /// The palette's row: a 13pt name over an 11pt path.
    let rowName = Font.system(size: 13)
    let rowDetail = Font.system(size: 11)
    static let rowHeight: CGFloat = 40
    static let iconSize: CGFloat = 20
    /// Start and Recent on the left, What's New and Shortcuts on the right;
    /// a window too narrow for both stacks them.
    static let leftColumnWidth: CGFloat = 440
    static let rightColumnWidth: CGFloat = 360
    static let columnSpacing: CGFloat = 56
}

// MARK: - View

struct WelcomeActions {
    var openFile: () -> Void = {}
    var openFolder: () -> Void = {}
    var newDocument: () -> Void = {}
    var open: (URL) -> Void = { _ in }
}

struct WelcomeView: View {
    let model: WelcomeModel
    let actions: WelcomeActions

    @Environment(\.colorScheme) private var colorScheme
    /// Bumped when a setting changes, so the theme accent is read again.
    @State private var settingsRevision = 0

    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }

    /// True while a file or folder is being dragged over the screen.
    @State private var isDropTargeted = false

    var body: some View {
        let style = WelcomeStyle(colorScheme: colorScheme)
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: WelcomeStyle.columnSpacing) {
                    leftColumn(style)
                        .frame(width: WelcomeStyle.leftColumnWidth, alignment: .leading)
                    rightColumn(style)
                        .frame(width: WelcomeStyle.rightColumnWidth, alignment: .leading)
                        // Level with the Start label rather than the app icon.
                        .padding(.top, 68)
                }
                VStack(alignment: .leading, spacing: 8) {
                    leftColumn(style)
                    rightColumn(style)
                }
                .frame(maxWidth: WelcomeStyle.leftColumnWidth, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 84)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
        .overlay {
            if isDropTargeted {
                dropOverlay(style)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: openDropped)
        .id(settingsRevision)
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in model.reload() }
        .onReceive(NotificationCenter.default.publisher(
            for: MarkdownDocumentController.recentDocumentsDidClear)) { _ in model.reload() }
        .onReceive(NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)) { _ in
            settingsRevision &+= 1
        }
    }

    private func leftColumn(_ style: WelcomeStyle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(style)

            sectionLabel(L("Start"), style)
            WelcomeRow(style: style, title: L("Open File…"), shortcut: "⌘O",
                       icon: .symbol("doc"), action: actions.openFile)
            WelcomeRow(style: style, title: L("Open Folder…"),
                       icon: .symbol("folder"), action: actions.openFolder)
            WelcomeRow(style: style, title: L("New Document"), shortcut: "⌘N",
                       icon: .symbol("square.and.pencil"), action: actions.newDocument)

            if model.folders.isEmpty && model.files.isEmpty {
                sectionLabel(L("Recent"), style)
                Text(L("No recent items"))
                    .font(style.rowName)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, WelcomeRow.inset)
                    .padding(.vertical, 6)
            } else {
                recentSection(title: L("Recent Folders"), items: model.folders, style,
                              forget: model.forgetFolder)
                recentSection(title: L("Recent Files"), items: model.files, style,
                              forget: model.forgetFile)
            }

            Text(L("Or drop a Markdown file or folder here."))
                .font(style.rowDetail)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, WelcomeRow.inset)
                .padding(.top, 20)
        }
    }

    /// The shortcuts worth knowing before a document is open; the labels are
    /// the menu items' own.
    private static let shortcuts: [(title: String, keys: String)] = [
        ("Search for Document…", "⇧⌘O"),
        ("New Tab", "⌘T"),
        ("Toggle Sidebar", "⌘L"),
        ("Toggle Edit Mode", "⌘E"),
        ("Settings…", "⌘,"),
    ]

    private func rightColumn(_ style: WelcomeStyle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(String(format: L("What’s New in Markdown Preview %@"),
                                WhatsNewPolicy.featuresVersion), style)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(WhatsNewFeature.current) { feature in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(style.accent)
                            .frame(width: WelcomeStyle.iconSize)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title)
                                .font(style.rowName)
                            Text(feature.detail)
                                .font(style.rowDetail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, WelcomeRow.inset)
            .padding(.top, 6)

            sectionLabel(L("Shortcuts"), style)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.shortcuts, id: \.keys) { shortcut in
                    HStack {
                        Text(L(shortcut.title))
                            .font(style.rowName)
                        Spacer(minLength: 12)
                        Text(verbatim: shortcut.keys)
                            .font(style.rowName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, WelcomeRow.inset)
            .padding(.top, 6)
        }
    }

    /// Washes the whole document area in the accent while a drag is over it,
    /// with the outcome named in the middle.
    private func dropOverlay(_ style: WelcomeStyle) -> some View {
        ZStack {
            Rectangle()
                .fill(.background.opacity(0.6))
            Rectangle()
                .fill(style.accent.opacity(0.14))
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(style.accent)
                    .accessibilityHidden(true)
                Text(L("Drop to Open"))
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func openDropped(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) else {
            return false
        }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in actions.open(url) }
        }
        return true
    }

    private func header(_ style: WelcomeStyle) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Markdown Preview")
                    .font(style.title)
                    .accessibilityAddTraits(.isHeader)
                if !version.isEmpty {
                    Text(String(format: L("Version %@"), version))
                        .font(style.rowName)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, WelcomeRow.inset)
        .padding(.bottom, 12)
    }

    private func sectionLabel(_ title: String, _ style: WelcomeStyle) -> some View {
        Text(title)
            .font(style.sectionLabel)
            .foregroundStyle(.secondary)
            .padding(.horizontal, WelcomeRow.inset)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func recentSection(title: String, items: [WelcomeModel.Item], _ style: WelcomeStyle,
                               forget: @escaping (WelcomeModel.Item) -> Void) -> some View {
        if !items.isEmpty {
            sectionLabel(title, style)
            ForEach(items) { item in
                WelcomeRow(style: style, title: item.name, detail: item.location,
                           icon: .file(item.url),
                           action: { actions.open(item.url) },
                           forget: { forget(item) })
            }
        }
    }
}

/// One row of the screen, shaped like a row of the Search for Document
/// palette: icon, name, and the path underneath.
private struct WelcomeRow: View {
    enum Icon {
        /// An SF Symbol in the accent, as the sidebar tints its own.
        case symbol(String)
        /// The Finder icon of a file or folder.
        case file(URL)
    }

    static let inset: CGFloat = 10

    let style: WelcomeStyle
    let title: String
    var detail: String?
    /// The menu shortcut of the same command, shown at the trailing edge.
    var shortcut: String?
    let icon: Icon
    let action: () -> Void
    var forget: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 10) {
                    iconView
                        .frame(width: WelcomeStyle.iconSize, height: WelcomeStyle.iconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(style.rowName)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let detail {
                            Text(detail)
                                .font(style.rowDetail)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer(minLength: 0)
                    if let shortcut {
                        Text(verbatim: shortcut)
                            .font(style.rowName)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: detail == nil ? 30 : WelcomeStyle.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let forget {
                // Always laid out so the row does not shift; shown on hover.
                Button(action: forget) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Remove from Recents"))
                .accessibilityLabel(L("Remove from Recents"))
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, Self.inset)
        .background(isHovered ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
        .contextMenu {
            if case .file(let url) = icon {
                Button(L("Show in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            if let forget {
                Button(L("Remove from Recents"), action: forget)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 15))
                .foregroundStyle(style.accent)
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
        }
    }
}
