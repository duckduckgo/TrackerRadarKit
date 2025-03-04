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
    
    var nextiOSTDS: TrackerData!
        
    var maxPercentRegression: Double = 0.05 // 5% by default

    var tdsFileName: String = "ios-tds.json"
    var tdsDevURL: String = "https://staticcdn.duckduckgo.com/trackerblocking/v5/next/"
    
    let numberOfRuns = 10
    let numberOfIterationsPerRun = 1
    
    func nextURL(filename: String, fileURL: String) -> URL {
        let baseURL = URL(string: fileURL)!
        return baseURL.appendingPathComponent(filename)
    }

    override func setUp() async throws {
        try await super.setUp()
        
        try loadParameters()
        
        let (data, _) = try await URLSession.shared.data(from: nextURL(filename: tdsFileName, fileURL: tdsDevURL))
        
        nextiOSTDS = try JSONDecoder().decode(TrackerData.self, from: data)
        
        print("Next TDS prepared")
    }
    
    func testPerformanceOfNext_iOSTDS() throws {
        var allAverages: [TimeInterval] = []
            
        // Perform multiple runs outside of the measure block
        for run in 1...numberOfRuns {
            let average = try performSingleRun(run: run, numberOfIterations: numberOfIterationsPerRun)
            allAverages.append(average)
        }
            
        // Calculate and print the final average
        let finalAverage = calculateFinalAverage(allAverages)
        print("Final average (30-70 percentile): \(finalAverage)")
            
        // Perform one last run inside measure block for XCTest metrics
        measure {
            let _ = try? performSingleRun(run: numberOfRuns + 1, numberOfIterations: 1)
        }
            
        // You can add assertions here if needed
        // XCTAssertLessThanOrEqual(finalAverage, someThreshold)
        }
    
    func performSingleRun(run: Int, numberOfIterations: Int) throws -> TimeInterval {
        let rules = ContentBlockerRulesBuilder(trackerData: nextiOSTDS).buildRules()
        
        let data = try JSONEncoder().encode(rules)
        let ruleList = String(data: data, encoding: .utf8)!
        
        guard let store = WKContentRuleListStore(url: FileManager.default.temporaryDirectory) else {
            throw NSError(domain: "PerformanceTestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create WKContentRuleListStore"])
        }
        
        var totalTime: TimeInterval = 0
        
        for iteration in 1...numberOfIterations {
            let time = CACurrentMediaTime()
            let expectation = expectation(description: "Compiled")
            
            store.compileContentRuleList(forIdentifier: UUID().uuidString, encodedContentRuleList: ruleList) { _, error in
                XCTAssertNil(error)
                Thread.sleep(forTimeInterval: 1)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 40)
            
            let executionTime = CACurrentMediaTime() - time
            print("Run \(run), Iteration \(iteration): Compiled in \(executionTime)")
            totalTime += executionTime
        }
        
        let average = totalTime / Double(numberOfIterationsPerRun)
        print("Run \(run) --> Average compilation time: \(average)")
        return average
    }
        
    func calculateFinalAverage(_ allAverages: [TimeInterval]) -> TimeInterval {
        let sortedAverages = allAverages.sorted()
        let lowerIndex = Int(Double(sortedAverages.count) * 0.3)
        let upperIndex = Int(Double(sortedAverages.count) * 0.7)
        let filteredAverages = Array(sortedAverages[lowerIndex...upperIndex])
        return filteredAverages.reduce(0, +) / Double(filteredAverages.count)
    }
    
    func loadParameters() throws {
        if let envTdsFileName = ProcessInfo.processInfo.environment["TDS_FILE_NAME"] {
            tdsFileName = envTdsFileName
        }
        
        if let envTdsUrl = ProcessInfo.processInfo.environment["TDS_URL"] {
            tdsDevURL = envTdsUrl
        }
    }
}
