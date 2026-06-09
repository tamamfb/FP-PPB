import 'package:flutter/material.dart';

Color timerColor(double value) {
  if (value > 0.5) {
    return Color.lerp(Colors.yellow, Colors.green, (value - 0.5) * 2)!;
  }
  return Color.lerp(Colors.red, Colors.yellow, value * 2)!;
}

/// Animated countdown bar for quiz screens.
///
/// [resetKey]  — change this value to restart the animation (e.g. question index).
/// [startFrom] — fraction (0.0–1.0) to begin from; lets multiplayer sync to
///               the remaining server time instead of always starting at 1.0.
/// [stopped]   — freeze the bar at its current position (player has answered).
/// [snapToZero]— jump instantly to 0 (timed out).
class QuizTimerBar extends StatefulWidget {
  final int totalSeconds;
  final double startFrom;
  final bool stopped;
  final bool snapToZero;
  final Object? resetKey;

  const QuizTimerBar({
    super.key,
    required this.totalSeconds,
    this.startFrom = 1.0,
    this.stopped = false,
    this.snapToZero = false,
    this.resetKey,
  });

  @override
  State<QuizTimerBar> createState() => _QuizTimerBarState();
}

class _QuizTimerBarState extends State<QuizTimerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Object? _lastResetKey;
  bool _lastStopped = false;

  @override
  void initState() {
    super.initState();
    _lastResetKey = widget.resetKey;
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.startFrom),
    );
    _controller.reverse(from: widget.startFrom);
  }

  Duration _durationFor(double fraction) => Duration(
        milliseconds: (fraction * widget.totalSeconds * 1000).round(),
      );

  @override
  void didUpdateWidget(QuizTimerBar old) {
    super.didUpdateWidget(old);

    if (widget.resetKey != _lastResetKey) {
      _lastResetKey = widget.resetKey;
      _lastStopped = false;
      _controller.duration = _durationFor(widget.startFrom);
      _controller.reverse(from: widget.startFrom);
      return;
    }

    if (widget.stopped && !_lastStopped) {
      _lastStopped = true;
      if (widget.snapToZero) {
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
        final seconds = (value * widget.totalSeconds).ceil();
        final barColor = timerColor(value);
        const double labelWidth = 36;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelLeft = constraints.maxWidth * value - labelWidth - 4;

              return SizedBox(
                height: 32,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
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
        );
      },
    );
  }
}
