import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'settings_provider.dart';

final voiceInputProvider =
    NotifierProvider<VoiceInputNotifier, VoiceInputState>(() {
      return VoiceInputNotifier();
    });

class VoiceInputState {
  final bool isListening;
  final String lastWords;
  final bool isAvailable;
  final String error;

  VoiceInputState({
    this.isListening = false,
    this.lastWords = '',
    this.isAvailable = false,
    this.error = '',
  });

  VoiceInputState copyWith({
    bool? isListening,
    String? lastWords,
    bool? isAvailable,
    String? error,
  }) {
    return VoiceInputState(
      isListening: isListening ?? this.isListening,
      lastWords: lastWords ?? this.lastWords,
      isAvailable: isAvailable ?? this.isAvailable,
      error: error ?? this.error,
    );
  }
}

class VoiceInputNotifier extends Notifier<VoiceInputState> {
  final SpeechToText _speechToText = SpeechToText();

  bool _isInitInProgress = false;

  Future<List<LocaleName>> availableLocales() async {
    if (!await _ensureInitialized()) {
      throw StateError(
        'Speech recognition is unavailable. Check microphone permission.',
      );
    }
    return _speechToText.locales();
  }

  @override
  VoiceInputState build() {
    return VoiceInputState();
  }

  Future<bool> _ensureInitialized() async {
    if (state.isAvailable) return true;
    if (_isInitInProgress) return false;

    _isInitInProgress = true;
    try {
      final isAvailable = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            stopListening();
          }
        },
        onError: (errorNotification) {
          state = state.copyWith(
            isListening: false,
            error: errorNotification.errorMsg,
          );
        },
      );
      state = state.copyWith(isAvailable: isAvailable);
      _isInitInProgress = false;
      return isAvailable;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isAvailable: false);
      _isInitInProgress = false;
      return false;
    }
  }

  Future<void> startListening() async {
    bool available = state.isAvailable;

    if (!available) {
      available = await _ensureInitialized();
    }

    if (!available) {
      state = state.copyWith(error: 'Speech recognition not available.');
      return;
    }

    state = state.copyWith(isListening: true, lastWords: '', error: '');

    // A null locale lets the recognizer follow the user's system language.
    final selectedLocale = ref.read(settingsProvider).voiceLocale;
    String? preferredLocaleId;
    if (selectedLocale != null) {
      try {
        final locales = await _speechToText.locales();
        if (locales.any((locale) => locale.localeId == selectedLocale)) {
          preferredLocaleId = selectedLocale;
        }
      } catch (_) {
        // A removed or unavailable language falls back to the system default.
      }
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (ref.mounted) {
            state = state.copyWith(lastWords: result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          localeId: preferredLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          isListening: false,
          error: 'Could not start speech recognition. Check microphone permission and try again.',
        );
      }
    }
  }

  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } finally {
      if (ref.mounted) state = state.copyWith(isListening: false);
    }
  }
}
