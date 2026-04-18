import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Excepción personalizada para fallos en la obtención de matrículas
class PlateException implements Exception {
  final String message;
  PlateException(this.message);
  @override
  String toString() => 'PlateException: $message';
}

/// Modelo de resultado que incluye texto Y imagen de la matrícula
class PlateResult {
  final String plateText;           // Ej: "6925 NMH"
  final DateTime updatedAt;
  final Uint8List? imageBytes;      // PNG en memoria (puede ser null)

  PlateResult({
    required this.plateText,
    required this.updatedAt,
    this.imageBytes,
  });

  @override
  String toString() => '$plateText (actualizado: $updatedAt)';
}

/// Servicio para obtener la última matrícula DGT con imagen
class PlateService {
  static const String _plateKey = 'dgt_last_plate_text';
  static const String _updatedKey = 'dgt_last_updated_iso';
  static const String _imageKey = 'dgt_last_plate_image_b64'; // Base64 para almacenar en SharedPreferences

  // URL que devuelve PNG directo de la última matrícula
  static const String _imageUrl = 'https://www.seisenlinea.com/ultima-matricula?img=png&url=public';
  // URL alternativa para scraping de texto si la imagen falla
  static const String _htmlUrl = 'https://www.seisenlinea.com/ultima-matricula/';

  /// Obtiene la última matrícula con imagen.
  /// Estrategia: 1) Intenta descargar imagen PNG, 2) Si falla, hace fallback a texto, 3) Si todo falla, usa caché.
  Future<PlateResult> fetchLatestPlate() async {
    try {
      // 🖼️ Intento 1: Descargar imagen PNG directa
      final imageBytes = await _downloadPlateImage();
      if (imageBytes != null) {
        // Extraemos el texto de la imagen (mock: en producción usarías OCR o scraping)
        // Por ahora usamos un placeholder o intentamos scraping ligero
        final plateText = await _extractPlateText() ?? '???? ???';
        
        final result = PlateResult(
          plateText: plateText,
          updatedAt: DateTime.now(),
          imageBytes: imageBytes,
        );
        await _saveToStorage(result);
        return result;
      }
    } catch (e) {
      // Si falla la imagen, continuamos con fallback a texto
    }

    try {
      // 📝 Intento 2: Scraping ligero del texto desde HTML
      final plateText = await _extractPlateText();
      if (plateText != null && plateText.isNotEmpty) {
        final result = PlateResult(
          plateText: plateText,
          updatedAt: DateTime.now(),
        );
        await _saveToStorage(result);
        return result;
      }
    } catch (e) {
      // Continuamos con caché
    }

    // 🔄 Fallback: Devolver caché si hay
    final cached = await getCachedPlate();
    if (cached != null) return cached;

    throw PlateException('No se pudo obtener la matrícula: sin conexión y sin datos cacheados');
  }

  /// Descarga la imagen PNG desde seisenlinea
  Future<Uint8List?> _downloadPlateImage() async {
    try {
      final response = await http
          .get(
            Uri.parse(_imageUrl),
            headers: {
              'User-Agent': 'DGT-Plate-App/1.0 (Flutter)',
              'Accept': 'image/png',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.length > 100) {
        // Validación básica: que sea PNG (firma 89 50 4E 47)
        if (response.bodyBytes[0] == 0x89 && 
            response.bodyBytes[1] == 0x50 && 
            response.bodyBytes[2] == 0x4E && 
            response.bodyBytes[3] == 0x47) {
          return response.bodyBytes;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extrae el texto de la matrícula haciendo scraping ligero del HTML
  Future<String?> _extractPlateText() async {
    try {
      final response = await http
          .get(
            Uri.parse(_htmlUrl),
            headers: {'User-Agent': 'DGT-Plate-App/1.0 (Flutter)'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final html = response.body;
        // Patrón simple: buscar "última matrícula asignada... es: XXXX LLL"
        // Ajustar según la estructura real de la web
        final regex = RegExp(r'(\d{4})\s+([BCDFGHJKLMNPRSTVWXYZ]{3})');
        final match = regex.firstMatch(html);
        if (match != null) {
          return '${match.group(1)} ${match.group(2)}';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Devuelve la última matrícula cacheada
  Future<PlateResult?> getCachedPlate() async {
    final prefs = await SharedPreferences.getInstance();
    final plate = prefs.getString(_plateKey);
    final isoDate = prefs.getString(_updatedKey);
    final imageB64 = prefs.getString(_imageKey);

    if (plate != null && isoDate != null) {
      Uint8List? imageBytes;
      if (imageB64 != null && imageB64.isNotEmpty) {
        try {
          imageBytes = _base64ToBytes(imageB64);
        } catch (_) {}
      }
      return PlateResult(
        plateText: plate,
        updatedAt: DateTime.parse(isoDate),
        imageBytes: imageBytes,
      );
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plateKey);
    await prefs.remove(_updatedKey);
    await prefs.remove(_imageKey);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MÉTODOS INTERNOS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _saveToStorage(PlateResult data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plateKey, data.plateText);
    await prefs.setString(_updatedKey, data.updatedAt.toIso8601String());
    
    if (data.imageBytes != null) {
      final b64 = _bytesToBase64(data.imageBytes!);
      // SharedPreferences tiene límite ~2MB por clave. Si la imagen es grande, omitir.
      if (b64.length < 1_500_000) {
        await prefs.setString(_imageKey, b64);
      }
    }
  }

  String _bytesToBase64(Uint8List bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    var result = '';
    for (var i = 0; i < bytes.length; i += 3) {
      var b0 = bytes[i];
      var b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      var b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result += alphabet[b0 >> 2];
      result += alphabet[((b0 & 0x03) << 4) | (b1 >> 4)];
      result += i + 1 < bytes.length ? alphabet[((b1 & 0x0F) << 2) | (b2 >> 6)] : '=';
      result += i + 2 < bytes.length ? alphabet[b2 & 0x3F] : '=';
    }
    return result;
  }

  Uint8List _base64ToBytes(String b64) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    var result = <int>[];
    var buffer = 0;
    var bits = 0;
    for (var c in b64.replaceAll(RegExp(r'[^A-Za-z0-9+/]'), '').split('')) {
      var idx = alphabet.indexOf(c);
      if (idx == -1) continue;
      buffer = (buffer << 6) | idx;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        result.add((buffer >> bits) & 0xFF);
      }
    }
    return Uint8List.fromList(result);
  }
}