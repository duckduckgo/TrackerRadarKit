//
//  File.swift
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

class ArrayExtensionTests: XCTestCase {

    func testRemoveDuplicates_noDuplicates() {
        let array = Array(1...10)
        let deduplicated = array.removeDuplicates()

        XCTAssertEqual(array, deduplicated)
    }

    func testRemoveDuplicates_duplicates() {
        let array = Array(1...100) + Array(1...100)
        let deduplicated = array.removeDuplicates()

        XCTAssertEqual(array.count, 200)
        XCTAssertEqual(deduplicated.count, 100)
        XCTAssertEqual(deduplicated, Array(1...100))
    }

    func testPrefixAll() {
        let strings = ["World"]
        let prefixed = strings.prefixAll(with: "👋 Hello ")

        XCTAssertEqual(prefixed, ["👋 Hello World"])
    }

    func testWildcards() {
        let strings = ["a", "b", "c"]
        let wildcards = strings.wildcards()

        XCTAssertEqual(wildcards, ["*a", "*b", "*c"])
    }

    func testMapResources() {
        let resources = [
            "script",
            "xmlhttprequest",
            "subdocument",
            "image",
            "stylesheet",
            "invalid-resource-type"
        ]

        let mapped = resources.mapResources()

        XCTAssertEqual(mapped, [.script, .raw, .document, .image, .stylesheet])
    }

}
