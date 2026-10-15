import SwiftUI
import ReceiverKit

/// Everything secondary in one place: sound, EQ, sleep timer and receiver connection.
struct SettingsView: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var manualHost = ""
    @AppStorage("halfStepVolume") private var halfStepVolume = true
    @AppStorage("hideVolumeSlider") private var hideVolumeSlider = false
    @AppStorage("scrollChangesVolume") private var scrollChangesVolume = false
    @AppStorage("arrowKeysSwitchZones") private var arrowKeysSwitchZones = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("hideMenuBarWhenAway") private var hideMenuBarWhenAway = false

    private enum Page: String, CaseIterable, Identifiable {
        case amp = "Amp", zones = "Zones", general = "General"
        var id: Self { self }
    }
    @State private var page = Page.amp

    var body: some View {
        #if os(macOS)
        // A real window (the Settings scene), so the switcher is the system's toolbar glass, the
        // same as the zone picker in the main window. A sheet can't show a top toolbar on macOS.
        form
            .frame(width: 420, height: 540)
        #else
        NavigationStack {
            form.toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", role: .confirm) { dismiss() } }
            }
        }
        #endif
    }

    private var form: some View {
        Form {
            switch page {
            case .amp: ampPage
            case .zones: zonesPage
            case .general: generalPage
            }
        }
        .formStyle(.grouped)
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Page", selection: $page) {
                    ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
        }
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
        Section {
            Toggle("Half-step volume", isOn: $halfStepVolume)
                .disabled(!s.zones.contains(where: \.halfStep))
            Toggle("Hide volume slider", isOn: $hideVolumeSlider)
            #if os(macOS)
            Toggle("Scroll to change volume", isOn: $scrollChangesVolume)
            #endif
        } header: {
            Text("Volume")
        } footer: {
            #if os(macOS)
            Text("Scroll or swipe over the volume number or slider, in the window or the menu bar.")
            #endif
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
        #if os(macOS)
        Section {
            Toggle("Show in menu bar", isOn: $showInMenuBar)
            Toggle("Hide when away from the receiver", isOn: $hideMenuBarWhenAway)
                .disabled(!showInMenuBar)
        } header: {
            Text("Menu Bar")
        } footer: {
            Text(hideMenuBarWhenAway
                 ? "The icon disappears when the receiver can't be reached, such as when you're out, and returns once it connects."
                 : "A compact controller for the selected zone.")
        }
        #endif
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
        Section {
            if store.demoMode {
                Label("Demo Receiver", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
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
                    Button { store.select(host: r.host) } label: {
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
                        }
                        .disabled(manualHost.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        } header: {
            Text("Receiver")
        } footer: {
            if store.demoMode { Text("Demo mode is on. Turn it off in General to use a real receiver.") }
        }
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
