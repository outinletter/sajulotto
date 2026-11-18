import AppKit

// App Store 스크린샷 합성: 앱 캡처 + 배경색 + 홍보 문구 (1206×2622 세로 — App Store Connect가 허용하는 iPhone 크기)
// 사용: swift scripts/ComposeScreenshots.swift <입력 폴더> <출력 폴더>
let args = CommandLine.arguments
let inDir = args.count > 1 ? args[1] : ".", outDir = args.count > 2 ? args[2] : "."
func color(_ hex: UInt32) -> NSColor { NSColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }

struct Slide { let file: String, out: String, title: String, sub: String, bg: UInt32; var cropTop: Double = 120 }
let slides = [
    Slide(file: "26.webp", out: "01-choice", title: "오늘의 기운으로\n고르는 오늘의 선택", sub: "선택지마다 오행 일치도를 한눈에", bg: 0xDCE3F2),
    Slide(file: "24.webp", out: "02-together", title: "친구와 함께\n모임 메뉴도 한 번에", sub: "모두의 기운을 합쳐 골라 줘요", bg: 0xF3E4C4),
    Slide(file: "27.webp", out: "03-week", title: "이번 주의 선택이\n한 줄씩 쌓여요", sub: "고른 쪽이 더 길고 진하게 보여요", bg: 0xF5D9CA, cropTop: 106),
    Slide(file: "23.webp", out: "04-journal", title: "선택을 돌아보는\n한 줄 기록", sub: "도감에 차곡차곡 저장돼요", bg: 0xD6E8DC),
]
let W = 1206, H = 2622
let K = CGFloat(W) / 1320
let cropRight: CGFloat = 14   // 스크롤 표시 막대 제거(원본 폭 920 기준)

for s in slides {
    guard let img = NSImage(contentsOfFile: inDir + "/" + s.file), let rep0 = img.representations.first else { print("missing \(s.file)"); continue }
    let sw = CGFloat(rep0.pixelsWide), sh = CGFloat(rep0.pixelsHigh)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    color(s.bg).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

    // 문구 (좌표계: 아래가 0)
    let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineSpacing = 8 * K
    let title = NSAttributedString(string: s.title, attributes: [.font: NSFont(name: "AppleSDGothicNeo-ExtraBold", size: 92 * K) ?? .boldSystemFont(ofSize: 92 * K), .foregroundColor: color(0x25242B), .paragraphStyle: style])
    title.draw(in: NSRect(x: 60 * K, y: CGFloat(H) - 380 * K, width: CGFloat(W) - 120 * K, height: 280 * K))
    let sub = NSAttributedString(string: s.sub, attributes: [.font: NSFont(name: "AppleSDGothicNeo-Medium", size: 46 * K) ?? .systemFont(ofSize: 46 * K), .foregroundColor: color(0x5C5850), .paragraphStyle: style])
    sub.draw(in: NSRect(x: 60 * K, y: CGFloat(H) - 470 * K, width: CGFloat(W) - 120 * K, height: 70 * K))

    // 화면 (상태바 제거, 위쪽만 둥글게, 아래는 캔버스 밖으로 이어짐)
    let cropTop = CGFloat(s.cropTop)
    let scale = CGFloat(1110) * K / (sw - cropRight)
    let drawW = (sw - cropRight) * scale, drawH = (sh - cropTop) * scale
    let x = (CGFloat(W) - drawW) / 2, top = CGFloat(H) - 560 * K
    let rect = NSRect(x: x, y: top - drawH, width: drawW, height: drawH)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.18); shadow.shadowBlurRadius = 60 * K; shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: 84 * K, yRadius: 84 * K)
    NSColor.white.setFill(); path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()
    img.draw(in: NSRect(x: x, y: top - drawH, width: drawW, height: sh * scale), from: NSRect(x: 0, y: 0, width: sw - cropRight, height: sh), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outDir + "/" + s.out + ".png"))
    print("ok", s.out)
}
