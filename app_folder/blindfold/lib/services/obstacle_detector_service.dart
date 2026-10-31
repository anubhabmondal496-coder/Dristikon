import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/obstacle_detection.dart';

/// Temporary candidate box used during YOLO output decoding & NMS
class _CandidateBox {
  final int classIdx;
  final double confidence;
  final double cx;
  final double cy;
  final double w;
  final double h;

  const _CandidateBox({
    required this.classIdx,
    required this.confidence,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
  });

  double get x1 => cx - w / 2.0;
  double get y1 => cy - h / 2.0;
  double get x2 => cx + w / 2.0;
  double get y2 => cy + h / 2.0;

  double iouWith(_CandidateBox other) {
    final interX1 = math.max(x1, other.x1);
    final interY1 = math.max(y1, other.y1);
    final interX2 = math.min(x2, other.x2);
    final interY2 = math.min(y2, other.y2);

    final interW = math.max(0.0, interX2 - interX1);
    final interH = math.max(0.0, interY2 - interY1);
    final interArea = interW * interH;

    final area1 = w * h;
    final area2 = other.w * other.h;
    final unionArea = area1 + area2 - interArea;

    if (unionArea <= 0.0) return 0.0;
    return interArea / unionArea;
  }
}

/// Real-time on-device service running the YOLO obstacle detection model
/// entirely offline via TensorFlow Lite (`tflite_flutter`), identical to the
/// local currency classifier model.
class ObstacleDetectorService {
  static final ObstacleDetectorService instance = ObstacleDetectorService._internal();
  ObstacleDetectorService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isBusy = false;
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int minThrottleMs = 300; // ~3.3 inferences/sec for responsive UI

  // 10 trained obstacle and hazard classes in exact model order
  final List<String> _classes = const [
    'bench',
    'bike',
    'car',
    'chair',
    'dog',
    'person',
    'pothole',
    'stairs',
    'tree',
    'zebra_crossing',
  ];

  bool get isModelLoaded => _isModelLoaded;
  bool get isBusy => _isBusy;

  /// Loads the TFLite model from assets
  Future<bool> loadModel() async {
    if (_isModelLoaded && _interpreter != null) return true;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/obstacle_model.tflite',
        options: options,
      );
      _interpreter?.allocateTensors();
      _isModelLoaded = true;
      debugPrint("[ObstacleDetector] Successfully loaded assets/obstacle_model.tflite on-device");
      return true;
    } catch (e) {
      debugPrint("[ObstacleDetector] Error loading local TFLite model: $e");
      _isModelLoaded = false;
      return false;
    }
  }

  /// Dispatches a captured camera frame (JPEG/PNG bytes) directly to the on-device TFLite model
  Future<ObstacleDetectionResult> detectObstacles(
    Uint8List imageBytes, {
    double confidence = 0.35,
  }) async {
    final now = DateTime.now();
    if (_isBusy || now.difference(_lastRequestTime).inMilliseconds < minThrottleMs) {
      return ObstacleDetectionResult.empty;
    }

    _isBusy = true;
    _lastRequestTime = now;
    final stopwatch = Stopwatch()..start();

    try {
      if (!_isModelLoaded || _interpreter == null) {
        final ok = await loadModel();
        if (!ok || _interpreter == null) {
          _isBusy = false;
          return ObstacleDetectionResult.empty;
        }
      }

      // 1. Decode camera frame
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        _isBusy = false;
        return ObstacleDetectionResult.empty;
      }

      final origW = decoded.width.toDouble();
      final origH = decoded.height.toDouble();

      // 2. Preprocessing: Resize to 320x320
      final resized = img.copyResize(decoded, width: 320, height: 320);

      // 3. Construct Float32 input tensor [1, 320, 320, 3] with RGB normalized to 0.0 - 1.0
      final input = List.generate(
        1,
        (_) => List.generate(
          320,
          (y) => List.generate(
            320,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // 4. Output tensor: [1, 14, 2100]
      final output = List.generate(
        1,
        (_) => List.generate(14, (_) => List<double>.filled(2100, 0.0)),
      );

      // 5. Run on-device inference
      _interpreter!.run(input, output);

      final out = output[0]; // [14, 2100]

      // 6. Parse candidate boxes above confidence threshold
      final candidates = <_CandidateBox>[];
      for (int i = 0; i < 2100; i++) {
        double maxClassProb = 0.0;
        int maxClassIdx = -1;

        for (int c = 0; c < 10; c++) {
          final p = out[4 + c][i];
          if (p > maxClassProb) {
            maxClassProb = p;
            maxClassIdx = c;
          }
        }

        if (maxClassProb >= confidence && maxClassIdx >= 0) {
          final cx = out[0][i];
          final cy = out[1][i];
          final w = out[2][i];
          final h = out[3][i];

          // Filter out degenerate boxes
          if (w > 2 && h > 2) {
            candidates.add(
              _CandidateBox(
                classIdx: maxClassIdx,
                confidence: maxClassProb,
                cx: cx,
                cy: cy,
                w: w,
                h: h,
              ),
            );
          }
        }
      }

      // 7. Non-Maximum Suppression (NMS) with IoU threshold 0.45
      candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
      final selectedBoxes = <_CandidateBox>[];
      const double iouThreshold = 0.45;

      for (final box in candidates) {
        bool suppress = false;
        for (final kept in selectedBoxes) {
          if (box.iouWith(kept) > iouThreshold) {
            suppress = true;
            break;
          }
        }
        if (!suppress) {
          selectedBoxes.add(box);
          if (selectedBoxes.length >= 8) break; // Maximum 8 hazards per frame
        }
      }

      // 8. Convert selected boxes to ObstacleDetection with physical monocular distance
      final hazards = <ObstacleDetection>[];
      final scaleX = origW / 320.0;
      final scaleY = origH / 320.0;

      for (final box in selectedBoxes) {
        final rawX1 = (box.cx - box.w / 2.0).clamp(0.0, 320.0);
        final rawY1 = (box.cy - box.h / 2.0).clamp(0.0, 320.0);
        final rawX2 = (box.cx + box.w / 2.0).clamp(0.0, 320.0);
        final rawY2 = (box.cy + box.h / 2.0).clamp(0.0, 320.0);

        final x1 = rawX1 * scaleX;
        final y1 = rawY1 * scaleY;
        final x2 = rawX2 * scaleX;
        final y2 = rawY2 * scaleY;

        final detection = ObstacleDetection.fromRawBoundingBox(
          category: _classes[box.classIdx],
          confidence: box.confidence,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          frameWidth: origW,
          frameHeight: origH,
        );

        hazards.add(detection);
      }

      // 9. Prioritize detections: Center corridor hazards closer to the user come first
      hazards.sort((a, b) {
        final penaltyA = a.zone == SpatialZone.center ? 0.0 : 0.8;
        final penaltyB = b.zone == SpatialZone.center ? 0.0 : 0.8;
        final scoreA = a.distanceMeters + penaltyA;
        final scoreB = b.distanceMeters + penaltyB;
        return scoreA.compareTo(scoreB);
      });

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMilliseconds;

      if (hazards.isEmpty) {
        return ObstacleDetectionResult(
          detectionCount: 0,
          primaryHazard: null,
          allHazards: const [],
          spokenAlert: 'Path clear ahead. Walk freely.',
          spokenAlertBengali: 'সামনে পথ পরিষ্কার। নিশ্চিন্তে হাঁটুন।',
          hapticPattern: 'GENTLE_PULSE',
          latencyMs: latencyMs,
          timestamp: DateTime.now(),
        );
      }

      final primary = hazards.first;

      String hapticPattern = 'SINGLE_PULSE';
      if (primary.urgency == ObstacleUrgency.critical) {
        hapticPattern = 'CONTINUOUS_URGENT';
      } else if (primary.urgency == ObstacleUrgency.warning) {
        hapticPattern = 'DOUBLE_PULSE_HEAVY';
      }

      return ObstacleDetectionResult(
        detectionCount: hazards.length,
        primaryHazard: primary,
        allHazards: hazards,
        spokenAlert: primary.spokenText,
        spokenAlertBengali: primary.spokenTextBengali,
        hapticPattern: hapticPattern,
        latencyMs: latencyMs,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint("[ObstacleDetector] Inference error: $e");
      return ObstacleDetectionResult.empty;
    } finally {
      _isBusy = false;
    }
  }

  /// Closes interpreter resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}
