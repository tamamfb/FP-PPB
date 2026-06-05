import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) quiz.reset();
      },
      child: switch (quiz.status) {
        QuizStatus.loading  => const _LoadingView(),
        QuizStatus.active   => _ActiveView(quiz: quiz),
        QuizStatus.finished => _FinishedView(quiz: quiz),
        QuizStatus.error    => _ErrorView(quiz: quiz),
        QuizStatus.idle     => const _LoadingView(),
      },
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

Color _timerColor(double value) {
  if (value > 0.5) {
    return Color.lerp(Colors.yellow, Colors.green, (value - 0.5) * 2)!;
  }
  return Color.lerp(Colors.red, Colors.yellow, value * 2)!;
}

// ── Loading ────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ── Active ─────────────────────────────────────────────────────────────────

class _ActiveView extends StatelessWidget {
  final QuizProvider quiz;
  const _ActiveView({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final question = quiz.currentQuestion!;
    final selectedAnswer = quiz.selectedAnswers[quiz.currentIndex];
    final answered = selectedAnswer != null;
    final timedOut = selectedAnswer == '';
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.session?.categoryName ?? 'Quiz'),
        leading: BackButton(
          onPressed: () {
            quiz.reset();
            context.go('/solo/category');
          },
        ),
      ),
      body: Column(
        children: [
          // Question progress bar
          LinearProgressIndicator(
            value: (quiz.currentIndex + 1) / quiz.questions.length,
            minHeight: 3,
          ),
          // Info row: soal counter | score | streak
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Soal ${quiz.currentIndex + 1} / ${quiz.questions.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: colorScheme.primary),
                      const SizedBox(width: 3),
                      Text(
                        '${quiz.totalPoints} pts',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (quiz.streak >= 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🔥 ${quiz.streak}x',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Time's up!" banner
                  if (timedOut)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_off_rounded,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Waktu habis! Ini jawaban yang benar.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    question.question,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  ...question.allAnswers.map(
                    (answer) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AnswerCard(
                        answer: answer,
                        isCorrect: answered && answer == question.correctAnswer,
                        isWrong: answered &&
                            answer == selectedAnswer &&
                            answer != question.correctAnswer,
                        onTap: answered
                            ? null
                            : () => quiz.answerQuestion(answer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: FilledButton(
                onPressed: quiz.nextQuestion,
                child: Text(quiz.isLastQuestion ? 'Selesai' : 'Selanjutnya'),
              ),
            ),
          _TimerBar(quiz: quiz),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String answer;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap;

  const _AnswerCard({
    required this.answer,
    required this.isCorrect,
    required this.isWrong,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color borderColor;
    final Color? bgColor;
    final Widget? trailing;

    if (isCorrect) {
      borderColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.12);
      trailing = const Icon(Icons.check_circle_rounded, color: Colors.green);
    } else if (isWrong) {
      borderColor = colorScheme.error;
      bgColor = colorScheme.error.withValues(alpha: 0.12);
      trailing = Icon(Icons.cancel_rounded, color: colorScheme.error);
    } else {
      borderColor = colorScheme.outline.withValues(alpha: 0.4);
      bgColor = null;
      trailing = null;
    }

    return Material(
      color: bgColor ?? Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  answer,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Timer bar ─────────────────────────────────────────────────────────────

class _TimerBar extends StatefulWidget {
  final QuizProvider quiz;
  const _TimerBar({required this.quiz});

  @override
  State<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<_TimerBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _lastIndex = 0;
  bool _lastAnswered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: QuizProvider.secondsPerQuestion),
    );
    _lastIndex = widget.quiz.currentIndex;
    _controller.reverse(from: 1.0);
  }

  @override
  void didUpdateWidget(_TimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idx = widget.quiz.currentIndex;
    final answered = idx < widget.quiz.selectedAnswers.length &&
        widget.quiz.selectedAnswers[idx] != null;

    if (idx != _lastIndex) {
      _lastIndex = idx;
      _lastAnswered = false;
      _controller.reverse(from: 1.0);
    } else if (answered && !_lastAnswered) {
      _lastAnswered = true;
      final timedOut = widget.quiz.selectedAnswers[idx] == '';
      if (timedOut) {
        _controller.value = 0;
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        final seconds = (value * QuizProvider.secondsPerQuestion).ceil();
        final barColor = _timerColor(value);

        const double labelWidth = 36;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labelLeft = constraints.maxWidth * value - labelWidth - 4;

                return SizedBox(
                  height: 32,
                  child: Stack(
                    children: [
                      // Background track
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      // Animated fill, clipped to bar shape
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: value,
                              heightFactor: 1,
                              child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                            ),
                          ),
                        ),
                      ),
                      // Label rides the right edge of the fill, exits left
                      Positioned(
                        left: labelLeft,
                        top: 0,
                        bottom: 0,
                        width: labelWidth,
                        child: Center(
                          child: Text(
                            '${seconds}s',
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ── Finished ───────────────────────────────────────────────────────────────

class _FinishedView extends StatelessWidget {
  final QuizProvider quiz;
  const _FinishedView({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final total = quiz.questions.length;
    final score = quiz.score;
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (icon, label) = switch (pct) {
      >= 80 => (Icons.emoji_events_rounded, 'Luar Biasa!'),
      >= 60 => (Icons.thumb_up_rounded, 'Bagus!'),
      >= 40 => (Icons.sentiment_neutral_rounded, 'Lumayan!'),
      _     => (Icons.menu_book_rounded, 'Terus Belajar!'),
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Icon(icon, size: 72, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                label,
                style: textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Text(
                '$score / $total',
                style: textTheme.displayMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$pct% benar',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 28),
              // Stats card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _StatRow(
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber,
                      label: 'Total Poin',
                      value: '${quiz.totalPoints} pts',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    _StatRow(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: colorScheme.primary,
                      label: 'XP Didapat',
                      value: '+${quiz.totalPoints} XP',
                      valueStyle: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    _StatRow(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: Colors.orange,
                      label: 'Streak Terbaik',
                      value: quiz.maxStreak > 0
                          ? '${quiz.maxStreak}x beruntun'
                          : '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    quiz.reset();
                    context.go('/solo/category');
                  },
                  child: const Text('Main Lagi'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    quiz.reset();
                    context.go('/');
                  },
                  child: const Text('Kembali ke Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Text(label, style: textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: valueStyle ??
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Error ──────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final QuizProvider quiz;
  const _ErrorView({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                quiz.errorMessage ?? 'Terjadi kesalahan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  quiz.reset();
                  context.go('/solo/category');
                },
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
