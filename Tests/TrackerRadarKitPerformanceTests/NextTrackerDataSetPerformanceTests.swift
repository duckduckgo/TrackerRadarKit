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
    
    var utTDS: TrackerData!
    var refTDS: TrackerData?
        
    var maxPercentRegression: Double = 0.05 // 5% by default

    var tdsUtFileName: String = "ios-tds.json"
    var tdsUtURL: String = "https://staticcdn.duckduckgo.com/trackerblocking/v5/next/"
    var tdsRefFileName: String?
    var tdsRefURL: String?
    
    let numberOfRuns = 10
    var numberOfIterationsPerRun: Int = 1 
    
    func nextURL(filename: String, fileURL: String) -> URL {
        let baseURL = URL(string: fileURL)!
        return baseURL.appendingPathComponent(filename)
    }

    override func setUp() async throws {
        try await super.setUp()
        
        try loadParameters()
        
        // Prepare TDS Under Test file
        let utTdsUrl = nextURL(filename: tdsUtFileName, fileURL: tdsUtURL)
        print("TDS under Test: \(utTdsUrl.absoluteString)")
        
        let (data, _) = try await URLSession.shared.data(from: utTdsUrl)
        utTDS = try JSONDecoder().decode(TrackerData.self, from: data)
        
        // Prepare reference TDS file
        if let refFileName = tdsRefFileName, let refURL = tdsRefURL {
            let refTdsUrl = nextURL(filename: refFileName, fileURL: refURL)
            print("Reference TDS: \(refTdsUrl.absoluteString)")
            
            let (refData, _) = try await URLSession.shared.data(from: refTdsUrl)
            refTDS = try JSONDecoder().decode(TrackerData.self, from: refData)
        }
        
        print("TDS files prepared")
    }
    
    func testPerformanceOfNext_iOSTDS() throws {
        let utAverage = try runPerformanceTest(tds: utTDS, name: "UT TDS")
        
        if let refTDS = refTDS {
            let refAverage = try runPerformanceTest(tds: refTDS, name: "Reference TDS")
            
            let percentDifference = (utAverage - refAverage) / refAverage
            print("Percent difference: \(String(format: "%.2f", percentDifference * 100))%")
            
            XCTAssertLessThanOrEqual(percentDifference, maxPercentRegression, "UT TDS performance regression exceeds allowed threshold")
        }
        
        // Perform one last run inside measure block for XCTest metrics
        let ruleList = try prepareRuleList(tds: utTDS)
        
        guard let store = WKContentRuleListStore(url: FileManager.default.temporaryDirectory) else {
            throw NSError(domain: "PerformanceTestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create WKContentRuleListStore"])
        }
        measure {
            _ = measureSingleRun(store: store, ruleList: ruleList)
        }
    }
        
    func runPerformanceTest(tds: TrackerData, name: String) throws -> TimeInterval {
        var allAverages: [TimeInterval] = []
        
        let ruleList = try prepareRuleList(tds: tds)
        
        guard let store = WKContentRuleListStore(url: FileManager.default.temporaryDirectory) else {
            throw NSError(domain: "PerformanceTestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create WKContentRuleListStore"])
        }
        
        // Perform multiple runs outside of the measure block
        for run in 1...numberOfRuns {
            let average = try performSingleRun(store: store, ruleList: ruleList, run: run, numberOfIterations: numberOfIterationsPerRun, name: name)
            allAverages.append(average)
        }
        
        // Calculate and print the final average
        let finalAverage = calculateFinalAverage(allAverages)
        print("Final average for \(name) (30-70 percentile): \(finalAverage)")
        
        return finalAverage
    }
    
    func performSingleRun(store: WKContentRuleListStore, ruleList: String, run: Int, numberOfIterations: Int, name: String) throws -> TimeInterval {
        var totalTime: TimeInterval = 0
        
        for iteration in 1...numberOfIterations {
            let executionTime = measureSingleRun(store: store, ruleList: ruleList)
            print("\(name) - Run \(run), Iteration \(iteration): Compiled in \(executionTime)")
            totalTime += executionTime
        }
        
        let average = totalTime / Double(numberOfIterationsPerRun)
        print("Run \(run) --> Average compilation time: \(average)")
        return average
    }
    
    func prepareRuleList(tds: TrackerData) throws -> String {
        let rules = ContentBlockerRulesBuilder(trackerData: tds).buildRules()
        
        let data = try JSONEncoder().encode(rules)
        return String(data: data, encoding: .utf8)!
    }
    
    func measureSingleRun(store: WKContentRuleListStore, ruleList: String) -> TimeInterval {
        let time = CACurrentMediaTime()
        let expectation = expectation(description: "Compiled")
        
        store.compileContentRuleList(forIdentifier: UUID().uuidString, encodedContentRuleList: ruleList) { _, error in
            XCTAssertNil(error)
            Thread.sleep(forTimeInterval: 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 40)
        
        return CACurrentMediaTime() - time
    }

    func calculateFinalAverage(_ allAverages: [TimeInterval]) -> TimeInterval {
        let sortedAverages = allAverages.sorted()
        let lowerIndex = Int(Double(sortedAverages.count) * 0.3)
        let upperIndex = Int(Double(sortedAverages.count) * 0.7)
        let filteredAverages = Array(sortedAverages[lowerIndex...upperIndex])
        return filteredAverages.reduce(0, +) / Double(filteredAverages.count)
    }
    
    func loadParameters() throws {
        if let envTdsFileName = ProcessInfo.processInfo.environment["TDS_UT_FILE_NAME"], !envTdsFileName.isEmpty {
            tdsUtFileName = envTdsFileName
        }
        
        if let envTdsUrl = ProcessInfo.processInfo.environment["TDS_UT_URL"], !envTdsUrl.isEmpty {
            tdsUtURL = envTdsUrl
        }
        
        if let envRefTdsFileName = ProcessInfo.processInfo.environment["TDS_REF_FILE_NAME"], !envRefTdsFileName.isEmpty {
            tdsRefFileName = envRefTdsFileName
        }
        
        if let envRefTdsUrl = ProcessInfo.processInfo.environment["TDS_REF_URL"], !envRefTdsUrl.isEmpty {
            tdsRefURL = envRefTdsUrl
        }
        
        if let envNumberOfIterations = ProcessInfo.processInfo.environment["NUMBER_OF_ITERATIONS_PER_RUN"], 
            !envNumberOfIterations.isEmpty, let iterations = Int(envNumberOfIterations) {
            numberOfIterationsPerRun = iterations
        }
    }
}
