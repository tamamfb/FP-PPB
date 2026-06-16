import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isRegister = false;

  Future<void> _handleAuth() async {
    final emailOrUsername = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (emailOrUsername.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email/Username dan Password tidak boleh kosong!'),
        ),
      );
      return;
    }

    if (_isRegister && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username wajib diisi saat register!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? result;

    if (_isRegister) {
      result = await AuthService().register(
        email: emailOrUsername,
        password: password,
        username: username,
      );
    } else {
      result = await AuthService().login(
        logininput: emailOrUsername,
        password: password,
      );
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isRegister ? 'Register berhasil!' : 'Login berhasil!'),
          backgroundColor: Colors.green,
        ),
      );

      if (_isRegister) {
        setState(() => _isRegister = false);
        _usernameController.clear();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 80),

              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'TriLearn',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(height: 40),

              /// EMAIL / USERNAME
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email / Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 16),

              /// USERNAME (ONLY REGISTER)
              if (_isRegister)
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

              if (_isRegister) const SizedBox(height: 16),

              /// PASSWORD
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 20),

              /// TOGGLE BUTTON
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isRegister = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isRegister
                            ? colorScheme.primary
                            : Colors.grey[300],
                        foregroundColor: !_isRegister
                            ? Colors.white
                            : Colors.black,
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isRegister = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRegister
                            ? colorScheme.primary
                            : Colors.grey[300],
                        foregroundColor: _isRegister
                            ? Colors.white
                            : Colors.black,
                      ),
                      child: const Text('Register'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// BUTTON ACTION
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isRegister ? 'Daftar' : 'Masuk',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 40),

              Text(
                '*Gunakan Email atau Username untuk login',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
