import 'package:flutter/material.dart';
import '../models/obstacle_detection.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

class WalkingRadarScreen extends StatefulWidget {
  const WalkingRadarScreen({super.key});

  @override
  State<WalkingRadarScreen> createState() => _WalkingRadarScreenState();
}

class _WalkingRadarScreenState extends State<WalkingRadarScreen> {
  final List<ObstacleDetection> _obstacles = ObstacleDetection.defaultObstacles;
  int _currentIndex = 0;
  bool _isPaused = false;

  ObstacleDetection get _current => _obstacles[_currentIndex];

  @override
  void initState() {
    super.initState();
    VoiceService.instance.speak("Obstacle Avoidance mode active. Camera scanning forward.");
  }

  void _nextObstacle() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _obstacles.length;
    });
    VoiceService.instance.speak(_current.spokenText);
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      VoiceService.instance.speak("Obstacle radar paused.");
    } else {
      VoiceService.instance.speak("Obstacle radar resumed.");
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
    final urgencyColor = _getUrgencyColor(_current.urgency);
    final urgencyBg = _getUrgencyBg(_current.urgency);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Row: Exit & Radar State
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: "Exit Obstacle Avoidance and return to home menu",
                      button: true,
                      child: Container(
                        height: 68,
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cardBorder,
                              offset: Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            VoiceService.instance.speak("Exiting obstacle mode.");
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back, size: 28, color: AppTheme.cardBorder),
                          label: const Text(
                            "EXIT",
                            style: TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cardBackground,
                            side: const BorderSide(color: AppTheme.cardBorder, width: 2.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: _isPaused ? "Radar is currently paused" : "Radar is live active",
                    child: Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: _isPaused ? AppTheme.cardBackground : urgencyBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.cardBorder,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isPaused ? "PAUSED" : "ACTIVE",
                        style: TextStyle(
                          color: _isPaused ? AppTheme.cardBorder : urgencyColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Giant Distance Readout Card
              Expanded(
                flex: 3,
                child: Semantics(
                  label: "Detected obstacle ${_current.title}. Distance ${_current.distanceFormatted}, ${_current.stepsFormatted}. Zone ${_current.zoneLabel}. Double tap anywhere to hear again.",
                  button: true,
                  child: InkWell(
                    onTap: () {
                      VoiceService.instance.speak(_current.spokenText);
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: urgencyBg,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppTheme.cardBorder, width: 2),
                            ),
                            child: Text(
                              "ZONE: ${_current.zoneLabel}",
                              style: TextStyle(
                                color: AppTheme.cardBorder,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _current.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackgroundAlt,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.cardBorder, width: 2),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _current.distanceFormatted,
                                  style: TextStyle(
                                    color: urgencyColor,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "APPROX. ${_current.stepsFormatted}",
                                  style: const TextStyle(
                                    color: AppTheme.cardBorder,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _current.advice,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Tap card anytime to repeat voice alert",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Physical Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: "Scan next obstacle in sequence",
                      button: true,
                      child: Container(
                        height: 76,
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cardBorder,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _nextObstacle,
                          icon: const Icon(Icons.radar, size: 32, color: AppTheme.cardBorder),
                          label: const Text(
                            "NEXT OBSTACLE",
                            style: TextStyle(
                              color: AppTheme.cardBorder,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentAmber,
                            side: const BorderSide(color: AppTheme.cardBorder, width: 2.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: _isPaused ? "Resume radar scanning" : "Pause radar scanning",
                    button: true,
                    child: Container(
                      width: 80,
                      height: 76,
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
                        onPressed: _togglePause,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cardBackground,
                          side: const BorderSide(color: AppTheme.cardBorder, width: 2.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause,
                          size: 36,
                          color: AppTheme.cardBorder,
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
    );
  }
}
