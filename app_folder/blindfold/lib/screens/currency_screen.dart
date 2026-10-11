import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/currency_classifier_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;
  String? _cameraErrorMessage;

  // Inference state
  Timer? _inferenceTimer;
  bool _isProcessingFrame = false;
  String? _detectedDenomination;
  double _currentConfidence = 0.0;
  bool _isStableDetection = false;
  String _statusTextBengali = "ক্যামেরা প্রস্তুত হচ্ছে…";
  String _statusTextEnglish = "Initializing camera...";

  // Debug testing panel toggle
  bool _showDebugOptions = false;
  final List<String> _debugDenominations = const ["10", "20", "50", "100", "200", "500"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _announceScreenEntrance();
    _initInferenceAndCamera();
  }

  void _announceScreenEntrance() {
    final isBengali = VoiceService.instance.isBengali;
    VoiceService.instance.speak(
      isBengali
          ? "কারেন্সি রিডার সক্রিয় হয়েছে। নোটটি ক্যামেরার সামনে ধরুন।"
          : "Currency reader active. Hold banknote before camera.",
    );
  }

  Future<void> _initInferenceAndCamera() async {
    // 1. Initialize local TFLite model
    await CurrencyClassifierService.instance.loadModel();

    // 2. Initialize Camera
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _cameraErrorMessage = "No camera found on this device.";
          _statusTextBengali = "ক্যামেরা পাওয়া যায়নি।";
          _statusTextEnglish = "No camera detected.";
        });
        return;
      }

      // Pick rear back-facing camera
      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusTextBengali = "নোটটি ক্যামেরার সামনে ধরুন";
        _statusTextEnglish = "Hold note before camera";
      });

      // 3. Start recurring on-device frame inference loop (throttled to ~2 FPS)
      _startInferenceLoop();
    } on CameraException catch (e) {
      debugPrint("[Camera Error]: ${e.code} - ${e.description}");
      if (!mounted) return;
      setState(() {
        if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt') {
          _isCameraPermissionDenied = true;
          _cameraErrorMessage = "Camera permission denied.";
          _statusTextBengali = "ক্যামেরার অনুমতি প্রয়োজন।";
          _statusTextEnglish = "Camera permission denied.";
        } else {
          _cameraErrorMessage = e.description ?? "Camera error.";
          _statusTextBengali = "ক্যামেরা লোড করা যায়নি।";
          _statusTextEnglish = "Camera failed to load.";
        }
      });
    } catch (e) {
      debugPrint("[Camera Init Error]: $e");
      if (!mounted) return;
      setState(() {
        _cameraErrorMessage = e.toString();
        _statusTextBengali = "ক্যামেরা ত্রুটি ঘটেছে।";
        _statusTextEnglish = "Camera error.";
      });
    }
  }

  void _startInferenceLoop() {
    _inferenceTimer?.cancel();
    _inferenceTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      _captureAndProcessFrame();
    });
  }

  Future<void> _captureAndProcessFrame() async {
    if (!mounted ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isTakingPicture ||
        _isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();

      final prediction = await CurrencyClassifierService.instance.classifyImageBytes(bytes);

      if (!mounted) return;

      setState(() {
        _statusTextBengali = prediction.statusBengali;
        _statusTextEnglish = prediction.statusEnglish;
        _currentConfidence = prediction.confidence;

        if (prediction.isConfident && prediction.denomination != null) {
          _detectedDenomination = prediction.denomination;
          _isStableDetection = true;

          // Automatically announce only when confirmed stable across frames
          VoiceService.instance.announceCurrency(_detectedDenomination!);
        } else if (prediction.denomination != null) {
          // Scanning in progress
          _isStableDetection = false;
        } else {
          // No note in sight or low confidence
          _isStableDetection = false;
        }
      });
    } catch (e) {
      debugPrint("[Inference Loop Error]: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _reannounceCurrentResult() {
    if (_detectedDenomination != null) {
      VoiceService.instance.announceCurrency(_detectedDenomination!, force: true);
    } else {
      final isBengali = VoiceService.instance.isBengali;
      VoiceService.instance.speak(
        isBengali
            ? "কোনো নোট শনাক্ত হয়নি। নোটটি ক্যামেরার সামনে ধরুন।"
            : "No note detected yet. Please hold a banknote before camera.",
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _inferenceTimer?.cancel();
      controller.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initInferenceAndCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inferenceTimer?.cancel();
    _cameraController?.dispose();
    CurrencyClassifierService.instance.resetSmoothing();
    VoiceService.instance.clearLastAnnouncedCurrency();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBengali = VoiceService.instance.isBengali;
    final statusText = isBengali ? _statusTextBengali : _statusTextEnglish;

    return Scaffold(
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // Top Action Row: Exit, Language & Mute (Liquid Glass)
                // ==========================================
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: isBengali ? "কারেন্সি রিডার থেকে প্রস্থান করুন" : "Exit Currency Reader and return to home menu",
                        button: true,
                        child: LiquidGlassContainer(
                          radius: 16,
                          blurSigma: 18.0,
                          opacity: 0.85,
                          borderColor: AppTheme.cardBorder,
                          borderWidth: 2.5,
                          onTap: () {
                            VoiceService.instance.speak(
                              isBengali ? "কারেন্সি রিডার বন্ধ করা হচ্ছে।" : "Exiting currency reader.",
                            );
                            Navigator.pop(context);
                          },
                          child: const SizedBox(
                            height: 60,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back, size: 26, color: AppTheme.cardBorder),
                                SizedBox(width: 8),
                                Text(
                                  "EXIT TO MENU",
                                  style: TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Language Toggle
                    Semantics(
                      label: isBengali ? "Switch to English" : "বাংলা ভাষা নির্বাচন করুন",
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
                          height: 60,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.language, size: 22, color: AppTheme.cardBorder),
                              const SizedBox(width: 4),
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
                  ],
                ),
                const SizedBox(height: 14),

                // ==========================================
                // Central Banknote Recognition Panel (Liquid Glass)
                // Featuring Live Camera Preview + Result Display
                // ==========================================
                Expanded(
                  child: Semantics(
                    label: _detectedDenomination != null
                        ? (isBengali
                            ? "শনাক্তকৃত নোট: $_detectedDenomination টাকা। পুনরায় শুনতে ট্যাপ করুন।"
                            : "Detected currency: $_detectedDenomination Rupees. Tap to hear again.")
                        : (isBengali
                            ? "কোনো নোট শনাক্ত হয়নি। নোটটি ক্যামেরার সামনে ধরুন।"
                            : "No note detected yet. Hold note before camera."),
                    button: true,
                    child: LiquidGlassContainer(
                      radius: 22,
                      blurSigma: 22.0,
                      opacity: 0.86,
                      borderColor: AppTheme.cardBorder,
                      borderWidth: 2.8,
                      padding: const EdgeInsets.all(16),
                      onTap: _reannounceCurrentResult,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ----------------------------------------
                          // Live Camera Preview Viewfinder
                          // ----------------------------------------
                          Expanded(
                            flex: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  if (_isCameraInitialized && _cameraController != null)
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!.value.previewSize?.height ?? 400,
                                        height: _cameraController!.value.previewSize?.width ?? 300,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    )
                                  else if (_isCameraPermissionDenied)
                                    Container(
                                      color: AppTheme.alertCriticalLight,
                                      padding: const EdgeInsets.all(20),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.no_photography, size: 52, color: AppTheme.alertCritical),
                                          const SizedBox(height: 10),
                                          Text(
                                            isBengali ? "ক্যামেরার অনুমতি প্রয়োজন" : "Camera Permission Required",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppTheme.alertCritical,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isBengali ? "ফোন সেটিংসে গিয়ে ক্যামেরা চালু করুন।" : "Please grant camera permission in system settings.",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_cameraErrorMessage != null)
                                    Container(
                                      color: AppTheme.alertCriticalLight,
                                      padding: const EdgeInsets.all(20),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline, size: 48, color: AppTheme.alertCritical),
                                          const SizedBox(height: 8),
                                          Text(
                                            _cameraErrorMessage!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppTheme.alertCritical,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      color: AppTheme.cardBackgroundAlt,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(color: AppTheme.cardBorder),
                                          const SizedBox(height: 12),
                                          Text(
                                            isBengali ? "ক্যামেরা চালু হচ্ছে…" : "Initializing camera feed...",
                                            style: const TextStyle(
                                              color: AppTheme.cardBorder,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // High-Contrast Banknote Alignment Frame
                                  Positioned.fill(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _isStableDetection
                                              ? AppTheme.alertSafe
                                              : (_isProcessingFrame ? AppTheme.accentAmber : Colors.white),
                                          width: 3.0,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Live Camera Badge
                                  Positioned(
                                    top: 10,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.fiber_manual_record,
                                            size: 12,
                                            color: _isStableDetection ? AppTheme.alertSafe : AppTheme.alertCritical,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isCameraInitialized ? "LIVE SCAN" : "CAMERA READY",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ----------------------------------------
                          // Detected Banknote Result Area
                          // ----------------------------------------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlueLight,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.cardBorder, width: 2),
                                ),
                                child: const Icon(
                                  Icons.payments,
                                  size: 24,
                                  color: AppTheme.cardBorder,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isBengali ? "ভারতীয় নোট" : "INDIAN BANKNOTE",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Large Detected Value
                          Text(
                            _detectedDenomination != null ? "₹$_detectedDenomination" : "₹ --",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),

                          // Spoken Denomination Badge (Liquid Glass)
                          Center(
                            child: LiquidGlassContainer(
                              radius: 14,
                              blurSigma: 12.0,
                              tintColor: _detectedDenomination != null
                                  ? AppTheme.accentAmberLight
                                  : Colors.white,
                              opacity: 0.90,
                              borderColor: AppTheme.cardBorder,
                              borderWidth: 2.0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Text(
                                _detectedDenomination != null
                                    ? (isBengali ? "$_detectedDenomination টাকার নোট" : "$_detectedDenomination RUPEES")
                                    : (isBengali ? "নোট শনাক্ত হয়নি" : "NO NOTE DETECTED"),
                                style: const TextStyle(
                                  color: AppTheme.cardBorder,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Re-announcement Instruction
                          Text(
                            isBengali
                                ? "পুনরায় শুনতে কার্ডের যেকোনো জায়গায় ট্যাপ করুন"
                                : "Tap card anytime to re-announce value",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // ==========================================
              // Bottom Camera Status & Confidence Panel (Liquid Glass)
              // Replaces manual buttons with real model metrics
              // ==========================================
              LiquidGlassContainer(
                radius: 16,
                blurSigma: 18.0,
                opacity: 0.85,
                borderColor: AppTheme.cardBorder,
                borderWidth: 2.5,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isStableDetection ? AppTheme.alertSafe : AppTheme.accentAmber,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cardBorder, width: 2),
                      ),
                      child: Icon(
                        _isStableDetection ? Icons.check : Icons.camera_alt,
                        size: 22,
                        color: AppTheme.cardBorder,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _currentConfidence > 0.1
                                ? "${( _currentConfidence * 100).toStringAsFixed(1)}% ${isBengali ? 'নিশ্চিত' : 'confidence'}"
                                : (_isProcessingFrame
                                    ? (isBengali ? "স্ক্যান চলছে…" : "Analyzing frame...")
                                    : (isBengali ? "ক্যামেরা সক্রিয়" : "Camera active")),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dev Debug Testing Expander Toggle
                    IconButton(
                      icon: Icon(
                        _showDebugOptions ? Icons.bug_report : Icons.bug_report_outlined,
                        color: AppTheme.textSecondary,
                        size: 22,
                      ),
                      tooltip: "Developer testing options",
                      onPressed: () {
                        setState(() {
                          _showDebugOptions = !_showDebugOptions;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ==========================================
              // Optional Developer Debug Test Buttons
              // Clearly labeled and separated from normal use
              // ==========================================
              if (_showDebugOptions) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "DEBUG TEST (SIMULATE DENOMINATION):",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _debugDenominations.map((note) {
                          return SizedBox(
                            height: 38,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _detectedDenomination = note;
                                  _isStableDetection = true;
                                  _currentConfidence = 0.99;
                                });
                                VoiceService.instance.announceCurrency(note, force: true);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              child: Text(
                                "₹$note",
                                style: const TextStyle(
                                  color: AppTheme.cardBorder,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }
}
