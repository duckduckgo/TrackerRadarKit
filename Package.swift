// swift-tools-version:5.3
//
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
//

import PackageDescription

let package = Package(
    name: "TrackerRadarKit",
    products: [
        .executable(name: "validator", targets: ["Validator"]),
        .library(
            name: "TrackerRadarKit",
            targets: ["TrackerRadarKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.2.0"))
    ],
    targets: [
        .target(
            name: "TrackerRadarKit",
            dependencies: []),
        .target(
            name: "Validator",
            dependencies:
                [
                    "TrackerRadarKit",
                    .product(name: "ArgumentParser", package: "swift-argument-parser")
                ]),
        .testTarget(
            name: "TrackerRadarKitTests",
            dependencies: ["TrackerRadarKit"],
            resources: [
                .process("Resources/trackerData.json"),
                .process("Resources/mockTrackerData.json")
            ])
    ]
)
