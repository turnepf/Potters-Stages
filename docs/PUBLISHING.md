# Publishing Potter's Stages (TestFlight / App Store)

**Read this before shipping any TestFlight or App Store build.**

## Why this matters: iCloud has two separate databases

The app syncs through the CloudKit container `iCloud.net.patrickturner.pottersstages`.
Every CloudKit container has **two separate environments**:

| Build | Uses environment |
|---|---|
| Builds installed from Xcode / `xcodebuild` (Debug, development signing) | **Development** |
| TestFlight and App Store builds (distribution signing) | **Production** |

They do not share data. **All of Patrick's real pieces currently live in Development**,
because every build so far has been a development build. A TestFlight or App Store build
starts with an **empty** Production database and will not show those pieces.

## Before the first TestFlight / App Store build

1. **Deploy the schema to Production.**
   - Open a development build on a device and use every feature once, so the Development
     schema has every record type and field (`CD_Piece`, `CD_Photo`, including `fingerprint`).
   - Go to the CloudKit Console (https://icloud.developer.apple.com) → container
     `iCloud.net.patrickturner.pottersstages` → **Deploy Schema Changes…** → deploy to Production.
   - Do this again whenever the model in `Shared/Piece.swift` gains fields. Production schemas
     can only be added to, never changed or removed, so plan model changes carefully.

2. **Move the existing pieces from Development to Production.** This needs one-time code
   that **doesn't exist yet**. A build can only reach one environment, so the likely approach
   is an Export (to a file) in a development build plus an Import in the production build.
   Don't delete the app from any device until this is done and checked.

3. **Check the signing entitlements on the archive.** With automatic signing, distribution
   builds should get `aps-environment = production` and the iCloud container environment
   set to Production. Confirm with
   `codesign -d --entitlements - <PottersStages.app>` on the exported app.

4. **App Store Connect basics.** The app collects no data and has no server, so the privacy
   label is "Data Not Collected". Add a privacy manifest (`PrivacyInfo.xcprivacy`) if Xcode's
   archive validation asks for one.

## Things that are safe today

- Deleting and reinstalling the **development** build: data comes back from iCloud
  (tested 2026-10-17: a fresh Mac install pulled down 56 pieces and 74 photos).
- Development data isn't reset automatically. It's only erased if someone clicks
  **Reset Development Environment** in the CloudKit Console, so **never click that** while
  the real pieces still live there.
