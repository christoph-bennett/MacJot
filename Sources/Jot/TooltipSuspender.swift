import AppKit

/// Takes the tooltips off a window's views while it is closed and puts them back when it
/// reopens. A tooltip timer that is still pending when the window closes (the pointer was over
/// a view with a tooltip) can otherwise fire with no window on screen: a "ghost tooltip".
@MainActor
final class TooltipSuspender {
    private var viewTips: [(view: NSView, tip: String?)] = []
    private var segmentTips: [(control: NSSegmentedControl, tips: [String?])] = []

    func suspend(_ root: NSView?) {
        guard viewTips.isEmpty, segmentTips.isEmpty, let root else { return }  // already suspended
        collect(root)
        for (view, _) in viewTips { view.toolTip = nil; view.removeAllToolTips() }
        for (control, tips) in segmentTips {
            for segment in tips.indices { control.setToolTip(nil, forSegment: segment) }
        }
    }

    func restore() {
        for (view, tip) in viewTips { view.toolTip = tip }
        for (control, tips) in segmentTips {
            for (segment, tip) in tips.enumerated() { control.setToolTip(tip, forSegment: segment) }
        }
        viewTips = []
        segmentTips = []
    }

    private func collect(_ view: NSView) {
        if let control = view as? NSSegmentedControl {
            segmentTips.append((control, (0..<control.segmentCount).map { control.toolTip(forSegment: $0) }))
        }
        if let tip = view.toolTip { viewTips.append((view, tip)) }
        view.subviews.forEach(collect)
    }
}
