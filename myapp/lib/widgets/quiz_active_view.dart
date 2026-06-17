import 'package:flutter/material.dart';
import '../providers/quiz_provider.dart';
import 'answer_card.dart';
import 'quiz_timer_bar.dart';

Future<void> showExitQuizDialog(BuildContext context, VoidCallback onConfirm) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Keluar dari kuis?'),
      content: const Text('Progresmu akan hilang jika keluar sekarang.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Keluar',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) onConfirm();
}

class QuizActiveView extends StatelessWidget {
  final QuizProvider quiz;
  final String title;
  final VoidCallback onExit;

  const QuizActiveView({
    super.key,
    required this.quiz,
    required this.title,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final question = quiz.currentQuestion!;
    final selectedAnswer = quiz.selectedAnswers[quiz.currentIndex];
    final answered = selectedAnswer != null;
    final timedOut = selectedAnswer == '';
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showExitQuizDialog(context, onExit);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: BackButton(
            onPressed: () => showExitQuizDialog(context, onExit),
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (quiz.currentIndex + 1) / quiz.questions.length,
              minHeight: 3,
            ),
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
                    if (timedOut)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_off_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Waktu habis! Ini jawaban yang benar.',
                              style: textTheme.bodySmall?.copyWith(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      question.question,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    ...question.allAnswers.map(
                      (answer) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnswerCard(
                          answer: answer,
                          isCorrect: answered && answer == question.correctAnswer,
                          isWrong: answered &&
                              answer == selectedAnswer &&
                              answer != question.correctAnswer,
                          onTap: answered ? null : () => quiz.answerQuestion(answer),
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
            QuizTimerBar(
              totalSeconds: QuizProvider.secondsPerQuestion,
              stopped: answered,
              snapToZero: timedOut,
              resetKey: quiz.currentIndex,
            ),
          ],
        ),
      ),
    );
  }
}
