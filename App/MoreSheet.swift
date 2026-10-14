import SwiftUI
import ReceiverKit

struct MoreSheet: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let s = store.state
        NavigationStack {
            Form {
                Section("Sound") {
                    Picker("Mode", selection: Binding(
                        get: { s.soundMode ?? "" },
                        set: { store.send(.soundMode($0)) })
                    ) {
                        if let m = s.soundMode, !store.soundModes.contains(m) { Text(m).tag(m) }
                        ForEach(store.soundModes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    if let v = s.dynamicEQ {
                        Toggle("Dynamic EQ", isOn: Binding(get: { v }, set: { store.send(.dynamicEQ($0)) }))
                    }
                }
                Section("Tone") {
                    if let v = s.bass { stepper("Bass", v, -6...6, "dB") { store.send(.bass($0)) } }
                    if let v = s.treble { stepper("Treble", v, -6...6, "dB") { store.send(.treble($0)) } }
                    if let v = s.subLevel {
                        stepper("Subwoofer", Int(v), -12...12, "dB") { store.send(.subLevel(Double($0))) }
                    }
                }
                Section("Sleep timer") {
                    Picker("Turn off after", selection: Binding(
                        get: { s.sleepMinutes ?? 0 },
                        set: { store.send(.sleep(minutes: $0 == 0 ? nil : $0)) })
                    ) {
                        Text("Off").tag(0)
                        ForEach([15, 30, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("More")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .frame(minWidth: 340, minHeight: 420)
    }

    private func stepper(_ title: String, _ value: Int, _ range: ClosedRange<Int>, _ unit: String,
                         set: @escaping @MainActor (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: set), in: range) {
            LabeledContent(title, value: "\(value > 0 ? "+" : "")\(value) \(unit)")
        }
    }
}
