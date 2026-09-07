import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_auth_service.dart';
import 'admin_auth_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminRootScreen extends ConsumerWidget {
  const AdminRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('خطأ في التحقق من تسجيل الدخول: $err')),
      ),
      data: (user) {
        if (user == null) {
          return const AdminAuthScreen();
        }
        return const AdminDashboardScreen();
      },
    );
  }
}
