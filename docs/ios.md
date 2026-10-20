# QM Intake for iOS

Native camera-first intake client for iOS 17 or newer. Uses the same authenticated Quartermaster `/v1` API as Android. App version 0.3.0, build 1. Expiration dates require Quartermaster 1.0.

## Install with SideStore

Open the [download page](https://erickolb.github.io/QuartermasterIntake/) in Safari on your iPhone, tap **Add to SideStore**, confirm the source, and install QM Intake from its listing. For an existing local IPA installation, use the same Apple account and install/update from the source without deleting the app first. See [SideStore updates](sidestore.md) for migration steps and future updates. Manual [IPA downloads](https://github.com/erickolb/QuartermasterIntake/releases/download/ios-v0.3.0-build1/QM-Intake.ipa) remain available. SideStore signs the package for your device. This app contains no extensions and needs one app ID. Refresh it through SideStore before its signing period expires, using the same Apple account and app identity to preserve access to saved credentials.

Open Settings and enter the HTTPS server origin, device ID, and one-time secret issued privately for this phone. Tap **Save and test connection**. Register the iPhone separately from Android. On astralplane:

```sh
cd ~/Quartermaster
sudo docker compose exec quartermaster node scripts/devices.mjs add 'QM Intake - iPhone'
```

The existing Caddy `/v1` routing and `ENABLE_INVENTORY_SERVICE=true` setup are required. The client never uses the unauthenticated browser API. Credentials are kept in the device-only, unlocked Keychain; they are not included in the source or IPA. Network redirects are refused to protect credentials.

## Intake and recovery

Create Item → camera → Review photo → Use photo → description, quantity, Consumable, location, optional expiration date, optional notes and comma-separated tags → Submit Item. Photos are oriented and converted to metadata-free JPEGs at a maximum of 1600 pixels per side. Camera access is requested; photo-library access is not needed. Location choices show full hierarchical paths; suggestions use tags currently attached to inventory items.

The expiration date picker is optional; use its × button to clear the date. The date is preserved in recovered drafts.

Draft fields and photos remain in private, protected app storage, excluded from backups. Successful intake or explicit discard removes them. A draft is bound to the original server and device. After an uncertain item POST, check the web inventory, then choose **item was created** or **item is missing**. Creation is not idempotent; the app never automatically retries an item POST. Photos are reuploaded for explicit retries, including recovered drafts older than the server's 24-hour upload expiry.

Uninstalling the app removes drafts. Reinstalling or changing the signing identity can require entering device credentials again. Keep the one-time secret privately or issue a new device registration.

Builds are maintained in the private Quartermaster repository. This public repository distributes the compiled app and installation guide.
