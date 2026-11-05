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
