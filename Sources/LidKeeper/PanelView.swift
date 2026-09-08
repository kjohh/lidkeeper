import SwiftUI

/// 選單列點開之後的面板。
///
/// 上半是插畫，下半是開關。插畫有兩個互不相干的狀態：
/// 精靈有沒有生命（跟著 sleepDisabled），還有筆電開著還是闔著（點一下切換，純粹好玩）。
struct PanelView: View {
    @ObservedObject var state: SleepState

    @State private var lidOpen: Bool
    @State private var gaze = CGSize.zero      // 眼球位移，單位是點

    init(state: SleepState, lidOpen: Bool = true) {
        self.state = state
        _lidOpen = State(initialValue: lidOpen)
    }

    /// 0 是睡著、1 是醒著。畫面上所有顏色都跟著它走，才會一起過渡。
    private var awakeAmount: Double { state.sleepDisabled ? 1 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            stage
            Divider().opacity(0.5)
            controls
        }
        .frame(width: Metrics.panelWidth)
        .fixedSize()
        .background(Tone.paper)
        .environment(\.colorScheme, .light)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): aim(at: point)
            case .ended: gaze = .zero
            }
        }
    }

    // MARK: - 插畫

    private var stage: some View {
        ZStack {
            ZStack {
                Tone.washNeutral
                Tone.washBlue.opacity(lidOpen ? awakeAmount : 0)
            }

            // 螢幕光把筆電後面的空間照亮。線性漸層只有最上面那條是藍的，
            // 到筆電的高度早就退成白色了，要有光暈才看得到。
            Ellipse()
                .fill(RadialGradient(
                    colors: [Tone.o3.opacity(0.34), Tone.o3.opacity(0.13), .clear],
                    center: .center, startRadius: 4,
                    endRadius: lidOpen ? 140 : 108))
                .frame(width: lidOpen ? 300 : 240, height: lidOpen ? 170 : 120)
                .offset(y: lidOpen ? -14 : 18)
                .opacity(lidOpen ? awakeAmount : 0)
                .animation(.easeInOut(duration: 0.6), value: lidOpen)

            LaptopArt(lidAngle: lidOpen ? Metrics.openAngle : Metrics.shutAngle,
                      awakeAmount: awakeAmount,
                      palette: .mist)

            // 闔著的時候它在裡面，只有那雙眼睛露在光裡。
            // 打開時立刻收掉，闔上時等蓋子翻完才出現，才不會跟球同時在場。
            eyes(diameter: 9, spacing: 21, reach: 1.5)
                .offset(y: Metrics.shutEyesY)
                .opacity(lidOpen ? 0 : awakeAmount)
                .animation(.easeOut(duration: lidOpen ? 0.1 : 0.22)
                    .delay(lidOpen ? 0 : 0.62), value: lidOpen)

            // 影子落在鍵盤面上，不是黏在球身後。壓扁的比例照相機俯角來。
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(0.24), .black.opacity(0.07), .clear],
                                     center: .center, startRadius: 0, endRadius: 38))
                .frame(width: Metrics.orbSize * 0.92, height: Metrics.orbSize * 0.92 * 0.375)
                .offset(x: 4, y: Metrics.orbCastY)
                .opacity(lidOpen ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(lidOpen ? 0.62 : 0), value: lidOpen)

            // 打開的時候整顆浮在鍵盤上方。等蓋子翻到一半以上才成形。
            orb
                .offset(y: Metrics.orbY)
                .scaleEffect(lidOpen ? 1 : 0.05, anchor: .bottom)
                .opacity(lidOpen ? 1 : 0)
                .animation(.timingCurve(0.2, 0.86, 0.26, 1.04, duration: 0.55)
                    .delay(lidOpen ? 0.46 : 0), value: lidOpen)
        }
        .frame(width: Metrics.panelWidth, height: Metrics.stageHeight)
        .animation(.easeInOut(duration: 0.42), value: state.sleepDisabled)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.timingCurve(0.33, 0.85, 0.3, 1, duration: 0.85)) { lidOpen.toggle() }
        }
    }

    // MARK: - 精靈

    private var orb: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Tone.grey0, Tone.grey1, Tone.grey2, Tone.grey3],
                    center: UnitPoint(x: 0.34, y: 0.27), startRadius: 2, endRadius: 62))

            Circle()
                .fill(RadialGradient(
                    colors: [Tone.o1, Tone.o2, Tone.o3, Tone.o4],
                    center: UnitPoint(x: 0.34, y: 0.27), startRadius: 2, endRadius: 62))
                .opacity(awakeAmount)

            // 右下的環境反光
            Circle()
                .fill(LinearGradient(colors: [.clear, .clear, .white.opacity(0.32)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            // 主高光加一個銳利的小點
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.8), .white.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 15))
                .frame(width: 30, height: 19)
                .rotationEffect(.degrees(-24))
                .offset(x: -11, y: -15)

            Circle()
                .fill(.white.opacity(0.88))
                .frame(width: 6, height: 6)
                .offset(x: -15, y: -18)

            shutEyes.offset(y: 6).opacity(1 - awakeAmount)
            eyes(diameter: 10.5, spacing: 17, reach: 1.9).offset(y: 6).opacity(awakeAmount)
        }
        .frame(width: Metrics.orbSize, height: Metrics.orbSize)
    }

    private func eyes(diameter: CGFloat, spacing: CGFloat, reach: CGFloat) -> some View {
        HStack(spacing: spacing) {
            eye(diameter: diameter, reach: reach)
            eye(diameter: diameter, reach: reach)
        }
    }

    private func eye(diameter: CGFloat, reach: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(Color.white.opacity(0.98))

            ZStack {
                Ellipse()
                    .fill(Tone.pupil)
                    .frame(width: diameter * 0.53, height: diameter * 0.66)
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: diameter * 0.22, height: diameter * 0.22)
                    .offset(x: -diameter * 0.12, y: -diameter * 0.2)
            }
            .offset(x: gaze.width * reach, y: gaze.height * reach)
            .animation(.easeOut(duration: 0.16), value: gaze)
        }
        .frame(width: diameter, height: diameter * 1.24)
        .clipShape(Ellipse())
    }

    private var shutEyes: some View {
        HStack(spacing: 17) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule().fill(Color.white.opacity(0.92)).frame(width: 10.5, height: 2.6)
            }
        }
    }

    /// 游標在面板上的位置換算成眼球位移，越靠近那顆球收得越小才不會抖。
    private func aim(at point: CGPoint) {
        let center = CGPoint(x: Metrics.panelWidth / 2,
                             y: Metrics.stageHeight / 2 + Metrics.orbY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = max(sqrt(dx * dx + dy * dy), 1)
        let reach = min(1, distance / 150)
        let next = CGSize(width: dx / distance * reach, height: dy / distance * reach)
        // 游標沒真的移動時 hover 還是會一直回報，擋掉才不會無止盡重繪
        guard abs(next.width - gaze.width) > 0.03 || abs(next.height - gaze.height) > 0.03 else { return }
        gaze = next
    }

    // MARK: - 開關

    private var controls: some View {
        VStack(spacing: 2) {
            SwitchRow(title: "闔蓋保持清醒", isOn: state.sleepDisabled) {
                state.setSleepDisabled(!state.sleepDisabled)
            }
            SwitchRow(title: "闔蓋時說話", isOn: state.voiceEnabled,
                      onPreview: { state.previewVoice() }) {
                state.setVoiceEnabled(!state.voiceEnabled)
            }
            SwitchRow(title: "開機時啟動", isOn: state.launchAtLogin) {
                state.setLaunchAtLogin(!state.launchAtLogin)
            }

            if let problem = state.problem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(Tone.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
            }

            Divider().padding(.vertical, 4)

            Button {
                state.quit()
            } label: {
                Text("結束 LidKeeper")
                    .font(.system(size: 13))
                    .foregroundStyle(Tone.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }
}

// MARK: - 尺寸

private enum Metrics {
    static let panelWidth: CGFloat = 292
    static let stageHeight: CGFloat = 196
    /// 0 度是完全闔上。這個角度剛好讓前緣露出十來點當作漏出來的光。
    static let shutAngle: Double = 5
    static let openAngle: Double = 96
    static let orbSize: CGFloat = 76
    static let orbY: CGFloat = 24
    /// 影子落在鍵盤面上的位置，比球底再低一點才有懸空感
    static let orbCastY: CGFloat = 66
    /// 闔著時那雙眼睛在畫面上的位置，對到露出來的那條光
    static let shutEyesY: CGFloat = 68
}

// MARK: - 顏色（霧藍）

private enum Tone {
    static let o1 = Color(red: 0.859, green: 0.890, blue: 0.925)
    static let o2 = Color(red: 0.678, green: 0.737, blue: 0.804)
    static let o3 = Color(red: 0.510, green: 0.588, blue: 0.682)
    static let o4 = Color(red: 0.361, green: 0.424, blue: 0.506)

    static let grey0 = Color(red: 0.886, green: 0.886, blue: 0.902)
    static let grey1 = Color(red: 0.765, green: 0.765, blue: 0.792)
    static let grey2 = Color(red: 0.616, green: 0.616, blue: 0.655)
    static let grey3 = Color(red: 0.463, green: 0.463, blue: 0.498)

    static let pupil = Color(red: 0.133, green: 0.188, blue: 0.247)
    static let paper = Color.white
    static let ink = Color(red: 0.102, green: 0.094, blue: 0.082)
    static let ink2 = Color(red: 0.373, green: 0.353, blue: 0.325)
    static let track = Color(red: 0.863, green: 0.855, blue: 0.839)

    static let washNeutral = LinearGradient(
        colors: [Color(red: 0.937, green: 0.937, blue: 0.949),
                 Color(red: 0.976, green: 0.976, blue: 0.980),
                 .white],
        startPoint: .top, endPoint: .bottom)

    static let washBlue = LinearGradient(
        colors: [Color(red: 0.855, green: 0.898, blue: 0.949),
                 Color(red: 0.910, green: 0.937, blue: 0.973),
                 Color(red: 0.973, green: 0.980, blue: 0.992)],
        startPoint: .top, endPoint: .bottom)
}

/// 設計稿上那顆開關。系統的 switch 在這個尺寸下太大，顏色也吃不到面板的色系。
private struct SwitchRow: View {
    let title: String
    let isOn: Bool
    var onPreview: (() -> Void)? = nil
    let toggle: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Tone.ink)
                Spacer(minLength: 0)

                if let onPreview {
                    Button(action: onPreview) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(isOn ? Tone.o3 : Tone.track)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("試聽")
                }

                ZStack {
                    Capsule().fill(Tone.track)
                    Capsule()
                        .fill(LinearGradient(colors: [Tone.o2, Tone.o3],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(isOn ? 1 : 0)
                        .animation(.easeOut(duration: 0.22), value: isOn)
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                        .frame(width: 14, height: 14)
                        .offset(x: isOn ? 6 : -6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isOn)
                }
                .frame(width: 30, height: 18)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.black.opacity(hovering ? 0.045 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.74), value: isOn)
    }
}
