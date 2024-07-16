//
//  JSONTestDataLoader.swift
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

class JSONTestDataLoader {

    static var trackerData: Data {
        JSONTestDataLoader().fromJSONFile("trackerData")
    }

    static var mockTrackerData: Data {
        JSONTestDataLoader().fromJSONFile("mockTrackerData")
    }

    static var trackerDataWithCPM: Data {
        JSONTestDataLoader().fromJSONFile("cpm_tds")
    }

    static var trackerDataWithoutCPM: Data {
        JSONTestDataLoader().fromJSONFile("no_cpm_tds")
    }

    private var bundle: Bundle {
        Bundle.module
    }

    private func fromJSONFile(_ fileName: String) -> Data {
        guard let data = try? load(fileName: fileName, fileExtension: "json", fromBundle: bundle) else {
            fatalError("Unable to load \(fileName)")
        }

        return data
    }

    // MARK: - File Loading

    enum FileError: Error {
        case unknownFile
        case invalidFileContents
    }

    private func load(fileName: String, fileExtension: String, fromBundle bundle: Bundle) throws -> Data {
        guard let resourceURL = bundle.url(forResource: fileName, withExtension: fileExtension) else {
            throw FileError.unknownFile
        }

        guard let data = try? Data(contentsOf: resourceURL, options: [.mappedIfSafe]) else {
            throw FileError.invalidFileContents
        }

        return data
    }
}
