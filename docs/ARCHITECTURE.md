# Architecture

The app uses a feature-first structure. Code that belongs to one product feature stays together, while reusable infrastructure stays in `core`.

```text
lib/
├── app/                     # Startup, dependency wiring, session state
├── core/
│   ├── network/            # HTTP client and errors
│   ├── files/              # Native document selection and upload validation
│   ├── storage/            # Secure session-cookie persistence
│   ├── theme/              # Shared visual tokens
│   └── widgets/            # Reusable app-level widgets and states
├── features/
│   ├── auth/               # Welcome, registration, sign in, sign out
│   ├── home/               # Personalized dashboard
│   ├── navigation/         # Top-level mobile shell
│   ├── profile/            # Student profile
│   ├── opportunities/      # Matched opportunities
│   ├── applications/       # Tracking, workspace and reviewed submissions
│   ├── academics/          # Courses, assessments, goals and planning
│   ├── coaching/           # Story, mentor and application guidance
│   ├── community/          # Posts, people, conversations and events
│   └── settings/           # Preferences, allowance, support and account controls
└── main.dart               # Small production entry point
```

Each feature may contain `data`, `domain`, and `presentation` folders. Add those folders only when they contain real code; do not create empty layers.

## Rules

1. Widgets never make raw HTTP calls.
2. Screens call a repository or service interface.
3. Repositories know endpoint paths and convert responses to domain models.
4. `ApiClient` owns headers, cookies, JSON, and API errors.
5. Secrets are stored in Android Keystore/iOS Keychain through secure storage.
6. Production builds must use HTTPS.
7. New features include tests before they are merged.
