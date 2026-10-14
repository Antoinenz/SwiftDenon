import SwiftUI

struct SettingsView: View {
    @Environment(ReceiverStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Receiver") {
                    TextField("IP address, e.g. 192.168.1.50", text: $host)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        store.host = host.trimmingCharacters(in: .whitespaces)
                        store.start()
                        dismiss()
                    }
                    .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .frame(minWidth: 340, minHeight: 220)
        .onAppear { host = store.host }
    }
}
