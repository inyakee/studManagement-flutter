# Flutter + Supabase Student App

Build a mobile-style app that runs in your browser, using GitHub Codespaces.

## What you will make

Your Flutter app will open without login, show student records, search, add, edit, and delete. It will use the same Supabase database as your Laravel website.

```text
Flutter app  <---->  Supabase database  <---->  Laravel website
```

Flutter and Laravel each connect to Supabase. Flutter does not call Laravel in this activity. A change becomes visible in the other app when you refresh its list. This version does not use automatic live updates.

The app looks like a phone app inside a desktop browser. It is a Flutter web build; you do not need an Android phone or emulator.

## What you need

- Your GitHub account and available Codespaces usage.
- Your completed Laravel repository and working Supabase `students` table from the previous activity.
- Access to your own Supabase project dashboard.
- This guide, `CODE_REFERENCE.md`, and the supplied reference source.
- A computer, browser, and internet connection.

Use your own project for class practice. Do not connect to your teacher's database unless the teacher has arranged a shared exercise. Use invented student details.

**Where commands go:** all commands below run in a Codespaces terminal, unless a step says Supabase SQL Editor. Run one command, press Enter, and wait before starting the next one.

## 1. Check the existing Laravel project

Open your Laravel Codespace. Confirm that the website can list and save a practice student, and that the same record appears in Supabase Table Editor.

**Why:** this app builds on the database you already made. Fix the existing connection first if it is not working.

The students table needs these fields: `id`, `student_number`, `first_name`, `last_name`, `email`, `course`, `year_level`, `created_at`, and `updated_at`.

Keep Laravel's original migrations. The Flutter access migration below adds security and validation; it does not replace your student table or erase its records.

## 2. Add the Flutter access migration to Laravel

In your Laravel repository, create:

```text
database/migrations/2026_11_05_000001_enable_flutter_demo_access.php
```

Copy its complete contents from `CODE_REFERENCE.md`, then save it. If your teacher already added this migration to your repository, use that existing file rather than making another copy with a different name.

In the Laravel terminal, run:

```bash
php artisan config:clear
```

```bash
php artisan migrate
```

**What this does:** it allows the no-login app to read, add, edit, and delete student records. It also checks fields, fills timestamps, and provides search. Laravel continues using its server connection.

**Fictional classroom data only:** anyone with the public app settings can read or change these records through the Supabase API. A private Codespaces port does not protect that API. Use an isolated practice project. In a shared project, get the owner's approval before running this migration. No Auth account or membership table is needed.

Checkpoint: the migration finishes successfully. Run it once. If policies or functions already exist, ask your teacher to inspect migration history. Do not reset or drop the students table.

## 3. Create a separate Flutter repository

On GitHub, create a new private repository named `studManagement-flutter` and add a README.

Your two repositories now have different jobs:

| Repository | Job |
|---|---|
| `studManagement` | Laravel website, database migrations, and server-side connection |
| `studManagement-flutter` | Flutter screens and direct Supabase requests |

Open **Code → Codespaces → Create codespace on main** in the Flutter repository.

## 4. Prepare Flutter in Codespaces

Create `.devcontainer/Dockerfile` using the Dockerfile in the code reference. For the first build, create `.devcontainer/devcontainer.json` with this shorter configuration:

```json
{
  "name": "Student Pocket - Flutter web",
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "forwardPorts": [8080],
  "portsAttributes": {
    "8080": {
      "label": "Student Pocket",
      "onAutoForward": "notify",
      "protocol": "http"
    }
  }
}
```

Save the files. Press **Ctrl+Shift+P**, choose **Codespaces: Rebuild Container**, then **Rebuild**. Wait for it to finish.

**Why the short version:** the final configuration runs setup scripts. Those scripts do not exist yet, so we add them after creating the app.

In the new terminal, run:

```bash
flutter --version
```

The supplied container uses Flutter **3.47.2**. Use that version for this exercise so the code and packages match.

## 5. Create the Flutter project

Make sure your terminal is in the new Flutter repository:

```bash
pwd
```

Then create the app in that folder:

```bash
flutter create --platforms=web --project-name student_management_flutter .
```

Add the Supabase package:

```bash
flutter pub add supabase_flutter:2.18.3
```

**What this does:** Flutter creates the standard project files, and the package lets the app send requests to Supabase.

Checkpoint: you can see `pubspec.yaml`, `lib/main.dart`, `test`, and `web` in the file panel.

## 6. Add the application code

Use the complete files in `CODE_REFERENCE.md`. Create the folders and files shown there. When a file already exists, replace its contents with the supplied version. Copy the code inside each block, without the backticks.

| File | Brief explanation |
|---|---|
| `lib/main.dart` | Reads the public configuration, starts Supabase, and opens the app. |
| `lib/student.dart` | Describes a student record and checks the form values. |
| `lib/repository.dart` | Sends search, list, add, edit, and delete requests to Supabase. |
| `lib/app.dart` | Contains the phone-style frame, student list, forms, and profile screen. |
| `config/app.example.json` | Shows which public settings the app needs. |
| `scripts/setup.sh` | Installs packages and prepares a first build. |
| `scripts/start.sh` | Builds the app when needed and serves it on port 8080. |
| `scripts/rebuild.sh` | Checks, tests, and rebuilds the app after changes. |
| `.devcontainer` files | Give Codespaces the correct Flutter environment and startup commands. |
| `test` files | Check form rules and app interactions with temporary sample data. |
| `.github/workflows/flutter.yml` | Runs checks when you push your project to GitHub. |

Replace the initial short `devcontainer.json` with the full version now that the scripts exist. Add `.gitignore` and `.gitattributes` from the reference as well.

Delete Flutter's original counter test, `test/widget_test.dart`, after adding the supplied replacement test files. It checks the sample counter app that you have replaced.

Save every file. Do not copy the Flutter code into the Laravel repository.

## 7. Add your public Supabase settings

In Supabase, open **Project Settings → API Keys**. Copy the **publishable key**, which starts with `sb_publishable_`. Copy your project URL from the project overview or Connect panel.

In the Flutter Codespace, run this once if the file does not exist:

```bash
cp config/app.example.json config/app.json
```

Edit `config/app.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REFERENCE.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_YOUR_PUBLIC_KEY"
}
```

Replace both example values with your own project details. Keep the quotation marks and comma. Save the file.

**Why this key is allowed in Flutter:** a publishable key identifies the Supabase project. Database access rules decide what requests are allowed. This demo deliberately permits anonymous student CRUD. The key does not replace those rules.

Never use `sb_secret_`, a service-role key, a database password, or your sign-in password here. Browser builds contain their configuration and can be inspected. The configuration file is ignored by Git for classroom convenience; it is not a way to hide secrets in a web app.

## 8. Build and open the app

Run:

```bash
bash scripts/setup.sh
```

Wait for the message that Student Pocket is ready. Open **Ports**, find **8080**, and choose **Open in Browser**. Add port 8080 manually if it is missing. Keep its visibility **Private**.

Your address will look like:

```text
https://YOUR-FLUTTER-CODESPACE-8080.app.github.dev
```

This is different from Laravel's port 8000 address. Do not use the teacher's Codespace name, and do not type `localhost:8080` in your computer's browser.

Checkpoint: the student list opens directly inside a phone-style frame. On a narrow screen it fills the available width. There is no login screen.

## 9. Test Flutter and Laravel together

Create this invented student in Flutter:

| Field | Value |
|---|---|
| Student number | `FLUTTER-001` |
| First name | `Jamie` |
| Last name | `Santos` |
| Email | `jamie.flutter@example.test` |
| Course | `Information Technology` |
| Year | `2` |

Save. Open the student's profile and confirm the details. Refresh Supabase Table Editor and your Laravel student list. Both should show the same saved record.

Next, test these actions:

1. In Flutter, edit the course to `Computer Science` and year to `3`. Refresh Laravel and Supabase and compare the values.
2. In Laravel, edit the same student's course. Refresh Flutter and confirm the change.
3. Search in Flutter by name, number, email, and course. Try an unmatched search, then clear it.
4. Try blank fields, an invalid email, and duplicate student numbers or emails. The app should show a useful message.
5. Add a second disposable student. Open Delete, choose Cancel, and verify it remains. Then delete it deliberately and confirm its removal in both apps.
6. Refresh the app and confirm the list opens without requesting an account.

**What this proves:** both applications save to the same database, and permission checks happen in Supabase. Flutter's form checks improve the experience, while database checks still protect direct requests.

If you edit an old version of a record that someone else has changed, the app asks you to refresh. This prevents silently overwriting newer changes.

## 10. Run tests and save your work

Run these commands from the Flutter project folder:

```bash
flutter analyze
```

```bash
flutter test
```

```bash
bash scripts/rebuild.sh
```

Refresh the browser after rebuilding. A release build does not automatically pick up source or configuration changes before you rebuild it.

The supplied tests use an in-memory repository and should all pass. They do not contact Supabase or prove live database access. Complete the live comparisons in Step 9 separately.

Check your files before committing:

```bash
git status --short
```

```bash
git check-ignore config/app.json
```

Then save and push:

```bash
git add .
```

```bash
git commit -m "Complete Flutter Supabase student app"
```

```bash
git push
```

Also commit the migration in your Laravel repository. On GitHub, check **Actions** in each repository. A green check means that workflow passed; still show your teacher the live Supabase record.

## 11. Return to your work later

Stop the Codespace from GitHub's Codespaces list when you finish. Your database records stay in Supabase.

When you return, open the same Codespace and choose Restart if asked. Wait for startup, then open port 8080. If the server does not start, run `bash scripts/start.sh`.

Use `bash scripts/rebuild.sh` after changing code or `config/app.json`, then refresh. You do not need to expose Laravel's private port to Flutter because Flutter connects directly to Supabase.

## Common problems and simple fixes

| Problem | What to check |
|---|---|
| `flutter: command not found` | Rebuild using the supplied Flutter Dockerfile, then open a fresh Codespaces terminal. |
| Dart or package version error | Check `flutter --version`. Use Flutter 3.47.2 and the supplied package files, then run `flutter pub get`. |
| Container build fails | Open View Creation Log and read the first useful error. Check Dockerfile spelling and internet access. Do not disable package signing or certificate checks. |
| “Add your Supabase URL…” screen | Replace both placeholders in `config/app.json`, save, and rebuild. |
| JSON configuration error | Use straight double quotation marks, the comma between the two settings, and no trailing comma. |
| Invalid API key or connection fails | Use the publishable key and URL from the same project. Check whether the Supabase project is paused. Rebuild after correcting the configuration. |
| Incomplete database setup or missing function | Run the supplied new migration in the Laravel Codespace connected to the correct Supabase project. |
| RLS or permission denied | Ask the owner whether the demo migration was approved and applied. Keep RLS enabled and use the supplied scoped demo policies. |
| Laravel table is missing | Complete the earlier Laravel activity and run its migrations before the Flutter migration. |
| A policy or function already exists | The setup may have been run through another route. Ask the teacher to check migration history; do not reset the database. |
| Nothing appears in the list | Clear search, refresh, and check the Supabase project and demo access setup. |
| Duplicate record message | Use another student number or email. Existing uniqueness rules are shared by both apps. |
| Saved in one app but not visible in the other | Refresh both lists, clear search filters, and check that both apps use the same Supabase project. |
| Record changed or no longer available | Someone edited or deleted the version you opened. Return to the list, refresh, then reopen it. |
| App still shows old code or settings | Run `bash scripts/rebuild.sh`, then refresh the browser. Use a hard refresh if needed. |
| HTTP 502 or page unavailable | Resume the Codespace, wait for setup, run the startup script if needed, and open port 8080 through Ports. |
| Private port is stuck connecting | Stay signed into the owning GitHub account. Refresh after startup finishes. Do not make the port public as a shortcut. |
| “Address already in use” | The server may already be running. Open port 8080 first; use the supplied startup script rather than launching duplicate servers. |
| Linux script mentions `bash\r` or a bad interpreter | Change the script's line endings from CRLF to LF using the editor's bottom-right control. Save and retry. |
| Counter test cannot find `MyApp` | Remove the original sample counter test after adding the supplied app tests. |
| Windows font or analyzer error involving a non-English folder path | Run the project inside the Linux Codespace as instructed. The classroom procedure does not require a local Windows Flutter build. |
| Git says nothing to commit | Your saved files already match the latest commit. Check GitHub to confirm. |
| Git cannot push | Check the repository owner and complete your own GitHub authentication. Do not force-push to hide a conflict. |
| GitHub or Supabase usage limit | Ask your teacher about available class resources. Do not enable paid usage without agreement. |

If you still need help, send the teacher the step number, the exact error, and what you tried. Keep passwords, tokens, and private settings out of screenshots.

## What to submit

- Links to your Flutter and Laravel repositories with access arranged for your teacher.
- A screenshot of the phone-style Flutter app.
- A screenshot of the same practice record in Laravel and Supabase.
- Passing test results.
- A short demonstration of add, view, edit, search, and delete without login.
- One or two sentences explaining what each main file does.

Keep ports private. A private Codespaces link is not automatically accessible to your teacher's account; arrange a demonstration or recording if needed.

## Official references

- [Supabase Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Flutter web builds](https://docs.flutter.dev/platform-integration/web/building)

The reference ZIP is a fallback for checking your work. If your teacher uses it as a starter, extract it, upload the project contents at the repository root, and follow the configuration, database, and testing steps above. Do not upload the ZIP itself as the project. It contains public placeholders rather than your teacher's account settings.
