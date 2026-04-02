import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

    String? preferredLocaleId;
    try {
      final locales = await _speechToText.locales();
      // Try to find a Philippine locale (en_PH or fil_PH) for better local word recognition
      for (var locale in locales) {
        if (locale.localeId.contains('en_PH') ||
            locale.localeId.contains('en-PH')) {
          preferredLocaleId = locale.localeId;
          break;
        }
      }

      if (preferredLocaleId == null) {
        for (var locale in locales) {
          if (locale.localeId.contains('fil') ||
              locale.localeId.contains('TL')) {
            preferredLocaleId = locale.localeId;
            break;
          }
        }
      }
    } catch (_) {
      // Fallback to system default if locales fetch fails
    }

    await _speechToText.listen(
      onResult: (result) {
        state = state.copyWith(lastWords: result.recognizedWords);
      },
      localeId: preferredLocaleId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    state = state.copyWith(isListening: false);
  }
}
