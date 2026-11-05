# Teacher notes

Use this as the second activity after the Laravel student-management exercise. Students keep two repositories and use the same Supabase project for both apps.

## Main explanation

Flutter and Laravel are two interfaces to one database. Flutter uses Supabase Auth plus row-level security. Laravel uses its existing private server connection. Laravel's form validation does not process Flutter requests, so this activity also adds database validation.

The approval list is intentional. Creating or confirming a Supabase Auth account alone does not authorize it to see student data. Only project owners can add enabled membership rows. The app is a shared directory for approved staff, not a portal where each student sees only their own record.

## Before class

- Give students STUDENT_GUIDE.md and CODE_REFERENCE.md.
- Students should have working Laravel CRUD and their own Supabase projects from the first activity.
- Decide whether students create files from the code reference or start with the clean reference ZIP.
- Check GitHub Codespaces usage and Supabase project availability before scheduling the activity.
- Account creation and approval are owner/teacher steps in a shared project. Do not distribute a shared database password or service-role key.
- Keep the student-management example data fictional and ports private.

## Recommended checkpoints

1. Student can explain the two independent database connections.
2. New Laravel migration runs once without resetting existing tables.
3. Auth account UID matches an enabled membership row.
4. Codespace uses the pinned Flutter version and shows private port 8080.
5. Only project URL and publishable key are used in Flutter.
6. Signed-out users see the sign-in screen, and unapproved accounts cannot open the directory.
7. A record created in Flutter appears in Laravel and Supabase after refreshing.
8. An update from Laravel appears in Flutter after refreshing.
9. Canceling deletion keeps a record; deliberately deleting a disposable fixture removes it from both interfaces.
10. Flutter analysis, tests, and web build pass; both repositories contain the student's saved work.

## Brief questions to ask

- What does `StudentRepository` do?
- Why is a publishable key allowed in a browser, while a database password is not?
- What is the difference between signing in and being approved?
- Why must access rules be checked in Supabase as well as in the app?
- Why does the other app need a refresh to show changes?
- What happens when two people edit an older version of the same record?

## Evidence and grading

Ask for both repository links, screenshots of the same record in Flutter/Laravel/Supabase, passing checks, and a short demo. A suggested split is setup 15%, authentication and permissions 25%, CRUD 30%, cross-app evidence and tests 20%, explanation and clean Git submission 10%.

The 8 supplied Flutter tests use a fake in-memory repository. They are useful for form and screen behavior but do not prove a student's live Supabase configuration. Grade the live checks separately.

The Laravel repository also provides `scripts/verify-flutter-access.php` for the owner. After applying the migration, run `php scripts/verify-flutter-access.php` from the configured Laravel Codespace. It checks anonymous, unapproved, approved, and disabled-account behavior through PostgreSQL roles, plus database validation and CRUD. It uses temporary transaction-only identities and rolls everything back. It does not create a usable Auth login or replace a real browser sign-in test.

If a student sees a policy/table-exists error, inspect migration history. Do not solve it by dropping the existing table or using migrate:fresh. Never disable row-level security, encryption, or authentication to get a green demo.

## Version and scope

The provided container pins Flutter 3.47.2. The project lockfile records the tested dependency versions, including supabase_flutter 2.18.3. The build is Flutter web, presented with a mobile-style layout. An APK, Android emulator, offline database, self-registration, email delivery, and real-time synchronization are outside this activity.

Read VERIFICATION.md for the exact checks completed in the instructor environment. The classroom copy removes the instructor's public project configuration and supplies placeholders; each student's account, policies, and live database still need their own verification.
