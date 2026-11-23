# Lavenga — Studio Space Booking Marketplace (frontend)

Flutter + Riverpod + GoRouter + Material 3. Three roles: Customer, Platform Manager, Administrator.
All data is mock, behind repository interfaces (see `docs/BACKEND_INTEGRATION.md`).

## Run
```
bash tools/setup_phase2.sh   # pub add deps, analyze, test (or run the steps yourself)
flutter run
```
Demo logins (password `Lavenga@123`, reset code `123456`): ayesha@example.com (customer),
manager@lavenga.app, admin@lavenga.app. The login screen has quick-fill chips.

## Layout
`lib/domain` pure Dart (models, pricing, policies) · `lib/data/mock` mock backend ·
`lib/core` theme, widgets, router, DI · `lib/features` screens per role.

Sign-up has no OTP step (`lib/core/config/auth_config.dart`); email verification is prepared in `docs/EMAIL_VERIFICATION.md`.

## Status
Written without a Flutter SDK available, so it has NOT been compiled. Expect a round of
`flutter analyze` fixes. Models are hand-written (no Freezed/codegen) to avoid build_runner.
