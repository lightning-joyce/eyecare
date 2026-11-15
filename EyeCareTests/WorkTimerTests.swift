import XCTest

final class WorkTimerTests: XCTestCase {
    func testEndingShortBreakEarlyResumesWorkAndPreservesLongBreakProgress() {
        var timer = WorkTimer(now: 0)
        timer.update(at: 1200, idleSeconds: 0, suspended: false)
        XCTAssertEqual(timer.schedule.session?.kind, .short)

        timer.endBreak(at: 1202)
        XCTAssertNil(timer.schedule.session)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1200)
        XCTAssertEqual(timer.schedule.untilLongBreak, 2400)

        timer.update(at: 1203, idleSeconds: 0, suspended: false)
        XCTAssertNil(timer.schedule.session)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1199)
        XCTAssertEqual(timer.schedule.untilLongBreak, 2399)
    }

    func testEndingLongBreakEarlyDoesNotImmediatelyShowAnOverlayAgain() {
        var timer = WorkTimer(now: 0)
        timer.update(at: 3600, idleSeconds: 0, suspended: false)
        XCTAssertEqual(timer.schedule.session?.kind, .long)
        timer.update(at: 3720, idleSeconds: 120, suspended: false)
        XCTAssertNotNil(timer.awaySince)

        timer.endBreak(at: 3721)
        XCTAssertNil(timer.schedule.session)
        XCTAssertNil(timer.awaySince)
        timer.update(at: 3722, idleSeconds: 122, suspended: false)
        XCTAssertNil(timer.schedule.session)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1199)
        XCTAssertEqual(timer.schedule.untilLongBreak, 3599)
    }

    func testIdleTimeIsRemovedAndOnlyTheDistanceBreakResetsAfterThreeMinutes() {
        var timer = WorkTimer(now: 0)
        timer.update(at: 600, idleSeconds: 0, suspended: false)
        timer.update(at: 690, idleSeconds: 90, suspended: false)
        timer.update(at: 720, idleSeconds: 120, suspended: false)

        XCTAssertEqual(timer.awaySince, 600)
        XCTAssertEqual(timer.schedule.untilLongBreak, 3000)
        XCTAssertNil(timer.schedule.session)

        timer.update(at: 780.25, idleSeconds: 0.25, suspended: false)
        XCTAssertNil(timer.awaySince)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1199.75)
        XCTAssertEqual(timer.schedule.untilLongBreak, 2999.75)
    }

    func testLongAbsenceResetsBothTimersAndHonorsCustomDuration() {
        var timer = WorkTimer(now: 0)
        timer.schedule.longDuration = 8 * 60
        timer.update(at: 600, idleSeconds: 0, suspended: false)
        timer.update(at: 720, idleSeconds: 120, suspended: false)
        timer.update(at: 900, idleSeconds: 0, suspended: false)
        XCTAssertEqual(timer.schedule.untilLongBreak, 3000)

        timer.update(at: 1000, idleSeconds: 0, suspended: false)
        timer.update(at: 1120, idleSeconds: 120, suspended: false)
        timer.update(at: 1480, idleSeconds: 0, suspended: false)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1200)
        XCTAssertEqual(timer.schedule.untilLongBreak, 3600)
    }

    func testReminderWaitsForInputUnlessTheIdlePeriodQualifiesAsRest() {
        var timer = WorkTimer(now: 0)
        timer.update(at: 1160, idleSeconds: 0, suspended: false)
        timer.update(at: 1200, idleSeconds: 40, suspended: false)
        XCTAssertNil(timer.schedule.session)

        var returnsEarly = timer
        returnsEarly.update(at: 1220, idleSeconds: 0, suspended: false)
        XCTAssertEqual(returnsEarly.schedule.session?.kind, .short)

        timer.update(at: 1280, idleSeconds: 120, suspended: false)
        timer.update(at: 1340, idleSeconds: 0, suspended: false)
        XCTAssertNil(timer.schedule.session)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1200)
    }

    func testShortLockDoesNotResetAndAutomaticWakeDoesNotEndLongAbsence() {
        var timer = WorkTimer(now: 0)
        timer.update(at: 500, idleSeconds: 0, suspended: false)
        timer.update(at: 520, idleSeconds: 20, suspended: true)
        timer.update(at: 535, idleSeconds: 0, suspended: false)
        XCTAssertEqual(timer.schedule.untilShortBreak, 680)

        timer.update(at: 600, idleSeconds: 1, suspended: true)
        timer.update(at: 710, idleSeconds: 111, suspended: false)
        XCTAssertEqual(timer.awaySince, 600)
        timer.update(at: 900, idleSeconds: 0, suspended: false)
        XCTAssertNil(timer.awaySince)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1200)
        XCTAssertEqual(timer.schedule.untilLongBreak, 3600)
    }

    func testReadingModeIgnoresIdleInputAndCanExpire() {
        var timer = WorkTimer(now: 0)
        timer.keepTiming(at: 0)
        timer.update(at: 1200, idleSeconds: 1200, suspended: false)
        XCTAssertEqual(timer.schedule.session?.kind, .short)
        timer.update(at: 1220, idleSeconds: 1220, suspended: false)
        timer.update(at: 1800, idleSeconds: 1800, suspended: false)
        XCTAssertNil(timer.readingUntil)
        XCTAssertNil(timer.awaySince)
        timer.update(at: 1920, idleSeconds: 1920, suspended: false)
        XCTAssertEqual(timer.awaySince, 1800)
    }

    func testLockStillPausesReadingMode() {
        var timer = WorkTimer(now: 0)
        timer.keepTiming(at: 0)
        timer.update(at: 1000, idleSeconds: 1000, suspended: true)
        timer.update(at: 1220, idleSeconds: 1220, suspended: true)
        timer.update(at: 1230, idleSeconds: 0, suspended: false)
        XCTAssertNil(timer.schedule.session)
        XCTAssertEqual(timer.schedule.untilShortBreak, 1200)
        XCTAssertEqual(timer.schedule.untilLongBreak, 2600)
    }
}
