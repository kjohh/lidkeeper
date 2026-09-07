import SwiftUI

/// 筆電的插畫。
///
/// 為什麼是 Canvas 而不是兩個 `rotation3DEffect`：SwiftUI 的 3D 效果是各自獨立的投影，
/// 沒有共用的空間，上蓋從「蓋在機身上」轉到「豎起」一定會跨過 90 度，
/// 投影在那一瞬間縮成一條線再翻到另一邊，看起來就是兩片各自滑動。
/// 這裡自己算 3D 座標再投影，掀蓋就是一段連續的旋轉，中間不會斷。
struct LaptopArt: View {
    /// 0 度是完全闔上（上蓋貼著機身），90 度是豎直，再多就是往後傾。
    var lidAngle: Double
    var awake: Bool
    var palette: LaptopPalette

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let scene = Scene(size: size)
            draw(in: &ctx, scene: scene)
        }
    }

    // MARK: - 幾何

    private struct Scene {
        let center: CGPoint
        /// 相機俯角。0 度是正面平視，90 度是正上方往下看。
        let tilt = 22.0
        let focal = 420.0
        /// 機身寬與深，單位跟畫布一樣
        let width = 174.0
        let depth = 116.0
        let thickness = 8.0

        init(size: CGSize) {
            center = CGPoint(x: size.width / 2, y: size.height * 0.58)
        }

        /// y 往觀眾方向為正，z 往上為正，原點在鉸鏈中央。
        func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
            let t = tilt * .pi / 180
            let depthFromCamera = -y * cos(t) + z * sin(t)
            let k = focal / (focal + depthFromCamera)
            return CGPoint(x: center.x + x * k,
                           y: center.y + (y * sin(t) - z * cos(t)) * k)
        }

        func quad(_ pts: [(Double, Double, Double)]) -> Path {
            var path = Path()
            for (i, p) in pts.enumerated() {
                let s = project(p.0, p.1, p.2)
                if i == 0 { path.move(to: s) } else { path.addLine(to: s) }
            }
            path.closeSubpath()
            return path
        }
    }

    // MARK: - 繪製

    private func draw(in ctx: inout GraphicsContext, scene: Scene) {
        let w = scene.width / 2
        let d = scene.depth
        let rad = lidAngle * .pi / 180
        // 上蓋自由端的位置：闔上時貼在機身前緣，豎起時在鉸鏈正上方
        let ly = d * cos(rad)
        let lz = d * sin(rad)

        deskShadow(&ctx, scene, w: w, d: d)
        if awake { spill(&ctx, scene, w: w, d: d) }

        // 上蓋在鉸鏈後面的時候先畫，才會被機身壓住
        if lidAngle > 90 { lid(&ctx, scene, w: w, ly: ly, lz: lz) }

        chassisFront(&ctx, scene, w: w, d: d)
        deck(&ctx, scene, w: w, d: d)
        if !isOpen { seam(&ctx, scene, w: w, d: d) }

        if lidAngle <= 90 { lid(&ctx, scene, w: w, ly: ly, lz: lz) }
    }

    private var isOpen: Bool { lidAngle > 45 }

    private func deskShadow(_ ctx: inout GraphicsContext, _ s: Scene, w: Double, d: Double) {
        let front = s.project(0, d, 0)
        let left = s.project(-w, d, 0)
        let rect = CGRect(x: left.x - 16, y: front.y - 6, width: (front.x - left.x) * 2 + 32, height: 26)
        ctx.fill(Path(ellipseIn: rect),
                 with: .radialGradient(
                    Gradient(colors: [.black.opacity(0.22), .black.opacity(0.06), .clear]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0, endRadius: rect.width / 2))
    }

    /// 螢幕的光打在桌面上。闔起來只有那條縫漏出去，所以窄很多。
    private func spill(_ ctx: inout GraphicsContext, _ s: Scene, w: Double, d: Double) {
        let front = s.project(0, d, 0)
        let width = isOpen ? (w * 2.6) : (w * 2.05)
        let rect = CGRect(x: front.x - width / 2, y: front.y - 10,
                          width: width, height: isOpen ? 42 : 30)
        ctx.fill(Path(ellipseIn: rect),
                 with: .radialGradient(
                    Gradient(colors: [palette.pool.opacity(0.5), palette.pool.opacity(0.14), .clear]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0, endRadius: rect.width / 2))
    }

    /// 機身前緣的厚度
    private func chassisFront(_ ctx: inout GraphicsContext, _ s: Scene, w: Double, d: Double) {
        let path = s.quad([(-w, d, 0), (w, d, 0), (w, d, -s.thickness), (-w, d, -s.thickness)])
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [palette.shellMid, palette.shellDark]),
            startPoint: s.project(0, d, 0), endPoint: s.project(0, d, -s.thickness)))
    }

    /// 鍵盤面
    private func deck(_ ctx: inout GraphicsContext, _ s: Scene, w: Double, d: Double) {
        let top = s.quad([(-w, 0, 0), (w, 0, 0), (w, d, 0), (-w, d, 0)])
        ctx.fill(top, with: .linearGradient(
            Gradient(colors: [palette.deckFar, palette.deckMid, palette.deckNear]),
            startPoint: s.project(0, 0, 0), endPoint: s.project(0, d, 0)))

        // 鍵盤區與觸控板，讓它讀得出來是鍵盤面而不是一塊板子
        let keys = s.quad([(-w + 10, 12, 0), (w - 10, 12, 0), (w - 14, d * 0.56, 0), (-w + 14, d * 0.56, 0)])
        ctx.fill(keys, with: .color(palette.keys.opacity(0.42)))

        let pad = s.quad([(-30, d * 0.66, 0), (30, d * 0.66, 0), (34, d * 0.9, 0), (-34, d * 0.9, 0)])
        ctx.fill(pad, with: .color(palette.keys.opacity(0.3)))

        // 螢幕的光打在鍵盤面上
        if isOpen && awake {
            ctx.fill(top, with: .linearGradient(
                Gradient(colors: [palette.screenLight.opacity(0.55), .clear]),
                startPoint: s.project(0, 0, 0), endPoint: s.project(0, d * 0.8, 0)))
        }

        ctx.stroke(top, with: .color(.black.opacity(0.13)), lineWidth: 0.5)
    }

    /// 上蓋蓋不到底，露出來的那截機身前緣就是光。
    /// 露出的範圍要用投影算，不是用深度：上蓋翹 5 度時深度上只差不到一個單位，
    /// 但它在畫面上已經抬高一截，露出來的是機身靠前的一整條。
    /// 先壓暗再放光，不然在淺灰的機身上只是白一點的一塊。
    private func seam(_ ctx: inout GraphicsContext, _ s: Scene, w: Double, d: Double) {
        let t = s.tilt * .pi / 180
        let lidRise = sin(t - lidAngle * .pi / 180) / sin(t)
        let from = min(max(d * lidRise, d * 0.55), d - 3)
        // 掀開的過程中這條會愈來愈長，超過一個角度就沒有「縫」可言了
        let fade = max(0, min(1, (13 - lidAngle) / 7))
        guard fade > 0 else { return }

        ctx.opacity = fade
        defer { ctx.opacity = 1 }

        let strip = s.quad([(-w + 3, from, 0), (w - 3, from, 0), (w - 3, d - 1, 0), (-w + 3, d - 1, 0)])
        ctx.fill(strip, with: .linearGradient(
            Gradient(colors: [.black.opacity(0.5), .black.opacity(0.34), .black.opacity(0.12)]),
            startPoint: s.project(0, from, 0), endPoint: s.project(0, d, 0)))

        let near = s.project(0, d - 1, 0)
        let far = s.project(0, from, 0)
        let mid = CGPoint(x: near.x, y: (near.y + far.y) / 2)
        let glowWidth = s.project(w - 3, d, 0).x - s.project(-w + 3, d, 0).x
        let stripHeight = max(near.y - far.y, 6)
        let glowRect = CGRect(x: mid.x - glowWidth / 2, y: mid.y - stripHeight * 0.85,
                              width: glowWidth, height: stripHeight * 1.7)

        // 裁切要在複本上做。GraphicsContext 是傳址進來的，直接 clip 會把後面畫的上蓋一起裁掉。
        var glow = ctx
        glow.clip(to: strip)
        glow.fill(Path(ellipseIn: glowRect), with: .radialGradient(
            Gradient(colors: [palette.seamCore, palette.seamEdge.opacity(0.8),
                              palette.seamEdge.opacity(0.25), .clear]),
            center: CGPoint(x: glowRect.midX, y: glowRect.midY),
            startRadius: 0, endRadius: glowWidth / 2))
    }

    /// 上蓋。闔著看到鋁背蓋，立起來看到螢幕，換面的角度跟相機俯角有關。
    private func lid(_ ctx: inout GraphicsContext, _ s: Scene, w: Double, ly: Double, lz: Double) {
        let face = s.quad([(-w, 0, 0), (w, 0, 0), (w, ly, lz), (-w, ly, lz)])
        let showsScreen = lidAngle > (90 - s.tilt)

        if showsScreen {
            ctx.fill(face, with: .color(palette.bezel))

            let inset = 5.0
            let iy = { (t: Double) in ly * t }
            let iz = { (t: Double) in lz * t }
            let a = inset / s.depth
            let b = 1 - a
            let screen = s.quad([
                (-w + inset, iy(a), iz(a)), (w - inset, iy(a), iz(a)),
                (w - inset, iy(b), iz(b)), (-w + inset, iy(b), iz(b))
            ])
            ctx.fill(screen, with: .linearGradient(
                Gradient(colors: awake
                         ? [palette.screenLight, palette.screenMid, palette.screenDark]
                         : [palette.greyLight, palette.greyMid, palette.greyDark]),
                startPoint: s.project(-w, iy(a), iz(a)), endPoint: s.project(w, iy(b), iz(b))))
        } else {
            ctx.fill(face, with: .linearGradient(
                Gradient(colors: [palette.shellLight, palette.shellMid, palette.shellDark]),
                startPoint: s.project(0, 0, 0), endPoint: s.project(0, ly, lz)))
            ctx.stroke(face, with: .color(.black.opacity(0.12)), lineWidth: 0.5)
        }
    }
}

/// 插畫的配色。目前只有霧藍這一組，換色只要換這裡。
struct LaptopPalette {
    var deckFar: Color
    var deckMid: Color
    var deckNear: Color
    var keys: Color

    var shellLight: Color
    var shellMid: Color
    var shellDark: Color

    var bezel: Color
    var screenLight: Color
    var screenMid: Color
    var screenDark: Color

    var greyLight: Color
    var greyMid: Color
    var greyDark: Color

    var seamCore: Color
    var seamEdge: Color
    var pool: Color

    static let mist = LaptopPalette(
        deckFar: Color(red: 0.910, green: 0.910, blue: 0.929),
        deckMid: Color(red: 0.867, green: 0.867, blue: 0.894),
        deckNear: Color(red: 0.976, green: 0.980, blue: 0.988),
        keys: Color(red: 0.678, green: 0.678, blue: 0.729),

        shellLight: Color(red: 0.949, green: 0.949, blue: 0.965),
        shellMid: Color(red: 0.870, green: 0.870, blue: 0.898),
        shellDark: Color(red: 0.729, green: 0.729, blue: 0.776),

        bezel: Color(red: 0.239, green: 0.239, blue: 0.278),
        screenLight: Color(red: 0.898, green: 0.925, blue: 0.957),
        screenMid: Color(red: 0.753, green: 0.816, blue: 0.878),
        screenDark: Color(red: 0.635, green: 0.710, blue: 0.788),

        greyLight: Color(red: 0.878, green: 0.878, blue: 0.894),
        greyMid: Color(red: 0.784, green: 0.784, blue: 0.816),
        greyDark: Color(red: 0.702, green: 0.702, blue: 0.741),

        seamCore: Color(red: 0.831, green: 0.906, blue: 0.976),
        seamEdge: Color(red: 0.408, green: 0.573, blue: 0.761),
        pool: Color(red: 0.510, green: 0.588, blue: 0.682)
    )
}

/// Canvas 的參數不會自動被動畫插值，掀蓋的角度要自己接上 SwiftUI 的動畫系統。
extension LaptopArt: Animatable {
    nonisolated var animatableData: Double {
        get { lidAngle }
        set { lidAngle = newValue }
    }
}
