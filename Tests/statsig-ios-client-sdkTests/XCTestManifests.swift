import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(statsig_ios_client_sdkTests.allTests),
    ]
}
#endif
