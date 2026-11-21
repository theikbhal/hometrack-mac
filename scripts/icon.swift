import AppKit
let out = CommandLine.arguments[1]
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let bg = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(red: 0.25, green: 0.30, blue: 0.75, alpha: 1),
           ending: NSColor(red: 0.10, green: 0.60, blue: 0.62, alpha: 1))!.draw(in: bg, angle: -50)
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 620, weight: .bold),
    .foregroundColor: NSColor.white
]
let str = NSAttributedString(string: "₹", attributes: attrs)
let sz = str.size()
str.draw(at: NSPoint(x: (S - sz.width) / 2, y: (S - sz.height) / 2))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
