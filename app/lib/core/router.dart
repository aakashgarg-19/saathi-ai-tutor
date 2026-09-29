import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/classroom/dashboard_screen.dart';
import '../features/classroom/student_home.dart';
import '../features/classroom/teacher_home.dart';
import '../features/doubts/ask_screen.dart';
import '../features/quiz/quiz_results_screen.dart';
import '../features/quiz/quiz_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever auth changes, without rebuilding the router.
  final authChanges = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref
    ..listen(
      authControllerProvider,
      (_, next) => authChanges.value = next,
      fireImmediately: true,
    )
    ..onDispose(authChanges.dispose);

  int idParam(GoRouterState s) => int.parse(s.pathParameters['id']!);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = authChanges.value;
      if (auth.isLoading && !auth.hasValue) return '/';
      final user = auth.value;
      final loc = state.matchedLocation;
      if (user == null) return loc == '/login' ? null : '/login';
      final home = user.isTeacher ? '/teacher' : '/student';
      if (loc == '/' || loc == '/login' || !loc.startsWith(home)) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/student',
        builder: (_, _) => const StudentHome(),
        routes: [
          GoRoute(
            path: 'chapter/:id',
            builder: (_, s) => AskScreen(chapterId: idParam(s)),
          ),
          GoRoute(
            path: 'quiz/:id',
            builder: (_, s) => QuizScreen(quizId: idParam(s)),
          ),
        ],
      ),
      GoRoute(
        path: '/teacher',
        builder: (_, _) => const TeacherHome(),
        routes: [
          GoRoute(
            path: 'classroom/:id',
            builder: (_, s) => DashboardScreen(classroomId: idParam(s)),
          ),
          GoRoute(
            path: 'quiz/:id',
            builder: (_, s) => QuizResultsScreen(quizId: idParam(s)),
          ),
        ],
      ),
    ],
  );
});
