import Foundation
import XCTest
@testable import MarkdownHelpers

final class WelcomeScreenSettingTests: XCTestCase {
    func testEnabledByDefault() throws {
        let defaults = try makeDefaults()

        XCTAssertTrue(WelcomeScreenSetting.read(from: defaults))
    }

    func testDisablingIsStoredAndReadBack() throws {
        let defaults = try makeDefaults()

        WelcomeScreenSetting.write(false, to: defaults)

        XCTAssertFalse(WelcomeScreenSetting.read(from: defaults))
    }

    func testEnablingAgainLeavesNoKey() throws {
        let defaults = try makeDefaults()
        WelcomeScreenSetting.write(false, to: defaults)

        WelcomeScreenSetting.write(true, to: defaults)

        XCTAssertNil(defaults.object(forKey: WelcomeScreenSetting.defaultsKey))
        XCTAssertTrue(WelcomeScreenSetting.read(from: defaults))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "WelcomeScreenSettingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
