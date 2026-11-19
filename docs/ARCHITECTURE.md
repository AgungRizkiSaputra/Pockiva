# Architecture Overview — Tabungan Pribadi

## 1. Architectural Pattern

Tabungan Pribadi uses a clean, feature-first modular architecture built on Flutter + Riverpod + GoRouter + Supabase. Abstractions are intentionally minimal so the codebase stays fast to navigate, easy to test, and simple to evolve.

```text
lib/
├── main.dart                         # Parallel bootstrap (<2s cold start)
├── app.dart                          # Theme, localization, 15-min inactivity listener
├── core/
│   ├── config/app_config.dart        # --dart-define runtime configuration
│   ├── theme/                        # Sand (#F4EFEA), Sage (#8A9A5B), Electric Blue (#007BFF), Light & Dark
│   ├── router/app_router.dart        # GoRouter with Auth / PIN / Onboarding guards
│   ├── security/                     # SecureStorage, InactivitySessionGuard, ErrorMapper
│   ├── sync/offline_sync_service.dart# Encrypted offline queue & connectivity auto-sync
│   ├── notifications/                # Firebase Cloud Messaging + local foreground notifications
│   ├── utils/                        # IDR formatters, Indonesian dates, validators/sanitizers
│   └── widgets/                      # PinPadWidget, SyncStatusTag, StateViews, ResponsiveAppShell
└── features/
    ├── auth/                         # Welcome, Google OAuth, PIN Setup/Verify
    ├── onboarding/                   # Intro + Initial Savings Target setup
    ├── dashboard/                    # Balance hero, target progress, monthly summary, recent activity
    ├── transactions/                 # <5s Quick Add numpad sheet, paginated History, Detail/Edit/Delete
    ├── savings/                      # Radial progress chart, 6-month savings chart, target editor
    ├── insights/                     # 6-month grouped bar chart, category breakdown, real-data insights
    ├── gamification/                 # Daily activity streak, longest streak, 8 milestone badges
    └── settings/                     # Profile, PIN change, Light/Dark mode, notifications, logout
```

## 2. Key Technical Decisions

1. **State Management (`flutter_riverpod` v2)**: Compile-safe dependency injection without codegen overhead; enables zero-mock production repositories with clean provider overrides in automated tests.
2. **Routing (`go_router`)**: Declarative redirect guards enforce the exact PRD flow (`Welcome -> PIN Setup/Verify -> Onboarding -> Dashboard`) and drive a `StatefulShellRoute` supporting Bottom `NavigationBar` on phones and `NavigationRail` on tablets/desktops (`>= 768px`).
3. **Offline-First Resilience (`OfflineSyncStore`)**:
   - Encrypted local cache hydrates the UI immediately on launch for sub-2-second perceived load.
   - Transactions submitted while offline are stored encrypted in `FlutterSecureStorage` with a client-generated UUID v4 `client_id` and tagged `Menunggu sinkronisasi` (`SyncStatus.pendingSync`).
   - Duplicate submissions are prevented via both an in-flight UI lock and server-side idempotency (`UNIQUE (user_id, client_id)` + `transactions-api` deduplication).
   - Connectivity changes automatically flush queued entries.

## 3. Resolved PRD Ambiguities

| PRD Area | Ambiguity | Decision |
|---|---|---|
| `transactions` table | Missing `type` column to distinguish savings deposits from expenses. | Added `type CHECK (type IN ('saving', 'expense'))`, optional `note` (<=140 chars), `occurred_at`, and `client_id` (idempotency). Total Savings = `SUM(amount WHERE type = 'saving')`; Monthly Spending = `SUM(amount WHERE type = 'expense')`. |
| Savings target model | FR-03 & Onboarding require a savings target not listed in Section 17 SQL. | Added `savings_target`, `savings_target_title`, `savings_target_deadline`, and `onboarding_completed` directly on `profiles` to avoid out-of-scope multi-wallet tables. |
| Gamification badges | FR-05 requires Streak & Badge while Section 17 defines only `streaks`. | Extended `streaks` (`longest_streak`, `total_active_days`) and added `user_badges`, automatically maintained by PostgreSQL triggers on `transactions` insert. |
| Server-side Argon2 PIN | Section 17 includes `pin_hash` on `profiles` while security requires Argon2 and zero client exposure. | Revoked column-level `SELECT`/`UPDATE` on `pin_hash` and lockout columns for `authenticated`/`anon`; all Argon2id hashing and verification run exclusively inside Supabase Edge Functions (`pin-manage`, `pin-verify`). |
