//
//  ContentBlockerRulesBuilderTests.swift
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

import XCTest
@testable import TrackerRadarKit

class ContentBlockerRulesBuilderTests: XCTestCase {

    // swiftlint:disable force_try
    lazy var trackerData: TrackerData = {
        let data = JSONTestDataLoader.trackerData
        return try! JSONDecoder().decode(TrackerData.self, from: data)
    }()
    // swiftlint:enable force_try

    func testLoadingRules() throws {
        let rules = ContentBlockerRulesBuilder(trackerData: trackerData).buildRules(withExceptions: ["duckduckgo.com"],
        andTemporaryUnprotectedDomains: [])

        // Test tracker is set up to be blocked
        if let rule = rules.findExactFilter(filter: "^(https?)?(wss?)?://([a-z0-9-]+\\.)*googleadservices\\.com(:?[0-9]+)?/.*") {
            XCTAssert(rule.action == .block())
        } else {
            XCTFail("Missing google ad services rule")
        }

        // Test exceptiions are set to ignore previous rules
        if let rule = rules.findInIfDomain(domain: "duckduckgo.com") {
            XCTAssert(rule.action == .ignorePreviousRules())
        } else {
            XCTFail("Missing domain exception")
        }
    }

    func testLoadingRulesIsDeterministic() {
        let firstGeneration = ContentBlockerRulesBuilder(trackerData: trackerData).buildRules(
            withExceptions: [],
            andTemporaryUnprotectedDomains: []
        ).map { $0.trigger.urlFilter }

        let secondGeneration = ContentBlockerRulesBuilder(trackerData: trackerData).buildRules(
            withExceptions: [],
            andTemporaryUnprotectedDomains: []
        ).map { $0.trigger.urlFilter }

        // Temporary quick checks to see if these are differences, limited to 50 because these tests are failing even on this limited subset.
        XCTAssertEqual(firstGeneration.prefix(upTo: 50), secondGeneration.prefix(upTo: 50))
        XCTAssertEqual(firstGeneration.suffix(50), secondGeneration.suffix(50))
    }

}
