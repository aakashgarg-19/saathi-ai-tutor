/// On-device speech, TTS and OCR: zero API cost and they keep working on
/// patchy networks, which matters for the students Saathi is built for.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

String _bcp47(String lang) => lang == 'hi' ? 'hi-IN' : 'en-IN';

class VoiceInput {
  final _speech = SpeechToText();
  bool? _available;

  bool get isListening => _speech.isListening;

  Future<bool> start({
    required String language,
    required void Function(String text, bool isFinal) onResult,
    required VoidCallback onDone,
  }) async {
    _available ??= await _speech.initialize(
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          onDone();
        }
      },
      onError: (_) => onDone(),
    );
    if (_available != true) return false;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: _bcp47(language).replaceAll('-', '_'),
        partialResults: true,
      ),
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
    );
    return true;
  }

  Future<void> stop() => _speech.stop();
}

class Speaker {
  Speaker() {
    _tts.setCompletionHandler(() => speaking.value = null);
    _tts.setCancelHandler(() => speaking.value = null);
  }

  final _tts = FlutterTts();

  /// Id of the answer currently being read aloud, if any.
  final speaking = ValueNotifier<String?>(null);

  Future<void> speak(String id, String text, String language) async {
    await _tts.stop();
    await _tts.setLanguage(_bcp47(language));
    await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
    speaking.value = id;
    await _tts.speak(_plain(text));
  }

  Future<void> stop() async {
    await _tts.stop();
    speaking.value = null;
  }

  /// Strip markdown emphasis and [S1] citations so they aren't read out.
  static String _plain(String text) => text
      .replaceAll(RegExp(r'\[S\d+\]'), '')
      .replaceAll('**', '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class QuestionScanner {
  final _picker = ImagePicker();

  /// Photographs a textbook question and returns the recognised text,
  /// `null` if cancelled, or an empty string if nothing was readable.
  Future<String?> scan({required String language}) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (photo == null) return null;
    final recognizer = TextRecognizer(
      script: language == 'hi'
          ? TextRecognitionScript.devanagiri
          : TextRecognitionScript.latin,
    );
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      return result.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    } finally {
      await recognizer.close();
    }
  }
}

final voiceInputProvider = Provider((ref) => VoiceInput());

final speakerProvider = Provider((ref) {
  final speaker = Speaker();
  ref.onDispose(speaker.stop);
  return speaker;
});

final questionScannerProvider = Provider((ref) => QuestionScanner());
