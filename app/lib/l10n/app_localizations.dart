import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Saathi'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your study companion'**
  String get tagline;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get name;

  /// No description provided for @iAmA.
  ///
  /// In en, this message translates to:
  /// **'I am a'**
  String get iAmA;

  /// No description provided for @student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// No description provided for @teacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get haveAccount;

  /// No description provided for @demoHint.
  ///
  /// In en, this message translates to:
  /// **'Demo: student@saathi.dev / teacher@saathi.dev, password demo1234'**
  String get demoHint;

  /// No description provided for @learn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learn;

  /// No description provided for @quizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get quizzes;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class {grade}'**
  String classLabel(int grade);

  /// No description provided for @joinClass.
  ///
  /// In en, this message translates to:
  /// **'Join your class'**
  String get joinClass;

  /// No description provided for @joinCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Code from your teacher, e.g. DEMO7A'**
  String get joinCodeHint;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @joinedClass.
  ///
  /// In en, this message translates to:
  /// **'Joined {name}'**
  String joinedClass(String name);

  /// No description provided for @askHint.
  ///
  /// In en, this message translates to:
  /// **'Type or speak your doubt…'**
  String get askHint;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listening;

  /// No description provided for @emptyChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything from this chapter'**
  String get emptyChatTitle;

  /// No description provided for @emptyChatBody.
  ///
  /// In en, this message translates to:
  /// **'Saathi answers from your textbook and shows you where the answer came from.'**
  String get emptyChatBody;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'From your textbook'**
  String get sources;

  /// No description provided for @queuedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline. It will be answered when you\'re back online.'**
  String get queuedOffline;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 doubt waiting to sync} other{{count} doubts waiting to sync}}'**
  String pendingSync(int count);

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @wasHelpful.
  ///
  /// In en, this message translates to:
  /// **'Was this helpful?'**
  String get wasHelpful;

  /// No description provided for @thanksFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the feedback!'**
  String get thanksFeedback;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @scanQuestion.
  ///
  /// In en, this message translates to:
  /// **'Scan a question'**
  String get scanQuestion;

  /// No description provided for @ocrNoText.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read any text. Try a clearer photo.'**
  String get ocrNoText;

  /// No description provided for @cachedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Instant answer'**
  String get cachedAnswer;

  /// No description provided for @noQuizzes.
  ///
  /// In en, this message translates to:
  /// **'No quizzes yet. Your teacher will assign one soon.'**
  String get noQuizzes;

  /// No description provided for @questionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String questionsCount(int count);

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}/{total}'**
  String score(int score, int total);

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @yourResult.
  ///
  /// In en, this message translates to:
  /// **'Your result'**
  String get yourResult;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @myClassrooms.
  ///
  /// In en, this message translates to:
  /// **'My classrooms'**
  String get myClassrooms;

  /// No description provided for @createClassroom.
  ///
  /// In en, this message translates to:
  /// **'New classroom'**
  String get createClassroom;

  /// No description provided for @classroomName.
  ///
  /// In en, this message translates to:
  /// **'Classroom name'**
  String get classroomName;

  /// No description provided for @grade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get grade;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 student} other{{count} students}}'**
  String students(int count);

  /// No description provided for @joinCode.
  ///
  /// In en, this message translates to:
  /// **'Join code'**
  String get joinCode;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Class insights'**
  String get dashboard;

  /// No description provided for @doubtsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Doubts (7 days)'**
  String get doubtsThisWeek;

  /// No description provided for @activeStudents.
  ///
  /// In en, this message translates to:
  /// **'Active students'**
  String get activeStudents;

  /// No description provided for @helpfulRate.
  ///
  /// In en, this message translates to:
  /// **'Found helpful'**
  String get helpfulRate;

  /// No description provided for @confusingConcepts.
  ///
  /// In en, this message translates to:
  /// **'What your class is asking about'**
  String get confusingConcepts;

  /// No description provided for @noDoubtsYet.
  ///
  /// In en, this message translates to:
  /// **'No doubts yet this week.'**
  String get noDoubtsYet;

  /// No description provided for @liveFeed.
  ///
  /// In en, this message translates to:
  /// **'Live doubts'**
  String get liveFeed;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @unhelpfulCount.
  ///
  /// In en, this message translates to:
  /// **'{count} not helpful'**
  String unhelpfulCount(int count);

  /// No description provided for @createQuiz.
  ///
  /// In en, this message translates to:
  /// **'Create quiz'**
  String get createQuiz;

  /// No description provided for @chapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapter;

  /// No description provided for @numQuestions.
  ///
  /// In en, this message translates to:
  /// **'Number of questions'**
  String get numQuestions;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @focusConcepts.
  ///
  /// In en, this message translates to:
  /// **'Focus concepts'**
  String get focusConcepts;

  /// No description provided for @focusConceptsHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to target what the class asks most'**
  String get focusConceptsHint;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// No description provided for @quizCreated.
  ///
  /// In en, this message translates to:
  /// **'Quiz assigned to the class'**
  String get quizCreated;

  /// No description provided for @attempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No attempts} =1{1 attempt} other{{count} attempts}}'**
  String attempts(int count);

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @perQuestion.
  ///
  /// In en, this message translates to:
  /// **'Correct answers per question'**
  String get perQuestion;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWrong;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
