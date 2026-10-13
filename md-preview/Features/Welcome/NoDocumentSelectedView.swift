//
//  NoDocumentSelectedView.swift
//  md-preview
//
//  Fills the document area of a window that has a folder open in the
//  Project Navigator but no file chosen yet, so the page is not left blank.
//

import SwiftUI

struct NoDocumentSelectedView: View {
    var body: some View {
        ContentUnavailableView {
            Label(L("No Document Selected"), systemImage: "doc.text")
        } description: {
            Text(L("Choose a file in the sidebar, or press ⇧⌘O to search this folder."))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
