import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/obstacle_detection.dart';
import '../services/obstacle_detector_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class WalkingRadarScreen extends StatefulWidget {
  const WalkingRadarScreen({super.key});

  @override
  State<WalkingRadarScreen> createState() => _WalkingRadarScreenState();
}

class _WalkingRadarScreenState extends State<WalkingRadarScreen> with WidgetsBindingObserver {
  // Live camera feed controllers
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  Timer? _inferenceTimer;

  // Real-time obstacle model detection state
  ObstacleDetection? _liveObstacle;
  List<ObstacleDetection> _liveHazards = [];
  bool _isLiveFeedActive = true;
  String _lastSpokenAlert = "";
  DateTime _lastSpeechTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Fallback simulation sequence
  final List<ObstacleDetection> _defaultObstacles = ObstacleDetection.defaultObstacles;
  int _simulationIndex = 0;
  bool _isPaused = false;

  ObstacleDetection get _current {
    if (_isLiveFeedActive && _liveObstacle != null) {
      return _liveObstacle!;
    }
    return _defaultObstacles[_simulationIndex];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _announceScreenEntrance();
    _initLiveCameraAndDetection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inferenceTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initLiveCameraAndDetection();
    }
  }

  void _announceScreenEntrance() {
    final isBengali = VoiceService.instance.isBengali;
    VoiceService.instance.speak(
      isBengali
          ? "বাধা শনাক্তকরণ রাডার সক্রিয়। ক্যামেরা রিয়েল-টাইমে স্ক্যান করছে।"
          : "Real-time obstacle radar active. Camera scanning forward for hazards.",
    );
  }

  Future<void> _initLiveCameraAndDetection() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isCameraInitialized = false;
          _isLiveFeedActive = false;
        });
        return;
      }

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
        _isLiveFeedActive = true;
      });

      _startLiveInferenceLoop();
    } catch (e) {
      debugPrint("[WalkingRadar Camera Init Exception]: $e");
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _isLiveFeedActive = false;
      });
    }
  }

  void _startLiveInferenceLoop() {
    _inferenceTimer?.cancel();
    _inferenceTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!_isPaused && _isLiveFeedActive) {
        _captureAndProcessCameraFrame();
      }
    });
  }

  Future<void> _captureAndProcessCameraFrame() async {
    if (!mounted ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isTakingPicture ||
        _isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final xFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await xFile.readAsBytes();

      final result = await ObstacleDetectorService.instance.detectObstacles(imageBytes);

      if (!mounted) return;

      if (result.primaryHazard != null) {
        setState(() {
          _liveObstacle = result.primaryHazard;
          _liveHazards = result.allHazards;
        });

        // Trigger voice alert if new hazard or enough interval passed
        final isBengali = VoiceService.instance.isBengali;
        final alertText = isBengali ? result.spokenAlertBengali : result.spokenAlert;
        final now = DateTime.now();

        if (alertText != _lastSpokenAlert || now.difference(_lastSpeechTime).inSeconds >= 3) {
          _lastSpokenAlert = alertText;
          _lastSpeechTime = now;
          VoiceService.instance.speak(alertText, interrupt: result.primaryHazard!.urgency == ObstacleUrgency.critical);
        }
      }
    } catch (e) {
      debugPrint("[WalkingRadar Inference Loop Exception]: $e");
    } finally {
      if (mounted) {
        _isProcessingFrame = false;
      }
    }
  }

  void _nextSimulationObstacle() {
    setState(() {
      _simulationIndex = (_simulationIndex + 1) % _defaultObstacles.length;
    });
    final isBengali = VoiceService.instance.isBengali;
    VoiceService.instance.speak(isBengali ? _current.spokenTextBengali : _current.spokenText);
  }

  void _togglePause() {
    final isBengali = VoiceService.instance.isBengali;
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      VoiceService.instance.speak(isBengali ? "স্ক্যানিং স্থগিত করা হয়েছে।" : "Obstacle radar paused.");
    } else {
      VoiceService.instance.speak(isBengali ? "স্ক্যানিং পুনরায় শুরু হয়েছে।" : "Obstacle radar resumed.");
    }
  }

  Color _getUrgencyColor(ObstacleUrgency urgency) {
    switch (urgency) {
      case ObstacleUrgency.critical:
        return AppTheme.alertCritical;
      case ObstacleUrgency.warning:
        return AppTheme.accentAmber;
      case ObstacleUrgency.caution:
        return AppTheme.accentBlue;
      case ObstacleUrgency.info:
        return AppTheme.alertSafe;
    }
  }

  Color _getUrgencyBg(ObstacleUrgency urgency) {
    switch (urgency) {
      case ObstacleUrgency.critical:
        return AppTheme.alertCriticalLight;
      case ObstacleUrgency.warning:
        return AppTheme.accentAmberLight;
      case ObstacleUrgency.caution:
        return AppTheme.accentBlueLight;
      case ObstacleUrgency.info:
        return const Color(0xFFDCFCE7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBengali = VoiceService.instance.isBengali;
    final urgencyColor = _getUrgencyColor(_current.urgency);
    final urgencyBg = _getUrgencyBg(_current.urgency);

    return Scaffold(
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ========================================================
                // Top Action Row: Exit, Radar State & Mode Indicator
                // ========================================================
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: isBengali
                            ? "অবস্ট্যাকল মোড থেকে প্রস্থান করুন"
                            : "Exit Obstacle Avoidance and return to home menu",
                        button: true,
                        child: LiquidGlassContainer(
                          radius: 18,
                          blurSigma: 18.0,
                          opacity: 0.85,
                          borderColor: AppTheme.cardBorder,
                          borderWidth: 2.5,
                          onTap: () {
                            VoiceService.instance.speak(
                                isBengali ? "অবস্ট্যাকল মোড বন্ধ করা হচ্ছে।" : "Exiting obstacle mode.");
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
                                  "EXIT",
                                  style: TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Live AI feed indicator
                    Semantics(
                      label: _isCameraInitialized ? "Live AI Camera feed online" : "Simulation mode",
                      child: LiquidGlassContainer(
                        radius: 18,
                        blurSigma: 18.0,
                        tintColor: _isCameraInitialized ? const Color(0xFFDCFCE7) : Colors.white,
                        opacity: 0.90,
                        borderColor: AppTheme.cardBorder,
                        borderWidth: 2.5,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                          height: 60,
                          child: Center(
                            child: Row(
                              children: [
                                Icon(
                                  _isCameraInitialized ? Icons.videocam : Icons.science,
                                  size: 20,
                                  color: _isCameraInitialized ? AppTheme.alertSafe : AppTheme.cardBorder,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isCameraInitialized
                                      ? (_isPaused ? "PAUSED" : "LIVE AI")
                                      : "TEST",
                                  style: TextStyle(
                                    color: _isCameraInitialized ? AppTheme.cardBorder : AppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
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
                const SizedBox(height: 12),

                // ========================================================
                // Main Scrollable Area with Square YOLO Viewport
                // ========================================================
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ========================================================
                        // Square YOLO Visual Interface (1:1 Aspect Ratio)
                        // Proportionate to phone width for optimal YOLO inference
                        // ========================================================
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: LiquidGlassContainer(
                            radius: 22,
                            blurSigma: 12.0,
                            opacity: 0.88,
                            borderColor: AppTheme.cardBorder,
                            borderWidth: 2.8,
                            padding: const EdgeInsets.all(5),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 1. Live Camera Feed or Sonar Radar Grid
                                  if (_isCameraInitialized && _cameraController != null)
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!.value.previewSize?.height ?? 400,
                                        height: _cameraController!.value.previewSize?.width ?? 400,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    )
                                  else
                                    // High-Tech Radar Sonar Scanning Grid (Simulation Mode)
                                    Container(
                                      color: const Color(0xFF0F172A),
                                      child: CustomPaint(
                                        painter: _RadarGridPainter(
                                          urgencyColor: urgencyColor,
                                        ),
                                      ),
                                    ),

                                  // 2. High-Tech HUD Aiming Reticle (Square Target Box)
                                  Center(
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: urgencyColor.withValues(alpha: 0.9),
                                          width: 2.5,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Crosshair Center
                                          Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: urgencyColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 3. Top YOLO Live Status Pill
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    right: 10,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                                size: 11,
                                                color: _isCameraInitialized ? AppTheme.alertSafe : AppTheme.accentAmber,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _liveHazards.isNotEmpty
                                                    ? "YOLOv8: ${_current.title} (${_liveHazards.length} IN VIEW)"
                                                    : "YOLOv8: ${_current.title}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: urgencyColor.withValues(alpha: 0.90),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isBengali ? _current.zoneLabelBengali : _current.zoneLabel,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 4. Bottom Distance Readout Overlay Strip
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.80),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white24, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isBengali
                                                ? _current.distanceFormattedBengali
                                                : _current.distanceFormatted,
                                            style: TextStyle(
                                              color: urgencyColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            isBengali
                                                ? "আনুমানিক ${_current.stepsFormattedBengali}"
                                                : "APPROX. ${_current.stepsFormatted}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
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
                        ),
                        const SizedBox(height: 12),

                        // ========================================================
                        // Tactile Distance & Voice Advice Card
                        // ========================================================
                        Semantics(
                          label:
                              "Detected obstacle ${_current.title}. Distance ${_current.distanceFormatted}, ${_current.stepsFormatted}. Zone ${_current.zoneLabel}. Tap anywhere to hear again.",
                          button: true,
                          child: LiquidGlassContainer(
                            radius: 20,
                            blurSigma: 16.0,
                            opacity: 0.86,
                            borderColor: AppTheme.cardBorder,
                            borderWidth: 2.5,
                            padding: const EdgeInsets.all(16),
                            onTap: () {
                              final isBn = VoiceService.instance.isBengali;
                              VoiceService.instance.speak(isBn ? _current.spokenTextBengali : _current.spokenText);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isBengali && _current.titleBengali.isNotEmpty
                                            ? _current.titleBengali
                                            : _current.title,
                                        style: const TextStyle(
                                          color: AppTheme.cardBorder,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: urgencyBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.cardBorder, width: 1.8),
                                      ),
                                      child: Text(
                                        isBengali ? "দিক: ${_current.zoneLabelBengali}" : "ZONE: ${_current.zoneLabel}",
                                        style: const TextStyle(
                                          color: AppTheme.cardBorder,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Spoken Advice
                                Text(
                                  isBengali && _current.adviceBengali.isNotEmpty
                                      ? _current.adviceBengali
                                      : _current.advice,
                                  style: const TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Repeat instruction
                                Text(
                                  isBengali
                                      ? "পুনরায় শুনতে কার্ডটিতে ট্যাপ করুন"
                                      : "Tap card anytime to repeat voice alert",
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ========================================================
                // Bottom Physical Action Buttons (Liquid Glass)
                // ========================================================
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: _isCameraInitialized
                            ? (isBengali ? "রিয়েল-টাইম ক্যামেরা স্ক্যান চলছে" : "Live real-time feed active")
                            : (isBengali ? "পরবর্তী নমুনা বাধা দেখুন" : "Next sample obstacle"),
                        button: true,
                        child: LiquidGlassContainer(
                          radius: 18,
                          blurSigma: 18.0,
                          tintColor: AppTheme.accentAmber,
                          opacity: 0.90,
                          borderColor: AppTheme.cardBorder,
                          borderWidth: 2.5,
                          onTap: () {
                            if (_isCameraInitialized) {
                              _captureAndProcessCameraFrame();
                            } else {
                              _nextSimulationObstacle();
                            }
                          },
                          child: SizedBox(
                            height: 64,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isCameraInitialized ? Icons.camera : Icons.radar,
                                  size: 26,
                                  color: AppTheme.cardBorder,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isCameraInitialized ? "SCAN NOW" : "NEXT OBSTACLE",
                                  style: const TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: _isPaused ? "Resume radar scanning" : "Pause radar scanning",
                      button: true,
                      child: SizedBox(
                        width: 76,
                        child: LiquidGlassContainer(
                          radius: 18,
                          blurSigma: 18.0,
                          tintColor: Colors.white,
                          opacity: 0.85,
                          borderColor: AppTheme.cardBorder,
                          borderWidth: 2.5,
                          onTap: _togglePause,
                          child: SizedBox(
                            height: 64,
                            child: Center(
                              child: Icon(
                                _isPaused ? Icons.play_arrow : Icons.pause,
                                size: 32,
                                color: AppTheme.cardBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the futuristic Sonar Radar grid when in simulation or loading
class _RadarGridPainter extends CustomPainter {
  final Color urgencyColor;
  _RadarGridPainter({required this.urgencyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw concentric range rings (0.5m, 1.5m, 3.0m)
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), gridPaint);
    }

    // Draw Crosshair Axes
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);

    // Draw animated scanner sweep tint
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          urgencyColor.withValues(alpha: 0.0),
          urgencyColor.withValues(alpha: 0.35),
        ],
        stops: const [0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.urgencyColor != urgencyColor;
}
