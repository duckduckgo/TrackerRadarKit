//
//  ArrayExtension.swift
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

extension Array where Element: Hashable {

    func removeDuplicates() -> [Element] {
        let string = "string" as! NSString
        
        var existingElements = Set<Element>()
        return self.filter { existingElements.insert($0).inserted }
    }

}

extension Array where Element == String {

    func prefixAll(with prefix: String) -> [String] {
        return map { prefix + $0 }
    }

    func wildcards() -> [String] {
        return prefixAll(with: "*")
    }

    func mapResources() -> [ContentBlockerRule.Trigger.ResourceType] {
        return compactMap { ContentBlockerRulesBuilder.resourceMapping[$0] }
    }

}
