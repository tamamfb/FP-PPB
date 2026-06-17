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
import 'screens/profile_screen.dart';
import 'screens/game_detail_screen.dart';
import 'screens/daily_challenge_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/friends/friend_search_screen.dart';
import 'screens/friends/friend_profile_screen.dart';
import 'screens/friends/notifications_screen.dart';
import 'screens/friends/challenge_invitation_screen.dart';
import 'models/notification_model.dart';
import 'providers/friend_provider.dart';

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
        ChangeNotifierProvider<FriendProvider>(
          create: (context) => FriendProvider(),
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
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/profile/history',
                builder: (context, state) => GameDetailScreen(
                  data: state.extra as Map<String, dynamic>,
                ),
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
                path: '/daily',
                builder: (context, state) => const DailyChallengeScreen(),
              ),
              GoRoute(
                path: '/friends',
                builder: (context, state) => const FriendsScreen(),
              ),
              GoRoute(
                path: '/friends/search',
                builder: (context, state) => const FriendSearchScreen(),
              ),
              GoRoute(
                path: '/friends/profile/:uid',
                builder: (context, state) => FriendProfileScreen(
                  uid: state.pathParameters['uid']!,
                ),
              ),
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/multi',
                builder: (context, state) => const MultiMenuScreen(),
              ),
              GoRoute(
                path: '/multi/create',
                builder: (context, state) => MultiCreateScreen(
                  challengeTargetUid: state.extra as String?,
                ),
              ),
              GoRoute(
                path: '/challenge/invitation',
                builder: (context, state) => ChallengeInvitationScreen(
                  notif: state.extra as NotificationModel,
                ),
              ),
              GoRoute(
                path: '/multi/join',
                builder: (context, state) => MultiJoinScreen(
                  initialCode: state.extra as String?,
                ),
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
