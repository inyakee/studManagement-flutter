# Complete code reference

Follow STUDENT_GUIDE.md. Copy inside the code fences. The first file belongs in Laravel; all remaining files belong in Flutter. Use the short initial devcontainer configuration from the guide until scripts exist. Standard web files are created by flutter create.

## Laravel: database/migrations/2026_11_05_000001_enable_flutter_demo_access.php

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
-- Classroom demonstration: anonymous clients can manage fictional students.
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.students FROM anon, authenticated;
GRANT SELECT, DELETE ON public.students TO anon;
GRANT INSERT (student_number, first_name, last_name, email, course, year_level),
    UPDATE (student_number, first_name, last_name, email, course, year_level)
    ON public.students TO anon;
REVOKE ALL ON SEQUENCE public.students_id_seq FROM anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.students_id_seq TO anon;

CREATE POLICY student_demo_read ON public.students FOR SELECT TO anon
    USING (true);
CREATE POLICY student_demo_insert ON public.students FOR INSERT TO anon
    WITH CHECK (true);
CREATE POLICY student_demo_update ON public.students FOR UPDATE TO anon
    USING (true)
    WITH CHECK (true);
CREATE POLICY student_demo_delete ON public.students FOR DELETE TO anon
    USING (true);

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
GRANT EXECUTE ON FUNCTION public.student_app_search(text, integer, integer) TO anon;
NOTIFY pgrst, 'reload schema';
SQL);
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }
        DB::unprepared(<<<'SQL'
DROP POLICY IF EXISTS student_demo_read ON public.students;
DROP POLICY IF EXISTS student_demo_insert ON public.students;
DROP POLICY IF EXISTS student_demo_update ON public.students;
DROP POLICY IF EXISTS student_demo_delete ON public.students;
DROP TRIGGER IF EXISTS student_app_validate_before_write ON public.students;
DROP FUNCTION IF EXISTS public.student_app_search(text, integer, integer);
DROP FUNCTION IF EXISTS public.student_app_validate_row();
REVOKE ALL ON public.students FROM anon;
REVOKE INSERT (student_number, first_name, last_name, email, course, year_level), UPDATE (student_number, first_name, last_name, email, course, year_level) ON public.students FROM anon;
REVOKE USAGE, SELECT ON SEQUENCE public.students_id_seq FROM anon, authenticated;
NOTIFY pgrst, 'reload schema';
SQL);
    }
};

```

## Flutter: .devcontainer/Dockerfile

```
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

## Flutter: .devcontainer/devcontainer.json

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

## Flutter: pubspec.yaml

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

## Flutter: .gitignore

```
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

## Flutter: .gitattributes

```
* text=auto eol=lf

```

## Flutter: config/app.example.json

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REFERENCE.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_YOUR_PUBLIC_KEY"
}

```

## Flutter: lib/main.dart

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
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
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

## Flutter: lib/student.dart

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

## Flutter: lib/repository.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student.dart';

abstract class StudentRepository {
  Future<StudentPage> fetch({String search = '', int page = 0});
  Future<void> save(StudentDraft draft, {Student? original});
  Future<void> delete(Student student);
}

class SupabaseStudentRepository implements StudentRepository {
  SupabaseStudentRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 20;
  @override
  Future<StudentPage> fetch({String search = '', int page = 0}) async {
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
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return error.message.contains('student_number')
          ? 'That student number is already in use.'
          : 'That email address is already in use.';
    }
    if (error.code == '42501') {
      return 'Demo database access is not enabled. Ask the project owner to check the classroom access rules.';
    }
    if (error.code == '23514' || error.code == '23502') {
      return 'Check all required fields. Year level must be from 1 to 6.';
    }
    if (error.code == 'PGRST202' || error.code == '42P01') {
      return 'The database setup is incomplete. Ask the project owner to run the Flutter database migration.';
    }
    if (error.code == 'PGRST301' || error.code == 'PGRST303') {
      return 'Check the Supabase project URL and publishable key, then rebuild the app.';
    }
  }
  return 'We could not connect. Check your internet connection and try again.';
}

```

## Flutter: lib/app.dart

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
    home: StudentHome(repository: repository),
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

## Flutter: scripts/setup.sh

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

## Flutter: scripts/start.sh

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

## Flutter: scripts/rebuild.sh

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

## Flutter: test/student_test.dart

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

## Flutter: test/app_test.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_management_flutter/app.dart';
import 'package:student_management_flutter/repository.dart';
import 'package:student_management_flutter/student.dart';

class MemoryRepository implements StudentRepository {
  bool fail = false;
  final records = <Student>[];
  @override
  Future<StudentPage> fetch({String search = '', int page = 0}) async {
    if (fail) throw const AppFailure('Connection unavailable.');
    return StudentPage(
      records
          .where(
            (s) => '${s.name} ${s.number} ${s.course}'.toLowerCase().contains(
              search.toLowerCase(),
            ),
          )
          .toList(),
      false,
    );
  }

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
  testWidgets('opens directory directly with no login', (tester) async {
    final repo = MemoryRepository();
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Your directory starts here'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
  testWidgets('connection errors can be retried', (tester) async {
    final repo = MemoryRepository()..fail = true;
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable.'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your directory starts here'), findsOneWidget);
  });
  testWidgets('student form creates, edits, searches, and confirms deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(460, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository();
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
    await tester.pumpWidget(StudentApp(repository: repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

```

## Flutter: .github/workflows/flutter.yml

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


## Laravel companion: scripts/verify-flutter-demo.php

Run this from the Laravel Codespace after applying the approved demo migration. It checks temporary transaction-only records and rolls back all its writes.

```php
<?php

require __DIR__.'/../vendor/autoload.php';
$app = require __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$db = Illuminate\Support\Facades\DB::connection();
if ($db->getDriverName() !== 'pgsql') { throw new RuntimeException('Use the configured Supabase PostgreSQL connection.'); }
$assert = function (bool $ok, string $message): void {
    if (!$ok) { throw new RuntimeException($message); }
    echo "PASS: $message\n";
};
$expectError = function (callable $operation, string $code) use ($db, $assert): void {
    $db->statement('SAVEPOINT expected_error');
    $caught = null;
    try { $operation(); } catch (Throwable $e) { $caught = $e; }
    $db->statement('ROLLBACK TO SAVEPOINT expected_error');
    $db->statement('RELEASE SAVEPOINT expected_error');
    $assert($caught !== null && (string) $caught->getCode() === $code, "Database rejects request with SQLSTATE $code");
};
$db->beginTransaction();
try {
    $db->statement('SET LOCAL ROLE anon');
    foreach (['users', 'sessions', 'password_reset_tokens'] as $table) {
        $p = $db->selectOne("SELECT has_table_privilege(current_user, ?, 'SELECT') AS allowed", ["public.$table"]);
        $assert(!$p->allowed, "Anonymous role cannot read $table");
    }
    $number = 'VERIFY-'.bin2hex(random_bytes(5));
    $email = strtolower($number).'@example.test';
    $row = $db->selectOne('INSERT INTO public.students (student_number, first_name, last_name, email, course, year_level) VALUES (?, ?, ?, ?, ?, ?) RETURNING *', [$number, '  Transaction  ', 'Demo', $email, 'Test Course', 2]);
    $assert($row->first_name === 'Transaction' && $row->created_at && $row->updated_at, 'Anonymous insert trims fields and fills timestamps');
    $found = $db->select('SELECT * FROM public.student_app_search(?, 0, 21)', [$number]);
    $assert(count($found) === 1 && $found[0]->id === $row->id, 'Search returns the saved record');
    $expectError(fn () => $db->statement('UPDATE public.students SET email = ? WHERE id = ?', ['invalid-email', $row->id]), '23514');
    $expectError(fn () => $db->statement('UPDATE public.students SET year_level = 7 WHERE id = ?', [$row->id]), '23514');
    $expectError(fn () => $db->statement('UPDATE public.students SET id = id WHERE id = ?', [$row->id]), '42501');
    $expectError(fn () => $db->statement('INSERT INTO public.students (student_number, first_name, last_name, email, course, year_level) VALUES (?, ?, ?, ?, ?, ?)', [$number, 'Duplicate', 'Demo', 'duplicate.'.$email, 'Test', 1]), '23505');
    $expectError(fn () => $db->statement('INSERT INTO public.students (student_number, first_name, last_name, email, course, year_level) VALUES (?, ?, ?, ?, ?, ?)', [$number.'X', 'Duplicate', 'Demo', $email, 'Test', 1]), '23505');
    $updated = $db->selectOne('UPDATE public.students SET course = ? WHERE id = ? RETURNING *', ['Updated Course', $row->id]);
    $assert($updated->course === 'Updated Course' && $updated->created_at === $row->created_at, 'Anonymous update works and preserves creation time');
    $assert($db->delete('DELETE FROM public.students WHERE id = ?', [$row->id]) === 1, 'Anonymous delete works');
    $assert(count($db->select('SELECT * FROM public.students WHERE id = ?', [$row->id])) === 0, 'Deleted fixture is absent');
} finally {
    $db->rollBack();
}
echo "All checks passed. Transaction rolled back; existing records were untouched.\n";
```
