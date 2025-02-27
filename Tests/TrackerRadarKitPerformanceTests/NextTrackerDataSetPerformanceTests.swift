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
    
    var compilationTimeBaseline: Double?
    let baselineFileName = "compilationTimeBaseline.json"
    var baselinePath: String!
    var initBaseline: Bool = false
    var testVsBaseline: Bool = false
    
    var maxPercentRegression: Double = 0.05 // 5% by default

    var tdsFileName: String = "ios-tds.json"
    var tdsDevURL: Bool = false
    var isUsingDefaultValues: Bool = true
    
    func nextURL(filename: String) -> URL {
        return tdsDevURL ? URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/whateveritwillbe/\(filename)")! : URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v5/next/\(filename)")!
    }
    
    override func setUp() async throws {
        try await super.setUp()
        
        try loadParameters()
        
        let (data, _) = try await URLSession.shared.data(from: nextURL(filename: tdsFileName))
        
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
        
        var iterations = 0
        var totalTime: TimeInterval = 0
        
        measure {
            let time = CACurrentMediaTime()
            let expectation = expectation(description: "Compiled")
            
            store.compileContentRuleList(forIdentifier: UUID().uuidString, encodedContentRuleList: ruleList) { _, error in
                XCTAssertNil(error)
                
                Thread.sleep(forTimeInterval: 1)
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 40)
            
            let executionTime = CACurrentMediaTime() - time
            print("Compiled in \(executionTime)")
            iterations += 1
            totalTime += executionTime
        }
        
        let currentAverage = totalTime / Double(iterations)
        print("--> Average compilation time: \(currentAverage)")
        
        // Check against previous value if set
        if testVsBaseline, let previousBaseline = compilationTimeBaseline {
            let maxAllowedValue = previousBaseline * (1 + maxPercentRegression)
            
            XCTAssertLessThanOrEqual(
                currentAverage,
                maxAllowedValue,
                "Performance degraded by more than \(maxPercentRegression * 100)%. Previous: \(previousBaseline), Current: \(currentAverage)"
            )
        }

        if initBaseline || isUsingDefaultValues {
            writeBaselineFile(with: currentAverage)
        }
    }
    
    func loadParameters() throws {
        if let initBaseline = ProcessInfo.processInfo.environment["INIT_BASELINE"] {
            self.initBaseline = initBaseline.lowercased() == "true"
        }
        
        if let maxPercentRegressionString = ProcessInfo.processInfo.environment["MAX_DEVIATION"] {
            maxPercentRegression = Double(maxPercentRegressionString) ?? self.maxPercentRegression
        }
        
        if let testVsBaseline = ProcessInfo.processInfo.environment["TEST_VS_BASELINE"] {
            self.testVsBaseline = testVsBaseline.lowercased() == "true"
        }
        
        if let envTdsFileName = ProcessInfo.processInfo.environment["TDS_FILE_NAME"] {
            tdsFileName = envTdsFileName
            isUsingDefaultValues = false
        }
        
        if let envTdsDevURL = ProcessInfo.processInfo.environment["USE_TDS_DEV_URL"] {
            tdsDevURL = envTdsDevURL.lowercased() == "true"
            isUsingDefaultValues = false
        }
        
        // Set the path for the baseline file
        let fileManager = FileManager.default
        baselinePath = fileManager.currentDirectoryPath.appending("/\(baselineFileName)")
        print("--> Baseline file path: \(baselinePath)")
        
        if testVsBaseline {
            try loadBaselineFile()
        }
    }
    
    func loadBaselineFile() throws {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: baselinePath))
            let json = try JSONDecoder().decode([String: Double].self, from: data)
            compilationTimeBaseline = json["compilationTimeBaseline"]
        } catch {
            print("Error reading baseline file: \(error)")
            
            if initBaseline {
                print("INIT_BASELINE is set to true. Continuing without baseline.")
            } else {
                throw error
            }
        }
    }
    
    func writeBaselineFile(with value: Double) {
        let json = ["compilationTimeBaseline": value]
        do {
            let data = try JSONEncoder().encode(json)
            try data.write(to: URL(fileURLWithPath: baselinePath))
            print("New baseline value written successfully.")
        } catch {
            print("Error writing new baseline value: \(error)")
        }
    }
}
