//
//  ContentBlockerRulesBuilder.swift
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

public struct ContentBlockerRulesBuilder: Sendable {

    struct Constants {
        // in the scheme .* overmatches and "OR" does not work
        static let subDomainPrefix = "^(https?)?(wss?)?://([a-z0-9-]+\\.)*"
        static let domainMatchSuffix = "(:?[0-9]+)?/.*"
    }
    
    public static let resourceMapping: [String: ContentBlockerRule.Trigger.ResourceType] = [
        "script": .script,
        "xmlhttprequest": .raw,
        "subdocument": .document,
        "image": .image,
        "stylesheet": .stylesheet
    ]
    
    let trackerData: TrackerData

    public init(trackerData: TrackerData) {
        self.trackerData = trackerData
    }
    
    /// Build all the rules for the given tracker data and list of exceptions.
    ///
    /// - Parameters:
    ///   - exceptions: A list of domains. TrackerData rules will be ignored when visiting these.
    ///   - tempUnprotectedDomains: A list of wildcard-matching domains. TrackerData rules will be ignored when visiting these.
    ///   - trackerAllowlist: A list of tracker rules to be excluded from the rules list
    ///
    /// - Returns: A list of ContentBlockerRule items. This list can be encoded and then used to compile a WKContentRuleListStore content rule list.
    
    public func buildRules(withExceptions exceptions: [String]? = nil,
                           andTemporaryUnprotectedDomains tempUnprotectedDomains: [String]? = nil,
                           andTrackerAllowlist trackerAllowlist: [TrackerException] = []) -> [ContentBlockerRule] {
        
        let trackerRules = trackerData.trackers.values.compactMap {
            buildRules(from: $0, loadTypes: [ .thirdParty ])
        }.flatMap { $0 }
        
        var cnameTrackers = [KnownTracker]()

        trackerData.cnames?.forEach { key, value in
            guard let knownTracker = trackerData.findTracker(byCname: value) else { return }
            let newTracker = knownTracker.copy(withNewDomain: key)
            cnameTrackers.append(newTracker)
        }

        let cnameRules = cnameTrackers.map { buildRules(from: $0, loadTypes: [.firstParty, .thirdParty]) }.flatMap { $0 }

        return trackerRules + cnameRules + buildExceptions(from: exceptions,
                                                           unprotectedDomains: tempUnprotectedDomains,
                                                           trackerAllowlist: trackerAllowlist,
                                                           loadTypes: [ .firstParty, .thirdParty ])
    }
    
    /// Build the rules for a specific tracker.
    public func buildRules(from tracker: KnownTracker, loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> [ContentBlockerRule] {
        
        let blockingRules: [ContentBlockerRule] = buildBlockingRules(from: tracker, loadTypes: loadTypes)
        
        let specialRules = tracker.rules?.compactMap { r -> [ContentBlockerRule] in
            buildRules(fromRule: r, inTracker: tracker, loadTypes: loadTypes)
            } ?? []
        
        let sortedRules = specialRules.sorted(by: { $0.count > $1.count })
        
        let dedupedRules = sortedRules.flatMap { $0 }.removeDuplicates()
        
        return blockingRules + dedupedRules
    }

    static public func buildRule(trigger: ContentBlockerRule.Trigger, withAction action: ContentBlockerRule.Action) -> ContentBlockerRule {
        return ContentBlockerRule(trigger: trigger, action: action)
    }

    static public func makeRegexpFilter(fromAllowlistRule rule: String) -> String {
        var rule = rule
        let index = rule.firstIndex(of: "/")
        if let index = index {
            rule.insert(contentsOf: "(:[0-9]+)?", at: index)
        }

        return Constants.subDomainPrefix + rule.regexEscape() + ".*"
    }
    
    private func buildExceptions(from exceptions: [String]?,
                                 unprotectedDomains: [String]?,
                                 trackerAllowlist: [TrackerException],
                                 loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> [ContentBlockerRule] {
        let domainExceptions = (exceptions ?? []) + (unprotectedDomains?.wildcards() ?? [])

        let result: [ContentBlockerRule]
        if domainExceptions.isEmpty {
            result = []
        } else {
            result = [ContentBlockerRule(trigger: .trigger(urlFilter: ".*", ifDomain: domainExceptions,
                                                           resourceType: nil, loadTypes: loadTypes),
                                         action: .ignorePreviousRules())]
        }

        let allowlistRules: [ContentBlockerRule] = trackerAllowlist.compactMap { exception in

            let urlFilter = Self.makeRegexpFilter(fromAllowlistRule: exception.rule)

            switch exception.matching {
            case .all:
                return ContentBlockerRule(trigger: .trigger(urlFilter: urlFilter, loadTypes: loadTypes),
                                   action: .ignorePreviousRules())
            case .domains(let domains):
                return ContentBlockerRule(trigger: .trigger(urlFilter: urlFilter, ifDomain: domains.wildcards(),
                                                            resourceType: nil, loadTypes: loadTypes),
                                   action: .ignorePreviousRules())
            case .none:
                return nil
            }
        }

        return result + allowlistRules
    }
    
    private func buildBlockingRules(from tracker: KnownTracker, loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> [ContentBlockerRule] {
        guard tracker.defaultAction == .block else { return [] }
        guard let domain = tracker.domain else { return [] }
        let urlFilter = Constants.subDomainPrefix + domain.regexEscape() + Constants.domainMatchSuffix
        return [ ContentBlockerRule(trigger: .trigger(urlFilter: urlFilter,
                                                      unlessDomain: trackerData.relatedDomains(for: tracker.owner)?.wildcards(),
                                                      loadTypes: loadTypes),
                                    action: .block()),
                 ContentBlockerRule(trigger: .trigger(urlFilter: urlFilter,
                                                      resourceType: [.popup],
                                                      loadTypes: loadTypes,
                                                      loadContext: [.topFrame]),
                                    action: .ignorePreviousRules())
        ]
    }

    private func buildRules(fromRule r: KnownTracker.Rule,
                            inTracker tracker: KnownTracker,
                            loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> [ContentBlockerRule] {
        
        return tracker.defaultAction == .block ?
            buildRulesForBlockingTracker(fromRule: r, inTracker: tracker, loadTypes: loadTypes) :
            buildRulesForIgnoringTracker(fromRule: r, inTracker: tracker, loadTypes: loadTypes)
    }
    
    private func buildRulesForIgnoringTracker(fromRule r: KnownTracker.Rule,
                                              inTracker tracker: KnownTracker,
                                              loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> [ContentBlockerRule] {
        if r.action == .some(.ignore) {
            return [
                block(r, withOwner: tracker.owner, loadTypes: loadTypes),
                ignorePrevious(r, matching: r.options, loadTypes: loadTypes)
            ]
        } else if r.options == nil && r.exceptions == nil {
            return [
                block(r, withOwner: tracker.owner, loadTypes: loadTypes),
                ignorePrevious(r, resourceTypes: [.popup], loadTypes: loadTypes, loadContext: [.topFrame])
            ]
        } else if r.exceptions != nil && r.options != nil {
            return [
                block(r, withOwner: tracker.owner, matching: r.options, loadTypes: loadTypes),
                ignorePrevious(r, matching: r.exceptions, loadTypes: loadTypes)
            ]
        } else if r.options != nil {
            return [
                block(r, withOwner: tracker.owner, matching: r.options, loadTypes: loadTypes)
            ]
        } else if r.exceptions != nil {
            return [
                block(r, withOwner: tracker.owner, loadTypes: loadTypes),
                ignorePrevious(r, matching: r.exceptions, loadTypes: loadTypes)
            ]
        }
        
        return []
    }
    
    private func buildRulesForBlockingTracker(fromRule r: KnownTracker.Rule,
                                              inTracker tracker: KnownTracker,
                                              loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> [ContentBlockerRule] {
        
        if r.options != nil && r.exceptions != nil {
            return [
                ignorePrevious(r, loadTypes: loadTypes),
                block(r, withOwner: tracker.owner, matching: r.options, loadTypes: loadTypes),
                ignorePrevious(r, matching: r.exceptions, loadTypes: loadTypes)
            ]
        } else if r.action == .some(.ignore) {
            return [
                ignorePrevious(r, matching: r.options, loadTypes: loadTypes)
            ]
        } else if r.options != nil {
            return [
                ignorePrevious(r, loadTypes: loadTypes),
                block(r, withOwner: tracker.owner, matching: r.options, loadTypes: loadTypes)
            ]
        } else if r.exceptions != nil {
            return [
                ignorePrevious(r, matching: r.exceptions, loadTypes: loadTypes)
            ]
        } else {
            return [
                block(r, withOwner: tracker.owner, loadTypes: loadTypes)
            ]
        }
    }
    
    private func block(_ rule: KnownTracker.Rule,
                       withOwner owner: KnownTracker.Owner?,
                       matching: KnownTracker.Rule.Matching? = nil,
                       loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> ContentBlockerRule {
        
        if let matching = matching {
            return ContentBlockerRule(trigger: .trigger(urlFilter: rule.normalizedRule(),
                                                        ifDomain: matching.domains?.prefixAll(with: "*"),
                                                        resourceType: matching.types?.mapResources()),
                                      action: .block())
            
        } else {
            return ContentBlockerRule(trigger: .trigger(urlFilter: rule.normalizedRule(),
                                                        unlessDomain: trackerData.relatedDomains(for: owner)?.wildcards(),
                                                        loadTypes: loadTypes),
                                      action: .block())
        }
    }
    
    private func ignorePrevious(_ rule: KnownTracker.Rule, matching: KnownTracker.Rule.Matching? = nil,
                                loadTypes: [ContentBlockerRule.Trigger.LoadType]) -> ContentBlockerRule {
        return ContentBlockerRule(trigger: .trigger(urlFilter: rule.normalizedRule(),
                                                    ifDomain: matching?.domains?.prefixAll(with: "*"),
                                                    resourceType: matching?.types?.mapResources(),
                                                    loadTypes: loadTypes),
                                  action: .ignorePreviousRules())
    }

    private func ignorePrevious(_ rule: KnownTracker.Rule, matching: KnownTracker.Rule.Matching? = nil,
                                resourceTypes: [ContentBlockerRule.Trigger.ResourceType], loadTypes: [ContentBlockerRule.Trigger.LoadType],
                                loadContext: [ContentBlockerRule.Trigger.LoadContext]) -> ContentBlockerRule {
        return ContentBlockerRule(trigger: .trigger(urlFilter: rule.normalizedRule(),
                                                    ifDomain: matching?.domains?.prefixAll(with: "*"),
                                                    resourceType: resourceTypes,
                                                    loadTypes: loadTypes,
                                                    loadContext: loadContext),
                                  action: .ignorePreviousRules())
    }

}

fileprivate extension String {
    
    func regexEscape() -> String {
        return replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "/", with: "\\/")
    }
    
}

fileprivate extension KnownTracker.Rule {
    
    func normalizedRule() -> String {
        guard !rule!.hasPrefix("http") else { return rule! }
        return ContentBlockerRulesBuilder.Constants.subDomainPrefix + rule!
    }
    
}
