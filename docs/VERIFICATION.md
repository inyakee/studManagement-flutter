# Verification status

November 5, 2026 (Asia/Manila)

## Completed

- Created private repository inyakee/studManagement-flutter and its GitHub Codespace using Flutter 3.47.2 / Dart 3.13.2.
- No-login app: Linux analysis passed, all eight unit/widget tests passed, and release web build passed. Tests cover directory opening, error/retry, CRUD interactions, search, canceled deletion, validation, and a narrow phone viewport.
- GitHub Flutter checks succeeded for app commit de53814 and subsequent documentation commit 8994fb2.
- Owner explicitly approved anonymous student CRUD for fictional classroom data. Applied migration 2026_11_05_000001_enable_flutter_demo_access successfully to the Supabase Student project.
- Browser app opened on private Codespaces port 8080 with no login and loaded existing Supabase records.
- Created fictional FLUTTER-LIVE-20261105 / Jamie Demo through Flutter. Confirmed the same values in the Laravel website and Supabase Table Editor.
- Edited its course in Flutter; Laravel showed Computer Science after refresh.
- Edited its course in Laravel; Flutter and Supabase showed Laravel Verified Course after refresh.
- Searched the exact student number in Flutter; the matching record was returned.
- Checked the deletion dialog and canceled it; the record remained. Confirmed deletion afterward; the fixture disappeared from Flutter, Laravel, and Supabase. Other records were left untouched.
- Ran the PostgreSQL verification script: all 13 checks passed. It checks anonymous CRUD/search, trimming/timestamps, invalid email/year rejection, duplicate number/email rejection, blocked ID changes, and blocked access to users/sessions/password-reset tables. All script writes were rolled back.
- Re-ran Laravel tests after the migration: five tests passed, 42 assertions.

## Scope

This is a Flutter web app presented in a phone-style frame, not an Android APK. Both apps connect independently to Supabase; refresh to see changes from the other app. There is no automatic real-time synchronization.

The no-login database rules intentionally allow anyone with the public project settings to read or change student records. Use fictional data only. Private Codespaces ports do not protect the Supabase API. Flutter contains no database password or secret/service-role key.

Each student's own project still needs live verification. Passing tests here does not guarantee every account, network, or project setup will work without errors.

Flutter repository: https://github.com/inyakee/studManagement-flutter

Flutter Codespace: https://improved-space-trout-r4rjv5w7q96g3wjrw.github.dev/

Flutter app: https://improved-space-trout-r4rjv5w7q96g3wjrw-8080.app.github.dev/

Laravel repository: https://github.com/inyakee/studManagement

Laravel app: https://turbo-guide-jj4xwp9rvx44fwg-8000.app.github.dev/students
