# Release setup

`.github/workflows/release.yml` provides continuous delivery: every `v*` tag produces versioned Android and iOS artifacts and attaches them to a GitHub Release.

Android CI and release jobs select Temurin JDK 17 and set Flutter's `jdk-dir` explicitly, matching the verified local toolchain and Gradle 8.14 runtime compatibility. This also overrides automatic selection of Android Studio's bundled JDK when the hosted image changes. See the [Gradle compatibility matrix](https://docs.gradle.org/current/userguide/compatibility.html).

## Android signing secrets

Add these repository secrets in GitHub before publishing a store-ready Android bundle:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

Without those secrets, CI still creates an unsigned Android artifact for verification; it cannot be uploaded to Google Play.

## iOS signing

CI builds iOS with `--no-codesign`. App Store delivery additionally needs an Apple Developer account, an App Store Connect app, distribution certificates, and a provisioning profile. Add automatic signing only after the organization owns those credentials.

## Create a release

After the pull request is merged and `main` is green:

```bash
git switch main
git pull --ff-only
git tag v1.0.0
git push origin v1.0.0
```

Never put signing credentials in the repository.

## Reset-link domain association

Android declares the exact HTTPS reset-password destination with App Links verification. iOS declares `applinks:myoccasio.ca` in the existing Runner entitlements. These project settings prepare routing; they do not prove that the production domain is associated.

Before release, the website must serve `/.well-known/assetlinks.json` containing the actual release certificate SHA-256 fingerprint(s) for `ca.occasiotech.myoccasio`, and `/.well-known/apple-app-site-association` containing the organization's real Apple Team ID plus that bundle ID and the reset-password path. Use the Play App Signing certificate where applicable. Never substitute a temporary debug certificate or invented Team ID. Verify installed, signed Android/iOS builds against those live files. Until then, the recovery screen accepts an explicitly pasted trusted email link; custom-scheme routing is also configured.

The separate Google authentication callback is `ca.occasiotech.myoccasio.auth://callback`. It carries only a short-lived PKCE-bound code and state, and does not depend on reset-link domain association. Live Google sign-in additionally requires the reviewed native-auth backend migration/deployment and its default-off feature flag to be enabled. Apple sign-in and remote push require organization-owned provider configuration; local deadline reminders work independently.

## Native service acceptance

Run the notification/system-browser bridge check on an isolated emulator or device:

```bash
flutter test integration_test/device_services_test.dart -d <device>
```

It uses no production account and checks actual native scheduling/replacement/cancellation and invalid-browser-URL rejection. It cancels the test installation's reminders, so use a dedicated test device. Notification delivery timing, permission dialogs, reboot restoration, HTTPS reset-link association, Google consent/cancellation, screen-reader navigation and iOS runtime still require signed-device acceptance. Run normal Android builds after integration tests and remove any private test defines before distributing artifacts.

An additional opt-in bridge check uses `--dart-define=VERIFY_NATIVE_BROWSER_CALLBACK=true`. When its test-only `NATIVE_BROWSER_CALLBACK_READY` marker appears, return the public fixture URI `ca.occasiotech.myoccasio.auth://callback?code=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&state=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA` through the isolated device's browser/ADB. Inspect tasks to confirm one MainActivity instance and the original Future's exact callback. This fixture never exchanges a code or creates a session. It complements, and cannot replace, deployed Google consent acceptance.

## Native branding

Launcher icons and light/dark splash screens use the existing MyOccasio key mark. The source SVG was copied from the website repository's `public/logo.svg`; it is not a new logo. Regenerate native assets after an approved source change:

```bash
flutter test tool/render_brand_test.dart
dart run tool/update_native_icons.dart
flutter test test/app/native_assets_test.dart
```

The export keeps the master icon at 1024 pixels, creates density-specific splash marks, and the icon generator removes the iOS alpha channel. Commit regenerated assets with their source. The generator is a development dependency; these commands do not sign or publish either app.

The wrapper preserves the existing Xcode project: AppIcon is already registered, and generator version 0.14.4 otherwise overwrites a Swift asset-symbol boolean with the icon name.
