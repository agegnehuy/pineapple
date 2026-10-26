# Backend integration

The Flutter app reuses the existing Next.js production backend at `https://myoccasio.ca`. Production contracts were inspected in Occasio-Tech/MyOccasio at commit `6e2404f3d3d1921a166715aee48661b552fb5051`. The additive backend changes described below are committed in a separate local checkout; none has been pushed or deployed.

## Session flow

1. `GET /api/auth/csrf`
2. `POST /api/auth/callback/credentials` with email/password/CSRF
3. Persist returned cookies in Android Keystore/iOS Keychain through the existing secure cookie store
4. Confirm and restore with `GET /api/auth/session`
5. Send cookies on protected requests; clear local storage on sign-out even when remote sign-out fails

The public session endpoint returns HTTP 200 with an empty object when unauthenticated. Protected endpoints return 401. Network failure during restoration retains the saved session for an explicit retry. Only reads retry automatically; mutation failures preserve user input and require explicit retry.

The redesigned registration form collects a full name and retains the existing `/api/register` payload: the first whitespace-delimited part becomes `firstName` and all remaining parts become `lastName`, with repeated whitespace normalized. Unicode and compound surnames are preserved. A single-part name sends an empty last name, which the inspected API accepts; the app does not invent a surname. Email/password validation and the existing automatic sign-in after registration remain intact. The reference names and addresses are empty-field hints only.

## Feature repositories

| Repository | Existing backend routes |
| --- | --- |
| Auth | `/api/register`, `/api/auth/*`, `/api/auth/forgot-password`, `/api/auth/reset-password` |
| Profile | `/api/me`, `/api/profile/import` (text or multipart file, review before applying), `/api/profile` (résumé metadata), `/api/profile/resume` (authenticated upload/download/removal) |
| Opportunities | `/api/matches` |
| Applications | `/api/tracking`, `/api/tracking/[id]`, `/api/applications/[id]`, `/api/ai/application-draft/[id]` |
| Academics | `/api/academic`, `/api/grading-scales`, courses, assessments, goals, deadlines, degree and calculations subroutes |
| Coaching | `/api/ai/coach`, `/api/ai/uploads`, `/api/academic/story`, `/api/ai/story-draft`, `/api/academic/story/draft` |
| Community | `/api/community/posts`, wins, comments, likes, people, chat-requests, events and register subroutes |
| Settings | `/api/me/notifications`, `/api/activity`, `/api/subscription/state`, `/api/subscription/portal`, `/api/ai/credits`, `/api/me/account`, `/api/contact` |

Catalogue IDs in the match feed use `cat:`; application workspace/draft routes receive the underlying catalogue ID. Tracker records retain the original opportunity ID. The app respects server submission mode, account-plan denials, allowance failures and explicit consent. Uploads use the actual source limit of 4 MB; the older backend prose limit differs from its current parser.

Résumé metadata is in `GET /api/profile` under `profile.resumeName`, `resumeMimeType` and `resumeSize`; `/api/me` does not expose it. `POST /api/profile/resume` accepts multipart field `file` for a non-empty PDF/DOCX up to 4 MB and immediately replaces the saved file. `GET` returns private binary bytes with Content-Disposition/Content-Type; `DELETE` clears bytes and metadata. Downloads use authenticated bounded transport and the filename/type from the same response, then Android's system document destination picker or iOS's document export picker. No authenticated URL or cookie is passed to an external browser. Selected files require explicit save, replacements require confirmation, and ambiguous upload failures trigger metadata reconciliation. A profile résumé is separate from provider application attachments.

The production grading-scale response was inspected on October 23 and returned HTTP 200 with six CMS definitions. The GPA calculator uses their actual letter/percentage bands. The converter uses those bands for percentages and the website's proportional formula between GPA scales. Estimates require institutional confirmation. Explicit calculation saves use `POST /api/academic/calculations`; history comes from `GET /api/academic`, and confirmed removal uses its calculation ID. These operations do not modify saved courses or the profile GPA.

## Password-reset completion and trusted links

The app sends `POST /api/auth/reset-password` with `{token,password}` and accepts success only after `{ok:true}`. The current website requires at least eight UTF-16 characters and returns 400 for an invalid/expired link. Its emailed token is opaque to mobile; the server verifies the signature and one-hour expiry. Reset does not automatically sign in, invalidate the current app session or revoke other sessions. Do not claim single-use reset tokens: the inspected backend does not consume them.

Only `https://myoccasio.ca/reset-password` and the owned `ca.occasiotech.myoccasio://reset-password` destination are accepted. Users can explicitly paste their email link in recovery until HTTPS domain association is configured. Platform initial routes are sanitized to `/`; reset tokens are held in memory and never placed in Navigator route names, logs or persisted preferences. Loading/pending requests, duplicate links, account changes, invalid links and unsaved password edits are guarded. See [release setup](RELEASES.md) for domain association requirements.

## Native Google sign-in and sign-up capability (prepared, not deployed)

Local backend commit `b241aa6814f50429191564fe815ff33282ed344c` follows the attachment/community changes on `codex/mobile-application-attachments`. Nothing in that backend branch has been pushed or deployed. Eight focused tests pass, including actual PostgreSQL/HTTP session exchange and the real NextAuth callback in request-cookie context. Typecheck, production build, migration and drift checks pass. Full suites retain the previously confirmed missing-CMS/source-assertion baseline failures. The generated snapshot was compared to its predecessor and adds only the native-flow table.

The additive server bridge is default-off through `MOBILE_NATIVE_AUTH_ENABLED=true` and reuses the existing verified Google provider, canonical NextAuth URL/secret and ordinary 30-minute cookie session. It requires migration `0047_native_auth_pkce.sql`. No Apple provider is invented. Both authentication screens show their Google entry point. While checking availability it is disabled. Both redesigned pages explain unavailable/retry guidance in a dialog when the entry is requested. An explicit retry rechecks real configuration and never opens the browser automatically. Delayed retry results cannot cover another route. Email authentication remains available throughout the capability check. Both pages' Apple entries explain their unsupported state without making an API request. Production returned HTTP 400 from the old NextAuth catch-all on October 25; no Google session is fabricated or browser launched against that unsupported route.

The **Continue with Google** entry on registration and sign-in uses the same native flow. The actual website Google callback requires a verified email and finds an existing user by normalized email or creates a student account with the provider's name/photo and existing free-plan defaults. Existing profile fields are retained. The app does not send a Google user through `/api/register`, request a local password or require the email form to validate. Existing onboarding/profile editing supplies the remaining academic information. Provider failure or cancellation retains all entered email-form values; competing submissions, account links, password visibility and navigation stay locked until an active attempt and any required encrypted cleanup finish.

1. `GET /api/auth/native/config` returns `{enabled,callbackUri,providers}`. The only supported provider is `google`; callback is exactly `ca.occasiotech.myoccasio.auth://callback`.
2. `POST /api/auth/native/start` sends `{provider:"google",state,codeChallenge,codeChallengeMethod:"S256",redirectUri}`. State and the in-memory verifier are separate cryptographically random 32-byte values encoded as canonical unpadded base64url. The challenge is SHA-256 of the ASCII verifier. Success 201 supplies a same-backend `/auth/native?request=...` URL and ten-minute expiry.
3. Android opens the system browser; iOS 13+ uses an ephemeral `ASWebAuthenticationSession`. The browser explicitly continues through the existing Google/NextAuth flow. A bound HttpOnly cookie, fresh verified provider proof, matching callback cookie and current browser user are required before the server issues a code.
4. Mobile verifies the exact owned callback, current operation and matching state. It sends `POST /api/auth/native/exchange` with `{code,codeVerifier,redirectUri}` once. The server atomically consumes the PKCE-bound code, which expires after 60 seconds, reloads the account/role, and returns `{authenticated:true}` plus the ordinary NextAuth `Set-Cookie`.
5. The existing encrypted cookie store and `/api/auth/session` confirm the session. No JWT, cookie, password or provider token is put in a deep link or JSON response. Cancellation and late responses cannot replace or clear a newer session. Failed encrypted cleanup remains locked and retryable.

The server validation, PostgreSQL locking/expiry, real HTTP exchange/session restoration and actual Google callback proof hooks have focused local tests. Live Google consent and the deployed production exchange still require deployment/device acceptance. Backend patches remain local for operator review; see the audit for current evidence.

## Device deadline reminders

Local notifications use actual opportunity deadlines and a separate encrypted, account/backend-scoped device store. The user explicitly chooses one, three or seven days before a deadline. Date-only deadlines use disclosed 9 AM device-local calendar time; explicit timestamps keep their actual instant. Permission is read on startup and requested only after an explicit save. Android uses inexact alarms without exact-alarm permission; delivery can be delayed by the device. Native scheduling and encrypted persistence are serialized, bounded and reconciled after ambiguous failures.

The app restores pending schedules, handles permission re-enabling and time-zone changes on resume, and clears records at sign-out. Notification text is generic and contains no opportunity title, account data or callback payload. This is separate from website email switches and recent activity. There is still no remote push-token registration, unread inbox, Firebase/APNs configuration or server delivery contract.

## Application document capability (prepared, not deployed)

The additive backend branch `codex/mobile-application-attachments`, local commit `d599070d4745aca6457bee5754d7ebe541ef728b`, is prepared in the local backend checkout. It has not been pushed or deployed. Migration `0045_application_attachments.sql` creates separate private files and immutable submission copies. Apply that migration through the existing deployment pipeline before enabling the new handlers. The organization portal's existing launch gate remains in force.

Mobile enables document actions only when the real workspace response advertises `attachmentLimits: {maxBytes: 4194304, maxCount: 3}` and valid metadata. Earlier production responses retain the unavailable state and cause no document requests. Each metadata record contains `id`, `fileName`, `mimeType`, `byteSize` and `createdAt`.

- `GET /api/applications/{catalogueUuid}/attachments` returns `{attachments, limits}`.
- `POST` to that route accepts multipart `file`, or JSON `{source: "profile_resume"}` to copy the current profile résumé immediately. PDF/DOCX bytes are validated and capped at 4 MB; at most three private files belong to a workspace. Explicit duplicate retries reuse the existing file.
- `GET`/`DELETE /api/applications/{catalogueUuid}/attachments/{id}` download/remove an owner-scoped private file.
- Confirmed submission includes the exact displayed `attachmentIds`. The server compares them under the same transaction lock used for uploads/removals and returns `409 ATTACHMENTS_CHANGED` if they differ. Omitting IDs works for old clients only when there are no private documents; files are never silently included without review.
- `submission.attachments` lists separately identified immutable copies. Student download uses `/api/applications/{catalogueUuid}/submission-attachments/{id}`. Organization download uses `/api/org/applications/{applicationId}/attachments/{id}` with existing portal, membership and organization-ownership checks.

The mobile flow reviews selected files before private upload, confirms résumé reuse/removal, uses bounded authenticated system export, reconciles ambiguous upload responses and requires fresh review after a conflict. No mutation is retried automatically. The website workspace also displays/reviews its files. Submitted bytes survive later private-file/profile edits; account deletion cascades the retained records. These operations have local real-HTTP/database tests, not claimed production acceptance. No live provider submission was made.

Backend TypeScript, production build, fresh migration chain and schema drift checks passed. Seven pure document tests and the opt-in real-HTTP/PostgreSQL integration passed (8/8). The full JavaScript suite's 218 passes/8 failures exactly match unchanged `6e2404f`; the TypeScript suite has 418 passes/3 existing missing-CMS-fixture failures/1 optional HTTP skip, compared with baseline 411 passes/3 failures. These existing failures are recorded in the backend's `docs/application-attachments.md`. The local test server/database were stopped after verification.

## Shared community history (prepared, not deployed)

Local backend commit `5394c6d26ee4d08af84178f3a08e9a6077794b75`, after the attachment commit on the same branch, makes normal mobile comments and website replies use canonical `replies` storage. The mobile `{comments}` / `{comment}` wrappers and website bare-reply response remain intact. Signed user IDs, visible/non-win posts, moderation, bounded input and private responses are enforced. Wins retain their original comments storage.

Migration `0046_community_reply_compatibility.sql` moves legacy normal comments with exact IDs, author, text and timestamps. Conflicting IDs abort the whole transaction; wins and existing moderated replies are preserved. A durable guard prevents later old-server writes into the retired normal-comment history. Eleven focused tests passed, including actual local PostgreSQL migration/conflict rollback and HTTP history/count/authentication checks. TypeScript, production build and schema drift checks also passed; local helpers were stopped.

Deployment requires a verified database backup, a restored-database rehearsal and draining all old community writers. The existing Jenkins image rollback does not reverse this data transition. The backend's `docs/community-reply-compatibility.md` contains conflict inventory and explicit recovery steps; an operator must review them before release. Production still has separate histories until that deployment. No live community content was published during testing.

## Live verification

On October 22, 2026 an authorized disposable production account verified registration, sign-in, profile editing, real matches, tracking and reset-email requests through actual responses. Welcome/reset delivery was confirmed by the user. The Android opt-in integration test additionally passed encrypted session persistence/restoration, profile restoration, tracking cleanup and sign-out. Credentials and cookies were kept outside version control.

Community publishing, provider submission, account deletion and billing were not performed during live verification. Their availability in source is distinct from successful production acceptance. See [the audit](IMPLEMENTATION_AUDIT.md) for design gaps and missing backend contracts.

## Environments and device verification

The backend repository deploys through its root `Jenkinsfile` and `deploy/remote-deploy.sh`, not GitHub Actions. The pipeline builds a versioned GHCR image, checks migration drift, applies migrations from that image before swapping the production container, and checks health/rolls back. The source contains no staging target or Jenkins server/job URL. Deployment credentials are Jenkins-managed; the server's `.env` is deliberately preserved. Backend pushes may trigger production releases. Access to this repository establishes the deployment workflow, but does not supply the deployment console, OAuth/Apple identifiers or Firebase/APNs credentials. No backend push or deployment was performed for this mobile change.

The repository's volunteer helper contains four sample records and the website sidebar marks that module retired. Those records must not be copied into a production mobile feed. The prepared native sign-in bridge preserves the website's safe callback gate. Apple and remote push delivery still need organization-owned service configuration.

Production is the default. Local Android backend example:

```bash
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Use `http://127.0.0.1:3000` for an iOS simulator. Production requires HTTPS.

The opt-in test requires an explicitly authorized disposable plus-alias account and an ignored JSON defines file containing `E2E_EMAIL` and `E2E_PASSWORD`. Optional `E2E_LANGUAGE` selects `en` (default) or `fr`; the app uses the existing `occasio-locale` cookie and `Accept-Language` header while preserving session cookies:

```bash
flutter test integration_test/production_session_test.dart -d <device> --dart-define-from-file=<ignored-private-file>
```

Never publish its APK or commit that file. Remove the plaintext file afterwards and rebuild normal Android outputs without the test defines. CI runs the regular unit/widget suite without production credentials.

The production test preserves an existing résumé. If none exists, it uploads one uniquely named verification PDF, checks metadata and identical downloaded bytes, then removes only that named file and confirms empty metadata.

System document export has a separate opt-in native test without account data:

```bash
flutter test integration_test/document_export_test.dart -d <device>
```

Cancel the first system destination picker, then save `myoccasio-export-verification.txt` in the second picker. The tests assert the corresponding false/true results. Check the saved file contains exactly `MyOccasio native export verification` followed by a newline. Native system controls are outside Flutter's widget tree, so this check requires device UI interaction; it is not in headless CI. iOS 13 uses the legacy export initializer, with the modern copying picker on iOS 14 and later.
