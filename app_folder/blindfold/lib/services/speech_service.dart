import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceIntentType {
  openCurrency,
  openObstacle,
  help,
  stop,
  unknown,
}

class VoiceIntentResult {
  final VoiceIntentType type;
  final String rawText;
  final String responseBengali;
  final String responseEnglish;

  const VoiceIntentResult({
    required this.type,
    required this.rawText,
    required this.responseBengali,
    required this.responseEnglish,
  });
}

class SpeechService {
  static final SpeechService instance = SpeechService._internal();
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastSpokenWords = "";

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get lastSpokenWords => _lastSpokenWords;

  /// Initialize the SpeechToText engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint("[SpeechService Error]: ${error.errorMsg} - permanent: ${error.permanent}");
          _isListening = false;
        },
        onStatus: (String status) {
          debugPrint("[SpeechService Status]: $status");
          if (status == "done" || status == "notListening") {
            _isListening = false;
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint("[SpeechService Init Exception]: $e");
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening for voice commands in either Bengali or English
  Future<bool> startListening({
    required Function(String words, bool isFinal) onResult,
    bool isBengali = true,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_isListening) {
      await stopListening();
    }

    // Determine target locale: bn_IN (Bengali India) or en_US
    String targetLocale = isBengali ? "bn_IN" : "en_US";

    try {
      final locales = await _speechToText.locales();
      final hasTarget = locales.any((l) => l.localeId.toLowerCase().startsWith(isBengali ? "bn" : "en"));
      if (!hasTarget && isBengali) {
        // Fallback to bd if in locale list
        final hasBd = locales.any((l) => l.localeId.toLowerCase().startsWith("bn_bd"));
        if (hasBd) targetLocale = "bn_BD";
      }
    } catch (e) {
      debugPrint("[SpeechService Locales Error]: $e");
    }

    _lastSpokenWords = "";
    _isListening = true;

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastSpokenWords = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _isListening = false;
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          localeId: targetLocale,
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (e) {
      debugPrint("[SpeechService Listen Exception]: $e");
      _isListening = false;
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speechToText.stop();
    } catch (e) {
      debugPrint("[SpeechService Stop Exception]: $e");
    } finally {
      _isListening = false;
    }
  }

  /// Cancel listening immediately
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
    } catch (e) {
      debugPrint("[SpeechService Cancel Exception]: $e");
    } finally {
      _isListening = false;
    }
  }

  /// Parse natural language voice commands to intent with both Bengali & English support
  VoiceIntentResult parseIntent(String rawInput) {
    final text = rawInput.toLowerCase().trim();

    // 1. Currency Reader Intent
    final currencyKeywords = [
      "টাকা", "টাকার", "নোট", "পয়সা", "কারেন্সি", "রুপি",
      "taka", "takar", "note", "currency", "cash", "money", "rupee", "banknote", "scan money"
    ];
    if (currencyKeywords.any((k) => text.contains(k))) {
      return VoiceIntentResult(
        type: VoiceIntentType.openCurrency,
        rawText: rawInput,
        responseBengali: "কারেন্সি রিডার মোড চালু হচ্ছে। নোটটি ক্যামেরার সামনে ধরুন।",
        responseEnglish: "Opening Currency Reader. Hold banknote before camera.",
      );
    }

    // 2. Obstacle Radar / Walking Mode Intent
    final obstacleKeywords = [
      "সামনে", "বাধা", "রাস্তা", "সিঁড়ি", "দূরত্ব", "হাঁটা", "অবস্ট্যাকল", "রাডার",
      "samne", "badha", "rasta", "shiri", "siri", "obstacle", "radar", "walking", "ahead", "path", "distance", "stairs"
    ];
    if (obstacleKeywords.any((k) => text.contains(k))) {
      return VoiceIntentResult(
        type: VoiceIntentType.openObstacle,
        rawText: rawInput,
        responseBengali: "অবস্ট্যাকল মোড চালু হচ্ছে। হাঁটার পথ পর্যবেক্ষণ করা হচ্ছে।",
        responseEnglish: "Starting Obstacle Radar. Monitoring your walking path.",
      );
    }

    // 3. Guidance / Help Intent
    final helpKeywords = [
      "সাহায্য", "কীভাবে", "সহায়তা", "নিয়ম", "বলুন",
      "help", "guide", "how to", "instruction", "what can you do"
    ];
    if (helpKeywords.any((k) => text.contains(k))) {
      return VoiceIntentResult(
        type: VoiceIntentType.help,
        rawText: rawInput,
        responseBengali: "ব্লাইন্ডফোল্ডে স্বাগতম। একবার ট্যাপ করলে অবস্ট্যাকল মোড, দুইবার ট্যাপ করলে কারেন্সি রিডার। আপনি মুখেও বলতে পারেন 'টাকা পরীক্ষা করো' বা 'সামনে কি আছে'।",
        responseEnglish: "Welcome to BlindFold. Tap once for Obstacle Radar. Tap twice for Currency Reader. Or speak commands like 'scan money' or 'what is ahead'.",
      );
    }

    // 4. Stop / Pause Intent
    final stopKeywords = [
      "থামো", "বন্ধ", "চুপ", "মিউট", "থেমে যাও",
      "stop", "pause", "quiet", "mute", "cancel"
    ];
    if (stopKeywords.any((k) => text.contains(k))) {
      return VoiceIntentResult(
        type: VoiceIntentType.stop,
        rawText: rawInput,
        responseBengali: "ভয়েস কমান্ড থামানো হয়েছে।",
        responseEnglish: "Voice Assistant stopped.",
      );
    }

    // 5. Unrecognized Query
    return VoiceIntentResult(
      type: VoiceIntentType.unknown,
      rawText: rawInput,
      responseBengali: "আমি শুনেছি: '$rawInput'। আপনি বলতে পারেন 'টাকা পরীক্ষা করো' অথবা 'সামনে কি আছে'।",
      responseEnglish: "I heard: '$rawInput'. You can say 'scan money' or 'check obstacles'.",
    );
  }
}
