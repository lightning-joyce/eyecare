import XCTest

final class BreakScheduleTests: XCTestCase {
    func testShortBreakStartsAtTwentyMinutesAndEndsAfterTwentySeconds() {
        var schedule = BreakSchedule(now: 0)
        schedule.advance(to: 1199, countingWork: true, canStartBreak: true)
        XCTAssertNil(schedule.session)

        schedule.advance(to: 1200, countingWork: true, canStartBreak: true)
        XCTAssertEqual(schedule.session, BreakSession(kind: .short, duration: 20, endsAt: 1220))
        schedule.advance(to: 1219, countingWork: true, canStartBreak: true)
        XCTAssertNotNil(schedule.session)

        schedule.advance(to: 1220, countingWork: true, canStartBreak: true)
        XCTAssertNil(schedule.session)
        XCTAssertEqual(schedule.untilShortBreak, 1200)
        XCTAssertEqual(schedule.untilLongBreak, 2400)
    }

    func testLongBreakWinsWhenBothAreDue() {
        var schedule = BreakSchedule(now: 0)
        schedule.advance(to: 1200, countingWork: true, canStartBreak: true)
        schedule.advance(to: 1220, countingWork: true, canStartBreak: true)
        schedule.advance(to: 2420, countingWork: true, canStartBreak: true)
        schedule.advance(to: 2440, countingWork: true, canStartBreak: true)
        schedule.advance(to: 3640, countingWork: true, canStartBreak: true)
        XCTAssertEqual(schedule.session, BreakSession(kind: .long, duration: 300, endsAt: 3940))
        schedule.advance(to: 3940, countingWork: true, canStartBreak: true)
        XCTAssertNil(schedule.session)
        XCTAssertEqual(schedule.untilShortBreak, 1200)
        XCTAssertEqual(schedule.untilLongBreak, 3600)
    }

    func testSuspensionPausesWorkAndLetsAnActiveBreakFinish() {
        var schedule = BreakSchedule(now: 0)
        schedule.advance(to: 600, countingWork: true, canStartBreak: false)
        schedule.creditNaturalBreak(20)
        schedule.advance(to: 7200, countingWork: false, canStartBreak: false)
        XCTAssertEqual(schedule.untilShortBreak, 1200)
        XCTAssertEqual(schedule.untilLongBreak, 3000)

        schedule.start(.long, at: 7200)
        schedule.advance(to: 7600, countingWork: false, canStartBreak: false)
        XCTAssertNil(schedule.session)
        XCTAssertEqual(schedule.untilLongBreak, 3600)
    }

    func testChangingLongBreakPreferencesPreservesWorkAndCurrentBreakDuration() {
        var schedule = BreakSchedule(now: 0)
        schedule.longInterval = 7200
        schedule.advance(to: 3500, countingWork: true, canStartBreak: false)
        schedule.longInterval = 3600
        schedule.longDuration = 60
        schedule.advance(to: 3600, countingWork: true, canStartBreak: true)
        schedule.longDuration = 120
        XCTAssertEqual(schedule.session, BreakSession(kind: .long, duration: 60, endsAt: 3660))
    }
}
