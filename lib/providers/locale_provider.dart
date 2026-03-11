import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the user's language preference (true = Romanian).
class LocaleNotifier extends StateNotifier<bool> {
  LocaleNotifier() : super(false); // default: English

  void toggle() => state = !state;
  void setRomanian() => state = true;
  void setEnglish() => state = false;
}

final isRomanianProvider =
    StateNotifierProvider<LocaleNotifier, bool>((_) => LocaleNotifier());
