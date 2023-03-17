import Foundation

import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

class AtomicDictionarySpec: BaseSpec {
    override func spec() {
        super.spec()

        describe("AtomicDictionary") {
            let iterations = 1000
            let dict = AtomicDictionary<String>()

            it("works from multiple threads") {
                let work = {
                    for _ in 0...iterations {
                        dict["foo"] = "bar"
                        expect(dict["foo"]).to(equal("bar"))
                    }
                }

                DispatchQueue.main.async(execute: work)
                DispatchQueue.global(qos: .background).async(execute: work)

                waitUntil { done in
                    DispatchQueue.global(qos: .userInitiated).sync {
                        work()
                        done()
                    }
                }
            }

            it("reads and writes values") {
                dict["one"] = "foo"
                expect(dict["one"]).to(equal("foo"))
            }

            it("can be created with initial values") {
                let new = AtomicDictionary(["a": "b"])
                expect(new["a"]).to(equal("b"))
            }
        }
    }
}
