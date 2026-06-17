import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/user_provider.dart';

class MultiJoinScreen extends StatefulWidget {
  final String? initialCode;
  const MultiJoinScreen({super.key, this.initialCode});

  @override
  State<MultiJoinScreen> createState() => _MultiJoinScreenState();
}

class _MultiJoinScreenState extends State<MultiJoinScreen> {
  final _controller = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text =
        context.read<UserProvider>().user?.displayName ?? '';
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _controller.text = widget.initialCode!.toUpperCase();
      // Auto-join when arriving from a challenge notification
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) return;

    final user = context.read<UserModel?>();
    if (user == null) return;

    final sessionDisplayName = _displayNameController.text.trim();
    if (sessionDisplayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tampilan tidak boleh kosong.')),
      );
      return;
    }

    setState(() => _loading = true);

    final mp = context.read<MultiplayerProvider>();
    await mp.joinRoom(
      roomCode: code,
      uid: user.uid,
      displayName: sessionDisplayName,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (mp.status != MultiplayerStatus.error) {
      context.go('/multi/game');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final code = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Gabung Room')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.login_rounded, size: 64, color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Masukkan Kode Room',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Minta kode 6 karakter dari host untuk bergabung.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              // Code input
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: textTheme.displaySmall?.copyWith(
                  letterSpacing: 10,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '· · · · · ·',
                  hintStyle: textTheme.displaySmall?.copyWith(
                    letterSpacing: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    fontWeight: FontWeight.w300,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Nama Tampilan',
                  hintText: 'Nama kamu di room ini',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              // Error banner
              if (mp.status == MultiplayerStatus.error &&
                  mp.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: colorScheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mp.error!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: bottomPad + 8),
                child: FilledButton(
                  onPressed:
                      (_loading || code.length != 6) ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Gabung'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
