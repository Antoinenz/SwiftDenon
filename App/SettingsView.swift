import SwiftUI
import ReceiverKit

/// Everything secondary in one place: sound, EQ, sleep timer and receiver connection.
struct SettingsView: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var manualHost = ""
    @AppStorage("halfStepVolume") private var halfStepVolume = false
    @AppStorage("hideVolumeSlider") private var hideVolumeSlider = false
    @AppStorage("arrowKeysSwitchZones") private var arrowKeysSwitchZones = false

    private enum Page: String, CaseIterable, Identifiable {
        case amp = "Amp", zones = "Zones", general = "General"
        var id: Self { self }
    }
    @State private var page = Page.amp

    var body: some View {
        Form {
            switch page {
            case .amp: ampPage
            case .zones: zonesPage
            case .general: generalPage
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .frame(minWidth: 380, minHeight: 460)
    }

    /// Title, Done and the page switcher. Built by hand: a sheet's navigation title is inset
    /// on macOS and its principal toolbar item isn't shown.
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Settings").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            GlassSegmented(selection: $page, options: Page.allCases) { Text($0.rawValue) }
        }
        .padding(.leading, 30)       // lines the title up with the section headers
        .padding(.trailing, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    @ViewBuilder private var ampPage: some View {
        let s = store.state
        receiverSection
        if s.connected {
            Section("Sound") {
                Picker("Mode", selection: Binding(get: { s.soundMode ?? "" }, set: { store.setSoundMode($0) })) {
                    if let m = s.soundMode, !DenonProtocol.soundModes.contains(m) { Text(m.capitalized).tag(m) }
                    ForEach(DenonProtocol.soundModes, id: \.self) { Text($0.capitalized).tag($0) }
                }
                if let v = s.dynamicEQ {
                    Toggle("Dynamic EQ", isOn: Binding(get: { v }, set: { store.setDynamicEQ($0) }))
                }
                Picker("Sleep timer", selection: Binding(get: { s.sleepMinutes ?? 0 },
                                                         set: { store.setSleep($0 == 0 ? nil : $0) })) {
                    Text("Off").tag(0)
                    ForEach([15, 30, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            if s.bass != nil || s.treble != nil || s.subLevel != nil {
                Section("Equalizer") { EQView() }
            }
        }
    }

    @ViewBuilder private var zonesPage: some View {
        let s = store.state
        if s.connected {
            Section {
                ForEach(s.zones) { z in
                    TextField(z.name, text: Binding(get: { store.zoneNames[z.id] ?? "" },
                                                    set: { store.setZoneName($0, for: z.id) }))
                }
            } header: {
                Text("Names")
            } footer: {
                Text("Names are stored in this app only; the receiver doesn't share them.")
            }
        } else {
            Section { Text("Connect to a receiver to edit its zones.").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var generalPage: some View {
        let s = store.state
        Section("Volume") {
            Toggle("Half-step volume", isOn: $halfStepVolume)
                .disabled(!s.zones.contains(where: \.halfStep))
            Toggle("Hide volume slider", isOn: $hideVolumeSlider)
        }
        Section {
            Toggle("Arrow keys switch zones", isOn: $arrowKeysSwitchZones)
        } header: {
            Text("Keyboard")
        } footer: {
            Text(arrowKeysSwitchZones
                 ? "← → switch zones, Tab steps through inputs."
                 : "← → step through inputs, Tab switches zones.")
        }
        Section {
            Toggle("Demo mode", isOn: Binding(get: { store.demoMode }, set: { store.setDemoMode($0) }))
        } header: {
            Text("Demo")
        } footer: {
            Text("Try the app with a simulated receiver. Your real receiver isn't touched.")
        }
        Section("About") {
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
        }
    }

    private var receiverSection: some View {
        Section("Receiver") {
            if store.demoMode {
                Label("Demo Receiver", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Demo mode is on. Turn it off in General to use a real receiver.").foregroundStyle(.secondary)
            } else if !store.host.isEmpty {
                LabeledContent {
                    Text(store.host).foregroundStyle(.secondary)
                } label: {
                    Label(store.displayName, systemImage: store.state.connected ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(store.state.connected ? .green : .secondary)
                }
            }
            if !store.demoMode {
                ForEach(store.discovered.filter { $0.host != store.host }) { r in
                    Button { store.select(host: r.host); dismiss() } label: {
                        LabeledContent(r.name, value: r.host)
                    }
                }
                HStack {
                    Button("Search again") { store.search() }.disabled(store.scanning)
                    if store.scanning { ProgressView().controlSize(.small) }
                    Spacer()
                    if store.webUIAvailable, let url = store.webUIURL {
                        Button("Open web interface", systemImage: "safari") { openURL(url) }
                    }
                }
                DisclosureGroup("Enter address manually") {
                    HStack {
                        TextField("192.168.1.50", text: $manualHost)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            #endif
                        Button("Connect") {
                            store.select(host: manualHost.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                        .disabled(manualHost.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}

/// A segmented control drawn as one glass capsule with a sliding selection,
/// matching the zone picker in the main window's toolbar.
struct GlassSegmented<Option: Hashable, Label: View>: View {
    @Binding var selection: Option
    let options: [Option]
    @ViewBuilder let label: (Option) -> Label
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button { withAnimation(.snappy(duration: 0.3)) { selection = option } } label: {
                    label(option)
                        .font(.body.weight(.medium))
                        .foregroundStyle(selection == option ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background {
                            if selection == option {
                                Capsule().fill(.primary.opacity(0.14))
                                    .matchedGeometryEffect(id: "selection", in: ns)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Bass / treble / sub as three glass faders.
struct EQView: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        let s = store.state
        HStack(spacing: 28) {
            if let v = s.bass { band("Bass", v, -6...6) { store.setBass($0) } }
            if let v = s.treble { band("Treble", v, -6...6) { store.setTreble($0) } }
            if let v = s.subLevel { band("Sub", Int(v), -12...12) { store.setSub($0) } }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func band(_ name: String, _ value: Int, _ range: ClosedRange<Int>,
                      set: @escaping @MainActor (Int) -> Void) -> some View {
        VStack(spacing: 8) {
            Text("\(value > 0 ? "+" : "")\(value)")
                .font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit()
            VerticalGlassSlider(value: Binding(get: { value }, set: { Haptics.tick(); set($0) }), range: range)
                .frame(width: 44, height: 150)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
    }
}
