import Testing
@testable import MyBetterLifeCore

@Suite("OverlapLayoutEngine")
struct OverlapLayoutEngineTests {
    @Test("Non-overlapping blocks each occupy full single column")
    func nonOverlapping() {
        let items = [
            TimelineLayoutInput(id: "a", startMinute: 540, endMinute: 600),
            TimelineLayoutInput(id: "b", startMinute: 600, endMinute: 660)
        ]
        let layout = OverlapLayoutEngine.layout(items: items)
        #expect(layout["a"]?.column == 0)
        #expect(layout["a"]?.totalColumns == 1)
        #expect(layout["b"]?.column == 0)
        #expect(layout["b"]?.totalColumns == 1)
    }

    @Test("Overlapping blocks split into distinct columns within cluster")
    func overlappingCluster() {
        // Mirrors screenshot: 13:00-17:00 overlapping with 15:30-16:30
        let items = [
            TimelineLayoutInput(id: "long", startMinute: 13 * 60, endMinute: 17 * 60),
            TimelineLayoutInput(id: "nested", startMinute: 15 * 60 + 30, endMinute: 16 * 60 + 30)
        ]
        let layout = OverlapLayoutEngine.layout(items: items)
        #expect(layout["long"]?.totalColumns == 2)
        #expect(layout["nested"]?.totalColumns == 2)
        #expect(layout["long"]?.column == 0)
        #expect(layout["nested"]?.column == 1)
    }

    @Test("Reuses freed column inside a 3-item cluster")
    func columnReuse() {
        let items = [
            TimelineLayoutInput(id: "a", startMinute: 600, endMinute: 720), // 10:00-12:00 -> col 0
            TimelineLayoutInput(id: "b", startMinute: 615, endMinute: 645), // 10:15-10:45 -> col 1
            TimelineLayoutInput(id: "c", startMinute: 660, endMinute: 700)  // 11:00-11:40 -> reuses col 1
        ]
        let layout = OverlapLayoutEngine.layout(items: items)
        #expect(layout["a"]?.totalColumns == 2)
        #expect(layout["a"]?.column == 0)
        #expect(layout["b"]?.column == 1)
        #expect(layout["c"]?.column == 1)
    }
}
