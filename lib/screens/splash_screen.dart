import 'package:flutter/material.dart';
import '../main.dart'; // Ajusta si tu HomePage está en otra ruta

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // ⏱️ Tiempo mínimo visible. Ajusta o quita si prefieres navegar en cuanto termine de cargar
    await Future.delayed(const Duration(seconds: 0));

    if (mounted) {
      // pushReplacement evita que el botón "Atrás" vuelva al splash
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🖼️ Icono centrado
              Image.asset(
                'assets/icon/icon.png',
                width: 100,
                height: 100,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.directions_car,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // 📝 Título
              Text(
                'Última Matrícula',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),

              // ⏳ Indicador de carga
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Cargando...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
