import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/user_provider.dart';
import 'providers/quiz_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: C will add Firebase.initializeApp() here
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
