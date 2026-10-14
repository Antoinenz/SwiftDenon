#if os(macOS)
import SwiftUI
import ReceiverKit

/// Compact controller for the selected zone, built from the same glass controls as the main window.
struct MenuBarView: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hideVolumeSlider") private var hideVolumeSlider = false

    var body: some View {
        let zone = store.zone
        let isPlaying = store.state.connected && zone.power
        VStack(spacing: 16) {
            header
            Group {
                if !store.state.connected {
                    connecting
                } else if !zone.power {
                    standby(zone)
                } else {
                    playing(zone)
                }
            }
            .transition(.opacity)
            footer
        }
        .padding(16)
        .frame(width: 300)
        .animation(.smooth(duration: 0.3), value: isPlaying)
        .animation(.snappy, value: store.zoneID)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { store.stepVolume(by: 1); return .handled }
        .onKeyPress(.downArrow) { store.stepVolume(by: -1); return .handled }
        .onKeyPress(.space) { store.toggleMute(); return .handled }
        .onKeyPress("m") { store.toggleMute(); return .handled }
        .onKeyPress("p") { store.togglePower(); return .handled }
        .onKeyPress(.tab) { store.cycleZone(by: 1); return .handled }
    }

    @ViewBuilder private var header: some View {
        if store.state.connected, store.state.zones.count > 1 {
            GlassSegmented(selection: Binding(get: { store.zoneID }, set: { store.zoneID = $0 }),
                           options: store.state.zones.map(\.id)) { id in
                Text(store.state.zone(id).map(store.name(of:)) ?? "Zone").lineLimit(1)
            }
        } else {
            Text(store.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var connecting: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(store.host.isEmpty && !store.demoMode ? "Looking for your receiver…" : "Connecting…")
                .foregroundStyle(.secondary)
        }
        .frame(height: 64)
    }

    private func standby(_ zone: Zone) -> some View {
        VStack(spacing: 10) {
            GlassCircleButton(symbol: "power", size: 64) { store.setPower(true) }
            Text("Off").font(.callout).foregroundStyle(Color.primary.opacity(0.55))
        }
        .padding(.vertical, 4)
    }

    private func playing(_ zone: Zone) -> some View {
        VStack(spacing: 16) {
            if hideVolumeSlider {
                // No slider: − and + sit either side of the number, as in the main window,
                // and the buttons move to their own row so the number has room.
                HStack(spacing: 16) {
                    GlassCircleButton(symbol: "minus", size: 30) { store.stepVolume(by: -1) }
                        .opacity(zone.mute ? 0.35 : 1)
                    volumeNumber(zone).frame(minWidth: 96)
                    GlassCircleButton(symbol: "plus", size: 30) { store.stepVolume(by: 1) }
                        .opacity(zone.mute ? 0.35 : 1)
                }
                powerAndMute(zone)
            } else {
                HStack {
                    volumeNumber(zone)
                    Spacer(minLength: 0)
                    powerAndMute(zone)
                }
                HStack(spacing: 8) {
                    GlassCircleButton(symbol: "minus", size: 30) { store.stepVolume(by: -1) }
                    GlassSlider(
                        value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                        range: 0...zone.maxVolume, halfStep: store.useHalfSteps,
                        onEnd: { store.setVolume(zone.volume, final: true) }
                    )
                    GlassCircleButton(symbol: "plus", size: 30) { store.stepVolume(by: 1) }
                }
                .opacity(zone.mute ? 0.35 : 1)
            }
            InputPicker()
        }
        .animation(.smooth(duration: 0.3), value: zone.mute)
    }

    private func powerAndMute(_ zone: Zone) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                GlassCircleButton(symbol: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                  active: zone.mute, tint: .orange, size: 36) { store.toggleMute() }
                GlassCircleButton(symbol: "power", active: true, tint: .green, size: 36) { store.setPower(false) }
            }
        }
    }

    private func volumeNumber(_ zone: Zone) -> some View {
        Text(zone.volume.formatted(.number.precision(store.useHalfSteps ? .fractionLength(1) : .fractionLength(0...1))))
            .font(.system(size: 44, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: zone.volume))
            .animation(.snappy(duration: 0.25), value: zone.volume)
            .opacity(zone.mute ? 0.3 : 1)
    }

    private var footer: some View {
        HStack {
            Button("Open SwiftDenon", action: showRemote)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .font(.callout)
        .padding(.top, 2)
    }

    /// Brings the remote window forward, or reopens it if it was closed.
    private func showRemote() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(SwiftDenonApp.remoteWindowID) == true }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: SwiftDenonApp.remoteWindowID)
        }
    }
}
#endif
