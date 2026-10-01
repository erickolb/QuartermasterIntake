# QM Intake

Android application for rapid intake into the private Chateau Lore Quartermaster application. It will not work without privately provisioned credentials.

This repository contains only the public download page and release artifacts. Quartermaster source code and credentials remain private.

Download page: https://erickolb.github.io/QuartermasterIntake/

## Releases

Publish signed APKs as GitHub release assets named `QM-Intake.apk`. Keep this filename consistent so the page's latest-release download link works. Increase the Android version code for each update and keep the same signing key.

## GitHub Pages

In repository Settings → Pages, set Source to GitHub Actions. The included workflow deploys `docs/` when `main` changes; it can also be run manually. Forward `intake.quartermaster.chateaulore.net` to the download page URL above. A forwarding address does not require a CNAME file here.

The Obtainium button uses the official Obtainium icon from https://github.com/ImranR98/Obtainium and its `obtainium://add/` link format.
