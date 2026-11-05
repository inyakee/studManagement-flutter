# Student Pocket

Flutter web with a mobile-style layout, Supabase email/password sign-in, and a shared student directory. This frontend uses the same Supabase students table as inyakee/studManagement.

## Codespaces

Create a Codespace from this repository. The Dockerfile installs Flutter 3.47.2. Setup restores locked packages, builds the app, and forwards private port 8080.

Copy config/app.example.json to config/app.json. Supply your Supabase project URL and publishable key. These are browser configuration, not database credentials. Never put a database password, secret key, or service-role key in Flutter.

Run bash scripts/rebuild.sh after changes, then refresh the browser. Run bash scripts/start.sh if the server is stopped. Open port 8080 from Ports. No Android emulator is needed.

## Supabase setup

Run the companion Laravel migration 2026_11_05_000001_enable_flutter_staff_access.php first. It adds member-only student policies, required-field checks, timestamps, and paginated search. Laravel's existing server connection continues working.

The project owner creates a confirmed Supabase Auth user and adds their UUID to public.student_app_members. Only enabled members may use the directory. There is no public registration flow, and users cannot approve themselves. This is a shared staff directory, not a personal student portal.

## Checks

flutter analyze
flutter test
flutter build web --dart-define-from-file=config/app.json

Widget tests use an in-memory repository. Live verification separately checks database policies and persistence, then compares changes with the Laravel website.
