import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_settings.dart';
import '../core/reminder.dart';
import 'theme.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.initial,
    required this.unitLabel,
    required this.onSave,
    required this.onCancel,
  });

  final AppSettings initial;

  /// "min", or "sec" in debug mode.
  final String unitLabel;
  final ValueChanged<AppSettings> onSave;
  final VoidCallback onCancel;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late AppSettings _s = widget.initial;

  static const _icons = {
    ReminderType.posture: ZipPose.stern,
    ReminderType.eyes: ZipPose.eyerest,
    ReminderType.water: ZipPose.thirsty,
    ReminderType.breakTime: ZipPose.cheer,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZipColors.background,
        borderRadius: BorderRadius.circular(zipRadius),
        border: Border.all(color: ZipColors.line, width: 1.5),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                const _SectionTitle('Reminders'),
                _Card(
                  children: [
                    for (final type in ReminderType.regular) _reminderRow(type),
                  ],
                ),
                const _SectionTitle('Pomodoro'),
                _Card(
                  children: [
                    _SwitchRow(
                      title: 'Pomodoro mode',
                      subtitle:
                          '25 ${widget.unitLabel} focus, 5 ${widget.unitLabel} '
                          'break. Replaces "Break time".',
                      value: _s.pomodoro,
                      onChanged: (v) =>
                          setState(() => _s = _s.copyWith(pomodoro: v)),
                    ),
                  ],
                ),
                const _SectionTitle('Effects'),
                _Card(
                  children: [
                    _SwitchRow(
                      title: 'Sounds',
                      subtitle:
                          'A horn when Zip arrives, an engine when he leaves',
                      value: _s.soundsEnabled,
                      onChanged: (v) =>
                          setState(() => _s = _s.copyWith(soundsEnabled: v)),
                    ),
                    _SwitchRow(
                      title: 'Drive-away animation',
                      subtitle: 'Zip drives off across the screen after Done',
                      value: _s.driveAwayEnabled,
                      onChanged: (v) =>
                          setState(() => _s = _s.copyWith(driveAwayEnabled: v)),
                    ),
                  ],
                ),
                const _SectionTitle('General'),
                _Card(
                  children: [
                    _Row(
                      title: 'Pause when idle for',
                      subtitle: 'No keyboard or mouse input',
                      trailing: _Stepper(
                        value: _s.idleMinutes,
                        min: AppSettings.minIdle,
                        max: AppSettings.maxIdle,
                        suffix: 'min',
                        onChanged: (v) =>
                            setState(() => _s = _s.copyWith(idleMinutes: v)),
                      ),
                    ),
                    _SwitchRow(
                      title: 'Start with Windows',
                      value: _s.startWithWindows,
                      onChanged: (v) =>
                          setState(() => _s = _s.copyWith(startWithWindows: v)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() => DragToMoveArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          SvgPicture.asset(ZipPose.happy.asset, width: 64),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Zip Break Buddy',
                  style: TextStyle(fontSize: 13, color: ZipColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close_rounded, color: ZipColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _footer() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => widget.onSave(_s),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  Widget _reminderRow(ReminderType type) {
    final r = _s.reminders[type]!;
    final replaced = type == ReminderType.breakTime && _s.pomodoro;
    final active = r.enabled && !replaced;
    return _Row(
      leading: Opacity(
        opacity: active ? 1 : 0.4,
        child: SvgPicture.asset(_icons[type]!.asset, width: 44),
      ),
      title: type.label,
      subtitle: replaced ? 'Replaced by Pomodoro' : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Stepper(
            value: r.interval,
            min: AppSettings.minInterval,
            max: AppSettings.maxInterval,
            prefix: 'every',
            suffix: widget.unitLabel,
            enabled: active,
            onChanged: (v) =>
                setState(() => _s = _s.withReminder(r.copyWith(interval: v))),
          ),
          const SizedBox(width: 4),
          Switch(
            value: r.enabled,
            onChanged: replaced
                ? null
                : (v) => setState(
                    () => _s = _s.withReminder(r.copyWith(enabled: v)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: ZipColors.muted,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ZipColors.line),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: ZipColors.line),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.leading, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: ZipColors.muted),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Row(
    title: title,
    subtitle: subtitle,
    trailing: Switch(value: value, onChanged: onChanged),
  );
}

/// A compact "− 20 min +" control. Steps by 5 above 10, by 1 below.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.prefix,
    this.enabled = true,
  });

  final int value, min, max;
  final String suffix;
  final String? prefix;
  final bool enabled;
  final ValueChanged<int> onChanged;

  int get _down => value > 10 ? value - 5 : value - 1;
  int get _up => value >= 10 ? value + 5 : value + 1;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? ZipColors.text : ZipColors.muted;
    Widget button(IconData icon, int next) => SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: enabled && next != value ? () => onChanged(next) : null,
        icon: Icon(icon),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix != null)
          Text(
            '$prefix ',
            style: const TextStyle(fontSize: 12, color: ZipColors.muted),
          ),
        button(Icons.remove_rounded, _down.clamp(min, max)),
        SizedBox(
          width: 58,
          child: Text(
            '$value $suffix',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        button(Icons.add_rounded, _up.clamp(min, max)),
      ],
    );
  }
}
