import XCTest

final class ReadingSizeTests: XCTestCase {
    func testSliderBoundsAndPreviousPresetMappings() {
        let smallest = ReadingSize(points: 9)
        let largest = ReadingSize(points: 33)
        XCTAssertEqual(smallest.points, 10)
        XCTAssertEqual(smallest.systemSliderValue, 0)
        XCTAssertEqual(largest.points, 32)
        XCTAssertEqual(largest.systemSliderValue, 14)
        for (points, level, browserPixels) in [(13, 4, 16), (15, 6, 20), (16, 8, 24)] {
            let size = ReadingSize(points: points)
            XCTAssertEqual(size.systemSliderValue, level)
            XCTAssertEqual(size.browserPixels, browserPixels)
        }
    }

    func testSliderRestoresPreviousPresetAndRemembersTheSavedSize() throws {
        let suite = "EyeCare.ReadingSizeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("large", forKey: "readingSize")
        let preferences = ReadingSizePreferences(defaults: defaults)
        XCTAssertEqual(preferences.selectedSize.points, 15)
        preferences.save(ReadingSize(points: 22))
        let reopened = ReadingSizePreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(reopened.selectedSize.points, 22)
    }

    func testChangingFileTextSizePreservesLayoutAndSeedsTheOpenPanelList() {
        let columns = [["identifier": "name", "width": 320]] as [[String: Any]]
        let input: [String: Any] = [
            "StandardViewSettings": [
                "ExtendedListViewSettingsV2": ["iconSize": 16, "textSize": 13],
                "IconViewSettings": ["iconSize": 64, "textSize": 12],
            ],
            "FK_StandardViewSettings": ["ExtendedListViewSettingsV2": ["columns": columns, "textSize": 13]],
            "FK_DefaultIconViewSettings": ["iconSize": 48, "textSize": 12],
        ]

        let result = FinderTextSize.updated(input, size: ReadingSize(points: 22))
        let views = result["StandardViewSettings"] as? [String: [String: Int]]
        XCTAssertEqual(views?["ExtendedListViewSettingsV2"], ["iconSize": 16, "textSize": 22])
        XCTAssertEqual(views?["IconViewSettings"], ["iconSize": 64, "textSize": 22])
        XCTAssertEqual(result["FK_DefaultIconViewSettings"] as? [String: Int], ["iconSize": 48, "textSize": 22])
        let panelList = result["FK_DefaultListViewSettingsV2"] as? [String: Any]
        XCTAssertEqual(panelList?["textSize"] as? Int, 22)
        XCTAssertEqual((panelList?["columns"] as? [[String: Any]])?.first?["width"] as? Int, 320)
    }

    func testChangingBrowserTextSizePreservesOtherPreferencesInEachProfile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaultProfile = try makeProfile("Default", in: directory)
        let otherProfile = try makeProfile("Profile 2", in: directory)

        XCTAssertTrue(try BrowserTextSize.apply(ReadingSize(points: 22), in: directory) { false })
        for profile in [defaultProfile, otherProfile] {
            let data = try Data(contentsOf: profile)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let webkit = json["webkit"] as? [String: [String: Int]]
            XCTAssertEqual(webkit?["webprefs"], ["default_font_size": 36, "minimum_font_size": 9])
            XCTAssertEqual(json["spellcheck"] as? Bool, true)
        }
    }

    func testBrowserBecomingActiveBeforeTheWriteLeavesItsPreferencesAlone() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let preferences = try makeProfile("Default", in: directory)
        let original = try Data(contentsOf: preferences)
        var checks = 0
        XCTAssertFalse(try BrowserTextSize.apply(ReadingSize(points: 15), in: directory) {
            checks += 1
            return checks > 1
        })
        XCTAssertEqual(try Data(contentsOf: preferences), original)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func makeProfile(_ name: String, in directory: URL) throws -> URL {
        let profile = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: false)
        let preferences = profile.appendingPathComponent("Preferences")
        let original = #"{"spellcheck":true,"webkit":{"webprefs":{"minimum_font_size":9}}}"#
        try Data(original.utf8).write(to: preferences)
        return preferences
    }
}
