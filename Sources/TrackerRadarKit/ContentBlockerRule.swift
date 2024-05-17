//
//  ContentBlockerRule.swift
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
import os

// swiftlint:disable nesting
public struct ContentBlockerRule: Codable, Hashable {

    public struct Trigger: Codable, Hashable {

        public enum ResourceType: String, Codable, CaseIterable {

            case document
            case image
            case stylesheet = "style-sheet"
            case script
            case font
            case raw
            case svg = "svg-document"
            case media
            case popup

        }
        
        public enum LoadType: String, Codable {
         
            case thirdParty = "third-party"
            case firstParty = "first-party"
            
        }

        public enum LoadContext: String, Codable {
            case topFrame = "top-frame"
            case childFrame = "child-frame"
        }

        let urlFilter: String
        let unlessDomain: [String]?
        let ifDomain: [String]?
        let resourceType: [ResourceType]?
        let loadType: [LoadType]?
        let loadContext: [LoadContext]?

        enum CodingKeys: String, CodingKey {
            case urlFilter = "url-filter"
            case unlessDomain = "unless-domain"
            case ifDomain = "if-domain"
            case resourceType = "resource-type"
            case loadType = "load-type"
            case loadContext = "load-context"
        }

        private init(urlFilter: String, unlessDomain: [String]?, ifDomain: [String]?, 
                     resourceType: [ResourceType]?, loadType: [LoadType]?, loadContext: [LoadContext]?) {
            self.urlFilter = urlFilter
            self.unlessDomain = unlessDomain
            self.ifDomain = ifDomain
            self.resourceType = resourceType
            self.loadType = loadType
            self.loadContext = loadContext
        }

        public static func trigger(onDomain domain: String) -> Trigger {
            return Trigger(urlFilter: ContentBlockerRulesBuilder.Constants.subDomainPrefix
                           + domain.replacingOccurrences(of: ".", with: "\\.")
                           + ContentBlockerRulesBuilder.Constants.domainMatchSuffix,
                           unlessDomain: nil, ifDomain: nil, resourceType: nil, loadType: nil, loadContext: nil)
        }

        public static func trigger(urlFilter filter: String, loadTypes: [LoadType]? = [ .thirdParty ]) -> Trigger {
            return Trigger(urlFilter: filter, unlessDomain: nil, ifDomain: nil, resourceType: nil, loadType: loadTypes, loadContext: nil)
        }
        
        public static func trigger(urlFilter filter: String, unlessDomain urls: [String]?, loadTypes: [LoadType]? = [ .thirdParty ] ) -> Trigger {
            return Trigger(urlFilter: filter, unlessDomain: urls, ifDomain: nil, resourceType: nil, loadType: loadTypes, loadContext: nil)
        }

        public static func trigger(urlFilter filter: String, resourceType types: [ResourceType]?, loadTypes: [LoadType]?, loadContext: [LoadContext]?) -> Trigger {
            return Trigger(urlFilter: filter, unlessDomain: nil, ifDomain: nil, resourceType: types, loadType: loadTypes, loadContext: loadContext)
        }

        public static func trigger(urlFilter filter: String, ifDomain domains: [String]?, resourceType types: [ResourceType]?) -> Trigger {
            return Trigger(urlFilter: filter, unlessDomain: nil, ifDomain: domains, resourceType: types, loadType: [ .thirdParty ], loadContext: nil)
        }
        
        public static func trigger(urlFilter filter: String,
                                   ifDomain domains: [String]?,
                                   resourceType types: [ResourceType]?,
                                   loadTypes: [LoadType]? = [ .thirdParty ]) -> Trigger {
            return Trigger(urlFilter: filter, unlessDomain: nil, ifDomain: domains, resourceType: types, loadType: loadTypes, loadContext: nil)
        }
        
        public static func trigger(urlFilter filter: String,
                                   ifDomain domains: [String]?,
                                   resourceType types: [ResourceType]?,
                                   loadTypes: [LoadType]? = [ .thirdParty ],
                                   loadContext: [LoadContext]? = nil) -> Trigger {
            return Trigger(urlFilter: filter, unlessDomain: nil, ifDomain: domains,
                           resourceType: types, loadType: loadTypes, loadContext: loadContext)
        }
    }

    public struct Action: Codable, Hashable {
    
        public enum ActionType: String, Codable {
            
            case block
            case ignorePreviousRules = "ignore-previous-rules"
            case cssDisplayNone = "css-display-none"
            
        }
        
        public let type: ActionType
        public let selector: String?

        public static func block() -> Action {
            return Action(type: .block, selector: nil)
        }
        
        public static func ignorePreviousRules() -> Action {
            return Action(type: .ignorePreviousRules, selector: nil)
        }
        
        public static func cssDisplayNone(selector: String) -> Action {
            return Action(type: .cssDisplayNone, selector: selector)
        }
        
    }
    
    public let trigger: Trigger
    public let action: Action

    public func hash(into hasher: inout Hasher) {
        hasher.combine(trigger)
        hasher.combine(action)
    }

    public func matches(resourceUrl: URL, onPageWithUrl pageUrl: URL, ofType resourceType: Trigger.ResourceType?) -> Bool {
        guard unlessDomain(trigger.unlessDomain, pageUrl: pageUrl) else { return false }
        guard trigger.urlFilter.matches(resourceUrl.absoluteString) else { return false }
        guard ifDomain(trigger.ifDomain, pageUrl: pageUrl) else { return false }
        guard resourceTypes(trigger.resourceType, resourceType: resourceType) else { return false }
        return true
    }

    private func unlessDomain(_ domains: [String]?, pageUrl: URL) -> Bool {
        guard let domains = domains else { return true }
        guard let pageDomains = pageUrl.hostVariations else { return true }
        for pageDomain in pageDomains where domains.contains(where: { $0 == pageDomain || $0 == "*" + pageDomain }) {
            return false
        }
        return true
    }

    private func resourceTypes(_ triggerTypes: [Trigger.ResourceType]?, resourceType: Trigger.ResourceType?) -> Bool {
        guard let triggerTypes = triggerTypes else { return true }
        guard let resourceType = resourceType else { return false }
        return triggerTypes.contains(resourceType)
    }

    private func ifDomain(_ domains: [String]?, pageUrl: URL) -> Bool {
        guard let domains = domains else { return true }
        guard let pageDomains = pageUrl.hostVariations else { return false }
        for pageDomain in pageDomains where domains.contains(where: { $0 == pageDomain || $0 == "*" + pageDomain }) {
            return true
        }
        return false
    }

}
// swiftlint:enable nesting

extension String {

    func matches(_ string: String) -> Bool {
        // opt: memoize?
        guard let regex = try? NSRegularExpression(pattern: self, options: [ .caseInsensitive ]) else {
            return false
        }

        let matches = regex.matches(in: string, options: [ ], range: NSRange(location: 0, length: string.utf16.count))
        return !matches.isEmpty
    }

}
