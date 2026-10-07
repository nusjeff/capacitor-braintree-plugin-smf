import XCTest

@main
struct ApplePayLifecycleTestRunner {
    static func main() {
        let suite = XCTestSuite(forTestCaseClass: ApplePayLifecycleTests.self)
        suite.run()
        guard let result = suite.testRun, result.executionCount == 12, result.totalFailureCount == 0 else {
            fatalError("Apple Pay lifecycle tests did not all pass")
        }
    }
}
