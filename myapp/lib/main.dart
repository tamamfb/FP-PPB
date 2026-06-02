import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/user_provider.dart'; // 👈 1. IMPORT JALUR USERPROVIDER TEMANMU DI SINI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 👈 2. DIUBAH MENJADI MULTIPROVIDER AGAR BISA MENAMPUNG KEDUA PROVIDER SEKALIGUS
    return MultiProvider(
      providers: [
        // Provider milikmu untuk memantau status login Firebase (Auto Redirect)
        StreamProvider<UserModel?>(
          initialData: null,
          create: (context) => AuthService().authStateChanges,
        ),
        // Provider milik Orang A/B yang dicari-cari oleh HomeScreen agar tidak layar merah
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Setup GoRouter dengan proteksi Auto-Redirect Auth
          final GoRouter router = GoRouter(
            initialLocation: '/',
            refreshListenable: GoRouterRefreshListenable(
              Stream.value(Provider.of<UserModel?>(context, listen: true)),
            ),
            redirect: (context, state) {
              final user = Provider.of<UserModel?>(context, listen: false);
              final loggingIn = state.matchedLocation == '/login';

              // Jika user BELUM login dan tidak sedang di halaman login, paksa ke /login
              if (user == null) {
                return loggingIn ? null : '/login';
              }

              // Jika user SUDAH login dan malah mencoba buka halaman login, lempar ke Home
              if (loggingIn) {
                return '/';
              }

              return null;
            },
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const HomeScreen(), // Kerjaan Orang A
              ),
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(), // Kerjaanmu
              ),
            ],
          );

          return MaterialApp.router(
            title: 'TriLearn',
            debugShowCheckedModeBanner: false,
            routerConfig: router, // Menggunakan konfigurasi GoRouter kelompok
          );
        },
      ),
    );
  }
}

// Helper class agar GoRouter bisa membaca Stream dari Provider secara reaktif
class GoRouterRefreshListenable extends ChangeNotifier {
  GoRouterRefreshListenable(Stream stream) {
    notifyListeners();
    stream.listen((_) => notifyListeners());
  }
}
