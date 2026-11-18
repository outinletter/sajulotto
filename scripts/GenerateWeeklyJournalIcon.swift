import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift GenerateWeeklyJournalIcon.swift output.png")
}
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(red: 0.28, green: 0.38, blue: 0.29, alpha: 1)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

let left = CGMutablePath()
left.move(to: CGPoint(x: 490, y: 322))
left.addQuadCurve(to: CGPoint(x: 256, y: 343), control: CGPoint(x: 389, y: 378))
left.addQuadCurve(to: CGPoint(x: 231, y: 367), control: CGPoint(x: 231, y: 340))
left.addLine(to: CGPoint(x: 231, y: 653))
left.addQuadCurve(to: CGPoint(x: 251, y: 676), control: CGPoint(x: 231, y: 673))
left.addQuadCurve(to: CGPoint(x: 490, y: 650), control: CGPoint(x: 384, y: 711))
left.closeSubpath()
var mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: CGFloat(size), ty: 0)
context.setFillColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
context.addPath(left)
context.addPath(left.copy(using: &mirror)!)
context.fillPath()

context.setStrokeColor(red: 0.28, green: 0.38, blue: 0.29, alpha: 1)
context.setLineWidth(18)
context.setLineCap(.round)
context.move(to: CGPoint(x: 584, y: 527))
context.addQuadCurve(to: CGPoint(x: 729, y: 544), control: CGPoint(x: 647, y: 550))
context.strokePath()

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write icon") }
