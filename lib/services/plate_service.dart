import 'package:shared_preferences/shared_preferences.dart';

/// Excepción personalizada para fallos en la obtención de matrículas
class PlateException implements Exception {
  final String message;
  PlateException(this.message);

  @override
  String toString() => 'PlateException: $message';
}

/// Modelo de resultado que devuelve el servicio
class PlateResult {
  final String plate;
  final DateTime updatedAt;

  PlateResult({required this.plate, required this.updatedAt});

  @override
  String toString() => '$plate (actualizado: $updatedAt)';
}

/// Servicio encargado de obtener, cachear y validar la última matrícula DGT
class PlateService {
  // Claves para almacenamiento local
  static const String _plateKey = 'dgt_last_plate';
  static const String _updatedKey = 'dgt_last_updated_iso';

  // Endpoint simulado (cambiar por tu API real)
  static const String _apiEndpoint =
      'https://api.tu-backend.com/dgt/last_plate';

  /// Obtiene la última matrícula.
  /// Si hay conexión: consulta, cachea y devuelve.
  /// Si falla: intenta devolver la versión cacheada o lanza PlateException.
  Future<PlateResult> fetchLatestPlate() async {
    try {
      // 🌐 TODO: Reemplazar por llamada HTTP real
      // final response = await http.get(Uri.parse(_apiEndpoint));
      // if (response.statusCode != 200) throw PlateException('HTTP ${response.statusCode}');

      // Simulación de latencia de red
      await Future.delayed(const Duration(milliseconds: 900));

      // Mock con formato DGT válido
      final now = DateTime.now();
      final plateData = PlateResult(
        plate: _generateValidMockPlate(now),
        updatedAt: now,
      );

      // 💾 Guardar en caché
      await _saveToStorage(plateData);
      return plateData;
    } catch (e) {
      // 🔄 Fallback a caché si hay error de red
      final cached = await getCachedPlate();
      if (cached != null) return cached;

      throw PlateException('Error de conexión y sin datos cacheados');
    }
  }

  /// Devuelve la última matrícula guardada localmente (sin llamar a red)
  Future<PlateResult?> getCachedPlate() async {
    final prefs = await SharedPreferences.getInstance();
    final plate = prefs.getString(_plateKey);
    final isoDate = prefs.getString(_updatedKey);

    if (plate != null && isoDate != null) {
      return PlateResult(plate: plate, updatedAt: DateTime.parse(isoDate));
    }
    return null;
  }

  /// Limpia la caché local (útil para testing o forzar resync)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plateKey);
    await prefs.remove(_updatedKey);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MÉTODOS INTERNOS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _saveToStorage(PlateResult data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plateKey, data.plate);
    await prefs.setString(_updatedKey, data.updatedAt.toIso8601String());
  }

  /// Genera una matrícula mock válida para pruebas
  /// Formato: XXXX LLL (consonantes válidas DGT)
  String _generateValidMockPlate(DateTime seed) {
    final number = (seed.millisecondsSinceEpoch % 10000).toString().padLeft(
      4,
      '0',
    );
    const validLetters = 'BCDFGHJKLMNPRSTVWXYZ';

    final l1 = validLetters[seed.day % validLetters.length];
    final l2 = validLetters[seed.month % validLetters.length];
    final l3 = validLetters[(seed.year + seed.hour) % validLetters.length];

    return '$number $l1$l2$l3';
  }
}
