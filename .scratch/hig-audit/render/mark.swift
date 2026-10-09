import AppKit
// mark <in.png> <out.png> "x,y,w,h,label" ...   (pixels, origin top-left)
let a = CommandLine.arguments
let image = NSImage(contentsOfFile: a[1])!
let rep = image.representations[0] as! NSBitmapImageRep
let W = rep.pixelsWide, H = rep.pixelsHigh
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
rep.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
let red = NSColor(srgbRed: 0.9, green: 0.1, blue: 0.2, alpha: 1)
for spec in a.dropFirst(3) {
    let p = spec.split(separator: ",").map(String.init)
    let (x, y, w, h) = (Double(p[0])!, Double(p[1])!, Double(p[2])!, Double(p[3])!)
    let r = NSRect(x: x, y: Double(H) - y - h, width: w, height: h)
    red.setStroke()
    let path = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8); path.lineWidth = 4; path.stroke()
    let c = NSRect(x: r.maxX - 22, y: r.maxY - 22, width: 44, height: 44)
    red.setFill(); NSBezierPath(ovalIn: c).fill()
    let label = p[4] as NSString
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 26), .foregroundColor: NSColor.white]
    let size = label.size(withAttributes: attrs)
    label.draw(at: NSPoint(x: c.midX - size.width / 2, y: c.midY - size.height / 2), withAttributes: attrs)
}
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
