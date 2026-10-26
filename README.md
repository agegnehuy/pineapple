# MyOccasio Mobile

The official Flutter app for MyOccasio. It targets Android and iOS and reuses the existing MyOccasio website backend.

## What is already connected

- NextAuth email/password session flow (`/api/auth/*`)
- Current student profile (`/api/me`)
- Matched opportunities (`/api/matches`)
- Tracked applications (`/api/tracking`)
- Encrypted session-cookie storage on the device
- Academics, story/AI coaching, community/events, notification preferences, plans and support through existing website endpoints

## App experience

The Figma-based mobile experience now includes:

- Figma artwork and bundled typography, welcome, sign-in, account creation, recovery and onboarding
- Native password-reset completion from trusted links or an explicitly pasted email link, with validation, retry and unsaved-password protection
- Google sign-in and sign-up entry points through the system browser, PKCE and the existing encrypted website session, with availability checks and retry (requires the prepared backend deployment)
- A personalized home dashboard
- Searchable/filterable/sortable opportunity matches and opportunity details
- Saved and tracked applications with status updates
- Profile completion and profile editing
- Application workspaces, statement review, provider handoff and consent-based application coaching
- Courses, weighted assessment estimates, live grading-scale GPA tools, reviewed calculation history, goals, deadlines and degree planning
- A device-local weekly study planner with availability, time estimates, actual deadline tasks and document export
- Real device deadline reminders with explicit notification permission, one/three/seven-day choices, management and sign-out cleanup
- Story editing, reviewed AI drafts, mentor history and document uploads
- Community posts/wins/conversations, coffee requests and event registration
- Profile résumé import with individual approval, settings, account preferences, allowance, privacy/account controls and searchable help
- Timestamped read-only saved opportunities after transport failure, with encrypted account/backend isolation and sign-out cleanup
- A five-tab mobile navigation shell and drawer
- Retriable session restoration, offline local sign-out, and bounded network requests
- Recoverable save/status errors and protection for unsaved profile edits
- Static loading indicators when the device requests reduced motion
- Persisted English/French language selection, localized dates/decimals and bilingual search

Screens use real backend repositories. An Android production integration test passed authentication, encrypted session restoration, profile editing, matches, tracking and sign-out with an authorized disposable account. The user confirmed welcome/reset email delivery. Appearance and language choices persist locally. Main-branch CI passed Android and unsigned iOS compilation. Full design parity, iOS runtime and several backend-dependent features remain; see the implementation audit before treating this as release-ready.

## Run the app

```bash
flutter pub get
flutter run
```

The default API is `https://myoccasio.ca`. To use a backend running on the same computer as an Android emulator:

```bash
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For an iOS simulator, use `http://127.0.0.1:3000` instead. Never commit passwords, API keys, signing files, or real environment files.

## Quality checks

```bash
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions runs these checks for every pull request. Release tags such as `v1.0.0` build Android and iOS artifacts automatically.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Backend integration](docs/BACKEND_INTEGRATION.md)
- [Git strategy](docs/GIT_STRATEGY.md)
- [Release setup](docs/RELEASES.md)
- [Contributing](CONTRIBUTING.md)
- [Implementation audit and remaining acceptance work](docs/IMPLEMENTATION_AUDIT.md)
