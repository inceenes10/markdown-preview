//
//  DocumentWindowController+Welcome.swift
//  md-preview
//
//  The Welcome screen of a window with nothing open yet: the app starts on
//  one instead of the Open panel (see `WelcomeScreenSetting`). The window is
//  an ordinary untitled document window, so whatever the reader picks — a
//  file, a folder, a new document — takes it over in place.
//

import Cocoa
import UniformTypeIdentifiers

extension DocumentWindowController {
    var isShowingWelcome: Bool {
        mainSplit?.isShowingWelcome ?? false
    }

    /// The window on the Welcome screen, if there is one; the front one first.
    static var showingWelcome: DocumentWindowController? {
        NSApp.orderedWindows
            .compactMap { $0.windowController as? DocumentWindowController }
            .first(where: \.isShowingWelcome)
    }

    /// Opens a document window with nothing in it yet, on the Welcome screen:
    /// a window of its own at launch, a tab of the front window for New Tab.
    static func openWelcomeWindow(asTab: Bool = false) {
        if asTab { markNextWindowAsTab() }
        let document = MarkdownDocument()
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
        (document.windowControllers.first as? DocumentWindowController)?.showWelcome()
    }

    func showWelcome() {
        guard currentFileURL == nil, let split = mainSplit, !split.isEditingDocument else { return }
        documentWindow.title = NSLocalizedString("Welcome", comment: "Window title on the Welcome screen")
        split.showWelcome(actions: WelcomeActions(
            openFile: { [weak self] in self?.chooseFromWelcome(folders: false) },
            openFolder: { [weak self] in self?.chooseFromWelcome(folders: true) },
            newDocument: { [weak self] in self?.startNewDocumentFromWelcome() },
            open: { [weak self] url in self?.openFromWelcome(url) }
        ))
    }

    func hideWelcome() {
        mainSplit?.hideWelcome()
    }

    func startNewDocumentFromWelcome(autofocus: Bool = true) {
        hideWelcome()
        documentWindow.title = NSLocalizedString("Untitled", comment: "Window title when no document is open")
        enterEditMode(autofocus: autofocus)
    }

    /// Folders get a panel of their own that offers nothing else, so the
    /// Markdown file filter cannot grey them out.
    private func chooseFromWelcome(folders: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = folders
        panel.canChooseFiles = !folders
        if !folders {
            panel.allowedContentTypes = Self.markdownFileExtensions
                .compactMap { UTType(filenameExtension: $0) }
        }
        panel.beginSheetModal(for: documentWindow) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openFromWelcome(url)
        }
    }

    private func openFromWelcome(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            NSSound.beep()
            return
        }
        if url.isExistingDirectory {
            openFolder(url)
            return
        }
        // Through the document controller, which reads the file before this
        // screen gives way to it and brings an already open file to the
        // front instead of loading it a second time.
        NSDocumentController.shared.openDocument(withContentsOf: url,
                                                 display: true) { [weak self] document, _, error in
            // An open document whose window was closed has none to show.
            if let document, document.windowControllers.isEmpty {
                document.makeWindowControllers()
                document.showWindows()
            }
            guard let self, let error else { return }
            NSAlert(error: error).beginSheetModal(for: self.documentWindow)
        }
    }
}
