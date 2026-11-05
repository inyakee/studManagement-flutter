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
