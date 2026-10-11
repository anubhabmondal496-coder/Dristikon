import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CurrencyPrediction {
  final String? denomination; // "10", "20", "50", "100", "200", "500", or null
  final double confidence;
  final bool isConfident;
  final String statusBengali;
  final String statusEnglish;

  const CurrencyPrediction({
    this.denomination,
    required this.confidence,
    required this.isConfident,
    required this.statusBengali,
    required this.statusEnglish,
  });

  static const CurrencyPrediction empty = CurrencyPrediction(
    denomination: null,
    confidence: 0.0,
    isConfident: false,
    statusBengali: "নোটটি ক্যামেরার সামনে ধরুন",
    statusEnglish: "Hold note before the camera",
  );
}

class CurrencyClassifierService {
  static final CurrencyClassifierService instance = CurrencyClassifierService._internal();
  CurrencyClassifierService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  bool _isBusy = false;

  final List<String> _classes = const ["10", "20", "50", "100", "200", "500"];
  static const double confidenceThreshold = 0.70;

  // Temporal smoothing queue (stores last 3 predictions)
  final List<String> _recentPredictions = [];
  static const int requiredStableFrames = 3;

  bool get isModelLoaded => _isModelLoaded;

  /// Loads the TFLite model from assets
  Future<bool> loadModel() async {
    if (_isModelLoaded && _interpreter != null) return true;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/currency_model.tflite',
        options: options,
      );
      _interpreter?.allocateTensors();
      _isModelLoaded = true;
      debugPrint("[CurrencyClassifier] Successfully loaded currency_model.tflite");
      return true;
    } catch (e) {
      debugPrint("[CurrencyClassifier] Error loading TFLite model: $e");
      _isModelLoaded = false;
      return false;
    }
  }

  /// Run inference on JPEG/PNG image bytes captured from the camera
  Future<CurrencyPrediction> classifyImageBytes(Uint8List imageBytes) async {
    if (_isBusy) return CurrencyPrediction.empty;
    _isBusy = true;

    try {
      if (!_isModelLoaded) {
        final ok = await loadModel();
        if (!ok || _interpreter == null) {
          _isBusy = false;
          return CurrencyPrediction.empty;
        }
      }

      // Decode image
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        _isBusy = false;
        return CurrencyPrediction.empty;
      }

      // Preprocessing: Resize to 128x128
      final resized = img.copyResize(decoded, width: 128, height: 128);

      // Construct Float32 input tensor with BGR channel ordering
      // Input shape: [1, 128, 128, 3]
      final input = List.generate(
        1,
        (_) => List.generate(
          128,
          (y) => List.generate(
            128,
            (x) {
              final pixel = resized.getPixel(x, y);
              // BGR normalized to 0.0 - 1.0 (matching training pipeline)
              final b = pixel.b / 255.0;
              final g = pixel.g / 255.0;
              final r = pixel.r / 255.0;
              return [b, g, r];
            },
          ),
        ),
      );

      // Output shape: [1, 6]
      final output = List.generate(1, (_) => List.filled(6, 0.0));

      _interpreter!.run(input, output);

      final probabilities = output[0];
      int maxIdx = 0;
      double maxProb = probabilities[0];

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

      final rawClass = _classes[maxIdx];
      debugPrint("[CurrencyClassifier] Raw pred: $rawClass (${(maxProb * 100).toStringAsFixed(1)}%)");

      // Apply confidence threshold and temporal smoothing
      if (maxProb >= confidenceThreshold) {
        _recentPredictions.add(rawClass);
        if (_recentPredictions.length > requiredStableFrames) {
          _recentPredictions.removeAt(0);
        }

        // Check if all recent predictions agree
        final isStable = _recentPredictions.length >= requiredStableFrames &&
            _recentPredictions.every((p) => p == rawClass);

        _isBusy = false;

        if (isStable) {
          return CurrencyPrediction(
            denomination: rawClass,
            confidence: maxProb,
            isConfident: true,
            statusBengali: "নোটটি সফলভাবে শনাক্ত হয়েছে",
            statusEnglish: "Banknote successfully detected",
          );
        } else {
          return CurrencyPrediction(
            denomination: rawClass,
            confidence: maxProb,
            isConfident: false,
            statusBengali: "নোট শনাক্ত হচ্ছে…",
            statusEnglish: "Scanning note...",
          );
        }
      } else {
        _recentPredictions.clear();
        _isBusy = false;
        return const CurrencyPrediction(
          denomination: null,
          confidence: 0.0,
          isConfident: false,
          statusBengali: "নোটটি ক্যামেরার সামনে ধরুন",
          statusEnglish: "Hold note before the camera",
        );
      }
    } catch (e) {
      debugPrint("[CurrencyClassifier] Inference error: $e");
      _isBusy = false;
      return CurrencyPrediction.empty;
    }
  }

  void resetSmoothing() {
    _recentPredictions.clear();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}
