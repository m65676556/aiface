import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, speaking }

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechAvailable = false;

  final _stateController = StreamController<VoiceState>.broadcast();
  Stream<VoiceState> get stateStream => _stateController.stream;
  VoiceState _currentState = VoiceState.idle;
  VoiceState get currentState => _currentState;

  Future<void> initialize() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          _setState(VoiceState.idle);
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
      _speechAvailable = false;
    }

    try {
      await _tts.setLanguage('en-US');
      if (!kIsWeb) {
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
      }
      _tts.setCompletionHandler(() {
        _setState(VoiceState.idle);
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  void _setState(VoiceState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> startListening(void Function(String text) onResult) async {
    if (!_speechAvailable) {
      debugPrint('Speech recognition not available');
      return;
    }

    _setState(VoiceState.listening);
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          _setState(VoiceState.idle);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _setState(VoiceState.idle);
  }

  Future<void> speak(String text) async {
    try {
      _setState(VoiceState.speaking);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _setState(VoiceState.idle);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
    _setState(VoiceState.idle);
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
    _stateController.close();
  }
}
