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
          LinearProgressIndicator(
            value: (quiz.currentIndex + 1) / quiz.questions.length,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soal ${quiz.currentIndex + 1} / ${quiz.questions.length}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        isCorrect:
                            answered && answer == question.correctAnswer,
                        isWrong: answered &&
                            answer == selectedAnswer &&
                            answer != question.correctAnswer,
                        onTap: answered
                            ? null
                            : () => quiz.answerQuestion(answer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80), // space for the button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: answered
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: FilledButton(
                onPressed: quiz.nextQuestion,
                child: Text(quiz.isLastQuestion ? 'Selesai' : 'Selanjutnya'),
              ),
            )
          : null,
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const SizedBox(height: 48),
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
