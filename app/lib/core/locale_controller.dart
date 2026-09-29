import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/local_store.dart';

/// App UI language. Also the default language Saathi answers in.
class LocaleController extends Notifier<Locale> {
  static const supported = [Locale('en'), Locale('hi')];

  @override
  Locale build() =>
      Locale(ref.read(localStoreProvider).setting('locale') ?? 'en');

  void toggle() => set(state.languageCode == 'en' ? 'hi' : 'en');

  void set(String code) {
    state = Locale(code);
    ref.read(localStoreProvider).setSetting('locale', code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
