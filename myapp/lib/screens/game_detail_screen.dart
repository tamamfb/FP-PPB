import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GameDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const GameDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMulti = data['mode'] == 'multiplayer';
    final answers = data['answers'] as List?;
    final skorAkhir = data['skorAkhir'] ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(isMulti ? 'Multiplayer Game' : 'Solo Quiz'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isMulti ? Icons.group_rounded : Icons.person_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$skorAkhir XP',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (!isMulti)
                        Text(
                          'Benar: ${data['jumlahBenar'] ?? '-'} / ${data['totalSoal'] ?? '-'}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (isMulti || answers == null) ...[
            const SizedBox(height: 40),
            Icon(Icons.info_outline_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Detail per soal tidak tersedia untuk game ini.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ] else ...[
            Text(
              'Jawaban per Soal',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(answers.length, (i) {
              final a = answers[i] as Map<String, dynamic>;
              final question = a['question'] as String? ?? '';
              final correctAnswer = a['correctAnswer'] as String? ?? '';
              final selectedAnswer = a['selectedAnswer'] as String? ?? '';
              final isCorrect = a['isCorrect'] as bool? ?? false;
              final points = a['points'] as int? ?? 0;
              final timedOut = selectedAnswer.isEmpty;

              final (statusIcon, statusColor) = timedOut
                  ? (Icons.timer_off_rounded, Colors.orange)
                  : isCorrect
                      ? (Icons.check_circle_rounded, Colors.green)
                      : (Icons.cancel_rounded, colorScheme.error);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Soal ${i + 1}: $question',
                              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (timedOut) ...[
                        _AnswerRow(
                          label: 'Waktu habis',
                          answer: '',
                          color: Colors.orange,
                        ),
                        _AnswerRow(
                          label: 'Jawaban benar',
                          answer: correctAnswer,
                          color: Colors.green,
                        ),
                      ] else if (isCorrect) ...[
                        _AnswerRow(
                          label: 'Jawabanmu',
                          answer: selectedAnswer,
                          color: Colors.green,
                        ),
                      ] else ...[
                        _AnswerRow(
                          label: 'Jawabanmu',
                          answer: selectedAnswer,
                          color: colorScheme.error,
                        ),
                        _AnswerRow(
                          label: 'Jawaban benar',
                          answer: correctAnswer,
                          color: Colors.green,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: points > 0
                                ? colorScheme.primary.withValues(alpha: 0.1)
                                : colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            points > 0 ? '+$points pts' : '0 pts',
                            style: textTheme.labelSmall?.copyWith(
                              color: points > 0 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String answer;
  final Color color;

  const _AnswerRow({required this.label, required this.answer, required this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: Text(
              answer.isEmpty ? '—' : answer,
              style: textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
