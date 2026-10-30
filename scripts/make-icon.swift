import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()
let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 220, yRadius: 220)
NSColor(red: 0.13, green: 0.17, blue: 0.18, alpha: 1).setFill()
background.fill()
NSColor(red: 0.74, green: 0.70, blue: 0.96, alpha: 1).setStroke()
let path = NSBezierPath()
path.lineWidth = 82; path.lineCapStyle = .round; path.lineJoinStyle = .round
path.move(to: NSPoint(x: 305, y: 305)); path.line(to: NSPoint(x: 718, y: 718))
path.move(to: NSPoint(x: 355, y: 718)); path.line(to: NSPoint(x: 718, y: 718)); path.line(to: NSPoint(x: 718, y: 355))
path.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
