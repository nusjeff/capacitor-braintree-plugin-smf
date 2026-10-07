import XCTest
import PassKit
#if canImport(SMFCapacitorBraintreePluginPlugin)
@testable import SMFCapacitorBraintreePluginPlugin
#endif

final class ApplePayLifecycleTests: XCTestCase {
    func testCancelKeepsSessionLockedUntilDismissalCompletes() {
        var session = ApplePayLifecycle()
        XCTAssertTrue(session.beginPresentation())
        XCTAssertTrue(session.didPresent())
        XCTAssertTrue(session.beginDismissal())
        XCTAssertEqual(session.phase, .dismissing)
        XCTAssertFalse(session.acceptsCallbacks)
        XCTAssertFalse(session.beginAuthorization())
        XCTAssertTrue(session.completeDismissal())
        XCTAssertEqual(session.phase, .finished)
    }

    func testLatePresentationCannotReopenTimedOutSession() {
        var session = ApplePayLifecycle()
        XCTAssertTrue(session.beginPresentation())
        XCTAssertTrue(session.beginDismissal())
        XCTAssertFalse(session.didPresent())
        XCTAssertTrue(session.completeDismissal())
        XCTAssertFalse(session.didPresent())
        XCTAssertFalse(session.beginPresentation())
    }

    func testTokenizationTimeoutAndSuccessCanOnlySettleOnce() {
        var session = ApplePayLifecycle()
        XCTAssertTrue(session.beginPresentation())
        XCTAssertTrue(session.didPresent())
        XCTAssertTrue(session.beginAuthorization())
        XCTAssertFalse(session.beginAuthorization())
        XCTAssertTrue(session.beginDismissal())
        XCTAssertFalse(session.beginDismissal())
        XCTAssertTrue(session.completeDismissal())
        XCTAssertFalse(session.completeDismissal())
    }

    func testOldCallbacksDoNotChangeNextSession() {
        var old = ApplePayLifecycle()
        XCTAssertTrue(old.beginPresentation())
        XCTAssertTrue(old.beginDismissal())
        XCTAssertTrue(old.completeDismissal())
        var next = ApplePayLifecycle()
        XCTAssertTrue(next.beginPresentation())
        XCTAssertTrue(next.didPresent())
        XCTAssertFalse(old.didPresent())
        XCTAssertFalse(old.beginAuthorization())
        XCTAssertFalse(old.completeDismissal())
        XCTAssertEqual(next.phase, .presented)
        XCTAssertTrue(next.beginAuthorization())
    }

    func testApprovalBeforePresentationCompletionKeepsAuthorizationActive() {
        var session = ApplePayLifecycle()
        XCTAssertTrue(session.beginPresentation())
        XCTAssertTrue(session.beginAuthorization())
        XCTAssertFalse(session.didPresent())
        XCTAssertTrue(session.acceptsCallbacks)
        XCTAssertEqual(session.phase, .tokenizing)
    }

    func testValidationFailureDoesNotRequireAPresentedController() {
        var session = ApplePayLifecycle()
        XCTAssertTrue(session.beginDismissal())
        XCTAssertTrue(session.completeDismissal())
        XCTAssertFalse(session.beginPresentation())
    }
    func testCannotCancelAfterApproval() {
        var session = ApplePayLifecycle()
        XCTAssertTrue(session.canCancel)
        _ = session.beginPresentation()
        XCTAssertTrue(session.canCancel)
        _ = session.beginAuthorization()
        XCTAssertFalse(session.canCancel)
    }

    func testCancellationWaitsForLatePresentAndDismissCallbacks() {
        let barrier = ApplePayDismissalBarrier()
        var dismissed = 0
        var settled = 0
        var dismissCompletion: (() -> Void)?
        barrier.presentationStarted()
        barrier.finish(dismiss: { done in
            dismissed += 1
            dismissCompletion = done
        }, completion: { settled += 1 })
        XCTAssertEqual(dismissed, 0)
        XCTAssertEqual(settled, 0)
        barrier.presentationReturned()
        XCTAssertEqual(dismissed, 1)
        XCTAssertEqual(settled, 0)
        dismissCompletion?()
        dismissCompletion?()
        barrier.presentationReturned()
        XCTAssertEqual(settled, 1)
        XCTAssertEqual(dismissed, 1)
    }

    func testReentrantDismissalCannotReplaceOutcomeOrSettleTwice() {
        let barrier = ApplePayDismissalBarrier()
        var settled = 0
        barrier.finish(dismiss: { done in
            barrier.finish(dismiss: { $0() }, completion: { settled += 100 })
            done()
            done()
        }, completion: { settled += 1 })
        XCTAssertEqual(settled, 1)
    }
    func testSharedGatewayDefaultsDoNotRejectAppMerchantAndCountry() {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.trainsplit.app.dev"
        request.countryCode = "IE"
        request.currencyCode = "GBP"
        request.supportedNetworks = [.visa, .masterCard]
        let failures = ApplePayRequestConfiguration.apply(to: request,
            merchant: "merchant.co.uk.splitmyfare.staging", country: "GB", currency: "GBP")
        XCTAssertTrue(failures.isEmpty)
        XCTAssertEqual(request.merchantIdentifier, "merchant.co.uk.splitmyfare.staging")
        XCTAssertEqual(request.countryCode, "GB")
        XCTAssertEqual(request.currencyCode, "GBP")
        XCTAssertEqual(request.supportedNetworks, [.visa, .masterCard])
    }

    func testCurrencyMismatchIsStillRejectedBeforeRequestOverrides() {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.trainsplit.app.dev"
        request.currencyCode = "EUR"
        request.supportedNetworks = [.visa]
        let failures = ApplePayRequestConfiguration.apply(to: request,
            merchant: "merchant.co.uk.splitmyfare.staging", country: "GB", currency: "GBP")
        XCTAssertEqual(failures, ["currencyCode: checkout=GBP, gateway=EUR"])
        XCTAssertEqual(request.currencyCode, "EUR")
        XCTAssertEqual(request.merchantIdentifier, "merchant.com.trainsplit.app.dev")
    }

    func testGatewayWithoutAcceptedNetworksIsStillRejected() {
        let request = PKPaymentRequest()
        request.currencyCode = "GBP"
        request.supportedNetworks = []
        XCTAssertEqual(ApplePayRequestConfiguration.apply(to: request,
            merchant: "merchant.co.uk.splitmyfare.staging", country: "GB", currency: "GBP"),
            ["gateway supportedNetworks is empty"])
    }
}
