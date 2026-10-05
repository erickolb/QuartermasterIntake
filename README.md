# QM Intake

Android and iOS applications for rapid intake into the private Chateau Lore Quartermaster application. They require privately provisioned credentials.

This repository contains the public download page, release artifacts, and the native iOS client source in `ios/`. The Quartermaster server source and credentials remain private.

For iOS installation through SideStore, building an IPA, and device enrollment, see [the iOS guide](ios/README.md). Download `QM-Intake.ipa` from the dedicated iOS release. The iOS app has no extensions.

Download page: https://erickolb.github.io/QuartermasterIntake/

## Releases

Publish signed APKs as GitHub release assets named `QM-Intake.apk`. Keep this filename consistent so the page's latest-release download link works. Increase the Android version code for each update and keep the same signing key. Publish iOS packages as `QM-Intake.ipa` on separate prereleases so Android's latest-release link continues to resolve to an APK.

## GitHub Pages

In repository Settings → Pages, set Source to GitHub Actions. The included workflow deploys `docs/` when `main` changes; it can also be run manually. Forward `intake.quartermaster.chateaulore.net` to the download page URL above. A forwarding address does not require a CNAME file here.

The Obtainium button uses the official Obtainium icon from https://github.com/ImranR98/Obtainium and its `obtainium://add/` link format.
