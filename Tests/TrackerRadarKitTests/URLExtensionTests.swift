//
//  URLExtensionTests.swift
//  TrackerBlockerKit
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

import XCTest
@testable import TrackerRadarKit

class URLExtensionTests: XCTestCase {

    func testHostVariations_noVariations() {
        let variations = URL(string: "/")?.hostVariations
        XCTAssertNil(variations)
    }

    func testHostVariations_basicURL() {
        let variations = URL(string: "https://duckduckgo.com/")?.hostVariations
        XCTAssertEqual(variations, ["duckduckgo.com"])
    }

    func testHostVariations_singleSubdomain() {
        let variations = URL(string: "http://subdomain.example.com/index.html")?.hostVariations
        XCTAssertEqual(variations, ["subdomain.example.com", "example.com"])
    }

    func testHostVariations_multipleSubdomains() {
        let variations = URL(string: "http://three.two.one.example.com/index.html")?.hostVariations
        XCTAssertEqual(variations, [
            "three.two.one.example.com",
            "two.one.example.com",
            "one.example.com",
            "example.com"
        ])
    }

}
