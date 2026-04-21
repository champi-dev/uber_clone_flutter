import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(user.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          const SizedBox(height: 4),
          Center(child: Text(user.email, style: const TextStyle(color: AppColors.textSecondary))),
          const SizedBox(height: 4),
          Center(child: Text(user.phone, style: const TextStyle(color: AppColors.textSecondary))),
          const SizedBox(height: 8),
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text('${user.ratingAvg.toStringAsFixed(2)} (${user.ratingCount})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Saved Places'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/saved-places'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ride History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/history'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'RideNow',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Local demo • Montería, Colombia',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
