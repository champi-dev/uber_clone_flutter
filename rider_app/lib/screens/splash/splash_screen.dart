import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (!next.isLoading) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          if (next.value != null) {
            context.go('/home');
          } else {
            context.go('/login');
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Opacity(
            opacity: _c.value,
            child: Transform.scale(
              scale: 0.8 + _c.value * 0.2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.local_taxi, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text('RideNow',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  const Text('Your ride, on demand',
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
