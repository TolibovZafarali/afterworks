import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Afterworks/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 4096, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
context.setAllowsAntialiasing(true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func roundRect(_ rect: NSRect, radius: CGFloat, fill: UInt32) {
    color(fill).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func ellipse(_ rect: NSRect, fill: UInt32) {
    color(fill).setFill()
    NSBezierPath(ovalIn: rect).fill()
}
func polygon(_ points: [NSPoint], fill: UInt32) {
    let path = NSBezierPath()
    path.move(to: points[0])
    points.dropFirst().forEach { path.line(to: $0) }
    path.close()
    color(fill).setFill()
    path.fill()
}

roundRect(NSRect(x: 0, y: 0, width: 1024, height: 1024), radius: 0, fill: 0xEDE3D2)
ellipse(NSRect(x: 130, y: 108, width: 764, height: 750), fill: 0xDDD2BD)
roundRect(NSRect(x: 142, y: 145, width: 740, height: 740), radius: 152, fill: 0xB5C5BD)
roundRect(NSRect(x: 170, y: 176, width: 684, height: 684), radius: 126, fill: 0xA0B7AF)
roundRect(NSRect(x: 202, y: 204, width: 620, height: 620), radius: 104, fill: 0xC3AE83)
roundRect(NSRect(x: 202, y: 230, width: 620, height: 620), radius: 104, fill: 0xDDCCAA)
roundRect(NSRect(x: 225, y: 255, width: 574, height: 574), radius: 87, fill: 0xA6B37C)

roundRect(NSRect(x: 465, y: 268, width: 78, height: 480), radius: 30, fill: 0xC5B38E)
roundRect(NSRect(x: 275, y: 450, width: 440, height: 76), radius: 28, fill: 0xDCC9A0)
roundRect(NSRect(x: 482, y: 279, width: 45, height: 456), radius: 18, fill: 0xE3D1AD)
roundRect(NSRect(x: 291, y: 467, width: 422, height: 42), radius: 17, fill: 0xE3D1AD)

ellipse(NSRect(x: 546, y: 568, width: 211, height: 174), fill: 0x8D9F79)
ellipse(NSRect(x: 553, y: 585, width: 199, height: 170), fill: 0xC9D0A8)
ellipse(NSRect(x: 564, y: 594, width: 178, height: 150), fill: 0x6F9DAD)
ellipse(NSRect(x: 579, y: 621, width: 144, height: 99), fill: 0x81ADBA)
roundRect(NSRect(x: 596, y: 662, width: 67, height: 7), radius: 3, fill: 0xBED2CE)
roundRect(NSRect(x: 647, y: 634, width: 43, height: 6), radius: 3, fill: 0xBED2CE)

ellipse(NSRect(x: 278, y: 585, width: 176, height: 111), fill: 0x8D9D6B)
roundRect(NSRect(x: 351, y: 605, width: 27, height: 114), radius: 8, fill: 0x776247)
ellipse(NSRect(x: 287, y: 655, width: 133, height: 137), fill: 0x435E42)
ellipse(NSRect(x: 333, y: 676, width: 115, height: 108), fill: 0x4B6746)
ellipse(NSRect(x: 302, y: 710, width: 105, height: 104), fill: 0x668356)
ellipse(NSRect(x: 320, y: 718, width: 17, height: 17), fill: 0xC77950)
ellipse(NSRect(x: 380, y: 695, width: 17, height: 17), fill: 0xCB8053)
ellipse(NSRect(x: 367, y: 762, width: 17, height: 17), fill: 0xD59665)

ellipse(NSRect(x: 284, y: 300, width: 168, height: 74), fill: 0x8C9E6F)
polygon([NSPoint(x: 289,y: 346),NSPoint(x: 309,y: 408),NSPoint(x: 365,y: 424),NSPoint(x: 393,y: 371),NSPoint(x: 372,y: 323)], fill: 0x8C9186)
polygon([NSPoint(x: 289,y: 346),NSPoint(x: 309,y: 408),NSPoint(x: 365,y: 424),NSPoint(x: 351,y: 370)], fill: 0xC9C8B6)
polygon([NSPoint(x: 351,y: 370),NSPoint(x: 365,y: 424),NSPoint(x: 393,y: 371),NSPoint(x: 372,y: 323)], fill: 0xADB3A3)
polygon([NSPoint(x: 374,y: 317),NSPoint(x: 382,y: 355),NSPoint(x: 421,y: 366),NSPoint(x: 447,y: 338),NSPoint(x: 429,y: 308)], fill: 0xA2A897)
polygon([NSPoint(x: 382,y: 355),NSPoint(x: 421,y: 366),NSPoint(x: 447,y: 338),NSPoint(x: 409,y: 339)], fill: 0xD6D1BC)

roundRect(NSRect(x: 565, y: 300, width: 173, height: 107), radius: 13, fill: 0x8D9B6E)
roundRect(NSRect(x: 574, y: 335, width: 152, height: 98), radius: 7, fill: 0xDDD2AE)
polygon([NSPoint(x: 565,y: 414),NSPoint(x: 650,y: 483),NSPoint(x: 738,y: 414),NSPoint(x: 650,y: 389)], fill: 0xB86646)
polygon([NSPoint(x: 565,y: 414),NSPoint(x: 650,y: 483),NSPoint(x: 650,y: 453),NSPoint(x: 589,y: 403)], fill: 0xD28A5C)
roundRect(NSRect(x: 632, y: 335, width: 36, height: 54), radius: 4, fill: 0x5E654E)
roundRect(NSRect(x: 590, y: 365, width: 23, height: 26), radius: 3, fill: 0x839C8C)
roundRect(NSRect(x: 690, y: 365, width: 23, height: 26), radius: 3, fill: 0x839C8C)

NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: output))
print(output)
