# QM Intake

Android and iOS applications for rapid intake into the private Chateau Lore Quartermaster application. They require privately provisioned credentials.

This repository contains only the public download page, installation guides, and compiled release artifacts. Both Android and iOS source and build automation are maintained in the private Quartermaster repository. No source is published here for new builds.

For iOS installation through SideStore and device enrollment, see [the iOS guide](docs/ios.md). Download `QM-Intake.ipa` from the dedicated iOS release. The iOS app has no extensions.

Download page: https://erickolb.github.io/QuartermasterIntake/

## Releases

Private Quartermaster workflows publish signed Android APKs as `QM-Intake.apk` and SideStore iOS packages as `QM-Intake.ipa`, with checksums and release notes. Keep these filenames consistent with the download page. Android remains Latest so the latest-release APK link works. iOS releases are regular releases explicitly published without the Latest label; the page links to a specific iOS release.

Release titles use `QM Intake VERSION for Android` and `QM Intake VERSION for iOS (build NUMBER)`. Increase the Android version code for updates and retain its signing key. Increase the iOS build number for each published IPA. Update the page's iOS link when a new build is released.

## GitHub Pages

In repository Settings → Pages, set Source to GitHub Actions. The included workflow deploys `docs/` when `main` changes; it can also be run manually. Forward `intake.quartermaster.chateaulore.net` to the download page URL above. A forwarding address does not require a CNAME file here.

The Obtainium button uses the official Obtainium icon from https://github.com/ImranR98/Obtainium and its `obtainium://add/` link format.
