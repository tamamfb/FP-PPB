import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'providers/multiplayer_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/user_provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/solo/category_screen.dart';
import 'screens/solo/quiz_screen.dart';
import 'screens/multiplayer/multi_menu_screen.dart';
import 'screens/multiplayer/multi_create_screen.dart';
import 'screens/multiplayer/multi_join_screen.dart';
import 'screens/multiplayer/multi_game_screen.dart';
import 'theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<UserModel?>(
          initialData: null,
          create: (context) => AuthService().authStateChanges,
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(),
        ),
        ChangeNotifierProvider<QuizProvider>(
          create: (context) => QuizProvider(),
        ),
        ChangeNotifierProvider<MultiplayerProvider>(
          create: (context) => MultiplayerProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final router = GoRouter(
            initialLocation: '/',
            refreshListenable: _GoRouterRefreshListenable(
              Stream.value(Provider.of<UserModel?>(context, listen: true)),
            ),
            redirect: (context, state) {
              final user = Provider.of<UserModel?>(context, listen: false);
              final loggingIn = state.matchedLocation == '/login';
              if (user == null) return loggingIn ? null : '/login';
              if (loggingIn) return '/';
              return null;
            },
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
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
                path: '/multi',
                builder: (context, state) => const MultiMenuScreen(),
              ),
              GoRoute(
                path: '/multi/create',
                builder: (context, state) => const MultiCreateScreen(),
              ),
              GoRoute(
                path: '/multi/join',
                builder: (context, state) => const MultiJoinScreen(),
              ),
              GoRoute(
                path: '/multi/game',
                builder: (context, state) => const MultiGameScreen(),
              ),
            ],
          );

          return MaterialApp.router(
            title: 'TriLearn',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class _GoRouterRefreshListenable extends ChangeNotifier {
  _GoRouterRefreshListenable(Stream stream) {
    notifyListeners();
    stream.listen((_) => notifyListeners());
  }
}
