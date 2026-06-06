import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_session.dart';
import '../../models/trivia_category.dart';
import '../../models/user_model.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/quiz_provider.dart';

class MultiCreateScreen extends StatefulWidget {
  const MultiCreateScreen({super.key});

  @override
  State<MultiCreateScreen> createState() => _MultiCreateScreenState();
}

class _MultiCreateScreenState extends State<MultiCreateScreen> {
  int? _categoryId;
  String _categoryName = 'Semua Kategori';
  String _difficulty = 'any';
  String _type = 'any';
  int _amount = 10;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<QuizProvider>().loadCategories();
  }

  @override
  void dispose() {
    context.read<QuizProvider>().clearCategoryCount();
    super.dispose();
  }

  Future<void> _create() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    setState(() => _loading = true);

    final mp = context.read<MultiplayerProvider>();
    await mp.createRoom(
      uid: user.uid,
      displayName: user.displayName,
      settings: QuizSession(
        categoryId: _categoryId,
        categoryName: _categoryName,
        difficulty: _difficulty,
        type: _type,
        amount: _amount,
      ),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (mp.status == MultiplayerStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mp.error ?? 'Gagal membuat room.')),
      );
    } else {
      context.go('/multi/game');
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Room')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        children: [
          _SectionLabel('Kategori'),
          const SizedBox(height: 8),
          quiz.isLoadingCategories
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _CategoryDropdown(
                  categories: quiz.categories,
                  selectedId: _categoryId,
                  onChanged: (id, name) =>
                      setState(() {
                        _categoryId = id;
                        _categoryName = name;
                      }),
                ),
          const SizedBox(height: 24),
          _SectionLabel('Kesulitan'),
          const SizedBox(height: 8),
          _ChipRow<String>(
            options: const {
              'any': 'Semua',
              'easy': 'Mudah',
              'medium': 'Sedang',
              'hard': 'Sulit',
            },
            selected: _difficulty,
            onSelected: (v) => setState(() => _difficulty = v),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Tipe Soal'),
          const SizedBox(height: 8),
          _ChipRow<String>(
            options: const {
              'any': 'Semua',
              'multiple': 'Pilihan Ganda',
              'boolean': 'Benar/Salah',
            },
            selected: _type,
            onSelected: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Jumlah Soal'),
          const SizedBox(height: 8),
          _ChipRow<int>(
            options: const {5: '5', 10: '10', 15: '15', 20: '20'},
            selected: _amount,
            onSelected: (v) => setState(() => _amount = v),
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 16),
        child: FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Buat Room'),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
    );
  }
}

// ── Category dropdown ─────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  final List<TriviaCategory> categories;
  final int? selectedId;
  final void Function(int? id, String name) onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedId,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Semua Kategori'),
            ),
            ...categories.map(
              (c) => DropdownMenuItem<int?>(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (id) {
            if (id == null) {
              onChanged(null, 'Semua Kategori');
            } else {
              final cat = categories.firstWhere((c) => c.id == id);
              onChanged(id, cat.name);
            }
          },
        ),
      ),
    );
  }
}

// ── Generic choice-chip row ───────────────────────────────────────────────

class _ChipRow<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selected;
  final void Function(T) onSelected;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries
          .map(
            (e) => ChoiceChip(
              label: Text(e.value),
              selected: e.key == selected,
              onSelected: (_) => onSelected(e.key),
              showCheckmark: false,
            ),
          )
          .toList(),
    );
  }
}
