# Publishing Potter's Stages (TestFlight / App Store)

**Read this before shipping any TestFlight or App Store build.**

## Why this matters: iCloud has two separate databases

The app syncs through the CloudKit container `iCloud.net.patrickturner.pottersstages`.
Every CloudKit container has **two separate environments**:

| Build | Uses environment |
|---|---|
| Builds installed from Xcode / `xcodebuild` (Debug, development signing) | **Development** |
| TestFlight and App Store builds (distribution signing) | **Production** |

They do not share data. Until the move below is done, **Patrick's real pieces live in
Development**, because every build before 2026-10-18 was a development build.

## Going forward: straight to the App Store

From 2026-10-21 new builds go straight to the App Store. TestFlight is only used when Patrick
asks for it. Don't install Xcode builds on his devices: a development build replaces the
installed app and switches that device to the separate Development data. Use the Simulator
for quick checks instead.

## Status (2026-10-18)

- [x] App Store Connect record "Potter's Stages" (iOS + macOS), SKU `pottersstages01`.
- [x] CloudKit schema deployed to Production (`CD_Piece`, `CD_Photo`, `Users`).
- [x] Build 1.0 (1), iOS, uploaded. Entitlements checked: `aps-environment = production`,
      iCloud container environment `Production`, in the app and the share extension.
- [x] TestFlight internal group **Internal** with Patrick. Since 2026-10-21 it has automatic
      distribution off, so uploads don't reach TestFlight unless a build is added by hand.
      (The API can't turn that setting on or off, and Apple won't remove a build from a
      group while it's on. The group had to be deleted and recreated.)
- [ ] Move the pieces from Development to Production (below).
- [ ] macOS TestFlight build (needs its own archive; only iOS has been uploaded).

## Moving the pieces from Development to Production

Apple has no tool that copies data between the two environments, and a build can only reach
one of them, so the app has **More (⋯) → Export Backup… / Import Backup…** in the toolbar.
The backup is a single `.plist` file with every piece, its dates, link and full-size photos.

1. In the current **development** build on the iPhone, tap **Export Backup…** and save the
   file to iCloud Drive (e.g. Files → iCloud Drive → Downloads). Check the file's there and
   looks the right size before going on.
2. Delete the development app from the iPhone, so the TestFlight build starts with a clean
   local database. The pieces are still safe in Development iCloud and in the backup file.
3. Install the **TestFlight** build, open it (it'll be empty), tap **Import Backup…** and
   pick the file. It reports how many pieces and photos it added.
4. Check the pieces arrived in Production: **More (⋯)** shows which database the build uses
   ("iCloud: Production" in TestFlight), and **Check iCloud Sync** compares the number of
   pieces and photos in that iCloud database with the ones on the device. When they match,
   everything has uploaded.

A TestFlight build installed over the old development app keeps the old app's local copy,
so pieces can show on the phone without being in Production. **Check iCloud Sync** tells
the two apart; if iCloud shows fewer, export a backup, delete and reinstall the app, and
import the backup.

Importing the same file again skips pieces that are already there (same title and created
time), so a second try is harmless.

## Shipping a new build

1. For an App Store update, bump `MARKETING_VERSION` (e.g. 1.0.1). Always bump
   `CURRENT_PROJECT_VERSION` in `project.yml` (App Store Connect rejects a repeated
   build number for the same version), then `xcodegen generate`.
2. If `Shared/Piece.swift` gained fields, run a development build in the Simulator once so
   the Development schema picks them up, then CloudKit Console → container → **Deploy Schema
   Changes…** *before* uploading. Production schemas can only be added to, never changed or
   removed, so plan model changes carefully. (The link is in the sidebar, which hides behind
   **‹ Menu** in a narrow window. Never click **Reset Environment…** next to it.)
3. Archive and upload with the Admin App Store Connect API key in
   `~/.appstoreconnect/private_keys/` (Xcode isn't signed in to an Apple account on this Mac;
   the older non-Admin key can't do cloud signing):

   ```bash
   xcodebuild archive -project PottersStages.xcodeproj -scheme PottersStages \
     -destination 'generic/platform=iOS' -archivePath build/PottersStages.xcarchive \
     -allowProvisioningUpdates <api-key flags>
   xcodebuild -exportArchive -archivePath build/PottersStages.xcarchive \
     -exportPath build/upload -exportOptionsPlist <options.plist> \
     -allowProvisioningUpdates <api-key flags>
   ```

   The API-key flags are `-authenticationKeyPath`, `-authenticationKeyID` and
   `-authenticationKeyIssuerID`. The options plist sets `method` = `app-store-connect`,
   `destination` = `upload`, `teamID` = `NQ6AJVVBBJ`, `signingStyle` = `automatic`.
   Archive and upload `generic/platform=macOS` the same way: each platform is its own build.
4. Processing takes 10–30 minutes. Then, in App Store Connect (or the API), create the new
   App Store version for each platform, add the "What's New" text, attach the build and
   submit it for review. A platform can't get a new version while its previous one is still
   in review.

## Updating App Store screenshots

The 1.0 screenshots show Patrick's real pieces. Two simulators are kept for this, set to
App Store sizes; find them with `xcrun simctl list devices | grep Shots`:

| Simulator | Screenshot size | App Store slot |
|---|---|---|
| Shots iPhone 17 Pro Max (iOS 27.0) | 1320×2868 | iPhone 6.9″ |
| Shots iPad Pro 13 (iOS 27.0) | 2064×2752 | iPad 13″ |

1. Patrick exports a backup from the TestFlight app (⋯ → Export Backup…) and AirDrops it here.
2. Build the Debug app for the simulator, install it on both, and launch with
   `xcrun simctl launch <sim> net.patrickturner.pottersstages -screenshotBackup <backup file>`.
   Screenshot mode (Debug builds only) shows that backup from an in-memory store, with no
   iCloud and no Development banner. `xcrun simctl status_bar <sim> override --time 9:41
   --batteryState charged --batteryLevel 100` gives a clean status bar.
3. Capture with `xcrun simctl io <sim> screenshot <file>.png`. Leave out the Ideas tab: its
   saved posts are other people's content.
4. **Mac (1280×800):** make a separate copy of the Debug Mac build so the real Mac app is
   never touched. Change its `CFBundleIdentifier` to `net.patrickturner.pottersstages.screenshots`,
   delete `Contents/PlugIns`, run `codesign --force --deep -s -` on it, and launch it with the same
   `-screenshotBackup` argument. It opens at 1440×900. Capture the window and scale it to 1280×800.
5. Upload in App Store Connect (or through the API): iPhone 6.9″, iPad 13″ and Mac sets.

## App Store review basics

The app collects no data and has no server, so the privacy label is "Data Not Collected".
`Shared/PrivacyInfo.xcprivacy` declares no tracking and no required-reason APIs, and
`ITSAppUsesNonExemptEncryption = NO` answers the export-compliance question for every build.

## Things that are safe

- Deleting and reinstalling a build: data comes back from iCloud (tested 2026-10-17 on
  Development: a fresh Mac install pulled down 56 pieces and 74 photos).
- Development data isn't reset automatically. It's only erased if someone clicks
  **Reset Environment…** in the CloudKit Console, so **never click that** while the real
  pieces still live there.
