import AppKit

// WeekPick 앱 아이콘: 크림 배경 위 오행 5색 구슬, 하나만 먹색(이번 주의 선택).
// 사용: swift scripts/GenerateWeekPickIcon.swift <출력 폴더>
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size = 1024
func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
color(0xF4EFE6).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let colors: [UInt32] = [0x2B2A33, 0xEDB89A, 0xE6D3A0, 0xC3CCE0, 0x9CB6E3]  // 위쪽이 선택된 먹색 구슬
let center = CGPoint(x: 512, y: 512 - 6), ring: CGFloat = 255, d: CGFloat = 290
for (i, hex) in colors.enumerated() {
    let angle = CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 5
    let c = CGPoint(x: center.x + ring * cos(angle), y: center.y + ring * sin(angle))
    let rect = NSRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
    color(hex).setFill(); NSBezierPath(ovalIn: rect).fill()
    color(0xFFFFFF, i == 0 ? 0.18 : 0.55).setFill()
    NSBezierPath(ovalIn: NSRect(x: rect.minX + d * 0.2, y: rect.maxY - d * 0.34, width: d * 0.2, height: d * 0.1)).fill()
}
NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
for name in ["AppIcon.png", "BrandIcon.png"] { try png.write(to: URL(fileURLWithPath: out).appendingPathComponent(name)) }
print("ok")
