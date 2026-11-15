import Foundation

/// The `source` and `page` of a Clip that the Service made (ticket 50).
public enum ClipOrigin {
    /// The frontmost app's name, and its cleaned window title only if the
    /// Accessibility permission was granted (without it the title isn't read).
    public static func forService(app: FrontmostApp?, permissionGranted: Bool) -> (source: String?, page: String?) {
        guard let app, !app.isMacJot else { return (nil, nil) }
        let page = permissionGranted ? PageTitle.page(app: app.name, windowTitle: app.windowTitle) : nil
        return (app.name, page)
    }
}
