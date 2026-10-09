# vendors-magento2click

Styleya customer app (Flutter), pointed at the `https://styleya.net` Magento backend.

The backend is configured in one place — `serverConfig.url` in [lib/env.dart](lib/env.dart).
Catalog media (`kMediaDomain` in `lib/common/constants/general.dart`) derives from it.

Domain and identity, shared with the Styleya Seller vendor app (`magentoegypt/locafy-vendorapp`):

- Website, API, privacy policy and About Us all live on `https://styleya.net`.
- User-facing name is Styleya (Android label, iOS display/bundle name, web title).
- Store and Firebase identifiers keep the Locafy name on purpose (`app.locafy.customer`,
  Firebase project `locafy-7461b`, iOS signing profile), so builds keep updating the
  existing store listings.
- Still on Locafy until the website switches them: the social links in Settings
  (`locafy.eg` accounts) and the guest checkout email fallback
  (`guest<phone>@locafy.market` in `lib/models/entities/address.dart`), which mirrors
  the website's default.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
