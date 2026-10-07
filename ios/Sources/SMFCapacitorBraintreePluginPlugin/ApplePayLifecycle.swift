import Foundation

// A session owns its callbacks until dismissal finishes. Completed sessions cannot
// transition back into authorization when a late PassKit or SDK callback arrives.
struct ApplePayLifecycle {
    enum Phase { case preparing, presenting, presented, tokenizing, dismissing, finished }
    private(set) var phase: Phase = .preparing

    mutating func beginPresentation() -> Bool {
        guard phase == .preparing else { return false }
        phase = .presenting
        return true
    }

    mutating func didPresent() -> Bool {
        guard phase == .presenting else { return false }
        phase = .presented
        return true
    }

    mutating func beginAuthorization() -> Bool {
        guard phase == .presented || phase == .presenting else { return false }
        phase = .tokenizing
        return true
    }

    mutating func beginDismissal() -> Bool {
        guard phase != .dismissing && phase != .finished else { return false }
        phase = .dismissing
        return true
    }

    mutating func completeDismissal() -> Bool {
        guard phase == .dismissing else { return false }
        phase = .finished
        return true
    }

    var canCancel: Bool { phase == .preparing || phase == .presenting || phase == .presented }

    var acceptsCallbacks: Bool { phase != .dismissing && phase != .finished }
}
