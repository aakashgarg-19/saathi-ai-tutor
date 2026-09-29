// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'साथी';

  @override
  String get tagline => 'आपका पढ़ाई का साथी';

  @override
  String get login => 'लॉग इन करें';

  @override
  String get register => 'खाता बनाएँ';

  @override
  String get logout => 'लॉग आउट';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get name => 'पूरा नाम';

  @override
  String get iAmA => 'मैं हूँ';

  @override
  String get student => 'विद्यार्थी';

  @override
  String get teacher => 'शिक्षक';

  @override
  String get noAccount => 'नए हैं? खाता बनाएँ';

  @override
  String get haveAccount => 'पहले से खाता है? लॉग इन करें';

  @override
  String get demoHint =>
      'डेमो: student@saathi.dev / teacher@saathi.dev, पासवर्ड demo1234';

  @override
  String get learn => 'पढ़ें';

  @override
  String get quizzes => 'क्विज़';

  @override
  String get chapters => 'अध्याय';

  @override
  String classLabel(int grade) {
    return 'कक्षा $grade';
  }

  @override
  String get joinClass => 'अपनी कक्षा से जुड़ें';

  @override
  String get joinCodeHint => 'शिक्षक का दिया कोड, जैसे DEMO7A';

  @override
  String get join => 'जुड़ें';

  @override
  String joinedClass(String name) {
    return '$name से जुड़ गए';
  }

  @override
  String get askHint => 'अपना सवाल लिखें या बोलें…';

  @override
  String get listening => 'सुन रहे हैं…';

  @override
  String get emptyChatTitle => 'इस अध्याय से कुछ भी पूछें';

  @override
  String get emptyChatBody =>
      'साथी आपकी किताब से जवाब देता है और बताता है कि जवाब कहाँ से आया।';

  @override
  String get sources => 'आपकी किताब से';

  @override
  String get queuedOffline =>
      'ऑफ़लाइन सेव किया गया। इंटरनेट आने पर जवाब मिलेगा।';

  @override
  String pendingSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सवाल सिंक होने का इंतज़ार कर रहे हैं',
      one: '1 सवाल सिंक होने का इंतज़ार कर रहा है',
    );
    return '$_temp0';
  }

  @override
  String get offline => 'आप ऑफ़लाइन हैं';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get wasHelpful => 'क्या यह मददगार था?';

  @override
  String get thanksFeedback => 'धन्यवाद!';

  @override
  String get listen => 'सुनें';

  @override
  String get stop => 'रोकें';

  @override
  String get scanQuestion => 'सवाल की फ़ोटो लें';

  @override
  String get ocrNoText => 'कोई टेक्स्ट नहीं पढ़ा जा सका। साफ़ फ़ोटो लें।';

  @override
  String get cachedAnswer => 'तुरंत जवाब';

  @override
  String get noQuizzes => 'अभी कोई क्विज़ नहीं है। शिक्षक जल्द देंगे।';

  @override
  String questionsCount(int count) {
    return '$count सवाल';
  }

  @override
  String score(int score, int total) {
    return 'अंक: $score/$total';
  }

  @override
  String get start => 'शुरू करें';

  @override
  String get next => 'आगे';

  @override
  String get submit => 'जमा करें';

  @override
  String get yourResult => 'आपका परिणाम';

  @override
  String get done => 'हो गया';

  @override
  String get myClassrooms => 'मेरी कक्षाएँ';

  @override
  String get createClassroom => 'नई कक्षा';

  @override
  String get classroomName => 'कक्षा का नाम';

  @override
  String get grade => 'कक्षा';

  @override
  String get create => 'बनाएँ';

  @override
  String get cancel => 'रद्द करें';

  @override
  String students(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विद्यार्थी',
      one: '1 विद्यार्थी',
    );
    return '$_temp0';
  }

  @override
  String get joinCode => 'जॉइन कोड';

  @override
  String get copied => 'कॉपी हो गया';

  @override
  String get dashboard => 'कक्षा की जानकारी';

  @override
  String get doubtsThisWeek => 'सवाल (7 दिन)';

  @override
  String get activeStudents => 'सक्रिय विद्यार्थी';

  @override
  String get helpfulRate => 'मददगार लगा';

  @override
  String get confusingConcepts => 'आपकी कक्षा क्या पूछ रही है';

  @override
  String get noDoubtsYet => 'इस हफ़्ते अभी कोई सवाल नहीं।';

  @override
  String get liveFeed => 'लाइव सवाल';

  @override
  String get live => 'लाइव';

  @override
  String unhelpfulCount(int count) {
    return '$count मददगार नहीं';
  }

  @override
  String get createQuiz => 'क्विज़ बनाएँ';

  @override
  String get chapter => 'अध्याय';

  @override
  String get numQuestions => 'सवालों की संख्या';

  @override
  String get language => 'भाषा';

  @override
  String get focusConcepts => 'मुख्य विषय';

  @override
  String get focusConceptsHint =>
      'खाली छोड़ें तो कक्षा के सबसे ज़्यादा पूछे गए विषय चुने जाएँगे';

  @override
  String get generating => 'बना रहे हैं…';

  @override
  String get quizCreated => 'क्विज़ कक्षा को दे दी गई';

  @override
  String attempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रयास',
      one: '1 प्रयास',
      zero: 'कोई प्रयास नहीं',
    );
    return '$_temp0';
  }

  @override
  String get results => 'परिणाम';

  @override
  String get perQuestion => 'हर सवाल पर सही जवाब';

  @override
  String get somethingWrong => 'कुछ गलत हो गया';
}
