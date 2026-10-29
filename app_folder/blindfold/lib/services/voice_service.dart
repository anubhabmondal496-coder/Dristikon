import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService instance = VoiceService._internal();
  VoiceService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _muted = false;

  // Language setting: default to Bengali ("bn-IN") as requested
  String _currentLanguage = "bn-IN";
  String _lastAnnouncedDenomination = "";

  bool get isSpeaking => _isSpeaking;
  bool get isMuted => _muted;
  String get currentLanguage => _currentLanguage;
  bool get isBengali => _currentLanguage.startsWith("bn");

  static const Map<String, String> _bengaliDenominationNames = {
    "10": "দশ টাকার নোট।",
    "20": "কুড়ি টাকার নোট।",
    "50": "পঞ্চাশ টাকার নোট।",
    "100": "একশো টাকার নোট।",
    "200": "দুইশো টাকার নোট।",
    "500": "পাঁচশো টাকার নোট।",
  };

  static const Map<String, String> _englishDenominationNames = {
    "10": "Ten rupees note.",
    "20": "Twenty rupees note.",
    "50": "Fifty rupees note.",
    "100": "One hundred rupees note.",
    "200": "Two hundred rupees note.",
    "500": "Five hundred rupees note.",
  };

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _flutterTts = FlutterTts();
      
      await _flutterTts?.setLanguage(_currentLanguage);
      // Smoothed speech rate and natural pitch to eliminate trembling/jittering
      await _flutterTts?.setSpeechRate(0.44);
      await _flutterTts?.setVolume(1.0);
      await _flutterTts?.setPitch(1.0);

      // On Android, enable audio focus and low-latency synthesis
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _flutterTts?.awaitSpeakCompletion(true);
        } catch (_) {}
      }

      _flutterTts?.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts?.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts?.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint("[VoiceService Error]: $msg");
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint("[VoiceService Init Exception]: $e");
    }
  }

  Future<void> setLanguage(String lang) async {
    _currentLanguage = lang;
    try {
      await _flutterTts?.setLanguage(lang);
    } catch (e) {
      debugPrint("[VoiceService] setLanguage error: $e");
    }
  }

  void toggleLanguage() {
    if (isBengali) {
      setLanguage("en-US");
      speak("English selected.");
    } else {
      setLanguage("bn-IN");
      speak("বাংলা ভাষা নির্বাচিত হয়েছে।");
    }
  }

  Future<void> speak(String message, {bool interrupt = true}) async {
    if (_muted || message.trim().isEmpty) return;

    HapticFeedback.lightImpact();

    if (!_isInitialized) {
      await init();
    }

    try {
      if (interrupt) {
        await _flutterTts?.stop();
      }
      await _flutterTts?.speak(message);
    } catch (e) {
      debugPrint("[VoiceService Speak Exception]: $e");
    }
  }

  /// Announce detected currency denomination
  /// [force]: if true, forces re-announcement even if the same denomination was previously spoken
  Future<void> announceCurrency(String denomination, {bool force = false}) async {
    if (!force && denomination == _lastAnnouncedDenomination) {
      return; // Do not repeatedly announce same note while held before camera
    }

    _lastAnnouncedDenomination = denomination;

    final phrase = isBengali
        ? (_bengaliDenominationNames[denomination] ?? "$denomination টাকার নোট।")
        : (_englishDenominationNames[denomination] ?? "$denomination rupees note.");

    await speak(phrase, interrupt: true);
  }

  void clearLastAnnouncedCurrency() {
    _lastAnnouncedDenomination = "";
  }

  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint("[VoiceService Stop Exception]: $e");
    }
  }

  void toggleMute() {
    _muted = !_muted;
    if (_muted) {
      stop();
    }
  }
}
