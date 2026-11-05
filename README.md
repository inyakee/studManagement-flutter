# Student Pocket

Flutter web in a mobile-style layout, with no login. Flutter and the Laravel website connect independently to the same Supabase students table.

Create a Codespace from this repository. Its Dockerfile installs Flutter 3.47.2 and forwards private port 8080. Copy config/app.example.json to config/app.json and enter your project URL and publishable key. Never use a database password or secret/service-role key in Flutter.

Run `bash scripts/rebuild.sh` after changing source or configuration, then refresh the browser. Run `bash scripts/start.sh` if the server is stopped. Open port 8080 through Ports.

The companion Laravel migration `2026_11_05_000001_enable_flutter_demo_access.php` prepares database validation, timestamps, search, and anonymous student CRUD. Apply it only after the project owner approves this access. Anyone with the public project settings can read or change these records through Supabase, even if the Codespaces port is private. Use fictional data in an isolated classroom project.

Follow [the student guide](docs/STUDENT_GUIDE.md) for step-by-step instructions and simple explanations. [The code reference](docs/CODE_REFERENCE.md) contains the complete files. [Verification status](docs/VERIFICATION.md) separates completed checks from pending live database checks.

Run `flutter analyze`, `flutter test`, and `flutter build web --dart-define-from-file=config/app.json`. Tests use an in-memory repository; verify real database persistence separately in Flutter, Laravel, and Supabase.
