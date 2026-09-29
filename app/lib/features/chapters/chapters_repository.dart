import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/cached_get.dart';
import '../../core/storage/local_store.dart';

class Chapter {
  const Chapter({
    required this.id,
    required this.subject,
    required this.grade,
    required this.title,
    required this.concepts,
    required this.isReady,
  });

  final int id;
  final String subject;
  final int grade;
  final String title;
  final List<String> concepts;
  final bool isReady;

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json['id'] as int,
    subject: json['subject'] as String,
    grade: json['grade'] as int,
    title: json['title'] as String,
    concepts: (json['concepts'] as List).cast<String>(),
    isReady: json['status'] == 'ready',
  );
}

final chaptersProvider = FutureProvider<List<Chapter>>((ref) {
  return cachedGet(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
    '/chapters',
    (json) => [
      for (final c in json as List) Chapter.fromJson(c as Map<String, dynamic>),
    ],
  );
});

final chapterProvider = Provider.family<Chapter?, int>((ref, id) {
  final chapters = ref.watch(chaptersProvider).value ?? const [];
  for (final c in chapters) {
    if (c.id == id) return c;
  }
  return null;
});
