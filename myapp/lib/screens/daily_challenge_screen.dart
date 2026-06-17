import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/quiz_provider.dart';
import '../providers/user_provider.dart';
import '../services/daily_challenge_service.dart';
import '../widgets/quiz_active_view.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final _service = DailyChallengeService();
  bool _started = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _startChallenge(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final questions = await _service.fetchOrCreateTodayQuestions();
      if (!mounted) return;
      await context.read<QuizProvider>().startQuizWithQuestions(questions);
      setState(() {
        _started = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();
    final user = context.watch<UserProvider>().user;
    final alreadyDone = user?.lastDailyDate == DailyChallengeService.todayKey;

    if (!_started) {
      if (_isLoading) return _buildLoading();
      if (_error != null) return _buildError(context);
      return _buildLobby(context, alreadyDone, user);
    }

    return switch (quiz.status) {
      QuizStatus.loading => _buildLoading(),
      QuizStatus.active => QuizActiveView(
        quiz: quiz,
        title: 'Tantangan Harian',
        onExit: () {
          quiz.reset();
          context.go('/');
        },
      ),
      QuizStatus.finished => _DailyFinishedView(quiz: quiz),
      QuizStatus.error => _buildError(context, message: quiz.errorMessage),
      QuizStatus.idle => _buildLobby(context, alreadyDone, user),
    };
  }

  Widget _buildLobby(BuildContext context, bool alreadyDone, dynamic user) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DailyChallengeService.todayKey;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tantangan Harian'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  alreadyDone
                      ? Icons.emoji_events_rounded
                      : Icons.calendar_today_rounded,
                  size: 56,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tantangan Harian',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                today,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              if (alreadyDone) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Sudah selesai!',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+${user?.lastDailyScore ?? 0} XP didapat hari ini',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kembali lagi besok untuk tantangan baru!',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.quiz_rounded, label: '10 soal'),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.category_rounded, label: 'Semua kategori'),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.shuffle_rounded, label: 'Tingkat campur'),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.auto_awesome_rounded,
                        label: 'XP 2× hari ini!',
                        highlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _startChallenge(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Mulai Tantangan'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError(BuildContext context, {String? message}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tantangan Harian')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                message ?? _error ?? 'Terjadi kesalahan. Coba lagi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _InfoRow({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: highlight ? FontWeight.bold : null,
              ),
        ),
      ],
    );
  }
}

// ── Finished ───────────────────────────────────────────────────────────────

class _DailyFinishedView extends StatefulWidget {
  final QuizProvider quiz;
  const _DailyFinishedView({required this.quiz});

  @override
  State<_DailyFinishedView> createState() => _DailyFinishedViewState();
}

class _DailyFinishedViewState extends State<_DailyFinishedView> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _saved) return;
      _saved = true;
      final quiz = widget.quiz;
      final answers = List.generate(quiz.questions.length, (i) {
        final q = quiz.questions[i];
        final selected = quiz.selectedAnswers[i];
        return {
          'question': q.question,
          'correctAnswer': q.correctAnswer,
          'selectedAnswer': selected ?? '',
          'isCorrect': selected == q.correctAnswer,
          'points': i < quiz.pointsPerQuestion.length ? quiz.pointsPerQuestion[i] : 0,
        };
      });
      context.read<UserProvider>().simpanHasilDaily(
        skorAkhir: quiz.totalPoints,
        jumlahBenar: quiz.score,
        totalSoal: quiz.questions.length,
        answers: answers,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final total = quiz.questions.length;
    final score = quiz.score;
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final xpGained = quiz.totalPoints * 2;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (icon, label) = switch (pct) {
      >= 80 => (Icons.emoji_events_rounded, 'Luar Biasa!'),
      >= 60 => (Icons.thumb_up_rounded, 'Bagus!'),
      >= 40 => (Icons.sentiment_neutral_rounded, 'Lumayan!'),
      _ => (Icons.menu_book_rounded, 'Terus Belajar!'),
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
                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tantangan Harian Selesai!',
                  style: textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                ),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
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
                      label: 'XP Didapat (2×)',
                      value: '+$xpGained XP',
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
                      value: quiz.maxStreak > 0 ? '${quiz.maxStreak}x beruntun' : '-',
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
