# Sign-in artwork

`google-signin-icon-button.png` is the unmodified 4x light square icon-only
button from Google's official [sign-in asset bundle](https://developers.google.com/static/identity/images/signin-assets.zip),
retrieved October 25, 2026. See the [Google sign-in branding guidelines](https://developers.google.com/identity/branding-guidelines).
The Flutter button exposes its central, original-color G mark at its original
proportions; the provider label remains accessible, localized native text.

The Apple silhouette uses Flutter's bundled Material `Icons.apple` glyph. Provider
artwork does not imply that authentication is configured: unavailable providers
explain their status when requested, and only the existing verified backend flow
can create a session.
