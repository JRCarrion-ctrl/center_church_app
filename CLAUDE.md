# Center Church App (`ccf_app`) — Agent Guide & Architecture Context

## Project Summary
Bilingual (English/Spanish) Flutter app for Center Church Frederick / Centro Cristiano Frederick.
Deployed to iOS, Android, and Web.
Package ID (Android): `com.jcarriondev.ccfapp`
Bundle ID (iOS): `com.centrocristiano.ccfapp` (Team: `9DD73QC3QV`)

## Core Tech Stack
- **Flutter SDK:** ^3.9.2 (Sound Null Safety)
- **State Management:** Provider (`AppState` as central ChangeNotifier in `lib/app_state.dart`)
- **Navigation:** GoRouter (`lib/app_router.dart` and `lib/routes/`)
- **Auth:** OIDC via Zitadel (`https://auth.ccfapp.com`) using `openid_client` and `flutter_web_auth_2`
- **Database/API:** Hasura GraphQL (`https://api.ccfapp.com/v1/graphql`, WSS: `wss://api.ccfapp.com/v1/graphql`)
- **Push Notifications:** OneSignal (`a75771e7-9bd5-4497-adf3-18b7c8901bcb`)
- **Giving / Payments:** Stripe (External Checkout & Customer Portal; see `GIVING_DESIGN.md`)
- **File Uploads:** S3 Presigned URLs via `https://uploads.ccfapp.com/storage/presign`
- **Localization:** EasyLocalization (`assets/translations/en.json`, `es.json`)

## Directory Layout
- `lib/core/`: Network clients (`hasura_client.dart`), theme (`theme.dart`), media pickers.
- `lib/features/`: Feature modules (`auth`, `calendar`, `groups`, `home`, `more`, `prayer`).
- `lib/routes/`: Route modules (`auth_routes.dart`, `group_routes.dart`, `main_shell_routes.dart`, `misc_routes.dart`).
- `lib/shared/`: Shared models (`user_roles.dart`) and widgets.
- `assets/`: Static image assets and `translations/` JSON files.

## Developer Workflows & Commands
- **Run Locally (Chrome):** `flutter run -d chrome`
- **Run Locally (Mobile):** `flutter run -d <device-id>`
- **Run Static Analysis:** `flutter analyze`
- **Run Tests:** `flutter test`
- **Regenerate Launcher Icons:** `flutter pub run flutter_launcher_icons`
- **Regenerate Splash Screen:** `flutter pub run flutter_native_splash:create`

## Critical Architectural Rules
1. **Never Capture Raw Card Data in Flutter:** Any giving features must redirect externally to Stripe Checkout via `url_launcher`.
2. **Enforce Backend Role Alignment:** Always pass active user roles to Hasura via `X-Hasura-Role` header. Never rely solely on client-side role checks for sensitive operations.
3. **No Direct `Colors.*` in UI:** Consume colors from `Theme.of(context).colorScheme` to preserve dark mode support.
4. **Every User-Facing String Must Be Localized:** Use `.tr()` keys. Never add raw English strings directly into `Text()` widgets.
5. **Guard Platform-Specific APIs:** Always check `kIsWeb` before invoking `dart:io` or native mobile plugins.
