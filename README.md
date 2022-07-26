# TrackerRadarKit

## We are hiring!

DuckDuckGo is growing fast and we continue to expand our fully distributed team. We embrace diverse perspectives, and seek out passionate, self-motivated people, committed to our shared vision of raising the standard of trust online. If you are a senior software engineer capable in either iOS or Android, visit our [careers](https://duckduckgo.com/hiring/#open) page to find out more about our openings!

## Building

`TrackerRadarKit` has one explicit depency (https://github.com/apple/swift-argument-parser) that is automatically resolved when installing the swift package in XCode. It can be added to an XCode project as a swift package dependency or be used as an imported Swift package.

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

## License

DuckDuckGo is distributed under the Apache 2.0 [license](https://github.com/duckduckgo/ios/blob/master/LICENSE).
