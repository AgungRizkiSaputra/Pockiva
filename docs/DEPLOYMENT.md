# Setup, Configuration & Deployment Guide

## 1. Prerequisites

- Flutter SDK `>= 3.38.0` (Dart `>= 3.10.0`)
- Supabase project (Cloud or local Supabase CLI)
- Google Cloud Console OAuth 2.0 Client IDs (Android, iOS, Web)
- Firebase project (optional for local dev; required for FCM push notifications in production)

## 2. Supabase Backend Provisioning

1. Link your Supabase project and push all migrations:
   ```bash
   supabase login
   supabase link --project-ref <YOUR_PROJECT_REF>
   supabase db push
   ```
2. Verify Row Level Security policies against a staging/local DB:
   ```bash
   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_policies.sql
   ```
3. Configure Edge Function secrets (never commit these):
   ```bash
   supabase secrets set CRON_SECRET=<RANDOM_32_BYTE_HEX>
   supabase secrets set FCM_PROJECT_ID=<FIREBASE_PROJECT_ID>
   supabase secrets set FCM_OAUTH_ACCESS_TOKEN=<FCM_V1_ACCESS_TOKEN>
   ```
4. Deploy Edge Functions:
   ```bash
   supabase functions deploy pin-manage
   supabase functions deploy pin-verify
   supabase functions deploy transactions-api
   supabase functions deploy smart-reminder --no-verify-jwt
   ```
5. Enable **Google** provider in Supabase Dashboard -> Authentication -> Providers, and add `com.tabunganpribadi.app://login-callback/` under Redirect URLs.

## 3. Firebase Push Notifications (FCM)

- Place `google-services.json` in `android/app/google-services.json` (git-ignored).
- Place `GoogleService-Info.plist` in `ios/Runner/GoogleService-Info.plist` (git-ignored).
- Schedule `smart-reminder` hourly via Supabase Cron (`pg_cron` + `pg_net`) passing header `x-cron-secret: <CRON_SECRET>`.

## 4. Running Locally

Create `.env.local` (git-ignored) from `.env.example` or pass `--dart-define`:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<YOUR_GOOGLE_WEB_CLIENT_ID>
```

## 5. Testing

```bash
# Static analysis
flutter analyze

# Unit, Widget & Integration tests
flutter test

# Patrol E2E tests (on connected Android/iOS emulator or device)
patrol test -t integration_test/app_patrol_test.dart \
  --dart-define=SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
```

## 6. Production Release Builds

```bash
# Android App Bundle (Play Store)
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/android \
  --dart-define=SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<YOUR_GOOGLE_WEB_CLIENT_ID> \
  --dart-define=APP_ENV=production

# iOS IPA (App Store)
flutter build ipa --release \
  --obfuscate --split-debug-info=build/symbols/ios \
  --dart-define=SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<YOUR_GOOGLE_WEB_CLIENT_ID> \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<YOUR_GOOGLE_IOS_CLIENT_ID> \
  --dart-define=APP_ENV=production
```
