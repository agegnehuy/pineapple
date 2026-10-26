# Git strategy

MyOccasio Mobile uses GitHub Flow: one protected `main` branch plus short-lived branches and pull requests.

## Branches

- `main` — always releasable; direct pushes are blocked.
- `feature/<short-name>` — a new feature, for example `feature/sign-in`.
- `fix/<short-name>` — a bug fix, for example `fix/session-expiry`.
- `chore/<short-name>` — tooling, dependency, or maintenance work.
- `docs/<short-name>` — documentation only.

Delete the branch after its pull request is squash-merged.

## Commits

Use Conventional Commit messages:

```text
feat(auth): add email sign-in
fix(api): refresh expired session
test(profile): cover profile mapping
chore(ci): cache Flutter packages
```

## Pull-request rules

1. Branch from an up-to-date `main`.
2. Keep one logical change per pull request.
3. Require at least one teammate approval.
4. Require the `quality`, `android`, and `ios` CI checks.
5. Resolve review conversations before merging.
6. Squash merge into `main`.

Configure these as branch-protection rules in GitHub. Also block force pushes and branch deletion on `main`.

## Releases and hotfixes

Create releases from `main` using semantic tags such as `v1.2.0`. The release workflow builds the Android App Bundle and an unsigned iOS build artifact. A critical production fix uses `fix/<issue>`, follows the same pull-request checks, and receives a patch tag such as `v1.2.1` after merging.
