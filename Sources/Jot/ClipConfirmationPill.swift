import AppKit
import JotCore

/// The Clip Confirmation (ticket 48): a small pill saying "Added to MacJot" and the
/// new Note's Title, at the bottom centre of the screen the mouse is on. It floats
/// above every window, also full-screen apps, never takes focus and lets clicks
/// through, fades in and out, and stays for the duration set in Settings > General.
/// A second Clip while it shows replaces the text and restarts the wait: one pill.
@MainActor
final class ClipConfirmationPill {
    static let durationKey = "clipConfirmationSeconds"

    private var panel: NSPanel?
    private let heading = NSTextField(labelWithString: "Added to MacJot")
    private let titleLabel = NSTextField(labelWithString: "")
    private var hideTask: Task<Void, Never>?
    /// Counts the pill's showings: a fade-out that finishes after a newer Clip began must not hide it.
    private var generation = 0

    private static let maxTitleWidth: CGFloat = 280
    private static let bottomMargin: CGFloat = 56

    func show(title: String) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        titleLabel.stringValue = title
        titleLabel.isHidden = title.isEmpty
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = panel.contentView?.fittingSize ?? .zero
        panel.setContentSize(size)
        (panel.contentView as? NSVisualEffectView)?.layer?.cornerRadius = size.height / 2
        panel.setFrameOrigin(origin(for: size))

        hideTask?.cancel()
        generation += 1
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()  // never makeKey: the app the user is in keeps focus
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: "Added to MacJot. \(title)"])

        let seconds = ClipConfirmation.duration(stored: UserDefaults.standard.object(forKey: Self.durationKey) as? Double)
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        guard let panel else { return }
        let showing = generation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // A new Clip may have started the pill again meanwhile.
            MainActor.assumeIsolated {
                if self?.generation == showing { panel.orderOut(nil) }
            }
        })
    }

    /// Bottom centre of the screen the mouse is on, above the Dock's reach.
    private func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        return NSPoint(x: (area.midX - size.width / 2).rounded(), y: area.minY + Self.bottomMargin)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        // The HUD material: light or dark with the system, no colour of our own.
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.masksToBounds = true

        let check = NSImageView(image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)!)
        check.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        check.contentTintColor = .secondaryLabelColor
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.textColor = .labelColor
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maxTitleWidth).isActive = true

        let row = NSStackView(views: [check, heading, titleLabel])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 18)
        row.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            row.topAnchor.constraint(equalTo: background.topAnchor),
            row.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
        return panel
    }
}
