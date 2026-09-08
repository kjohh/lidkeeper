// 畫出 app 圖示的 1024px PNG。由 Tools/make-icon.sh 呼叫，平常不用跑。
//
// 圖示就是面板上那隻精靈。顏色跟 PanelView 的霧藍同一組，
// 底板留著是因為沒有底的圖示在 Finder 的列表檢視裡會顯得特別小。
import AppKit

let side: CGFloat = 1024
let inset: CGFloat = 92
let radius: CGFloat = 224

func srgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

guard let context = NSGraphicsContext.current else { exit(1) }
context.imageInterpolation = .high

// 底板：面板背景那層霧藍，上淺下白
let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let plateShape = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)
plateShape.addClip()

NSGradient(starting: srgb(0.976, 0.984, 0.996), ending: srgb(0.831, 0.878, 0.941))?
    .draw(in: plate, angle: -90)

// 球
let orbSide: CGFloat = 560
let orbRect = NSRect(x: (side - orbSide) / 2, y: (side - orbSide) / 2 + 34,
                     width: orbSide, height: orbSide)

// 落在底板上的影子。壓扁，跟面板裡投在鍵盤上的那片同一個道理。
let shadowRect = NSRect(x: orbRect.midX - orbSide * 0.44, y: orbRect.minY - 42,
                        width: orbSide * 0.88, height: orbSide * 0.2)
NSGradient(colors: [srgb(0.16, 0.18, 0.22, 0.26), srgb(0.16, 0.18, 0.22, 0)],
           atLocations: [0, 1], colorSpace: .sRGB)?
    .draw(in: NSBezierPath(ovalIn: shadowRect), relativeCenterPosition: .zero)

// 球體。光源在左上，所以漸層中心偏左上。
let orbPath = NSBezierPath(ovalIn: orbRect)
NSGradient(colors: [srgb(0.882, 0.910, 0.945), srgb(0.678, 0.737, 0.804),
                    srgb(0.510, 0.588, 0.682), srgb(0.333, 0.396, 0.478)],
           atLocations: [0, 0.30, 0.64, 1], colorSpace: .sRGB)?
    .draw(in: orbPath, relativeCenterPosition: NSPoint(x: -0.34, y: 0.42))

// 右下的環境反光，讓球不會只有一側有立體感
orbPath.addClip()
NSGradient(colors: [srgb(1, 1, 1, 0), srgb(1, 1, 1, 0), srgb(1, 1, 1, 0.34)],
           atLocations: [0, 0.66, 1], colorSpace: .sRGB)?
    .draw(in: orbRect, angle: -55)

// 主高光加一顆銳利的小點
let glareRect = NSRect(x: orbRect.minX + orbSide * 0.15, y: orbRect.maxY - orbSide * 0.34,
                       width: orbSide * 0.36, height: orbSide * 0.22)
NSGradient(colors: [srgb(1, 1, 1, 0.82), srgb(1, 1, 1, 0)], atLocations: [0, 1], colorSpace: .sRGB)?
    .draw(in: NSBezierPath(ovalIn: glareRect), relativeCenterPosition: .zero)

let sparkSide = orbSide * 0.075
let sparkRect = NSRect(x: orbRect.minX + orbSide * 0.2, y: orbRect.maxY - orbSide * 0.28,
                       width: sparkSide, height: sparkSide)
srgb(1, 1, 1, 0.9).setFill()
NSBezierPath(ovalIn: sparkRect).fill()

// 眼睛。位置跟面板上那顆一致：略低於球心，間距約球徑的四分之一。
let eyeW = orbSide * 0.135
let eyeH = eyeW * 1.24
let eyeGap = orbSide * 0.225
let eyeY = orbRect.midY - orbSide * 0.09 - eyeH / 2

for dx in [-eyeGap / 2 - eyeW / 2, eyeGap / 2 - eyeW / 2] {
    let white = NSRect(x: orbRect.midX + dx, y: eyeY, width: eyeW, height: eyeH)
    srgb(1, 0.996, 0.98).setFill()
    NSBezierPath(ovalIn: white).fill()

    let pupilW = eyeW * 0.53
    let pupilH = eyeH * 0.66
    let pupil = NSRect(x: white.midX - pupilW / 2, y: white.midY - pupilH / 2,
                       width: pupilW, height: pupilH)
    srgb(0.133, 0.188, 0.247).setFill()
    NSBezierPath(ovalIn: pupil).fill()

    let dotSide = eyeW * 0.22
    let dot = NSRect(x: pupil.minX + pupilW * 0.06, y: pupil.maxY - dotSide * 1.1,
                     width: dotSide, height: dotSide)
    srgb(1, 1, 1, 0.9).setFill()
    NSBezierPath(ovalIn: dot).fill()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("轉 PNG 失敗")
    exit(1)
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try png.write(to: URL(fileURLWithPath: output))
print("畫好了：\(output)")
