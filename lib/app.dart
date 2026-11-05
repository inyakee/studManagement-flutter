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
