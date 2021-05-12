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
        print(Date(), "File loaded")

        let trackerRadar = try JSONDecoder().decode(TrackerData.self, from: data)
        print(Date(), "File decoded from TrackerRadar JSON")

        let temporaryUnprotectedDomains = temporaryUnprotectedList?.fileContentsAsStringArray()
        if let domains = temporaryUnprotectedDomains {
            print(Date(), "\(domains.count) unprotected domains")
        } else {
            print(Date(), "No unprotected domains")
        }

        let rules = ContentBlockerRulesBuilder(trackerData: trackerRadar).buildRules(withExceptions: nil, andTemporaryUnprotectedDomains: temporaryUnprotectedDomains)
        print(Date(), "Rules built")

        let jsonData = try JSONEncoder().encode(rules)
        print(Date(), "Rules encoded into Apple JSON")

        let ruleList = String(data: jsonData, encoding: .utf8)
        print(Date(), "Apple JSON encoded as string")

        let group = DispatchGroup()
        let startDate = Date()
        var compilationError: Error?

        group.enter()
        print(Date(), "Compilation starting...")
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "any",
            encodedContentRuleList: ruleList,
            completionHandler: { list, error in

                let time = Date().timeIntervalSince(startDate)
                print(Date(), "Compilation finished in \(time)s")
                compilationError = error

                group.leave()
        })

        group.wait()
        if let error = compilationError {
            throw error
        }

        print(Date(), "Compilation success")
    }
}

if #available(OSX 10.13, *) {
    Validator   .main()
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

