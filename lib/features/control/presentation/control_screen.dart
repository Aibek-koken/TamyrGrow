import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../state/control_provider.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fanController;

  @override
  void initState() {
    super.initState();
    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _fanController.dispose();
    super.dispose();
  }

  void _syncFanAnimation(int speed) {
    if (speed > 0) {
      if (!_fanController.isAnimating) {
        _fanController.repeat();
      }
    } else {
      _fanController.stop();
      _fanController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ControlProvider>();
    final device = provider.deviceState;

    final isAiMode = provider.isAiMode;
    final fanSpeed = device?.fanSpeed ?? 0;
    _syncFanAnimation(fanSpeed);

    return Scaffold(
      appBar: AppBar(
        title: Text('Control · Shelf ${provider.shelfId}'),
        actions: [
          IconButton(
            onPressed: provider.isLoading ? null : provider.load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BlurCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  value: isAiMode,
                  onChanged: (value) async {
                    try {
                      await provider.toggleAiMode(value);
                    } catch (_) {}
                  },
                  title: const Text('AI-Agronomist Autopilot'),
                  subtitle: Text(
                    'When active, AI maintains ideal climate parameters.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      provider.error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Opacity(
                opacity: isAiMode ? 0.5 : 1.0,
                child: AbsorbPointer(
                  absorbing: isAiMode,
                  child: Column(
                    children: [
                      _BlurCard(
                        child: _GrowLightsCard(
                          value: device?.lightBrightness ?? 0,
                          onChangedEnd: (v) => provider.setLightBrightness(v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BlurCard(
                        child: _VentilationCard(
                          speed: fanSpeed,
                          fanTurns: _fanController,
                          onSpeedChanged: (speed) => provider.setFanSpeed(speed),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BlurCard(
                        child: _HvacCard(
                          targetTemp: device?.targetTemperature ?? 22.0,
                          onTargetTempChangedEnd: (v) => provider.setTargetTemperature(v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isAiMode)
                Positioned.fill(
                  child: _LockedOverlay(),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _EmergencyStopButton(
            onPressed: provider.emergencyStop,
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: On Android emulator, use base URL `http://10.0.2.2:8000` instead of `localhost`.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
          ),
        ],
      ),
    );
  }
}

class _GrowLightsCard extends StatefulWidget {
  const _GrowLightsCard({required this.value, required this.onChangedEnd});

  final int value;
  final Future<void> Function(int value) onChangedEnd;

  @override
  State<_GrowLightsCard> createState() => _GrowLightsCardState();
}

class _GrowLightsCardState extends State<_GrowLightsCard> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value.toDouble();
  }

  @override
  void didUpdateWidget(covariant _GrowLightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.light_mode_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Grow Lights', style: theme.textTheme.titleMedium),
            ),
            Text('${_value.round()}%', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 10),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: _value,
          onChanged: (v) => setState(() => _value = v),
          onChangeEnd: (v) => widget.onChangedEnd(v.round()),
        ),
      ],
    );
  }
}

class _VentilationCard extends StatelessWidget {
  const _VentilationCard({
    required this.speed,
    required this.fanTurns,
    required this.onSpeedChanged,
  });

  final int speed;
  final Animation<double> fanTurns;
  final ValueChanged<int> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = <int>{speed};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RotationTransition(
              turns: fanTurns,
              child: Icon(Icons.toys_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Ventilation', style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment<int>(value: 0, label: Text('Low')),
            ButtonSegment<int>(value: 1, label: Text('Med')),
            ButtonSegment<int>(value: 2, label: Text('High')),
          ],
          selected: selected,
          onSelectionChanged: (value) => onSpeedChanged(value.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _HvacCard extends StatefulWidget {
  const _HvacCard({
    required this.targetTemp,
    required this.onTargetTempChangedEnd,
  });

  final double targetTemp;
  final Future<void> Function(double celsius) onTargetTempChangedEnd;

  @override
  State<_HvacCard> createState() => _HvacCardState();
}

class _HvacCardState extends State<_HvacCard> {
  late double _temp;

  @override
  void initState() {
    super.initState();
    _temp = widget.targetTemp;
  }

  @override
  void didUpdateWidget(covariant _HvacCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTemp != widget.targetTemp) {
      _temp = widget.targetTemp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.thermostat_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('HVAC (Target Temperature)', style: theme.textTheme.titleMedium),
            ),
            Text('${_temp.toStringAsFixed(1)}°C', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 10),
        CupertinoSlider(
          value: _temp,
          min: 16,
          max: 30,
          divisions: 28,
          onChanged: (v) => setState(() => _temp = v),
          onChangeEnd: (v) => widget.onTargetTempChangedEnd(v),
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Manual control locked by AI',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
        ),
      ),
    );
  }
}

class _EmergencyStopButton extends StatelessWidget {
  const _EmergencyStopButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF5252),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () async {
          try {
            await onPressed();
          } catch (_) {}
        },
        icon: const Icon(Icons.power_settings_new_rounded),
        label: const Text('Emergency Stop'),
      ),
    );
  }
}

class _BlurCard extends StatelessWidget {
  const _BlurCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.85),
                theme.colorScheme.surface.withValues(alpha: 0.70),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

