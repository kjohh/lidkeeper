// 畫出 app 圖示的 1024px PNG。由 Tools/make-icon.sh 呼叫，平常不用跑。
import AppKit

let side: CGFloat = 1024
let inset: CGFloat = 100          // macOS 圖示慣例：內容不要貼齊邊界
let radius: CGFloat = 200

let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

guard let context = NSGraphicsContext.current else { exit(1) }
context.imageInterpolation = .high

// 底：深靛藍到近黑的漸層，代表闔上的螢幕
let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let shape = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)
shape.addClip()

let gradient = NSGradient(
    starting: NSColor(srgbRed: 0.16, green: 0.20, blue: 0.32, alpha: 1),
    ending: NSColor(srgbRed: 0.06, green: 0.07, blue: 0.12, alpha: 1)
)
gradient?.draw(in: plate, angle: -90)

// 前景：咖啡杯，跟選單列上的圖示是同一個符號
let symbolSize: CGFloat = 400
let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)

guard let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    print("拿不到 SF Symbol")
    exit(1)
}

let box = NSRect(
    x: (side - symbol.size.width) / 2,
    y: (side - symbol.size.height) / 2 + 12,
    width: symbol.size.width,
    height: symbol.size.height
)

let white = NSImage(size: symbol.size, flipped: false) { rect in
    NSColor.white.setFill()
    rect.fill()
    symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
    return true
}
white.draw(in: box)

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
