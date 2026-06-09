import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_session.dart';
import '../../models/trivia_category.dart';
import '../../providers/quiz_provider.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  TriviaCategory? _selectedCategory; // null = "Any"
  String _selectedDifficulty = 'any';
  String _selectedType = 'any';
  int _amount = 10;
  bool _categoryOpen = false;

  static const _amountPresets = [5, 10, 15, 20];

  static const _difficultyLabels = {
    'any': 'Any',
    'easy': 'Mudah',
    'medium': 'Sedang',
    'hard': 'Sulit',
  };

  static const _typeLabels = {
    'any': 'Any',
    'multiple': 'Pilihan Ganda',
    'boolean': 'Benar / Salah',
  };

  @override
  void initState() {
    super.initState();
    final quiz = context.read<QuizProvider>();
    quiz.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      quiz.loadCategories();
    });
  }

  @override
  void dispose() {
    context.read<QuizProvider>().removeListener(_onProviderChanged);
    super.dispose();
  }

  // Clamps _amount after a category count finishes loading.
  void _onProviderChanged() {
    final quiz = context.read<QuizProvider>();
    if (!quiz.isLoadingCount && mounted) {
      final max = _maxAmountFor(_selectedDifficulty, quiz);
      if (_amount > max && max > 0) {
        final valid = _amountPresets.where((p) => p <= max).toList();
        setState(() {
          _amount = valid.isNotEmpty ? valid.last : max;
        });
      }
    }
  }

  int _maxAmountFor(String difficulty, QuizProvider quiz) {
    final count = quiz.categoryCount;
    if (count == null) return 20;
    switch (difficulty) {
      case 'easy':   return count.easy.clamp(0, 20);
      case 'medium': return count.medium.clamp(0, 20);
      case 'hard':   return count.hard.clamp(0, 20);
      default:       return count.total.clamp(0, 20);
    }
  }

  bool _isDifficultyEnabled(String difficulty, QuizProvider quiz) {
    if (difficulty == 'any' || quiz.categoryCount == null) return true;
    switch (difficulty) {
      case 'easy':   return quiz.categoryCount!.easy > 0;
      case 'medium': return quiz.categoryCount!.medium > 0;
      case 'hard':   return quiz.categoryCount!.hard > 0;
      default:       return true;
    }
  }

  int? _difficultyCount(String difficulty, QuizProvider quiz) {
    final count = quiz.categoryCount;
    if (count == null) return null;
    switch (difficulty) {
      case 'any':    return count.total;
      case 'easy':   return count.easy;
      case 'medium': return count.medium;
      case 'hard':   return count.hard;
      default:       return null;
    }
  }

  void _selectCategory(TriviaCategory? category, QuizProvider quiz) {
    setState(() {
      _selectedCategory = category;
      _selectedDifficulty = 'any';
      _amount = 10;
      _categoryOpen = false; // collapse after selection
    });
    if (category == null) {
      quiz.clearCategoryCount();
    } else {
      quiz.loadCategoryCount(category.id);
    }
  }

  void _selectDifficulty(String difficulty, QuizProvider quiz) {
    final max = _maxAmountFor(difficulty, quiz);
    setState(() {
      _selectedDifficulty = difficulty;
      if (_amount > max && max > 0) {
        final valid = _amountPresets.where((p) => p <= max).toList();
        _amount = valid.isNotEmpty ? valid.last : max;
      }
    });
  }

  void _startQuiz(BuildContext context, QuizProvider quiz) {
    final session = QuizSession(
      categoryId: _selectedCategory?.id,
      categoryName: _selectedCategory?.name ?? 'Any Category',
      difficulty: _selectedDifficulty,
      type: _selectedType,
      amount: _amount,
    );
    quiz.startQuiz(session);
    context.go('/solo/quiz');
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final max = _maxAmountFor(_selectedDifficulty, quiz);

    final canStart = !quiz.isLoadingCategories &&
        !quiz.isLoadingCount &&
        quiz.categories.isNotEmpty &&
        _amount <= max &&
        max > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Kategori'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Category picker ──────────────────────────────────────────

            _Label('Kategori'),
            const SizedBox(height: 8),

            // Trigger
            InkWell(
              onTap: quiz.isLoadingCategories
                  ? null
                  : () => setState(() => _categoryOpen = !_categoryOpen),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _categoryOpen
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.5),
                    width: _categoryOpen ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (quiz.isLoadingCategories)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _selectedCategory == null
                            ? Icons.shuffle_rounded
                            : Icons.category_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        quiz.isLoadingCategories
                            ? 'Memuat kategori...'
                            : (_selectedCategory?.name ?? 'Any Category'),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    Icon(
                      _categoryOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable list
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _categoryOpen
                  ? SizedBox(
                      height: 260,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: quiz.categories.isEmpty
                              ? _RetryButton(
                                  onRetry: () => quiz.loadCategories())
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: quiz.categories.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      final isSelected =
                                          _selectedCategory == null;
                                      return ColoredBox(
                                        color: isSelected
                                            ? colorScheme.primary
                                                .withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.shuffle_rounded,
                                            color: isSelected
                                                ? colorScheme.primary
                                                : null,
                                          ),
                                          title: Text(
                                            'Any Category',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? colorScheme.primary
                                                  : null,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : null,
                                            ),
                                          ),
                                          onTap: () =>
                                              _selectCategory(null, quiz),
                                        ),
                                      );
                                    }
                                    final category =
                                        quiz.categories[index - 1];
                                    final isSelected =
                                        _selectedCategory?.id == category.id;
                                    return ColoredBox(
                                      color: isSelected
                                          ? colorScheme.primary
                                              .withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      child: ListTile(
                                        title: Text(
                                          category.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? colorScheme.primary
                                                : null,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : null,
                                          ),
                                        ),
                                        onTap: () =>
                                            _selectCategory(category, quiz),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── Difficulty ───────────────────────────────────────────────

            _Label('Kesulitan'),
            const SizedBox(height: 8),
            quiz.isLoadingCount
                ? const LinearProgressIndicator()
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _difficultyLabels.entries.map((e) {
                      final enabled = _isDifficultyEnabled(e.key, quiz);
                      final count = _selectedCategory != null
                          ? _difficultyCount(e.key, quiz)
                          : null;
                      final label =
                          count != null ? '${e.value}  ·  $count' : e.value;
                      return ChoiceChip(
                        label: Text(label),
                        selected: _selectedDifficulty == e.key,
                        onSelected:
                            enabled ? (_) => _selectDifficulty(e.key, quiz) : null,
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 20),

            // ── Type ─────────────────────────────────────────────────────

            _Label('Tipe Soal'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _typeLabels.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.value),
                  selected: _selectedType == e.key,
                  onSelected: (_) => setState(() => _selectedType = e.key),
                  showCheckmark: false,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Amount ───────────────────────────────────────────────────

            _Label('Jumlah Soal'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _amountPresets.map((p) {
                final enabled = p <= max;
                return ChoiceChip(
                  label: Text('$p'),
                  selected: _amount == p,
                  onSelected: enabled ? (_) => setState(() => _amount = p) : null,
                  showCheckmark: false,
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canStart ? () => _startQuiz(context, quiz) : null,
                child: const Text('Mulai Quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryButton({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          const Text('Gagal memuat kategori'),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
