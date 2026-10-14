import SwiftUI
import ReceiverKit

/// Everything secondary in one place: sound, EQ, sleep timer and receiver connection.
struct SettingsView: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var manualHost = ""
    @AppStorage("halfStepVolume") private var halfStepVolume = false

    var body: some View {
        let s = store.state
        NavigationStack {
            Form {
                if s.connected {
                    Section("Sound") {
                        Picker("Mode", selection: Binding(get: { s.soundMode ?? "" }, set: { store.setSoundMode($0) })) {
                            if let m = s.soundMode, !DenonProtocol.soundModes.contains(m) { Text(m.capitalized).tag(m) }
                            ForEach(DenonProtocol.soundModes, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        if s.zone(1)?.halfStep == true || s.zones.contains(where: \.halfStep) {
                            Toggle("Half-step volume", isOn: $halfStepVolume)
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
                receiverSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .frame(minWidth: 380, minHeight: 460)
    }

    private var receiverSection: some View {
        Section("Receiver") {
            if !store.host.isEmpty {
                LabeledContent {
                    Text(store.host).foregroundStyle(.secondary)
                } label: {
                    Label(store.displayName, systemImage: store.state.connected ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(store.state.connected ? .green : .secondary)
                }
            }
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
