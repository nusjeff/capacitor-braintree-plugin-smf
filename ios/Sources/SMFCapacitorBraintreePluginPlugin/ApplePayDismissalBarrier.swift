import Foundation

// A pending present can succeed after cancellation/timeout. Keep session ownership
// until that callback returns, then dismiss its controller before settling the bridge.
final class ApplePayDismissalBarrier {
    private var presentationPending = false
    private var dismissalStarted = false
    private var completed = false
    private var dismiss: ((@escaping () -> Void) -> Void)?
    private var completion: (() -> Void)?

    func presentationStarted() { presentationPending = true }

    func presentationReturned() {
        presentationPending = false
        tryDismiss()
    }

    func finish(dismiss: @escaping (@escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        guard self.completion == nil, !completed else { return }
        self.dismiss = dismiss
        self.completion = completion
        tryDismiss()
    }

    private func tryDismiss() {
        guard !presentationPending, !dismissalStarted, let dismiss = dismiss else { return }
        dismissalStarted = true
        dismiss { [weak self] in
            guard let self = self, !self.completed else { return }
            self.completed = true
            let callback = self.completion
            self.completion = nil
            self.dismiss = nil
            callback?()
        }
    }
}
