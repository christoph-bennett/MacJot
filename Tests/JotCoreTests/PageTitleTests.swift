import Testing
@testable import JotCore

/// Seam 2: a Clip's `page` from the front window's title (ticket 49, findings of ticket 45).
struct PageTitleTests {
    @Test(arguments: [
        // (app, window title, page)
        ("Google Chrome", "GitHub · Change is constant. GitHub keeps you ahead. · GitHub · GitHub - Google Chrome",
         "GitHub · Change is constant. GitHub keeps you ahead. · GitHub · GitHub"),
        ("Google Chrome", "Finis - Write your book - Google Chrome - Personal", "Finis - Write your book"),
        ("Google Chrome", "Finis – Google Chrome – Person 1", "Finis"),
        ("Microsoft Edge", "Docs - Microsoft Edge", "Docs"),
        ("Brave Browser", "News - Brave", "News"),
        ("Safari", "Personal — Peer/SKILL.md at main · andykear/Peer", "Peer/SKILL.md at main · andykear/Peer"),
        ("Safari", "Finis — Write your book", "Write your book"),  // a leading segment is always the profile
        ("Safari", "No profile here", "No profile here"),
        ("Firefox", "Some page — Mozilla Firefox", "Some page"),
        ("Firefox", "Some page - Mozilla Firefox", "Some page"),
        ("Pages", "CV.pages", "CV.pages"),
        ("Preview", "screenshot-dark.png", "screenshot-dark.png"),
    ])
    func cleaning(_ app: String, _ title: String, _ page: String) {
        #expect(PageTitle.page(app: app, windowTitle: title) == page)
    }

    @Test(arguments: ["Terminal", "iTerm2", "iTerm"])
    func terminalsGivePageNothing(_ app: String) {
        #expect(PageTitle.page(app: app, windowTitle: "mac-notes — PasteboardInspector — 162×48") == nil)
    }

    @Test func noTitleMeansNoPage() {
        #expect(PageTitle.page(app: "Safari", windowTitle: nil) == nil)
        #expect(PageTitle.page(app: "Safari", windowTitle: "  ") == nil)
        #expect(PageTitle.page(app: "Google Chrome", windowTitle: " - Google Chrome") == nil)
    }
}
