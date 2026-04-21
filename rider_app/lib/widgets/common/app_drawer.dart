import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.secondary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? 'Rider',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(user?.ratingAvg.toStringAsFixed(2) ?? '5.00',
                              style: const TextStyle(color: Colors.white70)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(icon: Icons.home_outlined, label: 'Home', onTap: () { Navigator.pop(context); context.go('/home'); }),
            _DrawerItem(icon: Icons.history, label: 'Ride History', onTap: () { Navigator.pop(context); context.push('/history'); }),
            _DrawerItem(icon: Icons.bookmark_outline, label: 'Saved Places', onTap: () { Navigator.pop(context); context.push('/saved-places'); }),
            _DrawerItem(icon: Icons.person_outline, label: 'Profile', onTap: () { Navigator.pop(context); context.push('/profile'); }),
            const Divider(),
            _DrawerItem(
              icon: Icons.logout, label: 'Logout', color: AppColors.error,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('RideNow v1.0 — demo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
