import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale_controller.dart';

class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHindi = ref.watch(localeProvider).languageCode == 'hi';
    return TextButton.icon(
      onPressed: ref.read(localeProvider.notifier).toggle,
      icon: const Icon(Icons.translate_rounded, size: 18),
      // Show the language you'd switch *to*, written in that language.
      label: Text(isHindi ? 'English' : 'हिंदी'),
    );
  }
}
