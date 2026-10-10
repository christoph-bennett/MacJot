import Foundation
import Testing
@testable import JotCore

/// Settings > Editor > Line Spacing (ticket 33): the space below each line.
struct LineSpacingTests {
    @Test func normalIsTheEditorsFormerSpacing() {
        #expect(LineSpacing.normal.points(fontSize: 14) == 2)
        #expect(LineSpacing.normal.points(fontSize: 24) == 2)
    }

    @Test func tightHasNoneAndRelaxedGrowsWithTheFont() {
        #expect(LineSpacing.tight.points(fontSize: 14) == 0)
        #expect(LineSpacing.relaxed.points(fontSize: 10) < LineSpacing.relaxed.points(fontSize: 20))
        for size in [11.0, 14, 24] {
            #expect(LineSpacing.relaxed.points(fontSize: size) > LineSpacing.normal.points(fontSize: size))
        }
    }

    @Test func storedByName() {
        #expect(LineSpacing(rawValue: "relaxed") == .relaxed)
        #expect(LineSpacing.allCases.map(\.title) == ["Tight", "Normal", "Relaxed"])
    }
}
