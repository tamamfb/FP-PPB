import 'package:flutter/material.dart';

class AnswerCard extends StatelessWidget {
  final String answer;
  final bool isCorrect;
  final bool isWrong;
  /// Player has locked in this answer but correctness is not yet revealed.
  final bool isSelected;
  final VoidCallback? onTap;

  const AnswerCard({
    super.key,
    required this.answer,
    required this.isCorrect,
    required this.isWrong,
    this.isSelected = false,
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
    } else if (isSelected) {
      borderColor = colorScheme.primary;
      bgColor = colorScheme.primary.withValues(alpha: 0.08);
      trailing = Icon(Icons.radio_button_checked, color: colorScheme.primary, size: 20);
    } else {
      borderColor = colorScheme.outline.withValues(alpha: 0.4);
      bgColor = null;
      trailing = null;
    }

    final stateKey = isCorrect
        ? 'correct'
        : isWrong
        ? 'wrong'
        : isSelected
        ? 'selected'
        : 'none';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.transparent,
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: trailing != null
                    ? Padding(
                        key: ValueKey(stateKey),
                        padding: const EdgeInsets.only(left: 8),
                        child: trailing,
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
