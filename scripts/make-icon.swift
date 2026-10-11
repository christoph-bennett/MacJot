// Puts full-bleed square artwork on the macOS icon grid: a 1024 canvas with
// an 824 rounded rectangle and a soft shadow, transparent around it.
// Usage: swift scripts/make-icon.swift <artwork.png> <out-1024.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 3,
      let source = NSImage(contentsOfFile: args[1]),
      let artwork = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("usage: make-icon.swift <artwork.png> <out-1024.png>\n".data(using: .utf8)!)
    exit(1)
}

let size = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let corner: CGFloat = 185.4

let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.interpolationQuality = .high
let shape = CGPath(roundedRect: tile, cornerWidth: corner, cornerHeight: corner, transform: nil)

// The shadow Apple's icon template uses: 10 px below, 20 px blur, 30% black.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20,
                  color: CGColor(gray: 0, alpha: 0.3))
context.addPath(shape)
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fillPath()
context.restoreGState()

context.addPath(shape)
context.clip()
context.draw(artwork, in: tile)

let output = NSBitmapImageRep(cgImage: context.makeImage()!)
try! output.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: args[2]))
