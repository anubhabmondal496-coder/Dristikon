import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/speech_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import 'walking_radar_screen.dart';
import 'currency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isVoiceAssistantListening = false;
  String _recognizedSpeechText = "";
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideoBackground();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceWelcome();
    });
  }

  Future<void> _initVideoBackground() async {
    try {
      final controller = VideoPlayerController.asset('assets/bg.mp4');
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("[Background Video Error]: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _videoController?.play();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _videoController?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    super.dispose();
  }

  void _announceWelcome() {
    if (VoiceService.instance.isBengali) {
      VoiceService.instance.speak(
        "দৃষ্টিকোণ অ্যাপে স্বাগতম। অবস্ট্যাকল মোড চালু করতে একবার ট্যাপ করুন। কারেন্সি মোড চালু করতে ডাবল ট্যাপ করুন।",
      );
    } else {
      VoiceService.instance.speak(
        "Welcome to BlindFold. Single tap anywhere to start Obstacle Avoidance mode. Double tap anywhere to start Currency mode.",
      );
    }
  }

  // Single Tap Action: Start Obstacle Avoidance Mode
  void _startObstacleMode() {
    if (VoiceService.instance.isBengali) {
      VoiceService.instance.speak("অবস্ট্যাকল মোড চালু হচ্ছে।");
    } else {
      VoiceService.instance.speak("Starting Obstacle Avoidance mode.");
    }
    _videoController?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalkingRadarScreen()),
    ).then((_) {
      if (mounted) _videoController?.play();
    });
  }

  // Double Tap Action: Start Currency Mode
  void _startCurrencyMode() {
    if (VoiceService.instance.isBengali) {
      VoiceService.instance.speak("কারেন্সি রিডার মোড চালু হচ্ছে।");
    } else {
      VoiceService.instance.speak("Starting Currency Reader mode.");
    }
    _videoController?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CurrencyScreen()),
    ).then((_) {
      if (mounted) _videoController?.play();
    });
  }

  // Voice Assistant Button Handler (Speech-to-Text)
  Future<void> _handleVoiceAssistantPressed() async {
    final isBengali = VoiceService.instance.isBengali;

    if (_isVoiceAssistantListening) {
      await SpeechService.instance.stopListening();
      if (!mounted) return;
      setState(() {
        _isVoiceAssistantListening = false;
      });
      VoiceService.instance.speak(
        isBengali ? "ভয়েস অ্যাসিস্ট্যান্ট বন্ধ করা হয়েছে।" : "Voice Assistant paused.",
      );
      return;
    }

    // Stop ongoing speech so microphone doesn't transcribe the app's own TTS output
    await VoiceService.instance.stop();

    setState(() {
      _isVoiceAssistantListening = true;
      _recognizedSpeechText = "";
    });

    final started = await SpeechService.instance.startListening(
      isBengali: isBengali,
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _recognizedSpeechText = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          _executeVoiceCommand(words);
        }
      },
    );

    if (!started) {
      if (!mounted) return;
      setState(() {
        _isVoiceAssistantListening = false;
      });
      VoiceService.instance.speak(
        isBengali
            ? "মাইক্রোফোন চালু করা যায়নি। অনুগ্রহ করে সেটিংস পরীক্ষা করুন।"
            : "Could not start microphone. Please check settings.",
      );
    }
  }

  // Execute recognized voice intent
  void _executeVoiceCommand(String spokenText) {
    if (!mounted) return;
    setState(() {
      _isVoiceAssistantListening = false;
    });

    final isBengali = VoiceService.instance.isBengali;
    final intent = SpeechService.instance.parseIntent(spokenText);

    switch (intent.type) {
      case VoiceIntentType.openCurrency:
        VoiceService.instance.speak(isBengali ? intent.responseBengali : intent.responseEnglish);
        _videoController?.pause();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrencyScreen()),
        ).then((_) {
          if (mounted) _videoController?.play();
        });
        break;

      case VoiceIntentType.openObstacle:
        VoiceService.instance.speak(isBengali ? intent.responseBengali : intent.responseEnglish);
        _videoController?.pause();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalkingRadarScreen()),
        ).then((_) {
          if (mounted) _videoController?.play();
        });
        break;

      case VoiceIntentType.help:
      case VoiceIntentType.stop:
      case VoiceIntentType.unknown:
        VoiceService.instance.speak(isBengali ? intent.responseBengali : intent.responseEnglish);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBengali = VoiceService.instance.isBengali;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video Animation (bg.mp4)
          if (_isVideoInitialized && _videoController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else
            Container(color: AppTheme.background),

          // High-Contrast Frost Veil
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
              child: Container(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // ==========================================
              // Top Tactile Clarity Light Header
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: AppTheme.tactileCardDecoration(
                          radius: 14,
                          borderWidth: 2.5,
                          offsetY: 3.0,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "BLINDFOLD",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            "YOUR WORLD, YOUR WAY",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Language Toggle (বাংলা / ENG)
                      Semantics(
                        label: isBengali ? "Switch to English speech" : "বাংলা ভাষায় পরিবর্তন করুন",
                        button: true,
                        child: Container(
                          height: 48,
                          decoration: AppTheme.tactileButtonDecoration(
                            radius: 14,
                            backgroundColor: AppTheme.cardBackground,
                            offsetY: 3.0,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                VoiceService.instance.toggleLanguage();
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language, size: 20, color: AppTheme.cardBorder),
                                  const SizedBox(width: 4),
                                  Text(
                                    isBengali ? "বাংলা" : "ENG",
                                    style: const TextStyle(
                                      color: AppTheme.cardBorder,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Mute Audio Toggle with Shape-Aware Circular Decoration
                      Semantics(
                        label: VoiceService.instance.isMuted ? "Unmute Voice" : "Mute Voice",
                        button: true,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: AppTheme.tactileCircleDecoration(
                            backgroundColor: AppTheme.cardBackground,
                            offsetY: 3.0,
                          ),
                          child: IconButton(
                            iconSize: 26,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              VoiceService.instance.isMuted ? Icons.volume_off : Icons.volume_up,
                              color: VoiceService.instance.isMuted
                                  ? AppTheme.textSecondary
                                  : AppTheme.cardBorder,
                            ),
                            onPressed: () {
                              setState(() {
                                VoiceService.instance.toggleMute();
                              });
                              if (!VoiceService.instance.isMuted) {
                                VoiceService.instance.speak(
                                  isBengali ? "অডিও চালু হয়েছে।" : "Audio unmuted.",
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ========================================================
              // Giant Gesture Surface
              // Single Tap -> Obstacle Avoidance | Double Tap -> Currency
              // ========================================================
              Expanded(
                child: Semantics(
                  label: isBengali
                      ? "প্রধান নিয়ন্ত্রণ ক্ষেত্র। একবার ট্যাপ করলে অবস্ট্যাকল মোড শুরু হবে। দুইবার ট্যাপ করলে কারেন্সি মোড শুরু হবে।"
                      : "Main gesture area. Tap once for obstacle avoidance mode. Double tap for currency mode.",
                  button: true,
                  child: GestureDetector(
                    onTap: _startObstacleMode,
                    onDoubleTap: _startCurrencyMode,
                    child: Container(
                      decoration: AppTheme.tactileCardDecoration(
                        radius: 22,
                        offsetY: 4.0,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ----------------------------------------
                          // Mode 1: Single Tap -> Obstacle Radar
                          // ----------------------------------------
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.accentAmberLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentAmber,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                                    ),
                                    child: const Icon(
                                      Icons.radar,
                                      size: 32,
                                      color: AppTheme.cardBorder,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isBengali ? "একবার ট্যাপ করুন" : "SINGLE TAP",
                                          style: const TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isBengali ? "অবস্ট্যাকল মোড" : "Obstacle Avoidance",
                                          style: const TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          isBengali ? "বাধা, সিঁড়ি ও দূরত্ব শনাক্তকরণ" : "Detect obstacles, stairs & distance",
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 22,
                                    color: AppTheme.cardBorder,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ----------------------------------------
                          // Mode 2: Double Tap -> Currency Reader
                          // ----------------------------------------
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlueLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentBlue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                                    ),
                                    child: const Icon(
                                      Icons.payments,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isBengali ? "দুইবার ট্যাপ করুন" : "DOUBLE TAP",
                                          style: const TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isBengali ? "কারেন্সি রিডার" : "Currency Reader",
                                          style: const TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          isBengali ? "ক্যামেরা দিয়ে কি প্রকৃতির নোট শনাক্ত করুন" : "Live camera banknote recognition",
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 22,
                                    color: AppTheme.cardBorder,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Tactile Guidance Strip
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackgroundAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app, size: 20, color: AppTheme.cardBorder),
                                const SizedBox(width: 8),
                                Text(
                                  isBengali ? "সক্রিয় করতে এই কার্ডের যেকোনো জায়গায় ট্যাপ করুন" : "Tap anywhere inside this box to activate",
                                  style: const TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ========================================================
              // Dedicated Voice Assistant Button (Shape-Aware Tactile Card)
              // ========================================================
              Semantics(
                label: _isVoiceAssistantListening
                    ? (isBengali ? "ভয়েস অ্যাসিস্ট্যান্ট শুনছে। বিরতির জন্য ট্যাপ করুন।" : "Voice Assistant is listening. Tap to pause.")
                    : (isBengali ? "ভয়েস অ্যাসিস্ট্যান্ট বোতাম। কথা বলতে ট্যাপ করুন।" : "Voice Assistant Button. Tap to speak commands."),
                button: true,
                child: Container(
                  height: 80,
                  decoration: AppTheme.tactileButtonDecoration(
                    radius: 18,
                    backgroundColor: _isVoiceAssistantListening
                        ? AppTheme.accentAmber
                        : AppTheme.cardBackground,
                    offsetY: 3.5,
                  ),
                  child: InkWell(
                    onTap: _handleVoiceAssistantPressed,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.cardBorder, width: 2),
                            ),
                            child: Icon(
                              _isVoiceAssistantListening ? Icons.mic : Icons.mic_none,
                              size: 28,
                              color: AppTheme.cardBorder,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isVoiceAssistantListening
                                      ? (isBengali ? "ভয়েস অ্যাসিস্ট্যান্ট (শুনছে)" : "VOICE ASSISTANT (LISTENING)")
                                      : (isBengali ? "ভয়েস অ্যাসিস্ট্যান্ট" : "VOICE ASSISTANT"),
                                  style: const TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _recognizedSpeechText.isNotEmpty
                                      ? "\"$_recognizedSpeechText\""
                                      : (_isVoiceAssistantListening
                                          ? (isBengali ? "আপনার অনুরোধ বলুন..." : "Speak your request now...")
                                          : (isBengali ? "নির্দেশ দিতে ট্যাপ করুন" : "Tap to speak voice instructions")),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _recognizedSpeechText.isNotEmpty ? AppTheme.cardBorder : AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: _recognizedSpeechText.isNotEmpty ? FontWeight.w900 : FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }
}
