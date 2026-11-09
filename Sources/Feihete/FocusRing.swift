import SwiftUI
import AppKit

extension View {
    /// Native macOS controls draw a focus ring in addition to their selected
    /// state. Keep keyboard interaction on newer systems while removing that
    /// extra outline from this app's compact controls.
    @ViewBuilder
    func withoutFocusRing() -> some View {
        if #available(macOS 14.0, *) {
            focusEffectDisabled()
        } else {
            focusable(false)
        }
    }

    /// A window hands keyboard focus to its first control as soon as it opens,
    /// which painted a blue focus ring around the section switcher and around
    /// "设置" in the menu bar panel — looked like a selection the user never
    /// made. No control in this app needs initial focus: the first click or Tab
    /// press still moves focus normally afterwards.
    func clearsInitialFocus() -> some View {
        background(InitialFocusClearer())
    }
}

private struct InitialFocusClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ClearerView() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ClearerView: NSView {
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObserver()
            guard let window else { return }

            // SwiftUI installs the controls after this view and may hand focus
            // over a moment after the window becomes key, so retry briefly
            // instead of clearing once and losing the race.
            clearRepeatedly(in: window)
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.clearRepeatedly(in: window)
            }
        }

        deinit {
            removeObserver()
        }

        private func removeObserver() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }

        private func clearRepeatedly(in window: NSWindow) {
            for delay in [0.0, 0.05, 0.15, 0.35] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.clear(in: window)
                }
            }
        }

        private func clear(in window: NSWindow) {
            // Only controls swallow focus this way; text fields would lose the
            // caret. This app has none, but keep the check explicit.
            guard window.firstResponder is NSControl else { return }
            window.makeFirstResponder(nil)
        }
    }
}
