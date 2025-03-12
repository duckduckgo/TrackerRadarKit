//
//  NextTrackerDataSetPerformanceTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import XCTest
import TrackerRadarKit
import WebKit

class NextTrackerDataSetPerformanceTests: XCTestCase {

    static func nextURL(filename: String) -> URL {
        return URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v5/next/\(filename)")!
    }

    var nextiOSTDS: TrackerData!

    override func setUp() async throws {
        try await super.setUp()

        let (data, _) = try await URLSession.shared.data(from: Self.nextURL(filename: "ios-tds.json"))

        nextiOSTDS = try JSONDecoder().decode(TrackerData.self, from: data)

        print("Next TDS prepared")
    }

    func testPerformanceOfNext_iOSTDS() throws {

        let rules = ContentBlockerRulesBuilder(trackerData: nextiOSTDS).buildRules()
        
        let data = try JSONEncoder().encode(rules)
        let ruleList = String(data: data, encoding: .utf8)!

        var store: WKContentRuleListStore!

        let warmUpExpectation = expectation(description: "Warmed up")

        DispatchQueue.main.async {
            store = WKContentRuleListStore(url: FileManager.default.temporaryDirectory)
            store.compileContentRuleList(forIdentifier: UUID().uuidString, encodedContentRuleList: ruleList) { _, error in
                XCTAssertNil(error)
                warmUpExpectation.fulfill()
            }
        }
        wait(for: [warmUpExpectation], timeout: 40)

        measure {
            let time = CACurrentMediaTime()
            let expectation = expectation(description: "Compiled")

            store.compileContentRuleList(forIdentifier: UUID().uuidString, encodedContentRuleList: ruleList) { _, error in
                XCTAssertNil(error)

                Thread.sleep(forTimeInterval: 1)

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 40)
            print("Compiled in \(CACurrentMediaTime() - time)")
        }
    }
}
