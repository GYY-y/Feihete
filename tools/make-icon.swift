// 从 Feihete.svg 生成 macOS 应用图标 AppIcon.icns
// 用法：bash tools/make-icon.sh
import AppKit
import CoreGraphics

let root = FileManager.default.currentDirectoryPath
let svgURL = URL(fileURLWithPath: root).appendingPathComponent("Feihete.svg")
let outURL = URL(fileURLWithPath: root).appendingPathComponent("AppIcon.icns")

guard let logo = NSImage(contentsOf: svgURL) else {
    FileHandle.standardError.write("无法读取 Feihete.svg\n".data(using: .utf8)!)
    exit(1)
}

/// 生成 macOS 风格的连续圆角（squircle）路径
func squircle(rect: CGRect, n: CGFloat = 5.0) -> CGPath {
    let path = CGMutablePath()
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2 / n), st)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func renderIcon(size: CGFloat) -> Data {
    let px = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("bitmap 创建失败") }

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    let full = CGRect(x: 0, y: 0, width: size, height: size)
    // macOS 图标规范：内容区留约 8% 边距
    let inset = size * 0.08
    let body = full.insetBy(dx: inset, dy: inset)
    let shape = squircle(rect: body)

    // 背景：深墨蓝渐变，衬托白色仙鹤
    ctx.cgContext.saveGState()
    ctx.cgContext.addPath(shape)
    ctx.cgContext.clip()
    let colors = [
        NSColor(srgbRed: 0.153, green: 0.302, blue: 0.486, alpha: 1).cgColor,
        NSColor(srgbRed: 0.043, green: 0.137, blue: 0.243, alpha: 1).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    ctx.cgContext.drawLinearGradient(gradient,
                                     start: CGPoint(x: body.midX, y: body.maxY),
                                     end: CGPoint(x: body.midX, y: body.minY),
                                     options: [])
    ctx.cgContext.restoreGState()

    // 内描边，增强立体感
    ctx.cgContext.saveGState()
    ctx.cgContext.addPath(shape)
    ctx.cgContext.setStrokeColor(NSColor(white: 1.0, alpha: 0.14).cgColor)
    ctx.cgContext.setLineWidth(max(1, size * 0.006))
    ctx.cgContext.strokePath()
    ctx.cgContext.restoreGState()

    // Logo 居中，等比缩放至内容区宽度的 74%
    let logoAspect = logo.size.width / max(logo.size.height, 1)
    let maxW = body.width * 0.74
    let maxH = body.height * 0.74
    var w = maxW
    var h = w / logoAspect
    if h > maxH { h = maxH; w = h * logoAspect }
    let logoRect = CGRect(x: body.midX - w / 2, y: body.midY - h / 2, width: w, height: h)
    logo.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1.0,
              respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// 生成 iconset
let iconsetDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Feihete.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let variants: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (base, scale) in variants {
    let px = base * scale
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    let data = renderIcon(size: CGFloat(px))
    try! data.write(to: iconsetDir.appendingPathComponent(name))
    print("生成 \(name)  (\(px)px)")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", outURL.path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil 失败\n".data(using: .utf8)!)
    exit(1)
}
print("已生成 \(outURL.path)")
