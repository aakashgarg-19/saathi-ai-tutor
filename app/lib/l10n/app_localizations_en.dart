// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Saathi';

  @override
  String get tagline => 'Your study companion';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Create account';

  @override
  String get logout => 'Log out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Full name';

  @override
  String get iAmA => 'I am a';

  @override
  String get student => 'Student';

  @override
  String get teacher => 'Teacher';

  @override
  String get noAccount => 'New here? Create an account';

  @override
  String get haveAccount => 'Already have an account? Log in';

  @override
  String get demoHint =>
      'Demo: student@saathi.dev / teacher@saathi.dev, password demo1234';

  @override
  String get learn => 'Learn';

  @override
  String get quizzes => 'Quizzes';

  @override
  String get chapters => 'Chapters';

  @override
  String classLabel(int grade) {
    return 'Class $grade';
  }

  @override
  String get joinClass => 'Join your class';

  @override
  String get joinCodeHint => 'Code from your teacher, e.g. DEMO7A';

  @override
  String get join => 'Join';

  @override
  String joinedClass(String name) {
    return 'Joined $name';
  }

  @override
  String get askHint => 'Type or speak your doubt…';

  @override
  String get listening => 'Listening…';

  @override
  String get emptyChatTitle => 'Ask anything from this chapter';

  @override
  String get emptyChatBody =>
      'Saathi answers from your textbook and shows you where the answer came from.';

  @override
  String get sources => 'From your textbook';

  @override
  String get queuedOffline =>
      'Saved offline. It will be answered when you\'re back online.';

  @override
  String pendingSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doubts waiting to sync',
      one: '1 doubt waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get offline => 'You\'re offline';

  @override
  String get retry => 'Retry';

  @override
  String get wasHelpful => 'Was this helpful?';

  @override
  String get thanksFeedback => 'Thanks for the feedback!';

  @override
  String get listen => 'Listen';

  @override
  String get stop => 'Stop';

  @override
  String get scanQuestion => 'Scan a question';

  @override
  String get ocrNoText => 'Couldn\'t read any text. Try a clearer photo.';

  @override
  String get cachedAnswer => 'Instant answer';

  @override
  String get noQuizzes => 'No quizzes yet. Your teacher will assign one soon.';

  @override
  String questionsCount(int count) {
    return '$count questions';
  }

  @override
  String score(int score, int total) {
    return 'Score: $score/$total';
  }

  @override
  String get start => 'Start';

  @override
  String get next => 'Next';

  @override
  String get submit => 'Submit';

  @override
  String get yourResult => 'Your result';

  @override
  String get done => 'Done';

  @override
  String get myClassrooms => 'My classrooms';

  @override
  String get createClassroom => 'New classroom';

  @override
  String get classroomName => 'Classroom name';

  @override
  String get grade => 'Grade';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String students(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students',
      one: '1 student',
    );
    return '$_temp0';
  }

  @override
  String get joinCode => 'Join code';

  @override
  String get copied => 'Copied';

  @override
  String get dashboard => 'Class insights';

  @override
  String get doubtsThisWeek => 'Doubts (7 days)';

  @override
  String get activeStudents => 'Active students';

  @override
  String get helpfulRate => 'Found helpful';

  @override
  String get confusingConcepts => 'What your class is asking about';

  @override
  String get noDoubtsYet => 'No doubts yet this week.';

  @override
  String get liveFeed => 'Live doubts';

  @override
  String get live => 'LIVE';

  @override
  String unhelpfulCount(int count) {
    return '$count not helpful';
  }

  @override
  String get createQuiz => 'Create quiz';

  @override
  String get chapter => 'Chapter';

  @override
  String get numQuestions => 'Number of questions';

  @override
  String get language => 'Language';

  @override
  String get focusConcepts => 'Focus concepts';

  @override
  String get focusConceptsHint =>
      'Leave empty to target what the class asks most';

  @override
  String get generating => 'Generating…';

  @override
  String get quizCreated => 'Quiz assigned to the class';

  @override
  String attempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
      zero: 'No attempts',
    );
    return '$_temp0';
  }

  @override
  String get results => 'Results';

  @override
  String get perQuestion => 'Correct answers per question';

  @override
  String get somethingWrong => 'Something went wrong';
}
