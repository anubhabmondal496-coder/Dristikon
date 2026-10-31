import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import 'walking_radar_screen.dart';
import 'currency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceWelcome();
    });
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalkingRadarScreen()),
    );
  }

  // Double Tap Action: Start Currency Mode
  void _startCurrencyMode() {
    if (VoiceService.instance.isBengali) {
      VoiceService.instance.speak("কারেন্সি রিডার মোড চালু হচ্ছে।");
    } else {
      VoiceService.instance.speak("Starting Currency Reader mode.");
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CurrencyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBengali = VoiceService.instance.isBengali;

    return Scaffold(
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // Top Header Row: Logo, Title & Utility Buttons (Liquid Glass)
                // ==========================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        LiquidGlassContainer(
                          radius: 16,
                          blurSigma: 18.0,
                          opacity: 0.85,
                          borderColor: AppTheme.cardBorder,
                          borderWidth: 2.5,
                          padding: const EdgeInsets.all(4),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Image.asset(
                              'assets/logo_J2M.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBengali ? "দৃষ্টিকোণ" : "DRISHTIKON",
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              isBengali ? "আপনার পথ, আপনার স্বাধীনতা" : "YOUR WORLD, YOUR WAY",
                              style: const TextStyle(
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
                        // Language Toggle (Liquid Glass)
                        Semantics(
                          label: isBengali ? "Switch to English speech" : "বাংলা ভাষায় পরিবর্তন করুন",
                          button: true,
                          child: LiquidGlassContainer(
                            radius: 16,
                            blurSigma: 18.0,
                            opacity: 0.85,
                            borderColor: AppTheme.cardBorder,
                            borderWidth: 2.5,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onTap: () {
                              setState(() {
                                VoiceService.instance.toggleLanguage();
                              });
                            },
                            child: SizedBox(
                              height: 52,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language, size: 22, color: AppTheme.cardBorder),
                                  const SizedBox(width: 6),
                                  Text(
                                    isBengali ? "বাংলা" : "ENG",
                                    style: const TextStyle(
                                      color: AppTheme.cardBorder,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Mute Audio Toggle (Liquid Glass)
                        Semantics(
                          label: VoiceService.instance.isMuted ? "Unmute Voice" : "Mute Voice",
                          button: true,
                          child: LiquidGlassContainer(
                            radius: 16,
                            blurSigma: 18.0,
                            opacity: 0.85,
                            borderColor: AppTheme.cardBorder,
                            borderWidth: 2.5,
                            onTap: () {
                              setState(() {
                                VoiceService.instance.toggleMute();
                              });
                              if (!VoiceService.instance.isMuted) {
                                VoiceService.instance.speak(
                                  isBengali ? "অডিও চালু হয়েছে।" : "Audio unmuted.",
                                );
                              }
                            },
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: Center(
                                child: Icon(
                                  VoiceService.instance.isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: VoiceService.instance.isMuted
                                      ? AppTheme.textSecondary
                                      : AppTheme.cardBorder,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ========================================================
                // Giant Gesture Surface (Liquid Glass Interactive Panel)
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
                      child: LiquidGlassContainer(
                        radius: 24,
                        blurSigma: 24.0,
                        opacity: 0.86,
                        borderColor: AppTheme.cardBorder,
                        borderWidth: 2.8,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ----------------------------------------
                            // Mode 1: Single Tap -> Obstacle Radar (Liquid Amber Glass)
                            // ----------------------------------------
                            Expanded(
                              child: LiquidGlassContainer(
                                radius: 18,
                                blurSigma: 14.0,
                                tintColor: AppTheme.accentAmberLight,
                                opacity: 0.90,
                                borderColor: AppTheme.cardBorder,
                                borderWidth: 2.5,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
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
                            // Mode 2: Double Tap -> Currency Reader (Liquid Blue Glass)
                            // ----------------------------------------
                            Expanded(
                              child: LiquidGlassContainer(
                                radius: 18,
                                blurSigma: 14.0,
                                tintColor: AppTheme.accentBlueLight,
                                opacity: 0.90,
                                borderColor: AppTheme.cardBorder,
                                borderWidth: 2.5,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
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
                                            isBengali ? "ক্যামেরা দিয়ে ব্যাঙ্কনোট শনাক্তকরণ" : "Live camera banknote recognition",
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

                            // Tactile Guidance Strip (Liquid Glass Pill)
                            LiquidGlassContainer(
                              radius: 12,
                              blurSigma: 10.0,
                              tintColor: Colors.white,
                              opacity: 0.80,
                              borderColor: AppTheme.cardBorder,
                              borderWidth: 1.5,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.touch_app, size: 20, color: AppTheme.cardBorder),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isBengali ? "সক্রিয় করতে এই কার্ডের যেকোনো জায়গায় ট্যাপ করুন" : "Tap anywhere inside this box to activate",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.cardBorder,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
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
      ),
    );
  }
}
