import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/obstacle_detection.dart';

/// Real-time service that passes live camera frames to the obstacle detection model
/// and yields parsed distance-estimated spatial obstacle alerts.
class ObstacleDetectorService {
  static final ObstacleDetectorService instance = ObstacleDetectorService._internal();
  ObstacleDetectorService._internal();

  bool _isBusy = false;
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int minThrottleMs = 350; // Max ~2.8 inferences/sec to preserve battery

  // Backend host URLs (Android emulator uses 10.0.2.2, desktop/web uses 127.0.0.1)
  String _customHost = '';
  int _port = 8000;
  bool _isBackendReachable = false;

  bool get isBusy => _isBusy;
  bool get isBackendReachable => _isBackendReachable;

  void setCustomHost(String host, {int port = 8000}) {
    _customHost = host;
    _port = port;
  }

  /// Determines the best candidate base URLs depending on platform
  List<String> get candidateBaseUrls {
    if (_customHost.isNotEmpty) {
      return ["http://$_customHost:$_port"];
    }
    if (kIsWeb) {
      return ["http://localhost:8000", "http://127.0.0.1:8000"];
    }
    if (Platform.isAndroid) {
      return [
        "http://10.0.2.2:8000", // Android emulator host alias
        "http://127.0.0.1:8000",
        "http://192.168.1.100:8000",
      ];
    }
    return [
      "http://127.0.0.1:8000",
      "http://localhost:8000",
    ];
  }

  /// Verifies if the FastAPI assistive vision backend is online
  Future<bool> checkBackendHealth() async {
    for (final base in candidateBaseUrls) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1200);
        final request = await client.getUrl(Uri.parse('$base/api/v1/health'));
        final response = await request.close().timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          _isBackendReachable = true;
          debugPrint("[ObstacleDetector] Connected to vision backend at $base");
          return true;
        }
      } catch (_) {
        // Try next candidate
      }
    }
    _isBackendReachable = false;
    return false;
  }

  /// Dispatches a captured camera frame (JPEG/PNG bytes) to the YOLO detection model
  Future<ObstacleDetectionResult> detectObstacles(Uint8List imageBytes, {double confidence = 0.35}) async {
    final now = DateTime.now();
    if (_isBusy || now.difference(_lastRequestTime).inMilliseconds < minThrottleMs) {
      return ObstacleDetectionResult.empty;
    }

    _isBusy = true;
    _lastRequestTime = now;

    try {
      // Attempt inference via backend API
      final result = await _callInferenceApi(imageBytes, confidence: confidence);
      if (result != null) {
        _isBackendReachable = true;
        _isBusy = false;
        return result;
      }

      // If backend was unreachable, mark unreachable
      _isBackendReachable = false;
    } catch (e) {
      debugPrint("[ObstacleDetector] Error during detection: $e");
    } finally {
      _isBusy = false;
    }

    return ObstacleDetectionResult.empty;
  }

  /// Sends a multipart HTTP POST containing the image frame to FastAPI
  Future<ObstacleDetectionResult?> _callInferenceApi(
    Uint8List imageBytes, {
    double confidence = 0.35,
  }) async {
    for (final base in candidateBaseUrls) {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);

        final boundary = "----BlindFoldBoundary${DateTime.now().millisecondsSinceEpoch}";
        final uri = Uri.parse("$base/api/v1/vision/detect-obstacles?confidence=$confidence");

        final request = await client.postUrl(uri);
        request.headers.set(HttpHeaders.contentTypeHeader, "multipart/form-data; boundary=$boundary");

        // Build multipart body
        final header = "--$boundary\r\n"
            'Content-Disposition: form-data; name="file"; filename="frame.jpg"\r\n'
            "Content-Type: image/jpeg\r\n\r\n";
        final footer = "\r\n--$boundary--\r\n";

        final headerBytes = utf8.encode(header);
        final footerBytes = utf8.encode(footer);

        request.contentLength = headerBytes.length + imageBytes.length + footerBytes.length;

        request.add(headerBytes);
        request.add(imageBytes);
        request.add(footerBytes);

        final response = await request.close().timeout(const Duration(milliseconds: 2000));

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          if (decoded['success'] == true && decoded['data'] != null) {
            final data = decoded['data'] as Map<String, dynamic>;
            return ObstacleDetectionResult.fromJson(data);
          }
        }
      } catch (_) {
        // Try next candidate base URL
      } finally {
        client?.close();
      }
    }
    return null;
  }
}
