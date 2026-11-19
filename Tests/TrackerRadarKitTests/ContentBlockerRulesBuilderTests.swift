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
        // Optimized per WebKit recommendations: https://webkit.org/blog/4062/targeting-domains-with-content-blockers/
        if let rule = rules.findExactFilter(filter: "^[^:]+://+([^:/]+\\.)?googleadservices\\.com[:/]") {
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

    private let surrogateFilter = "^[^:]+://+([^:/]+\\.)?tracker\\.com\\/surrogate\\.js"

    private func surrogateTrackerData() -> TrackerData {
        let surrogateRule = KnownTracker.Rule(rule: "tracker\\.com\\/surrogate\\.js",
                                              surrogate: "surrogate.js",
                                              action: nil,
                                              options: KnownTracker.Rule.Matching(domains: ["example.com"], types: nil),
                                              exceptions: KnownTracker.Rule.Matching(domains: ["other.com"], types: nil))
        let blockRule = KnownTracker.Rule(rule: "tracker\\.com\\/surrogate\\.js",
                                          surrogate: nil, action: nil, options: nil, exceptions: nil)
        let blockingTracker = KnownTracker(domain: "tracker.com", defaultAction: .block, owner: nil, prevalence: nil,
                                           subdomains: nil, categories: nil, rules: [surrogateRule, blockRule])
        let ignoringTracker = KnownTracker(domain: "ignored.com", defaultAction: .ignore, owner: nil, prevalence: nil,
                                           subdomains: nil, categories: nil,
                                           rules: [KnownTracker.Rule(rule: "ignored\\.com\\/surrogate\\.js", surrogate: "surrogate.js",
                                                                     action: nil, options: nil, exceptions: nil)])
        return TrackerData(trackers: ["tracker.com": blockingTracker, "ignored.com": ignoringTracker],
                           entities: [:], domains: [:], cnames: nil)
    }

    func testSurrogateRulesAreNotBlockedWhenUnblockSurrogateRulesIsSet() throws {
        let rules = ContentBlockerRulesBuilder(trackerData: surrogateTrackerData(), unblockSurrogateRules: true).buildRules()

        // Blocking tracker: the surrogate rule becomes an unconditional ignore, after any rule that blocks the same URL
        let matching = rules.filter { $0.trigger.urlFilter == surrogateFilter }
        XCTAssertEqual(matching.last?.action, .ignorePreviousRules())
        XCTAssertNil(matching.last?.trigger.ifDomain)
        XCTAssertNil(matching.last?.trigger.resourceType)

        // Ignoring tracker: the surrogate rule becomes an unconditional ignore, and is never blocked
        let ignoredMatching = rules.filter { $0.trigger.urlFilter.contains("ignored\\.com\\/surrogate") }
        XCTAssertEqual(ignoredMatching.map(\.action), [.ignorePreviousRules()])
        XCTAssertNil(ignoredMatching.first?.trigger.ifDomain)
    }

    func testSurrogateRulesAreNotBlockedByBroaderRulesInIgnoringTracker() throws {
        let broadRule = KnownTracker.Rule(rule: "ignored\\.com\\/", surrogate: nil, action: nil, options: nil, exceptions: nil)
        let surrogateRule = KnownTracker.Rule(rule: "ignored\\.com\\/surrogate\\.js", surrogate: "surrogate.js",
                                              action: nil, options: nil, exceptions: nil)
        let ignoringTracker = KnownTracker(domain: "ignored.com", defaultAction: .ignore, owner: nil, prevalence: nil,
                                           subdomains: nil, categories: nil, rules: [broadRule, surrogateRule])
        let trackerData = TrackerData(trackers: ["ignored.com": ignoringTracker], entities: [:], domains: [:], cnames: nil)
        let rules = ContentBlockerRulesBuilder(trackerData: trackerData, unblockSurrogateRules: true).buildRules()

        let broadFilter = "^[^:]+://+([^:/]+\\.)?ignored\\.com\\/"
        let surrogateFilter = "^[^:]+://+([^:/]+\\.)?ignored\\.com\\/surrogate\\.js"
        guard let blockIndex = rules.lastIndex(where: { $0.trigger.urlFilter == broadFilter && $0.action == .block() }) else {
            return XCTFail("Missing block rule for the broad rule")
        }
        // The surrogate URL is blocked by the broad rule, so it needs an unconditional ignore after it
        guard let ignoreIndex = rules.lastIndex(where: { $0.trigger.urlFilter == surrogateFilter }) else {
            return XCTFail("Missing ignore rule for the surrogate rule")
        }
        XCTAssertGreaterThan(ignoreIndex, blockIndex)
        XCTAssertEqual(rules[ignoreIndex].action, .ignorePreviousRules())
        XCTAssertNil(rules[ignoreIndex].trigger.ifDomain)
        XCTAssertNil(rules[ignoreIndex].trigger.resourceType)
        XCTAssertFalse(rules.contains { $0.trigger.urlFilter == surrogateFilter && $0.action == .block() })
    }

    func testSurrogateRulesAreBlockedByDefault() throws {
        let rules = ContentBlockerRulesBuilder(trackerData: surrogateTrackerData()).buildRules()

        // Blocking tracker: the last rule for the surrogate URL blocks it
        let matching = rules.filter { $0.trigger.urlFilter == surrogateFilter }
        XCTAssertEqual(matching.last?.action, .block())

        // Ignoring tracker: the surrogate rule blocks as a normal rule would
        XCTAssertTrue(rules.contains { $0.trigger.urlFilter.contains("ignored\\.com\\/surrogate") && $0.action == .block() })
    }

    func testDefaultIgnoreGeneratesPopupIgnoreRules() throws {
        let rules = ContentBlockerRulesBuilder(trackerData: trackerData).buildRules(withExceptions: ["duckduckgo.com"],
        andTemporaryUnprotectedDomains: [])

        // Optimized per WebKit recommendations: https://webkit.org/blog/4062/targeting-domains-with-content-blockers/
        var domainFilter = "^[^:]+://+([^:/]+\\.)?xvideos-cdn\\.com\\/v-c19d94e7937\\/v3\\/js\\/skins\\/min\\/default\\.header\\.static\\.js"
        if let idx = rules.firstIndexOfExactFilter(filter: domainFilter) {
            let nextRule = rules[idx + 1]
            XCTAssertNotNil(nextRule, "Missing ignore-previous popup type rule")
            XCTAssert(nextRule.action == .ignorePreviousRules())
            XCTAssert(nextRule.trigger.loadContext?.first == .topFrame)
            XCTAssert(nextRule.trigger.resourceType?.first == .popup)
        } else {
            XCTFail("Missing rule for testing")
        }

        // Test top level default block rule
        // Optimized per WebKit recommendations
        domainFilter = "^[^:]+://+([^:/]+\\.)?google-analytics\\.com[:/]"
        if let idx = rules.firstIndexOfExactFilter(filter: domainFilter) {
            let nextRule = rules[idx + 1]
            XCTAssertNotNil(nextRule, "Missing ignore-previous popup type rule")
            XCTAssert(nextRule.action == .ignorePreviousRules())
            XCTAssert(nextRule.trigger.loadContext?.first == .topFrame)
            XCTAssert(nextRule.trigger.resourceType?.first == .popup)
        } else {
            XCTFail("Missing rule for testing")
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

    func testTrackerDataParserPerformance() {
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
