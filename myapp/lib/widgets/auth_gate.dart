import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // TODO: C - replace with StreamBuilder on authStateChanges
  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
