# SideStore updates

## On your iPhone

1. With SideStore installed, open the [QM Intake download page](https://erickolb.github.io/QuartermasterIntake/) in Safari and tap **Add to SideStore**. Confirm adding the source in SideStore.
2. Alternatively, open SideStore's Sources screen and add `https://erickolb.github.io/QuartermasterIntake/apps.json` manually.
3. Open the QM Intake listing in that source and install or update it using the same Apple account as your existing installation. If your locally imported copy is not recognized as coming from the source, install from this listing over the existing app. Do not delete QM Intake first: deletion removes saved drafts and may require credentials to be provisioned again.
4. Confirm QM Intake opens and **Settings → Save and test connection** succeeds. If credentials are requested, use the existing privately issued device credentials or have a new registration issued.

Future published iOS versions appear through this source in SideStore. Check My Apps for updates and apply them there. Refreshing the signing period is separate from installing a new app version; keep your existing SideStore refresh setup. Source publication does not guarantee unattended installation.

## Publishing and recovery

The private Quartermaster repository still builds and publishes `QM-Intake.ipa`. No source code or private credentials are added to this public repository.

The **Publish download page** workflow regenerates `apps.json` as part of every Pages deployment. It runs on `main` pushes, manually, and when an `ios-v` release is published, edited, deleted, or unpublished. Checkout always uses `main`, not the release tag. Android release events are ignored. The existing cross-repository release token triggers the release event; a release created using this repository's own `GITHUB_TOKEN` would require a manual Pages workflow run because GitHub suppresses recursive workflow triggers.

Publish stable releases with tags `ios-vVERSION-buildNUMBER` and asset name `QM-Intake.ipa`. Upload assets before publishing (create a draft, attach the IPA and checksum, then publish). The generator reads every page of releases, excludes drafts, prereleases, and Android, orders versions numerically, and keeps the highest build per marketing version. It downloads each selected IPA to validate its bundle ID, version, build, size, minimum iOS version, and privacy descriptions. Missing or mismatched assets fail deployment, preserving the previously deployed site.

The source uses the Classic format without marketplace or build-version fields for SideStore compatibility. **Increase the marketing version for each user-visible update**; rebuilding an unchanged marketing version updates its download but may not produce an update prompt on devices already running that version. The current ad-hoc IPA has no custom entitlements or extensions. If either is added, review the source generator's permissions before publishing.

To recover a failed deployment or refresh an existing release, correct the release assets, then run **Actions → Publish download page → Run workflow → main**. No extra secrets, webhook, Connect account, or server/container update is needed. Confirm the deployed [source JSON](https://erickolb.github.io/QuartermasterIntake/apps.json) lists the intended version. `docs/apps.json` is generated into the deployment artifact and is not committed.

Local verification (Python 3.12 or newer, standard library only):

```sh
python -m unittest discover -s scripts -p 'test_*.py'
python scripts/sidestore_source.py
```

The second command requires internet access and optionally uses `GH_TOKEN` for GitHub API rate limits. It never sends that token to IPA download URLs.
