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
