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

    func testLoadingUnsupportedRules() throws {
        let data = JSONTestDataLoader.mockTrackerData
        guard let mockData = try? JSONDecoder().decode(TrackerData.self, from: data) else {
            XCTFail("Failed to decode tracker data")
            return
        }

        guard let tracker = mockData.findTracker(byCname: "tracker-4.com") else {
            XCTFail("Failed to find tracker")
            return
        }

        let expectedNumberOfRules = 1
        XCTAssertEqual(tracker.rules?.count, expectedNumberOfRules)
    }

    func testTrackerDataParserPerformance () {
        let data = JSONTestDataLoader.trackerData
        measure {
            _ = try? JSONDecoder().decode(TrackerData.self, from: data)
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

        // The data set is large enough that comparing these is slow, so check batches at the start and end.
        XCTAssertEqual(firstGeneration.prefix(upTo: 1000), secondGeneration.prefix(upTo: 1000))
        XCTAssertEqual(firstGeneration.suffix(1000), secondGeneration.suffix(1000))
    }

    func testLoadingRulesIsDeterministic_MockData() {
        let data = JSONTestDataLoader.mockTrackerData
        guard let mockData = try? JSONDecoder().decode(TrackerData.self, from: data) else {
            XCTFail("Failed to decode tracker data")
            return
        }

        let firstGeneration = ContentBlockerRulesBuilder(trackerData: mockData).buildRules(
            withExceptions: [],
            andTemporaryUnprotectedDomains: []
        ).map { $0.trigger.urlFilter }

        let secondGeneration = ContentBlockerRulesBuilder(trackerData: mockData).buildRules(
            withExceptions: [],
            andTemporaryUnprotectedDomains: []
        ).map { $0.trigger.urlFilter }

        XCTAssertEqual(firstGeneration, secondGeneration)
    }

}
