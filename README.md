# TrackerRadarKit

## We are hiring!

DuckDuckGo is growing fast and we continue to expand our fully distributed team. We embrace diverse perspectives, and seek out passionate, self-motivated people, committed to our shared vision of raising the standard of trust online. If you are a senior software engineer capable in either iOS or Android, visit our [careers](https://duckduckgo.com/hiring/#open) page to find out more about our openings!

## Building

`TrackerRadarKit` has one explicit dependency (https://github.com/apple/swift-argument-parser) that is automatically resolved when installing the swift package in Xcode. It can be added to an Xcode project as a swift package dependency or be used as an imported Swift package.

It can be built manually two ways:

1. Build the  `TrackerRadarKit` scheme by opening the Swift package in Xcode
2. Run `swift build -c release` to build a release binary

### SwiftLint

We use [SwiftLint](https://github.com/realm/SwiftLint) for enforcing Swift style and conventions, so you'll need to [install it](https://github.com/realm/SwiftLint#installation).

### Validator

The Validator tool can be used to validate that Tracker Radar data can be parsed, transformed and compiled by WebKit's content rule list store.   As such, it requires macos 10.13 to run.

To build, check out the code and run from the project root:
* `swift build`

To run, execute the following from the project root:
* `.build/debug/Validator`

## Installation

We recommend the use of [Swift Package Manager](https://www.swift.org/package-manager/) 

## How to block trackers

In order to block content on the web view you need to [compile](https://developer.apple.com/documentation/webkit/wkcontentruleliststore/2902761-compilecontentrulelist/) a content rule list using  Apple's [WKContentRuleListStore](https://developer.apple.com/documentation/webkit/wkcontentruleliststore). 
TrackerRadarKit allows you to generate this list using DuckDuckGo's [Tracker Radar](https://github.com/duckduckgo/tracker-radar) as source.
The main structs you'll need to use to create a content rule lists are:

* [TrackerData](https://github.com/duckduckgo/TrackerRadarKit/blob/main/Sources/TrackerRadarKit/TrackerData.swift) -  Tracker Radar [JSON file](http://staticcdn.duckduckgo.com/trackerblocking/v2.1/tds.json) encoded format;

* [ContentBlockerRulesBuilder](https://github.com/duckduckgo/TrackerRadarKit/blob/main/Sources/TrackerRadarKit/ContentBlockerRulesBuilder.swift) - uses  TrackerData to generate a list of [ContentBlockerRules](https://github.com/duckduckgo/TrackerRadarKit/blob/main/Sources/TrackerRadarKit/ContentBlockerRule.swift) which can be encoded as a JSON source for the new rule list. To find more about the content rule list specifications, please visit [Apple's documentation](https://developer.apple.com/documentation/safariservices/creating_a_content_blocker).

### Example
```swift
let trackerData: TrackerData = ...
let allowList: [String] = ...

let blockerBuilder = ContentBlockerRulesBuilder(trackerData: trackerData)
let rules = blockerBuilder.buildRules(withExceptions: allowList)

let data: Data

do {
    data = try JSONEncoder().encode(rules)
} catch {
    // Handle Error
}

let ruleList = String(data: data, encoding: .utf8)!

WKContentRuleListStore.default()
    .compileContentRuleList(forIdentifier: settings.ruleListIdentifier,
                            encodedContentRuleList: ruleList) { list, error in
    
        // return WKContentRuleList or error
    }
```


## License

DuckDuckGo is distributed under the Apache 2.0 [license](https://github.com/duckduckgo/ios/blob/master/LICENSE).
