# Potter's Stages

A simple native app (iPhone, iPad, Mac) for tracking pottery pieces through
Idea → Leather Hard → Greenware → Bisqueware → Finished. Data is stored with SwiftData
and syncs through the user's private iCloud (CloudKit). There's no server.

On the App Store: <https://apps.apple.com/app/potters-stages/id6824291888>

> **Before publishing to TestFlight or the App Store, read [docs/PUBLISHING.md](docs/PUBLISHING.md).**
> Development and production iCloud are separate databases, and all current data is in development.

## Building

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate          # after editing project.yml; commit both files
open PottersStages.xcodeproj
```

- Team `NQ6AJVVBBJ`, bundle ID `net.patrickturner.pottersstages`
- App Group `group.net.patrickturner.pottersstages` (shared with the share extension)
- iCloud container `iCloud.net.patrickturner.pottersstages`

## Layout

- `Shared/`: the model (`Piece`, `Photo`), stages, image helpers, and the store setup, used by both targets
- `App/`: the main app's screens
- `ShareExtension/`: the share sheet (new piece or add to an existing one)
- `UITests/`: a simulator walkthrough (`xcodebuild test`)
