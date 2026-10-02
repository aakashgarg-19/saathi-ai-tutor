import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/cached_get.dart';
import '../../core/storage/local_store.dart';
import '../classroom/classroom_repository.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.concept,
    this.answerIndex,
    this.explanation = '',
  });

  final String question;
  final List<String> options;
  final String concept;

  /// Only present after the student has submitted (in the review).
  final int? answerIndex;
  final String explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question: json['question'] as String,
    options: (json['options'] as List).cast<String>(),
    concept: json['concept'] as String,
    answerIndex: json['answer_index'] as int?,
    explanation: json['explanation'] as String? ?? '',
  );
}

class Quiz {
  const Quiz({
    required this.id,
    required this.classroomId,
    required this.chapterId,
    required this.title,
    required this.createdAt,
    required this.questions,
    required this.myScore,
    required this.attemptCount,
  });

  final int id;
  final int classroomId;
  final int chapterId;
  final String title;
  final DateTime createdAt;
  final List<QuizQuestion> questions;
  final int? myScore;
  final int attemptCount;

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    id: json['id'] as int,
    classroomId: json['classroom_id'] as int,
    chapterId: json['chapter_id'] as int,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    questions: [
      for (final q in json['questions'] as List)
        QuizQuestion.fromJson(q as Map<String, dynamic>),
    ],
    myScore: json['my_score'] as int?,
    attemptCount: json['attempt_count'] as int? ?? 0,
  );
}

class AttemptResult {
  const AttemptResult(this.score, this.total, this.review, this.yourAnswers);

  final int score;
  final int total;
  final List<QuizQuestion> review;
  final List<int> yourAnswers;

  factory AttemptResult.fromJson(Map<String, dynamic> json) =>
      AttemptResult(json['score'] as int, json['total'] as int, [
        for (final q in json['review'] as List)
          QuizQuestion.fromJson(q as Map<String, dynamic>),
      ], (json['your_answers'] as List).cast<int>());
}

class QuizResults {
  const QuizResults(this.attempts, this.perQuestionCorrect);

  final List<({String name, int score, int total})> attempts;
  final List<int> perQuestionCorrect;

  factory QuizResults.fromJson(Map<String, dynamic> json) => QuizResults([
    for (final a in (json['attempts'] as List).cast<Map<String, dynamic>>())
      (
        name: a['student_name'] as String,
        score: a['score'] as int,
        total: a['total'] as int,
      ),
  ], (json['per_question_correct'] as List).cast<int>());
}

class QuizRepository {
  QuizRepository(this._api);

  final ApiClient _api;

  Future<Quiz> generate({
    required int classroomId,
    required int chapterId,
    required int numQuestions,
    required String language,
    List<String>? concepts,
  }) async => Quiz.fromJson(
    await _api.post(
      '/classrooms/$classroomId/quizzes',
      body: {
        'chapter_id': chapterId,
        'num_questions': numQuestions,
        'language': language,
        if (concepts != null && concepts.isNotEmpty) 'concepts': concepts,
      },
    ),
  );

  Future<Quiz> get(int quizId) async =>
      Quiz.fromJson(await _api.get('/quizzes/$quizId'));

  Future<AttemptResult> attempt(int quizId, List<int> answers) async =>
      AttemptResult.fromJson(
        await _api.post(
          '/quizzes/$quizId/attempts',
          body: {'answers': answers},
        ),
      );

  Future<QuizResults> results(int quizId) async =>
      QuizResults.fromJson(await _api.get('/quizzes/$quizId/results'));
}

final quizRepositoryProvider = Provider(
  (ref) => QuizRepository(ref.watch(apiClientProvider)),
);

final classroomQuizzesProvider = FutureProvider.autoDispose
    .family<List<Quiz>, int>((ref, classroomId) {
      return cachedGet(
        ref.watch(apiClientProvider),
        ref.watch(localStoreProvider),
        '/classrooms/$classroomId/quizzes',
        (json) => [
          for (final q in json as List)
            Quiz.fromJson(q as Map<String, dynamic>),
        ],
      );
    });

/// Every quiz across all classrooms a student belongs to, newest first.
final studentQuizzesProvider = FutureProvider.autoDispose<List<Quiz>>((
  ref,
) async {
  final classrooms = await ref.watch(myClassroomsProvider.future);
  final lists = await Future.wait([
    for (final c in classrooms)
      ref.watch(classroomQuizzesProvider(c.id).future),
  ]);
  return lists.expand((l) => l).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final quizProvider = FutureProvider.autoDispose.family<Quiz, int>(
  (ref, id) => ref.watch(quizRepositoryProvider).get(id),
);

final quizResultsProvider = FutureProvider.autoDispose.family<QuizResults, int>(
  (ref, id) => ref.watch(quizRepositoryProvider).results(id),
);
