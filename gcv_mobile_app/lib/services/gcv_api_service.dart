import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GCVProcessResult {
  final Uint8List imageBytes;
  final List<dynamic> detections;

  GCVProcessResult({
    required this.imageBytes,
    required this.detections,
  });
}

class GCVApiService {
  // Prevent duplicate customisation requests
  bool _isApplying = false;

  // ANDROID EMULATOR
  final String baseUrl = 'http://10.0.2.2:8010';

  // REAL DEVICE / MAC TESTING
  // final String baseUrl = 'http://127.0.0.1:8010';

  Future<GCVProcessResult?> processCar(Uint8List imageBytes) async {
    final url = Uri.parse('$baseUrl/process-car');

    try {
      final request = http.MultipartRequest('POST', url);

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'car.png',
        ),
      );

      final streamedResponse = await request.send().timeout(
            const Duration(minutes: 15),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final detectionsHeader = response.headers['x-detections'];

        List<dynamic> detections = [];

        if (detectionsHeader != null && detectionsHeader.isNotEmpty) {
          detections = jsonDecode(detectionsHeader);
        }

        debugPrint('DETECTIONS FOUND:');
        debugPrint(detections.toString());

        return GCVProcessResult(
          imageBytes: response.bodyBytes,
          detections: detections,
        );
      }

      debugPrint('PROCESS FAILED: ${response.statusCode}');
      debugPrint(response.body);
    } catch (e) {
      debugPrint('PROCESS ERROR: $e');
    }

    return null;
  }

  Future<Uint8List?> applyModification({
    required Uint8List imageBytes,
    required String prompt,
    required Map<String, dynamic> part,
    required List<dynamic> parts,
  }) async {
    if (_isApplying) {
      debugPrint('CUSTOMISATION ALREADY RUNNING - DUPLICATE REQUEST BLOCKED');
      return null;
    }

    _isApplying = true;

    final url = Uri.parse('$baseUrl/customize-wheel');

    try {
      debugPrint('==============================');
      debugPrint('APPLYING CUSTOMISATION');
      debugPrint('PROMPT: $prompt');
      debugPrint('SELECTED PART: ${part['part']}');
      debugPrint('PART SENT: ${part['part']}');
      debugPrint('BOX SENT: ${part['box']}');
      debugPrint('ALL PARTS SENT: $parts');

      final request = http.MultipartRequest('POST', url);

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'car.png',
        ),
      );

      request.fields['prompt'] = prompt;

      request.fields['part'] = jsonEncode(part);

      request.fields['box'] = jsonEncode(part['box'] ?? []);

      request.fields['mask_poly'] = jsonEncode(parts);

      final streamedResponse = await request.send().timeout(
            const Duration(minutes: 10),
          );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('STATUS CODE: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('CUSTOMISATION SUCCESS');
        return response.bodyBytes;
      }

      debugPrint('CUSTOMISATION FAILED');
      debugPrint(response.body);

    } catch (e) {
      debugPrint('MODIFICATION ERROR: $e');
      
    } finally {
      _isApplying = false;
    }

    return null;
  }
}