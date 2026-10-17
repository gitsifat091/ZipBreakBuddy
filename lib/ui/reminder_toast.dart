import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/reminder.dart';
import 'theme.dart';

/// The 380x200 pop-up: Zip on the left, message and actions on the right.
class ReminderToast extends StatelessWidget {
  const ReminderToast({
    super.key,
    required this.message,
    required this.onDone,
    required this.onSnooze,
  });

  final ReminderMessage message;
  final VoidCallback onDone;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZipColors.background,
        borderRadius: BorderRadius.circular(zipRadius),
        border: Border.all(color: ZipColors.line, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 18, 16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: SvgPicture.asset(message.pose.asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: ZipColors.text,
                  ),
                ),
                if (message.actionable) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: onDone,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: const Text('Done', softWrap: false),
                        ),
                      ),
                      if (message.snoozable) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            onPressed: onSnooze,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            child: const Text('Snooze 10 min', softWrap: false),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
