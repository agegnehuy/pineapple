# Native password reset

The app reuses the existing website contract without changing it:

- `POST /api/auth/forgot-password` with `{email}` requests an email. A successful response does not disclose whether that account exists.
- The existing email points to `https://myoccasio.ca/reset-password?token=…`.
- `POST /api/auth/reset-password` with `{token,password}` changes the password only after the user submits the native form. Success requires `{ok:true}`. The existing server returns 400 for an invalid or expired link and requires at least 8 UTF-16 code units in the password.

Tokens stay opaque to Flutter. The server verifies signature and expiry. The app does not persist tokens or passwords, place them in route names, automatically retry the password-changing request, automatically sign in, or claim that existing sessions were revoked. The current backend does not provide a separate token-validation endpoint or single-use/session-revocation guarantee.

Cold-start links wait for the initial session restoration before presenting a reset page. A running link pushes above the current editor so its draft remains intact. Repeated links are deduplicated; a different link waits until the current reset page closes. Later account boundaries discard reset routes and queued secrets. Pending requests block Back; unsaved password fields require an explicit discard. The autofill context is canceled when the form is discarded or removed, and only a confirmed successful password update requests saving the password. The screen supports large text, reduced-motion indicators, French, validation, retry, success and server-rejected links.

## Opening the reset page

The native custom URL is `ca.occasiotech.myoccasio://reset-password?token=…`. The distinct OAuth callback scheme `ca.occasiotech.myoccasio.auth://callback` is handled by the native authentication bridge rather than the reset flow.

Existing email links can also be pasted into the password-recovery screen with **Open reset link**. Pasting does not send another email or change a password. Only the exact trusted HTTPS host `myoccasio.ca`, the reset path and one bounded token are accepted; user-info, foreign hosts/ports, fragments and duplicate token parameters are rejected.

Android has a path-specific HTTPS intent filter. iOS has `applinks:myoccasio.ca` in Runner.entitlements, and Debug/Profile/Release reference that file while retaining the iOS 13 deployment target. These settings prepare the projects; they do not prove domain association.

Verified HTTPS email opening still requires production website configuration using the actual identities:

- Android: serve `/.well-known/assetlinks.json` for package `ca.occasiotech.myoccasio`, using the SHA-256 fingerprints of the real release/Play app-signing certificates.
- iOS: serve `/.well-known/apple-app-site-association` with the actual Apple TeamID and bundleID, allow only the intended reset path, and enable Associated Domains in the matching provisioning profile.

No fabricated TeamID, certificate fingerprint, private signing key or association success is included. Until those files and signed builds are verified, the custom scheme and explicit paste flow are available and existing email links can continue opening the website. iOS compilation and on-device association verification require macOS/Xcode.

## Verification

Focused tests are in `test/features/auth/password_reset_test.dart` and `test/features/auth/password_reset_navigation_test.dart`. They use local HTTP fixtures and test-only tokens; they must not send production reset emails or change a live password. Incoming route tests cover both legacy `pushRoute` and current `pushRouteInformation` messages through Flutter's built-in route delivery, without adding a routing plugin.
