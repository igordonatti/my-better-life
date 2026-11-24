import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("TimelineMath")
struct TimelineMathTests {
    @Test("Snaps minutes to nearest 15-minute increment and clamps bounds")
    func snapMinutes() {
        #expect(TimelineMath.snap(minute: 0) == 0)
        #expect(TimelineMath.snap(minute: 7) == 0)
        #expect(TimelineMath.snap(minute: 8) == 15)
        #expect(TimelineMath.snap(minute: 37) == 30)
        #expect(TimelineMath.snap(minute: 53) == 60)
        #expect(TimelineMath.snap(minute: -25) == 0)
        #expect(TimelineMath.snap(minute: 1500) == 1440)
    }

    @Test("Snaps signed minute deltas in both upward (negative) and downward (positive) directions")
    func snapSignedDelta() {
        #expect(TimelineMath.snapDelta(minutes: -60) == -60)
        #expect(TimelineMath.snapDelta(minutes: -22) == -15)
        #expect(TimelineMath.snapDelta(minutes: -23) == -30)
        #expect(TimelineMath.snapDelta(minutes: -7) == 0)
        #expect(TimelineMath.snapDelta(minutes: 0) == 0)
        #expect(TimelineMath.snapDelta(minutes: 8) == 15)
        #expect(TimelineMath.snapDelta(minutes: 45) == 45)
    }

    @Test("Converts Y coordinates to snapped minute-of-day and back")
    func coordinateConversion() {
        let hourHeight = 64.0
        #expect(TimelineMath.minuteOfDay(forY: 64.0, hourHeight: hourHeight) == 60)
        #expect(TimelineMath.minuteOfDay(forY: 80.0, hourHeight: hourHeight) == 75)
        #expect(TimelineMath.yPosition(forMinute: 90, hourHeight: hourHeight) == 96.0)
    }

    @Test("Formats duration cleanly")
    func formatDuration() {
        #expect(TimelineMath.formatDuration(minutes: 45) == "45min")
        #expect(TimelineMath.formatDuration(minutes: 60) == "1h")
        #expect(TimelineMath.formatDuration(minutes: 90) == "1h 30min")
    }

    @Test("Computes 7 week days starting Monday")
    func weekDaysStartMonday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let wednesday = cal.date(from: DateComponents(year: 2026, month: 11, day: 25))!
        let days = TimelineMath.weekDays(containing: wednesday, calendar: cal)
        #expect(days.count == 7)
        #expect(cal.component(.weekday, from: days.first!) == 2) // Monday
        #expect(cal.component(.weekday, from: days.last!) == 1)  // Sunday
    }
}
