//
//  WelcomeScreenSetting.swift
//  md-preview
//
//  Whether the app starts, or is reopened with no document open, on a window
//  showing the Welcome screen instead of the Open panel. On by default;
//  turning it off brings the Open panel back.
//

import Foundation

enum WelcomeScreenSetting {
    static let defaultsKey = "MarkdownPreview.showsWelcomeScreen"

    static var isEnabled: Bool {
        get { read(from: .standard) }
        set { write(newValue, to: .standard) }
    }

    static func read(from defaults: UserDefaults?) -> Bool {
        (defaults?.object(forKey: defaultsKey) as? Bool) ?? true
    }

    /// On clears the key rather than storing `true`: an untouched
    /// preference leaves no trace.
    static func write(_ isEnabled: Bool, to defaults: UserDefaults?) {
        if isEnabled {
            defaults?.removeObject(forKey: defaultsKey)
        } else {
            defaults?.set(false, forKey: defaultsKey)
        }
    }
}
