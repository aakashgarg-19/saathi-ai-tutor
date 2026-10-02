import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/cached_get.dart';
import '../../core/storage/local_store.dart';

class Classroom {
  const Classroom({
    required this.id,
    required this.name,
    required this.grade,
    required this.joinCode,
    required this.studentCount,
  });

  final int id;
  final String name;
  final int grade;
  final String joinCode;
  final int studentCount;

  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
    id: json['id'] as int,
    name: json['name'] as String,
    grade: json['grade'] as int,
    joinCode: json['join_code'] as String,
    studentCount: json['student_count'] as int? ?? 0,
  );
}

class ConceptStat {
  const ConceptStat(
    this.concept,
    this.chapterTitle,
    this.count,
    this.unhelpful,
  );

  final String concept;
  final String chapterTitle;
  final int count;
  final int unhelpful;

  factory ConceptStat.fromJson(Map<String, dynamic> json) => ConceptStat(
    json['concept'] as String,
    json['chapter_title'] as String,
    json['count'] as int,
    json['unhelpful'] as int,
  );
}

class RecentDoubt {
  const RecentDoubt(
    this.question,
    this.studentName,
    this.concepts,
    this.createdAt,
  );

  final String question;
  final String studentName;
  final List<String> concepts;
  final DateTime createdAt;

  factory RecentDoubt.fromJson(Map<String, dynamic> json) => RecentDoubt(
    json['question'] as String,
    json['student_name'] as String,
    (json['concepts'] as List).cast<String>(),
    DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

class Insights {
  const Insights({
    required this.totalDoubts,
    required this.activeStudents,
    required this.totalStudents,
    required this.helpfulRate,
    required this.concepts,
    required this.recent,
  });

  final int totalDoubts;
  final int activeStudents;
  final int totalStudents;
  final double? helpfulRate;
  final List<ConceptStat> concepts;
  final List<RecentDoubt> recent;

  factory Insights.fromJson(Map<String, dynamic> json) => Insights(
    totalDoubts: json['total_doubts'] as int,
    activeStudents: json['active_students'] as int,
    totalStudents: json['total_students'] as int,
    helpfulRate: (json['helpful_rate'] as num?)?.toDouble(),
    concepts: [
      for (final c in json['concepts'] as List)
        ConceptStat.fromJson(c as Map<String, dynamic>),
    ],
    recent: [
      for (final r in json['recent'] as List)
        RecentDoubt.fromJson(r as Map<String, dynamic>),
    ],
  );
}

class ClassroomRepository {
  ClassroomRepository(this._api);

  final ApiClient _api;

  Future<Classroom> create(String name, int grade) async => Classroom.fromJson(
    await _api.post('/classrooms', body: {'name': name, 'grade': grade}),
  );

  Future<Classroom> join(String code) async => Classroom.fromJson(
    await _api.post('/classrooms/join', body: {'join_code': code}),
  );

  Future<Insights> insights(int classroomId) async =>
      Insights.fromJson(await _api.get('/classrooms/$classroomId/insights'));
}

final classroomRepositoryProvider = Provider(
  (ref) => ClassroomRepository(ref.watch(apiClientProvider)),
);

final myClassroomsProvider = FutureProvider<List<Classroom>>((ref) {
  return cachedGet(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
    '/classrooms',
    (json) => [
      for (final c in json as List)
        Classroom.fromJson(c as Map<String, dynamic>),
    ],
  );
});

final insightsProvider = FutureProvider.autoDispose.family<Insights, int>(
  (ref, classroomId) =>
      ref.watch(classroomRepositoryProvider).insights(classroomId),
);
