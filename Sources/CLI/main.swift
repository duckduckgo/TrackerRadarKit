//
//  main.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import TrackerRadarKit

guard ProcessInfo().arguments.count == 2 else {
    print("Usage: trkcli <blocklist url>")
    exit(1)
}

let urlString = ProcessInfo().arguments[1]

guard let url = URL(string: urlString) else {
    print("Bad URL", urlString)
    exit(2)
}

let data = try Data(contentsOf: url)
let trackerData = try JSONDecoder().decode(TrackerData.self, from: data)
let builder = ContentBlockerRulesBuilder(trackerData: trackerData)
let rules = builder.buildRules()
print(rules.count, "rules")
