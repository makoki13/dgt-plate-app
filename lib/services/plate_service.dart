import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PlateException implements Exception {
  final String message;
  PlateException(this.message);
}

class PlateResult {
  final String plateText;
  final DateTime updatedAt;
  final Uint8List? imageBytes;

  PlateResult({
    required this.plateText,
    required this.updatedAt,
    this.imageBytes,
  });
}

class PlateService {
  static const String _plateKey = 'dgt_last_plate_text';
  static const String _updatedKey = 'dgt_last_updated_iso';
  static const String _imageUrl =
      'https://www.seisenlinea.com/ultima-matricula?img=png&url=public';
  static const String _htmlUrl =
      'https://www.seisenlinea.com/ultima-matricula/';

  /// Obtiene la imagen y texto actualizados. Se ejecuta al abrir la app o al refrescar.
  Future<PlateResult> fetchLatestPlate() async {
    Uint8List? imageBytes;
    try {
      final response = await http
          .get(
            Uri.parse(_imageUrl),
            headers: {'User-Agent': 'DGT-Plate-App/1.0'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && _isValidPng(response.bodyBytes)) {
        imageBytes = response.bodyBytes;
      }
    } catch (_) {}

    String plateText = '???? ???';
    try {
      final text = await _extractPlateText();
      if (text != null) plateText = text;
    } catch (_) {}

    final now = DateTime.now();
    final result = PlateResult(
      plateText: plateText,
      updatedAt: now,
      imageBytes: imageBytes,
    );

    // Guardamos SOLO texto y fecha en caché para soporte offline
    await _saveToStorage(result);
    return result;
  }

  /// Devuelve datos cacheados si no hay red
  Future<PlateResult?> getCachedPlate() async {
    final prefs = await SharedPreferences.getInstance();
    final plate = prefs.getString(_plateKey);
    final isoDate = prefs.getString(_updatedKey);
    if (plate != null && isoDate != null) {
      return PlateResult(plateText: plate, updatedAt: DateTime.parse(isoDate));
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plateKey);
    await prefs.remove(_updatedKey);
  }

  Future<void> _saveToStorage(PlateResult data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plateKey, data.plateText);
    await prefs.setString(_updatedKey, data.updatedAt.toIso8601String());
  }

  bool _isValidPng(List<int> bytes) {
    return bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  Future<String?> _extractPlateText() async {
    final response = await http
        .get(Uri.parse(_htmlUrl), headers: {'User-Agent': 'DGT-Plate-App/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final regex = RegExp(r'(\d{4})\s+([BCDFGHJKLMNPRSTVWXYZ]{3})');
      final match = regex.firstMatch(response.body);
      return match != null ? '${match.group(1)} ${match.group(2)}' : null;
    }
    return null;
  }
}
