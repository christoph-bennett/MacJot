import Testing
@testable import JotCore

/// Seam 2: where a Service Clip says it came from (ticket 50).
struct ClipOriginTests {
    private let chrome = FrontmostApp(name: "Google Chrome", windowTitle: "Docs - Google Chrome")

    @Test func withoutThePermissionThereIsASourceAndNoPage() {
        let origin = ClipOrigin.forService(app: chrome, permissionGranted: false)
        #expect(origin.source == "Google Chrome")
        #expect(origin.page == nil)
    }

    @Test func withThePermissionThePageIsCleaned() {
        let origin = ClipOrigin.forService(app: chrome, permissionGranted: true)
        #expect(origin.source == "Google Chrome")
        #expect(origin.page == "Docs")
    }

    @Test func noFrontmostAppMeansNothing() {
        let origin = ClipOrigin.forService(app: nil, permissionGranted: true)
        #expect(origin.source == nil)
        #expect(origin.page == nil)
    }

    @Test func macJotItselfIsNoSource() {
        let me = FrontmostApp(name: "MacJot", windowTitle: nil, isMacJot: true)
        #expect(ClipOrigin.forService(app: me, permissionGranted: true).source == nil)
    }
}
