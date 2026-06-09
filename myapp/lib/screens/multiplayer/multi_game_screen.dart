import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/multiplayer_player.dart';
import '../../providers/multiplayer_provider.dart';
import '../../services/multiplayer_service.dart';
import '../../widgets/answer_card.dart';
import '../../widgets/quiz_timer_bar.dart';

class MultiGameScreen extends StatelessWidget {
  const MultiGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack(context, mp);
      },
      child: switch (mp.status) {
        MultiplayerStatus.idle => _IdleRedirect(),
        MultiplayerStatus.creating ||
        MultiplayerStatus.joining =>
          const _LoadingView('Menghubungkan...'),
        MultiplayerStatus.loadingQuestions =>
          const _LoadingView('Memuat pertanyaan...'),
        MultiplayerStatus.lobby => _LobbyView(mp: mp),
        MultiplayerStatus.active ||
        MultiplayerStatus.answered =>
          _QuizView(mp: mp),
        MultiplayerStatus.intermission => _IntermissionView(mp: mp),
        MultiplayerStatus.finished => _FinalView(mp: mp),
        MultiplayerStatus.error => _ErrorView(mp: mp),
      },
    );
  }

  Future<void> _handleBack(
      BuildContext context, MultiplayerProvider mp) async {
    final inGame = mp.status == MultiplayerStatus.active ||
        mp.status == MultiplayerStatus.answered ||
        mp.status == MultiplayerStatus.intermission;

    if (inGame) {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Keluar dari Game?'),
              content: Text(
                mp.isHost
                    ? 'Kamu adalah host. Keluar akan mengakhiri permainan untuk semua pemain.'
                    : 'Kamu akan meninggalkan game ini.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirm || !context.mounted) return;
    }

    await mp.leaveRoom();
    if (context.mounted) context.go('/multi');
  }
}

// ── Idle redirect (shouldn't happen in normal flow) ───────────────────────

class _IdleRedirect extends StatefulWidget {
  @override
  State<_IdleRedirect> createState() => _IdleRedirectState();
}

class _IdleRedirectState extends State<_IdleRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (mounted) context.go('/multi');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// ── Loading ────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView(this.message);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ── Lobby ─────────────────────────────────────────────────────────────────

class _LobbyView extends StatelessWidget {
  final MultiplayerProvider mp;
  const _LobbyView({required this.mp});

  @override
  Widget build(BuildContext context) {
    final room = mp.room!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Lobby'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            await mp.leaveRoom();
            if (context.mounted) context.go('/multi');
          },
        ),
      ),
      body: Column(
        children: [
          // Room code card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  'Kode Room',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  room.roomCode,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 10,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: room.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kode disalin!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Salin Kode'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          // Players header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Pemain',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${mp.players.length} / ${MultiplayerService.maxPlayers}',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          // Player list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: mp.players.length,
              itemBuilder: (_, i) {
                final player = mp.players[i];
                return _PlayerTile(
                  player: player,
                  isHost: player.uid == room.hostId,
                  isMe: player.uid == mp.myPlayer?.uid,
                );
              },
            ),
          ),
          // Bottom action
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 16),
            child: mp.isHost
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${room.settings.categoryName}  ·  ${_diffLabel(room.settings.difficulty)}  ·  ${room.settings.amount} soal',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: mp.startGame,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Mulai Game'),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Menunggu host memulai...',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _diffLabel(String d) => switch (d) {
        'easy' => 'Mudah',
        'medium' => 'Sedang',
        'hard' => 'Sulit',
        _ => 'Semua Kesulitan',
      };
}

class _PlayerTile extends StatelessWidget {
  final MultiplayerPlayer player;
  final bool isHost;
  final bool isMe;

  const _PlayerTile({
    required this.player,
    required this.isHost,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial = player.displayName.isNotEmpty
        ? player.displayName[0].toUpperCase()
        : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: textTheme.titleSmall
              ?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          Text(player.displayName),
          if (isMe) ...[
            const SizedBox(width: 6),
            Text(
              '(Kamu)',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
      trailing: isHost
          ? Chip(
              label: const Text('Host'),
              labelStyle: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.primary),
              backgroundColor:
                  colorScheme.primary.withValues(alpha: 0.1),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}

// ── Quiz ──────────────────────────────────────────────────────────────────

class _QuizView extends StatelessWidget {
  final MultiplayerProvider mp;
  const _QuizView({required this.mp});

  @override
  Widget build(BuildContext context) {
    final room = mp.room;
    final question = mp.currentQuestion;

    // Guard: room or question not ready yet (server timestamp still pending).
    if (room == null || question == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final myPlayer = mp.myPlayer;
    final answered = mp.status == MultiplayerStatus.answered;
    final selectedAnswer = myPlayer?.selectedAnswer;
    final timedOut = selectedAnswer == '';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Soal ${room.currentQuestionIndex + 1} / ${room.questions.length}',
        ),
        actions: [
          // Score
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    size: 12, color: colorScheme.primary),
                const SizedBox(width: 3),
                Text(
                  '${myPlayer?.score ?? 0} pts',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Streak
          if ((myPlayer?.streak ?? 0) >= 2)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🔥 ${myPlayer!.streak}x',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Question progress bar
          LinearProgressIndicator(
            value: (room.currentQuestionIndex + 1) / room.questions.length,
            minHeight: 3,
          ),
          // Answered count row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.people_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  '${mp.answeredCount} / ${mp.players.length} menjawab',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (answered) ...[
                  const Spacer(),
                  if (mp.allAnswered)
                    Text(
                      'Semua sudah menjawab!',
                      style: textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600),
                    )
                  else
                    Text(
                      'Menunggu pemain lain...',
                      style: textTheme.bodySmall?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.5),
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
                  // Timeout banner
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
                            color:
                                Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_off_rounded,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Waktu habis! Menunggu pemain lain...',
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
                      child: AnswerCard(
                        answer: answer,
                        isCorrect: false,
                        isWrong: false,
                        isSelected: answered &&
                            selectedAnswer != null &&
                            selectedAnswer.isNotEmpty &&
                            answer == selectedAnswer,
                        onTap: answered
                            ? null
                            : () => mp.submitAnswer(answer),
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
      bottomNavigationBar: QuizTimerBar(
        totalSeconds: 15,
        startFrom: mp.timeLeftMs / MultiplayerService.timeLimitMs,
        stopped: false,
        resetKey: mp.questionKey,
      ),
    );
  }
}

// ── Intermission ──────────────────────────────────────────────────────────

class _IntermissionView extends StatefulWidget {
  final MultiplayerProvider mp;
  const _IntermissionView({required this.mp});

  @override
  State<_IntermissionView> createState() => _IntermissionViewState();
}

class _IntermissionViewState extends State<_IntermissionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _answerFade;
  late final Animation<double> _answerScale;
  late final Animation<double> _pointsFade;
  late final Animation<Offset> _pointsSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _answerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _answerScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );
    _pointsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    _pointsSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = widget.mp;
    final room = mp.room!;
    final question = mp.currentQuestion;
    final myPlayer = mp.myPlayer;
    final leaderboard = mp.leaderboard;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
            'Soal ${room.currentQuestionIndex + 1} Selesai'),
      ),
      body: Column(
        children: [
          // Correct answer banner — animated reveal
          if (question != null)
            FadeTransition(
              opacity: _answerFade,
              child: ScaleTransition(
                scale: _answerScale,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Jawaban Benar',
                            style: textTheme.labelMedium
                                ?.copyWith(color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.correctAnswer,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // My points this round — slides in slightly after the answer
          if (myPlayer != null)
            SlideTransition(
              position: _pointsSlide,
              child: FadeTransition(
                opacity: _pointsFade,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: myPlayer.lastPoints > 0
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        myPlayer.lastPoints > 0
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: myPlayer.lastPoints > 0
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        myPlayer.lastPoints > 0
                            ? 'Kamu mendapat +${myPlayer.lastPoints} pts'
                            : 'Tidak mendapat poin',
                        style: textTheme.bodyMedium?.copyWith(
                          color: myPlayer.lastPoints > 0
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (myPlayer.streak >= 2) ...[
                        const Spacer(),
                        Text(
                          '🔥 ${myPlayer.streak}x',
                          style: textTheme.labelSmall?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          // Leaderboard header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Text(
                  'Papan Skor',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Leaderboard list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: leaderboard.length,
              itemBuilder: (_, i) {
                final player = leaderboard[i];
                final isMe = player.uid == myPlayer?.uid;
                return _LeaderboardTile(
                  rank: i + 1,
                  player: player,
                  isMe: isMe,
                );
              },
            ),
          ),
          // Host action
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 16),
            child: mp.isHost
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: mp.advanceToNext,
                      child: Text(mp.isLastQuestion
                          ? 'Lihat Hasil Akhir'
                          : 'Pertanyaan Berikutnya'),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Menunggu host...',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Final ─────────────────────────────────────────────────────────────────

class _FinalView extends StatelessWidget {
  final MultiplayerProvider mp;
  const _FinalView({required this.mp});

  @override
  Widget build(BuildContext context) {
    final leaderboard = mp.leaderboard;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final winner = leaderboard.isNotEmpty ? leaderboard.first : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Winner celebration
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 64, color: Colors.amber),
                  const SizedBox(height: 8),
                  Text(
                    'Game Selesai!',
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (winner != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${winner.displayName} menang!',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Leaderboard header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Hasil Akhir',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Leaderboard list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: leaderboard.length,
                itemBuilder: (_, i) {
                  final player = leaderboard[i];
                  final isMe = player.uid == mp.myPlayer?.uid;
                  return _LeaderboardTile(
                    rank: i + 1,
                    player: player,
                    isMe: isMe,
                    showLastPoints: false,
                  );
                },
              ),
            ),
            // Actions
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    mp.reset();
                    context.go('/');
                  },
                  child: const Text('Kembali ke Home'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final MultiplayerProvider mp;
  const _ErrorView({required this.mp});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
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
                mp.error ?? 'Terjadi kesalahan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  mp.reset();
                  context.go('/multi');
                },
                child: const Text('Kembali ke Menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared leaderboard tile ───────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final MultiplayerPlayer player;
  final bool isMe;
  final bool showLastPoints;

  const _LeaderboardTile({
    required this.rank,
    required this.player,
    required this.isMe,
    this.showLastPoints = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (medalColor, medalLabel) = switch (rank) {
      1 => (const Color(0xFFFFD700), '🥇'),
      2 => (const Color(0xFFC0C0C0), '🥈'),
      3 => (const Color(0xFFCD7F32), '🥉'),
      _ => (Colors.transparent, '$rank'),
    };

    final highlight = isMe
        ? colorScheme.primary.withValues(alpha: 0.06)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.25))
            : null,
      ),
      child: ListTile(
        leading: rank <= 3
            ? Text(medalLabel, style: const TextStyle(fontSize: 24))
            : CircleAvatar(
                radius: 16,
                backgroundColor:
                    colorScheme.surfaceContainerHighest,
                child: Text(
                  '$rank',
                  style: textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
        title: Row(
          children: [
            Text(
              player.displayName,
              style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
            ),
            if (isMe) ...[
              const SizedBox(width: 6),
              Text(
                '(Kamu)',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${player.score} pts',
              style: textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (showLastPoints && player.lastPoints > 0)
              Text(
                '+${player.lastPoints}',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
