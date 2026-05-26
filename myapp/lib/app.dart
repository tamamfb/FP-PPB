import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/solo/category_screen.dart';
import 'screens/solo/quiz_screen.dart';
import 'screens/multiplayer/multi_menu_screen.dart';
import 'screens/multiplayer/lobby_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      name: 'home',
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      name: 'login',
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      name: 'category',
      path: '/solo/category',
      builder: (context, state) => const CategoryScreen(),
    ),
    GoRoute(
      name: 'quiz',
      path: '/solo/quiz',
      builder: (context, state) => const QuizScreen(),
    ),
    GoRoute(
      name: 'multiMenu',
      path: '/multi',
      builder: (context, state) => const MultiMenuScreen(),
    ),
    GoRoute(
      name: 'lobby',
      path: '/multi/lobby',
      builder: (context, state) => const LobbyScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TriLearn',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
