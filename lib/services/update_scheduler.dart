import 'dart:developer' as developer;
import 'package:workmanager/workmanager.dart';
import 'plate_service.dart';

/// Nombre único para identificar la tarea en WorkManager
const String _taskName = 'dgt_plate_daily_sync';

/// ⚠️ FUNCIÓN TOP-LEVEL (fuera de clases) requerida por WorkManager
/// Se ejecuta en un isolate de fondo.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      developer.log('🔄 Ejecutando sync de matrícula en background...', name: 'Scheduler');
      
      final service = PlateService();
      await service.fetchLatestPlate();
      
      developer.log('✅ Matrícula actualizada y cacheada correctamente.', name: 'Scheduler');
      return true;
    } catch (e, stack) {
      developer.log('❌ Error en sync: $e\n$stack', name: 'Scheduler', level: 1000);
      return false;
    } finally {
      // ✅ CORREGIDO: Llamada explícita al método estático público
      await UpdateScheduler.scheduleNextSync();
    }
  });
}

/// Gestor de la programación diaria a las 16:00
class UpdateScheduler {
  /// Inicializa la programación. Llámalo UNA sola vez al inicio de la app.
  static Future<void> initialize() async {
    await scheduleNextSync();
  }

  /// Calcula el tiempo restante hasta las 16:00 y registra la tarea en WorkManager
  /// ✅ Se eliminó el '_' para que sea accesible desde callbackDispatcher
  static Future<void> scheduleNextSync() async {
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, 16, 0, 0);

    // Si ya pasaron las 16:00 (o es exactamente esa hora), programar para mañana
    if (targetTime.isBefore(now) || targetTime.isAtSameMomentAs(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    final delay = targetTime.difference(now);
    final delayInSeconds = delay.inSeconds;

    developer.log(
      '⏰ Próxima sync: ${targetTime.toLocal().toString()} (delay: ${delayInSeconds}s)',
      name: 'Scheduler',
    );

    // registerOneOffTask con initialDelay es la forma más fiable de simular
    // una hora fija respetando las restricciones de Doze y Android 12+.
    await Workmanager().registerOneOffTask(
      _taskName,
      _taskName,
      initialDelay: Duration(seconds: delayInSeconds),
      existingWorkPolicy: ExistingWorkPolicy.replace, // Evita tareas duplicadas
    );
  }
}