//
//  main.swift
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
import ArgumentParser
import TrackerRadarKit
import WebKit

@available(OSX 10.13, *)
struct Validator: ParsableCommand {

    enum ValidatorError: Error {
        case failedToReadFile(fileName: String)
    }

    @Argument(help: "TrackerRadar json file.")
    var trackerRadarFile: String

    @Argument(help: "Temporary unprotected list.")
    var temporaryUnprotectedList: String?

    mutating func run() throws {

        guard let data = trackerRadarFile.fileContentsAsData() else {
            throw ValidatorError.failedToReadFile(fileName: trackerRadarFile)
        }

        let trackerRadar = try JSONDecoder().decode(TrackerData.self, from: data)
        print(Date(),
              trackerRadar.trackers.count,
              "trackers.",
              trackerRadar.domains.count,
              "domains.",
              trackerRadar.cnames?.count ?? 0,
              "cnames.",
              trackerRadar.entities.count,
              "entities.")

        let temporaryUnprotectedDomains = temporaryUnprotectedList?.fileContentsAsStringArray()
        if let domains = temporaryUnprotectedDomains {
            print("\(domains.count) unprotected domains")
        } else {
            print("No unprotected domains")
        }

        do {
            try compile("Complete", trackerRadar: trackerRadar, temporaryUnprotectedDomains: temporaryUnprotectedDomains)
            print("Compilation success")
        } catch {
            print("Compilation failed")

            // Check it wasn't the unprotected domains
            if temporaryUnprotectedDomains != nil {
                print("Checking temporary unprotected domains")
                do {
                    try compile("temporaryUnprotectedDomains", trackerRadar: trackerRadar, temporaryUnprotectedDomains: nil)
                    print("Error with temporary unprotected domains")
                } catch {
                    // Wasn't the temporary unprotected domains then
                }
            }

            // Check each tracker in turn
            print("Checking each tracker, please wait")
            for tracker in trackerRadar.trackers.sorted(by: { $0.key < $1.key }) {
                if tracker.value.defaultAction == .ignore && tracker.value.rules?.isEmpty ?? true {
                    print("Skipping \(tracker.key), default ignore and no rules")
                    continue
                }

                do {
                    let single = TrackerData(trackers: [tracker.key: tracker.value],
                                             entities: trackerRadar.entities,
                                             domains: trackerRadar.domains,
                                             cnames: trackerRadar.cnames)

                    try compile(tracker.key, trackerRadar: single, temporaryUnprotectedDomains: nil)
                } catch {
                    print()
                    print("Error with tracker `\(tracker.key)`", error)
                }
            }

            print()
            throw error
        }
    }

    func compile(_ identifier: String, trackerRadar: TrackerData, temporaryUnprotectedDomains: [String]?  ) throws {

        let rules = ContentBlockerRulesBuilder(trackerData: trackerRadar).buildRules(withExceptions: nil, andTemporaryUnprotectedDomains: temporaryUnprotectedDomains)

        let jsonData = try JSONEncoder().encode(rules)

        let ruleList = String(data: jsonData, encoding: .utf8)

        var compilationError: Error?
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: ruleList,
            completionHandler: { _, error in
                compilationError = error
        })

        if let error = compilationError {
            throw error
        }
    }

}

if #available(OSX 10.13, *) {
    Validator.main()
} else {
    print("macos 10.13 or higher is required")
}

extension String {

    func fileContentsAsData() -> Data? {
        return FileManager.default.contents(atPath: self)
    }

    func fileContentsAsStringArray() -> [String]? {
        guard let data = fileContentsAsData() else { return nil }
        return String(data: data, encoding: .utf8)?.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
    }

}

extension KnownTracker {

    func toJson() -> String {
        return String(data: try! JSONEncoder().encode(self), encoding: .utf8)!
    }

}

