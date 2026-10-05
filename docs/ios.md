# QM Intake for iOS

Native camera-first intake client for iOS 17 or newer. Uses the same authenticated Quartermaster `/v1` API as Android. Requires Quartermaster β-001 or later for consumables. App version 0.2.0; initial iOS build 1.

## Install with SideStore

Download `QM-Intake.ipa` from the repository's **iOS release**, then import it into your existing SideStore installation. SideStore signs the package for your device. This app contains no extensions and needs one app ID. Refresh it through SideStore before its signing period expires, using the same Apple account and app identity to preserve access to saved credentials.

Open Settings and enter the HTTPS server origin, device ID, and one-time secret issued privately for this phone. Tap **Save and test connection**. Register the iPhone separately from Android. On astralplane:

```sh
cd ~/Quartermaster
sudo docker compose exec quartermaster node scripts/devices.mjs add 'QM Intake - iPhone'
```

The existing Caddy `/v1` routing and `ENABLE_INVENTORY_SERVICE=true` setup are required. The client never uses the unauthenticated browser API. Credentials are kept in the device-only, unlocked Keychain; they are not included in the source or IPA. Network redirects are refused to protect credentials.

## Intake and recovery

Create Item → camera → Review photo → Use photo → description, quantity, Consumable, location, optional notes and comma-separated tags → Submit Item. Photos are oriented and converted to metadata-free JPEGs at a maximum of 1600 pixels per side. Camera access is requested; photo-library access is not needed. Location choices show full hierarchical paths; suggestions use tags currently attached to inventory items.

Draft fields and photos remain in private, protected app storage, excluded from backups. Successful intake or explicit discard removes them. A draft is bound to the original server and device. After an uncertain item POST, check the web inventory, then choose **item was created** or **item is missing**. Creation is not idempotent; the app never automatically retries an item POST. Photos are reuploaded for explicit retries, including recovered drafts older than the server's 24-hour upload expiry.

Uninstalling the app removes drafts. Reinstalling or changing the signing identity can require entering device credentials again. Keep the one-time secret privately or issue a new device registration.

Builds are maintained in the private Quartermaster repository. This public repository distributes the compiled app and installation guide.
