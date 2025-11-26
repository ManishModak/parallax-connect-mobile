import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/history_screen.dart';
import '../../features/config/presentation/config_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../utils/logger.dart';

// Route paths
class AppRoutes {
  static const splash = '/';
  static const config = '/config';
  static const chat = '/chat';
  static const history = '/history';
  static const settings = '/settings';
}

/// Common fade transition builder
CustomTransitionPage _buildFadeTransition({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Slide from left transition builder
CustomTransitionPage _buildSlideTransition({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(-1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

// GoRouter provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    navigatorKey: GlobalKey<NavigatorState>(),
    debugLogDiagnostics: true,

    // Error builder for 404 and other errors
    errorBuilder: (context, state) {
      Log.e('Navigation error: ${state.error}');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Page not found',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.chat),
                child: const Text('Go to Chat'),
              ),
            ],
          ),
        ),
      );
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) {
          Log.nav('Splash');
          return _buildFadeTransition(
            key: state.pageKey,
            child: const SplashScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.config,
        pageBuilder: (context, state) {
          Log.nav('Config');
          return _buildFadeTransition(
            key: state.pageKey,
            child: const ConfigScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        pageBuilder: (context, state) {
          Log.nav('Chat');
          return _buildFadeTransition(
            key: state.pageKey,
            child: const ChatScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        pageBuilder: (context, state) {
          Log.nav('History');
          return _buildSlideTransition(
            key: state.pageKey,
            child: const HistoryScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) {
          Log.nav('Settings');
          return _buildFadeTransition(
            key: state.pageKey,
            child: const SettingsScreen(),
          );
        },
      ),
    ],
  );
});
