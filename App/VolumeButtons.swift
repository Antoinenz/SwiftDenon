#if os(iOS)
import SwiftUI
import AVFoundation
import MediaPlayer

extension View {
    /// Routes the iPhone's volume buttons to `onStep` (+1 louder, −1 quieter) while `enabled`,
    /// in place of changing the phone's own volume.
    func volumeButtons(enabled: Bool, onStep: @escaping @MainActor (Int) -> Void) -> some View {
        background(VolumeButtonCatcher(enabled: enabled, onStep: onStep).frame(width: 1, height: 1))
    }
}

/// iOS has no API for "the volume buttons were pressed", so this watches the system output volume
/// instead. It parks the volume at the midpoint, so there is always room to move in both
/// directions; a press shows up as a move away from the midpoint, which gives the direction, and the
/// volume is put back at the midpoint straight away. The original volume is restored when it stops.
/// An `MPVolumeView` in the hierarchy keeps the system volume overlay from appearing.
private struct VolumeButtonCatcher: UIViewRepresentable {
    let enabled: Bool
    let onStep: @MainActor (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.alpha = 0.01                      // hidden is not enough: it must count as visible
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        context.coordinator.view = view
        context.coordinator.onStep = onStep
        if enabled { context.coordinator.start() } else { context.coordinator.stop() }
    }

    static func dismantleUIView(_ view: MPVolumeView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor final class Coordinator {
        weak var view: MPVolumeView?
        var onStep: @MainActor (Int) -> Void = { _ in }
        private var observation: NSKeyValueObservation?
        private var original: Float?
        private let midpoint: Float = 0.5

        func start() {
            guard observation == nil else { return }
            let session = AVAudioSession.sharedInstance()
            // Ambient and mixable, so other apps' audio isn't interrupted.
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
            original = session.outputVolume
            setSystemVolume(midpoint)
            observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
                guard let volume = change.newValue else { return }
                Task { @MainActor in self?.changed(to: volume) }
            }
        }

        func stop() {
            guard observation != nil else { return }
            observation = nil
            if let original { setSystemVolume(original) }
            original = nil
        }

        private func changed(to volume: Float) {
            // Ignore the echo of our own reset to the midpoint.
            guard abs(volume - midpoint) > 0.02 else { return }
            onStep(volume > midpoint ? 1 : -1)
            setSystemVolume(midpoint)
        }

        private func setSystemVolume(_ value: Float) {
            guard let slider = view?.subviews.compactMap({ $0 as? UISlider }).first else { return }
            DispatchQueue.main.async { slider.value = value }
        }
    }
}
#endif
