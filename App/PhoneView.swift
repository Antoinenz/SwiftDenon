#if os(iOS)
import SwiftUI
import ReceiverKit

/// The iPhone remote: the same glass controls as the Mac window, laid out for one hand. Controls
/// sit in the lower half where the thumb is, the number takes the middle, and the zone switcher and
/// settings live in the navigation bar's glass.
struct PhoneView: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @State private var showSettings = UserDefaults.standard.bool(forKey: "debugSettings")   // `-debugSettings YES`
    #else
    @State private var showSettings = false
    #endif
    @State private var leftAt: Date?
    @State private var inputsOpen = false
    @State private var height: CGFloat = 0
    @AppStorage("hideVolumeSlider") private var hideVolumeSlider = false
    @AppStorage("volumeButtons") private var volumeButtons = true

    private enum Kind { case connecting, standby, playing }

    var body: some View {
        let zone = store.zone
        let connected = store.state.connected
        let kind: Kind = !connected ? .connecting : (zone.power ? .playing : .standby)

        NavigationStack {
            ZStack {
                PhoneBackground()
                Group {
                    switch kind {
                    case .connecting: connecting
                    case .standby: standby(zone)
                    case .playing: playing(zone)
                    }
                }
                .transition(.opacity)
            }
            .animation(.smooth(duration: 0.35), value: kind)
            .animation(.snappy, value: store.zoneID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if connected && store.state.zones.count > 1 { ZonePicker() }
                }
                .sharedBackgroundVisibility(.hidden)   // the switcher draws its own glass
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            // Swipe sideways anywhere that isn't a control to change zone, or up from the bottom third
            // for the inputs. Controls (the slider especially) claim their own drags first.
            .gesture(
                DragGesture(minimumDistance: 40).onEnded { g in
                    let dx = g.translation.width, dy = g.translation.height
                    if abs(dx) > abs(dy) * 1.5, abs(dx) > 60 {
                        Haptics.tick()
                        store.cycleZone(by: dx < 0 ? 1 : -1)
                    } else if kind == .playing, -dy > 60, -dy > abs(dx) * 1.5, g.startLocation.y > height * 2 / 3 {
                        Haptics.tap()
                        inputsOpen = true
                    }
                }
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        // The buttons only belong to the amp while it is actually playing and we are on screen.
        .volumeButtons(enabled: volumeButtons && scenePhase == .active && kind == .playing) { step in
            Haptics.tick()
            store.stepVolume(by: Double(step))
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: leftAt = .now
            case .active:
                store.resume(awayFor: leftAt.map { Date.now.timeIntervalSince($0) } ?? 0)
                leftAt = nil
            default: break
            }
        }
    }

    private var connecting: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text(store.host.isEmpty && !store.demoMode ? "Looking for your receiver…" : "Connecting…")
                .foregroundStyle(.secondary)
        }
    }

    private func standby(_ zone: Zone) -> some View {
        VStack(spacing: 20) {
            GlassCircleButton(symbol: "power", size: 120) { Haptics.tap(); store.setPower(true) }
            let label = store.state.zones.count > 1 ? store.name(of: zone) : store.displayName
            Text(label)
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.55))
                .id(label)
                .transition(.blurReplace)
        }
        .animation(.snappy, value: store.zoneID)
    }

    private func playing(_ zone: Zone) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if hideVolumeSlider {
                // No slider: − and + either side of the number.
                HStack(spacing: 12) {
                    GlassCircleButton(symbol: "minus", size: 56, repeats: true) { Haptics.tick(); store.stepVolume(by: -1) }
                    VolumeReadout(volume: zone.volume, halfSteps: store.useHalfSteps, size: 76, muted: zone.mute)
                        .frame(maxWidth: .infinity)
                    GlassCircleButton(symbol: "plus", size: 56, repeats: true) { Haptics.tick(); store.stepVolume(by: 1) }
                }
                .opacity(zone.mute ? 0.55 : 1)
            } else {
                VolumeReadout(volume: zone.volume, halfSteps: store.useHalfSteps, size: 112, muted: zone.mute)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 28).frame(maxHeight: 56)
                HStack(spacing: 12) {
                    GlassCircleButton(symbol: "minus", size: 52, repeats: true) { Haptics.tick(); store.stepVolume(by: -1) }
                    GlassSlider(
                        value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                        range: 0...zone.maxVolume, halfStep: store.useHalfSteps, relative: true,
                        onEnd: { store.setVolume($0, final: true) }
                    )
                    GlassCircleButton(symbol: "plus", size: 52, repeats: true) { Haptics.tick(); store.stepVolume(by: 1) }
                }
                .opacity(zone.mute ? 0.35 : 1)
            }
            Spacer(minLength: 0)
            GlassEffectContainer(spacing: 20) {
                HStack(spacing: 20) {
                    GlassCircleButton(symbol: "power", active: true, tint: .green, size: 80) { Haptics.tap(); store.setPower(false) }
                    GlassCircleButton(symbol: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      active: zone.mute, tint: .orange, size: 80) { Haptics.tap(); store.toggleMute() }
                }
            }
            InputPicker(isOpen: $inputsOpen)
                .controlSize(.large)
                .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .animation(.smooth(duration: 0.3), value: zone.mute)
    }
}

/// A soft, slightly colourful wash for the glass to sit on; flat black or white would leave the
/// glass nothing to bend.
private struct PhoneBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.55, 0.45], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: dark ? [
            c(12, 14, 24), c(22, 28, 52), c(14, 16, 30),
            c(20, 24, 46), c(38, 44, 84), c(22, 26, 50),
            c(10, 12, 20), c(18, 22, 40), c(12, 14, 24),
        ] : [
            c(238, 242, 252), c(224, 232, 250), c(236, 238, 250),
            c(228, 234, 250), c(206, 216, 244), c(230, 234, 250),
            c(244, 246, 252), c(232, 238, 250), c(240, 242, 252),
        ])
        .ignoresSafeArea()
    }

    private func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
}
#endif
