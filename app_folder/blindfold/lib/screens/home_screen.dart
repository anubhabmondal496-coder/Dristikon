import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import 'walking_radar_screen.dart';
import 'currency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isVoiceAssistantListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VoiceService.instance.speak(
        "Welcome to BlindFold. Single tap anywhere to start Obstacle Avoidance mode. Double tap anywhere to start Currency mode.",
      );
    });
  }

  // Single Tap Action: Start Obstacle Avoidance Mode
  void _startObstacleMode() {
    VoiceService.instance.speak("Starting Obstacle Avoidance mode.");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalkingRadarScreen()),
    );
  }

  // Double Tap Action: Start Currency Mode
  void _startCurrencyMode() {
    VoiceService.instance.speak("Starting Currency Reader mode.");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CurrencyScreen()),
    );
  }

  // Voice Assistant Button Handler
  void _handleVoiceAssistantPressed() {
    setState(() {
      _isVoiceAssistantListening = !_isVoiceAssistantListening;
    });

    if (_isVoiceAssistantListening) {
      VoiceService.instance.speak("Voice Assistant listening. Ready for your command.");
    } else {
      VoiceService.instance.speak("Voice Assistant paused.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
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
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.cardBorder,
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
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
                  Semantics(
                    label: VoiceService.instance.isMuted ? "Unmute Voice" : "Mute Voice",
                    button: true,
                    child: Container(
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cardBorder,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: IconButton(
                        iconSize: 32,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.cardBackground,
                          side: const BorderSide(color: AppTheme.cardBorder, width: 2.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
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
                            VoiceService.instance.speak("Audio unmuted.");
                          }
                        },
                      ),
                    ),
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
                  label: "Main gesture area. Tap once for obstacle avoidance mode. Double tap for currency mode.",
                  button: true,
                  child: GestureDetector(
                    onTap: _startObstacleMode,
                    onDoubleTap: _startCurrencyMode,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.cardBorder, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.cardBorder,
                            offset: Offset(0, 5),
                            blurRadius: 0,
                          ),
                        ],
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
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentAmber,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                                    ),
                                    child: const Icon(
                                      Icons.radar,
                                      size: 34,
                                      color: AppTheme.cardBorder,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "SINGLE TAP",
                                          style: TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "Obstacle Avoidance",
                                          style: TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          "Detect obstacles, stairs & distance",
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 24,
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
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentBlue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                                    ),
                                    child: const Icon(
                                      Icons.payments,
                                      size: 34,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "DOUBLE TAP",
                                          style: TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "Currency Reader",
                                          style: TextStyle(
                                            color: AppTheme.cardBorder,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          "Identify Indian banknotes instantly",
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 24,
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
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.touch_app, size: 20, color: AppTheme.cardBorder),
                                SizedBox(width: 8),
                                Text(
                                  "Tap anywhere inside this box to activate",
                                  style: TextStyle(
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
              // Dedicated Voice Assistant Button (Light Mode Tactile Card)
              // ========================================================
              Semantics(
                label: _isVoiceAssistantListening
                    ? "Voice Assistant is listening. Tap to pause."
                    : "Voice Assistant Button. Tap to speak commands.",
                button: true,
                child: Container(
                  height: 84,
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cardBorder,
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleVoiceAssistantPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVoiceAssistantListening
                          ? AppTheme.accentAmber
                          : AppTheme.cardBackground,
                      side: const BorderSide(color: AppTheme.cardBorder, width: 2.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
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
                                    ? "VOICE ASSISTANT (LISTENING)"
                                    : "VOICE ASSISTANT",
                                style: const TextStyle(
                                  color: AppTheme.cardBorder,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _isVoiceAssistantListening
                                    ? "Speak your request now..."
                                    : "Tap to ask or give voice instructions",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }
}
