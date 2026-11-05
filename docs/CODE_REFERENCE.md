# Flutter Student App — Complete Code Reference

Follow STUDENT_GUIDE.md. Each heading is an exact file path. Create missing folders and replace the file contents with the code shown. Copy inside the fences only. The first migration belongs in the Laravel repository; the remaining app files belong in the Flutter repository.

Use the short devcontainer.json from the guide for the initial empty repository. Use the full version below after the scripts exist. Standard web scaffold files are created by flutter create. The reference ZIP includes the tested pubspec.lock.

## Laravel repository: database/migrations/2026_11_05_000001_enable_flutter_staff_access.php

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        DB::unprepared(<<<'SQL'
CREATE TABLE public.student_app_members (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.student_app_members ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.student_app_members FROM anon, authenticated;
GRANT SELECT ON public.student_app_members TO authenticated;
CREATE POLICY student_app_member_own_status ON public.student_app_members
    FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);

CREATE FUNCTION public.student_app_has_access() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (SELECT 1 FROM public.student_app_members
      WHERE user_id = (SELECT auth.uid()) AND enabled = true);
$$;
REVOKE ALL ON FUNCTION public.student_app_has_access() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.student_app_has_access() TO authenticated;

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.students FROM anon;
REVOKE ALL ON public.students FROM authenticated;
GRANT SELECT, DELETE ON public.students TO authenticated;
GRANT INSERT (student_number, first_name, last_name, email, course, year_level),
    UPDATE (student_number, first_name, last_name, email, course, year_level)
    ON public.students TO authenticated;
REVOKE ALL ON SEQUENCE public.students_id_seq FROM authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.students_id_seq TO authenticated;

CREATE POLICY student_app_read ON public.students FOR SELECT TO authenticated
    USING ((SELECT public.student_app_has_access()));
CREATE POLICY student_app_insert ON public.students FOR INSERT TO authenticated
    WITH CHECK ((SELECT public.student_app_has_access()));
CREATE POLICY student_app_update ON public.students FOR UPDATE TO authenticated
    USING ((SELECT public.student_app_has_access()))
    WITH CHECK ((SELECT public.student_app_has_access()));
CREATE POLICY student_app_delete ON public.students FOR DELETE TO authenticated
    USING ((SELECT public.student_app_has_access()));

CREATE FUNCTION public.student_app_validate_row() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    NEW.student_number := btrim(NEW.student_number);
    NEW.first_name := btrim(NEW.first_name);
    NEW.last_name := btrim(NEW.last_name);
    NEW.email := btrim(NEW.email);
    NEW.course := btrim(NEW.course);
    IF NEW.student_number IS NULL OR char_length(NEW.student_number) NOT BETWEEN 1 AND 30
       OR NEW.first_name IS NULL OR char_length(NEW.first_name) NOT BETWEEN 1 AND 100
       OR NEW.last_name IS NULL OR char_length(NEW.last_name) NOT BETWEEN 1 AND 100
       OR NEW.course IS NULL OR char_length(NEW.course) NOT BETWEEN 1 AND 120
       OR NEW.email IS NULL OR char_length(NEW.email) > 255
       OR NEW.email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
       OR NEW.year_level IS NULL OR NEW.year_level NOT BETWEEN 1 AND 6 THEN
        RAISE EXCEPTION 'Student fields are invalid. Check required fields, email and year level.' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'INSERT' THEN
        NEW.created_at := COALESCE(NEW.created_at, timezone('utc', now()));
    ELSE
        NEW.created_at := OLD.created_at;
    END IF;
    NEW.updated_at := timezone('utc', clock_timestamp());
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.student_app_validate_row() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER student_app_validate_before_write BEFORE INSERT OR UPDATE ON public.students
    FOR EACH ROW EXECUTE FUNCTION public.student_app_validate_row();

CREATE FUNCTION public.student_app_search(search_term text DEFAULT '', offset_rows integer DEFAULT 0, page_size integer DEFAULT 21)
RETURNS SETOF public.students LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
    SELECT * FROM public.students
    WHERE COALESCE(search_term, '') = ''
       OR strpos(lower(student_number), lower(search_term)) > 0
       OR strpos(lower(first_name || ' ' || last_name), lower(search_term)) > 0
       OR strpos(lower(email), lower(search_term)) > 0
       OR strpos(lower(course), lower(search_term)) > 0
    ORDER BY last_name, first_name, id
    LIMIT greatest(1, least(COALESCE(page_size, 21), 101)) OFFSET greatest(0, COALESCE(offset_rows, 0));
$$;
REVOKE ALL ON FUNCTION public.student_app_search(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.student_app_search(text, integer, integer) TO authenticated;
NOTIFY pgrst, 'reload schema';
SQL);
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }
        DB::unprepared(<<<'SQL'
DROP POLICY IF EXISTS student_app_read ON public.students;
DROP POLICY IF EXISTS student_app_insert ON public.students;
DROP POLICY IF EXISTS student_app_update ON public.students;
DROP POLICY IF EXISTS student_app_delete ON public.students;
DROP TRIGGER IF EXISTS student_app_validate_before_write ON public.students;
DROP FUNCTION IF EXISTS public.student_app_search(text, integer, integer);
DROP FUNCTION IF EXISTS public.student_app_validate_row();
DROP FUNCTION IF EXISTS public.student_app_has_access();
DROP TABLE IF EXISTS public.student_app_members;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.students FROM authenticated;
REVOKE USAGE, SELECT ON SEQUENCE public.students_id_seq FROM authenticated;
NOTIFY pgrst, 'reload schema';
SQL);
    }
};
```

## Laravel repository: scripts/verify-flutter-access.php

```php
<?php

require __DIR__.'/../vendor/autoload.php';
$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$db = Illuminate\Support\Facades\DB::connection();
if ($db->getDriverName() !== 'pgsql') {
    throw new RuntimeException('This check requires the Supabase PostgreSQL connection.');
}
$checks = 0;
$assert = function (bool $ok, string $label) use (&$checks): void {
    if (!$ok) {
        throw new RuntimeException('FAILED: '.$label);
    }
    $checks++;
    echo 'PASS: '.$label.PHP_EOL;
};
$denied = function (string $sql, array $bindings, string $code) use ($db): bool {
    $db->statement('SAVEPOINT permission_check');
    try {
        $db->select($sql, $bindings);
        $db->statement('ROLLBACK TO SAVEPOINT permission_check');
        return false;
    } catch (Illuminate\Database\QueryException $error) {
        $db->statement('ROLLBACK TO SAVEPOINT permission_check');
        return (string) $error->getCode() === $code;
    } finally {
        $db->statement('RELEASE SAVEPOINT permission_check');
    }
};

$db->beginTransaction();
try {
    $id = $db->selectOne('SELECT gen_random_uuid()::text AS id')->id;
    $suffix = str_replace('-', '', $id);
    $number = 'VERIFY-'.substr($suffix, 0, 12);
    // Transaction-only identity for permission checks; never a usable login.
    $db->insert('INSERT INTO auth.users (id, email) VALUES (?::uuid, ?)', [$id, 'verify-'.$suffix.'@example.test']);
    $db->statement('SET LOCAL ROLE anon');
    $assert($denied('SELECT id FROM public.students LIMIT 1', [], '42501'), 'Anonymous student reads blocked');
    $assert($denied('SELECT public.student_app_has_access()', [], '42501'), 'Anonymous membership lookup blocked');
    $db->statement('RESET ROLE');
    $db->select("SELECT set_config('request.jwt.claims', ?, true)", [json_encode(['sub' => $id, 'role' => 'authenticated'])]);
    $db->statement('SET LOCAL ROLE authenticated');
    $assert(!$db->selectOne('SELECT public.student_app_has_access() AS allowed')->allowed, 'Unapproved identity has no access');
    $assert((int) $db->selectOne('SELECT count(*) AS count FROM public.students')->count === 0, 'Unapproved identity cannot see existing students');
    $assert($denied('INSERT INTO public.student_app_members (user_id) VALUES (?::uuid) RETURNING user_id', [$id], '42501'), 'Accounts cannot approve themselves');
    $insert = 'INSERT INTO public.students (student_number, first_name, last_name, email, course, year_level) VALUES (?, ?, ?, ?, ?, ?) RETURNING id';
    $values = [$number, 'Disposable', 'Verification', $number.'@example.test', 'Information Technology', 2];
    $assert($denied($insert, $values, '42501'), 'Unapproved student inserts blocked');
    $db->statement('RESET ROLE');
    $db->insert('INSERT INTO public.student_app_members (user_id) VALUES (?::uuid)', [$id]);
    $db->statement('SET LOCAL ROLE authenticated');
    $assert((bool) $db->selectOne('SELECT public.student_app_has_access() AS allowed')->allowed, 'Approved identity has access');
    $assert(!$db->selectOne("SELECT has_table_privilege('authenticated', 'public.students', 'TRUNCATE') AS allowed")->allowed, 'Authenticated role cannot truncate the table');
    $row = $db->selectOne($insert, $values);
    $studentId = $row->id;
    $saved = $db->selectOne('SELECT * FROM public.students WHERE id = ?', [$studentId]);
    $assert($saved->student_number === $number && $saved->created_at !== null && $saved->updated_at !== null, 'Approved insert and timestamp defaults work');
    $assert(count($db->select('SELECT * FROM public.student_app_search(?, 0, 21)', [$number])) === 1, 'RLS-protected search finds the record');
    $bad = $values; $bad[0] .= 'B'; $bad[3] = 'invalid';
    $assert($denied($insert, $bad, '23514'), 'Database rejects invalid email');
    $bad = $values; $bad[0] .= 'C'; $bad[3] = 'other-'.$number.'@example.test'; $bad[5] = 7;
    $assert($denied($insert, $bad, '23514'), 'Database rejects invalid year');
    $assert($denied($insert, $values, '23505'), 'Database rejects duplicate student number');
    $db->update('UPDATE public.students SET course = ? WHERE id = ?', ['Computer Science', $studentId]);
    $assert($db->selectOne('SELECT course FROM public.students WHERE id = ?', [$studentId])->course === 'Computer Science', 'Approved update works');
    $assert($denied('UPDATE public.students SET id = id + 1000000 WHERE id = ? RETURNING id', [$studentId], '42501'), 'Clients cannot change record IDs');
    $db->delete('DELETE FROM public.students WHERE id = ?', [$studentId]);
    $assert((int) $db->selectOne('SELECT count(*) AS count FROM public.students WHERE id = ?', [$studentId])->count === 0, 'Approved delete works');
    $db->statement('RESET ROLE');
    $db->update('UPDATE public.student_app_members SET enabled = false WHERE user_id = ?::uuid', [$id]);
    $db->statement('SET LOCAL ROLE authenticated');
    $assert(!$db->selectOne('SELECT public.student_app_has_access() AS allowed')->allowed, 'Disabled membership immediately blocks access');
    $db->statement('RESET ROLE');
    echo $checks.' live access checks passed. All fixtures rolled back.'.PHP_EOL;
} finally {
    $db->rollBack();
}
```

## Flutter repository: .devcontainer/Dockerfile

```text
FROM mcr.microsoft.com/devcontainers/base:bookworm
ARG FLUTTER_VERSION=3.47.2
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl git unzip xz-utils zip libglu1-mesa python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && chown -R vscode:vscode /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
USER vscode
RUN flutter config --enable-web --no-analytics && flutter precache --web
```

## Flutter repository: .devcontainer/devcontainer.json

```json
{
  "name": "Student Pocket - Flutter web",
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "forwardPorts": [8080],
  "portsAttributes": { "8080": { "label": "Student Pocket", "onAutoForward": "notify", "protocol": "http" } },
  "postCreateCommand": "bash scripts/setup.sh",
  "postStartCommand": "bash scripts/start.sh",
  "customizations": { "vscode": { "extensions": ["Dart-Code.dart-code", "Dart-Code.flutter"] } }
}
```

## Flutter repository: .gitattributes

```text
* text=auto eol=lf
```

## Flutter repository: .gitignore

```text
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.build/
.buildlog/
.history
.svn/
.swiftpm/
migrate_working_dir/

# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

# The .vscode folder contains launch configuration and tasks you configure in
# VS Code which you may wish to be included in version control, so this line
# is commented out by default.
#.vscode/

# Flutter/Dart/Pub related
/config/app.json
/.logs/
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins-dependencies
.pub-cache/
.pub/
/build/
/coverage/

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

# Android Studio will place build artifacts here
/android/app/debug
/android/app/profile
/android/app/release

# Widget Preview related
.widget_preview/
```

## Flutter repository: pubspec.yaml

```yaml
name: student_management_flutter
description: "A new Flutter project."
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
# Read more about Android versioning at https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is used as CFBundleVersion.
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build suffix.
version: 1.0.0+1

environment:
  sdk: ^3.13.2

# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.18.3

dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^6.0.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package
```

## Flutter repository: analysis_options.yaml

```yaml
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.

# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - build/**
    - web/**

linter:
  # The lint rules applied to this project can be customized in the
  # section below to disable rules from the `package:flutter_lints/flutter.yaml`
  # included above or to enable additional rules. A list of all available lints
  # and their documentation is published at https://dart.dev/lints.
  #
  # Instead of disabling a lint rule for the entire project in the
  # section below, it can also be suppressed for a single line of code
  # or a specific dart file by using the `// ignore: name_of_lint` and
  # `// ignore_for_file: name_of_lint` syntax on the line or in the file
  # producing the lint.
  rules:
    # avoid_print: false  # Uncomment to disable the `avoid_print` rule
    # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule

# Additional information about this file can be found at
# https://dart.dev/guides/language/analysis-options
```

## Flutter repository: config/app.example.json

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REFERENCE.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_YOUR_PUBLIC_KEY"
}
```

## Flutter repository: lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.contains('YOUR_') ||
      key.contains('YOUR_') ||
      url.isEmpty ||
      !key.startsWith('sb_publishable_')) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add your Supabase URL and publishable key to config/app.json, then rebuild the app. Never use a database password or secret key here.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  try {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    runApp(
      StudentApp(
        repository: SupabaseStudentRepository(Supabase.instance.client),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The app could not start. Check config/app.json and your connection, then refresh.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

## Flutter repository: lib/student.dart

```dart
class Student {
  const Student({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.course,
    required this.year,
    this.updatedAt,
  });
  final int id;
  final String number, firstName, lastName, email, course;
  final int year;
  final String? updatedAt;
  String get name => '$firstName $lastName';
  String get initials =>
      '${firstName.isEmpty ? '?' : firstName[0]}${lastName.isEmpty ? '' : lastName[0]}'
          .toUpperCase();
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: (json['id'] as num).toInt(),
    number: json['student_number'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    email: json['email'] as String,
    course: json['course'] as String,
    year: (json['year_level'] as num).toInt(),
    updatedAt: json['updated_at'] as String?,
  );
}

class StudentDraft {
  const StudentDraft({
    required this.number,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.course,
    required this.year,
  });
  final String number, firstName, lastName, email, course;
  final int year;
  Map<String, dynamic> toJson() => {
    'student_number': number.trim(),
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'email': email.trim(),
    'course': course.trim(),
    'year_level': year,
  };
  static String? requiredText(String? value, String label, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter $label.';
    if (text.length > max) return 'Use $max characters or fewer.';
    return null;
  }

  static String? emailError(String? value) {
    final required = requiredText(value, 'an email address', 255);
    if (required != null) return required;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class StudentPage {
  const StudentPage(this.students, this.hasMore);
  final List<Student> students;
  final bool hasMore;
}
```

## Flutter repository: lib/repository.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student.dart';

abstract class StudentRepository {
  String? get accountEmail;
  Stream<void> get authChanges;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<bool> hasAccess();
  Future<StudentPage> fetch({String search = '', int page = 0});
  Future<void> save(StudentDraft draft, {Student? original});
  Future<void> delete(Student student);
}

class SupabaseStudentRepository implements StudentRepository {
  SupabaseStudentRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 20;
  @override
  String? get accountEmail => client.auth.currentUser?.email;
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
  @override
  Future<bool> hasAccess() async =>
      await client.rpc('student_app_has_access') == true;
  @override
  Future<StudentPage> fetch({String search = '', int page = 0}) async {
    if (!await hasAccess()) {
      throw const AppFailure(
        'Your account is not approved. Ask the project owner for access.',
      );
    }
    final data = await client.rpc(
      'student_app_search',
      params: {
        'search_term': search.trim(),
        'offset_rows': page * pageSize,
        'page_size': pageSize + 1,
      },
    );
    final rows = (data as List)
        .map((row) => Student.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    return StudentPage(rows.take(pageSize).toList(), rows.length > pageSize);
  }

  @override
  Future<void> save(StudentDraft draft, {Student? original}) async {
    if (original == null) {
      await client
          .from('students')
          .insert(draft.toJson())
          .select('id')
          .single();
    } else {
      var query = client
          .from('students')
          .update(draft.toJson())
          .eq('id', original.id);
      if (original.updatedAt != null) {
        query = query.eq('updated_at', original.updatedAt!);
      }
      final result = await query.select('id');
      if (result.isEmpty) {
        throw const AppFailure(
          'This record changed or is no longer available. Refresh the list and try again.',
        );
      }
    }
  }

  @override
  Future<void> delete(Student student) async {
    var query = client.from('students').delete().eq('id', student.id);
    if (student.updatedAt != null) {
      query = query.eq('updated_at', student.updatedAt!);
    }
    final result = await query.select('id');
    if (result.isEmpty) {
      throw const AppFailure(
        'This record changed or is no longer available. Refresh before deleting.',
      );
    }
  }
}

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is AuthException) {
    if (error.code == 'invalid_credentials') {
      return 'The email or password is incorrect.';
    }
    if (error.code == 'email_not_confirmed') {
      return 'Your email is not confirmed. Ask the project owner to check your account.';
    }
    if (error.statusCode == '429') {
      return 'Too many attempts. Wait a moment before trying again.';
    }
    return 'Sign-in failed. Check your connection and account details.';
  }
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return error.message.contains('student_number')
          ? 'That student number is already in use.'
          : 'That email address is already in use.';
    }
    if (error.code == '42501') {
      return 'You do not have permission to change student records.';
    }
    if (error.code == '23514' || error.code == '23502') {
      return 'Check all required fields. Year level must be from 1 to 6.';
    }
    if (error.code == 'PGRST202' || error.code == '42P01') {
      return 'The database setup is incomplete. Ask the project owner to run the Flutter database migration.';
    }
    if (error.code == 'PGRST301' || error.code == 'PGRST303') {
      return 'Your session expired. Sign out and sign in again.';
    }
  }
  return 'We could not connect. Check your internet connection and try again.';
}
```

## Flutter repository: lib/app.dart

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'repository.dart';
import 'student.dart';

const ink = Color(0xFF182D47);
const accent = Color(0xFF315DDA);

class StudentApp extends StatelessWidget {
  const StudentApp({super.key, required this.repository});
  final StudentRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Student Pocket',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F8FC),
        foregroundColor: ink,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
      ),
    ),
    builder: (context, child) => MobileFrame(child: child!),
    home: StreamBuilder<void>(
      stream: repository.authChanges,
      builder: (context, _) => repository.accountEmail == null
          ? LoginScreen(repository: repository)
          : AccessGate(
              key: ValueKey(repository.accountEmail),
              repository: repository,
            ),
    ),
  );
}

class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final framed = box.maxWidth > 600;
      return ColoredBox(
        color: const Color(0xFFE9EEF8),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(framed ? 20 : 0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: framed ? 920 : double.infinity,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(framed ? 28 : 0),
                boxShadow: framed
                    ? [
                        const BoxShadow(
                          color: Color(0x1F203961),
                          blurRadius: 40,
                          offset: Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(framed ? 28 : 0),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repository});
  final StudentRepository repository;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFE3EAFF),
                    child: Icon(Icons.school_rounded, size: 30, color: accent),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'STUDENT POCKET',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your directory.\nA little closer.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign in to manage the same student records used by your Laravel website.',
                  style: TextStyle(color: Color(0xFF68768D), height: 1.6),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: StudentDraft.emailError,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _hide ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _hide = !_hide),
                      icon: Icon(
                        _hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Enter your password.' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ErrorNotice(_error!),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Signing in…' : 'Sign in'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Accounts are provided by your project owner.\nNeed access or a password reset? Ask your teacher.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68768D),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccessGate extends StatefulWidget {
  const AccessGate({super.key, required this.repository});
  final StudentRepository repository;
  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  late Future<bool> _access;
  @override
  void initState() {
    super.initState();
    _access = widget.repository.hasAccess();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, result) {
      if (result.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (result.data == true) {
        return StudentHome(repository: widget.repository);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Account access')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 52,
                  color: accent,
                ),
                const SizedBox(height: 20),
                Text(
                  result.hasError ? friendlyError(result.error!) : 'Your account has not been approved for the student directory. Ask your project owner to enable access.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      setState(() => _access = widget.repository.hasAccess()),
                  child: const Text('Check again'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await widget.repository.signOut();
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, friendlyError(e));
                      }
                    }
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.repository});
  final StudentRepository repository;
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final _search = TextEditingController();
  Timer? _debounce;
  StudentPage? _data;
  String? _error;
  bool _loading = true;
  int _page = 0, _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.fetch(
        search: _search.text,
        page: _page,
      );
      if (mounted && request == _request) setState(() => _data = data);
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Student? student]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StudentForm(repository: widget.repository, student: student),
      ),
    );
    if (saved == true && mounted) {
      showMessage(
        context,
        student == null ? 'Student added.' : 'Student updated.',
      );
      await _load();
    }
  }

  Future<void> _details(Student student) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StudentDetails(repository: widget.repository, student: student),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Student Pocket',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh students',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (sheet) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Signed in',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.repository.accountEmail ?? ''),
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () async {
                        Navigator.pop(sheet);
                        try {
                          await widget.repository.signOut();
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, friendlyError(e));
                          }
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      backgroundColor: accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Add student'),
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
          children: [
            const Text(
              'A place for\nevery student.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: ink,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Search, organize, and keep details up to date.',
              style: TextStyle(color: Color(0xFF68768D), height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search students',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _page = 0;
                          _debounce?.cancel();
                          _load();
                        },
                      ),
              ),
              onChanged: (_) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  _page = 0;
                  _load();
                });
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'DIRECTORY',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 11,
                    color: Color(0xFF68768D),
                  ),
                ),
                const Spacer(),
                Text(
                  'Page ${_page + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68768D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              ErrorNotice(_error!),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ] else if (!_loading && (_data?.students.isEmpty ?? true))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    const Icon(Icons.school_outlined, size: 48, color: accent),
                    const SizedBox(height: 18),
                    Text(
                      _search.text.isEmpty
                          ? 'Your directory starts here'
                          : 'No matching students',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _search.text.isEmpty
                          ? 'Tap Add student to create the first record.'
                          : 'Try another name, number, email, or course.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...(_data?.students ?? []).map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _details(student),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEAF0FF),
                              foregroundColor: accent,
                              child: Text(
                                student.initials,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    student.number,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF68768D),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${student.course} · Year ${student.year}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF8D9AB0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_page > 0 || (_data?.hasMore ?? false))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _loading || _page == 0
                        ? null
                        : () {
                            _page--;
                            _load();
                          },
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: _loading || !(_data?.hasMore ?? false)
                        ? null
                        : () {
                            _page++;
                            _load();
                          },
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class StudentForm extends StatefulWidget {
  const StudentForm({super.key, required this.repository, this.student});
  final StudentRepository repository;
  final Student? student;
  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _number, _first, _last, _email, _course;
  int? _year;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _number = TextEditingController(text: s?.number);
    _first = TextEditingController(text: s?.firstName);
    _last = TextEditingController(text: s?.lastName);
    _email = TextEditingController(text: s?.email);
    _course = TextEditingController(text: s?.course);
    _year = s?.year;
  }

  @override
  void dispose() {
    for (final c in [_number, _first, _last, _email, _course]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        StudentDraft(
          number: _number.text,
          firstName: _first.text,
          lastName: _last.text,
          email: _email.text,
          course: _course.text,
          year: _year!,
        ),
        original: widget.student,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int max, {
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      maxLength: max,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      textCapitalization: email
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: email
          ? StudentDraft.emailError
          : (v) => StudentDraft.requiredText(v, label.toLowerCase(), max),
      textInputAction: TextInputAction.next,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.student == null ? 'Add student' : 'Edit student'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'The details that matter.',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All fields are required.',
                style: TextStyle(color: Color(0xFF68768D)),
              ),
              const SizedBox(height: 26),
              _field(_number, 'Student number', 30),
              _field(_first, 'First name', 100),
              _field(_last, 'Last name', 100),
              _field(_email, 'Email', 255, email: true),
              _field(_course, 'Course', 120),
              DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Year level'),
                items: List.generate(
                  6,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Year ${i + 1}'),
                  ),
                ),
                onChanged: _saving ? null : (v) => setState(() => _year = v),
                validator: (v) => v == null ? 'Choose a year level.' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: ErrorNotice(_error!),
                ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save student'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StudentDetails extends StatefulWidget {
  const StudentDetails({
    super.key,
    required this.repository,
    required this.student,
  });
  final StudentRepository repository;
  final Student student;
  @override
  State<StudentDetails> createState() => _StudentDetailsState();
}

class _StudentDetailsState extends State<StudentDetails> {
  bool _deleting = false;
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this student?'),
        content: Text(
          '${widget.student.name}\n${widget.student.number}\n\nThis permanently removes the record from both apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.delete(widget.student);
      if (mounted) {
        showMessage(context, 'Student deleted.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Student profile')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(26),
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFFE3EAFF),
                child: Text(
                  s.initials,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                s.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF68768D)),
              ),
              const SizedBox(height: 28),
              ...{
                'Email': s.email,
                'Course': s.course,
                'Year level': 'Year ${s.year}',
              }.entries.map(
                (e) => Card(
                  elevation: 0,
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF68768D),
                      ),
                    ),
                    subtitle: Text(
                      e.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _deleting
                    ? null
                    : () async {
                        final saved = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => StudentForm(
                              repository: widget.repository,
                              student: s,
                            ),
                          ),
                        );
                        if (saved == true && context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit student'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deleting ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB33A4E),
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(_deleting ? 'Deleting…' : 'Delete student'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF9B2B3E))),
    ),
  );
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
```

## Flutter repository: scripts/setup.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter config --enable-web --no-analytics
flutter pub get
if [ ! -f config/app.json ]; then
    cp config/app.example.json config/app.json
fi
bash scripts/start.sh
```

## Flutter repository: scripts/start.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .logs
if [ ! -f config/app.json ]; then cp config/app.example.json config/app.json; fi
if python3 -c 'import socket; s=socket.socket(); exit(s.connect_ex(("127.0.0.1",8080)))'; then
    echo 'Student Pocket is already running on port 8080.'
    exit 0
fi
flutter build web --dart-define-from-file=config/app.json
setsid -f python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web >.logs/server.log 2>&1 </dev/null
for attempt in {1..30}; do
    if curl --silent --fail http://127.0.0.1:8080/ >/dev/null; then
        echo 'Student Pocket is ready. Open forwarded port 8080.'
        exit 0
    fi
    sleep 1
done
tail -20 .logs/server.log
exit 1
```

## Flutter repository: scripts/rebuild.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter analyze
flutter test
flutter build web --dart-define-from-file=config/app.json
echo 'Build complete. Refresh the browser. If port 8080 is stopped, run bash scripts/start.sh.'
```

## Flutter repository: test/student_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:student_management_flutter/student.dart';

void main() {
  test('required fields reject blanks and overlong input', () {
    expect(StudentDraft.requiredText('  ', 'a name', 100), isNotNull);
    expect(StudentDraft.requiredText('a' * 101, 'a name', 100), isNotNull);
    expect(StudentDraft.requiredText(' Jamie ', 'a name', 100), isNull);
  });
  test('email validation rejects malformed addresses', () {
    for (final email in [
      '',
      'abc',
      'a@b',
      'a b@example.test',
      'a@@example.test',
    ]) {
      expect(StudentDraft.emailError(email), isNotNull);
    }
    expect(StudentDraft.emailError('jamie@example.test'), isNull);
  });
  test('draft trims values and keeps year numeric', () {
    const draft = StudentDraft(
      number: ' A-01 ',
      firstName: ' Jamie ',
      lastName: ' Santos ',
      email: ' jamie@example.test ',
      course: ' IT ',
      year: 2,
    );
    expect(draft.toJson(), {
      'student_number': 'A-01',
      'first_name': 'Jamie',
      'last_name': 'Santos',
      'email': 'jamie@example.test',
      'course': 'IT',
      'year_level': 2,
    });
  });
  test('student parses database record and version for concurrency checks', () {
    final student = Student.fromJson({
      'id': 2,
      'student_number': 'A-01',
      'first_name': 'Jamie',
      'last_name': 'Santos',
      'email': 'jamie@example.test',
      'course': 'IT',
      'year_level': 2,
      'updated_at': '2026-11-05T00:00:00',
    });
    expect(student.name, 'Jamie Santos');
    expect(student.initials, 'JS');
    expect(student.updatedAt, isNotNull);
  });
}
```

## Flutter repository: test/app_test.dart

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_management_flutter/app.dart';
import 'package:student_management_flutter/repository.dart';
import 'package:student_management_flutter/student.dart';

class MemoryRepository implements StudentRepository {
  final changes = StreamController<void>.broadcast();
  String? email;
  bool approved = true;
  final records = <Student>[];
  @override
  String? get accountEmail => email;
  @override
  Stream<void> get authChanges => changes.stream;
  @override
  Future<void> signIn(String email, String password) async {
    this.email = email;
    changes.add(null);
  }

  @override
  Future<void> signOut() async {
    email = null;
    changes.add(null);
  }

  @override
  Future<bool> hasAccess() async => approved;
  @override
  Future<StudentPage> fetch({String search = '', int page = 0}) async =>
      StudentPage(
        records
            .where(
              (s) => '${s.name} ${s.number} ${s.course}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
            )
            .toList(),
        false,
      );
  @override
  Future<void> save(StudentDraft draft, {Student? original}) async {
    if (records.any((s) => s.number == draft.number && s.id != original?.id)) {
      throw const AppFailure('That student number is already in use.');
    }
    records.removeWhere((s) => s.id == original?.id);
    records.add(
      Student(
        id: original?.id ?? 1,
        number: draft.number,
        firstName: draft.firstName,
        lastName: draft.lastName,
        email: draft.email,
        course: draft.course,
        year: draft.year,
      ),
    );
  }

  @override
  Future<void> delete(Student student) async =>
      records.removeWhere((s) => s.id == student.id);
}

void main() {
  testWidgets('login rejects empty input and enters approved directory', (
    tester,
  ) async {
    final repo = MemoryRepository();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'teacher@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'classroom-password',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Your directory starts here'), findsOneWidget);
  });
  testWidgets('unapproved accounts cannot enter the directory', (tester) async {
    final repo = MemoryRepository()
      ..email = 'pending@example.test'
      ..approved = false;
    addTearDown(repo.changes.close);
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('has not been approved'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
  testWidgets('student form creates, edits, searches, and confirms deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(460, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository()..email = 'teacher@example.test';
    addTearDown(repo.changes.close);
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final values = [
      'CLASS-001',
      'Jamie',
      'Santos',
      'jamie@example.test',
      'Information Technology',
    ];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year 2').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save student'));
    await tester.tap(find.text('Save student'));
    await tester.pumpAndSettle();
    expect(repo.records.single.name, 'Jamie Santos');
    await tester.tap(find.text('Jamie Santos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit student'));
    await tester.tap(find.text('Edit student'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(4),
      'Computer Science',
    );
    await tester.ensureVisible(find.text('Save student'));
    await tester.tap(find.text('Save student'));
    await tester.pumpAndSettle();
    expect(repo.records.single.course, 'Computer Science');
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('No matching students'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jamie Santos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete student'));
    await tester.tap(find.text('Delete student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.records, hasLength(1));
    await tester.tap(find.text('Delete student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.records, isEmpty);
  });
  testWidgets('small phone viewport stays usable', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Sign in'));
    expect(find.text('Sign in'), findsOneWidget);
  });
}
```

## Flutter repository: .github/workflows/flutter.yml

```yaml
name: Flutter checks
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.47.2'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build web --dart-define-from-file=config/app.example.json
```
