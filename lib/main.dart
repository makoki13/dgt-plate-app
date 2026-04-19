import 'package:flutter/material.dart';
import 'services/plate_service.dart';
import 'screens/splash_screen.dart'; // Añade este import

void main() {
  runApp(const DgtPlateApp());
}

class DgtPlateApp extends StatelessWidget {
  const DgtPlateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DGT Matrículas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(), // ✅ Cambiado de HomePage a SplashScreen
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _plateService = PlateService();
  PlateResult? _plateResult;
  String? _plate;
  DateTime? _lastUpdated;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlate(); // Carga automática al abrir la app
  }

  Future<void> _fetchPlate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _plateService.fetchLatestPlate();
      if (mounted) {
        setState(() {
          _plateResult = result;
          _plate = result.plateText;
          _lastUpdated = result.updatedAt;
          _isLoading = false;
        });
      }
    } on PlateException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error inesperado: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTextPlate() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _plate ?? '???? ???',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Última Matrícula DGT'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchPlate,
            tooltip: 'Actualizar manualmente',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPlate,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Consultando web...'),
                    ],
                  )
                else if (_error != null)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _fetchPlate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  )
                else if (_plate != null)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_plateResult?.imageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _plateResult!.imageBytes!,
                            width: 300,
                            height: 100,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        )
                      else
                        _buildTextPlate(),
                      const SizedBox(height: 24),
                      Text(
                        'Actualizado: ${_formatDate(_lastUpdated!)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🔄 Carga al abrir o refrescar',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _fetchPlate,
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Obtener última matrícula'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
