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
