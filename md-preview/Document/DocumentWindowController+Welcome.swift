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

    func startNewDocumentFromWelcome() {
        documentWindow.title = NSLocalizedString("Untitled", comment: "Window title when no document is open")
        enterEditMode(autofocus: true)
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
        // A file that is already open elsewhere comes to the front instead
        // of loading a second time here.
        if !url.isExistingDirectory,
           let open = NSDocumentController.shared.document(for: url) {
            open.showWindows()
            return
        }
        present(url: url)
    }
}
