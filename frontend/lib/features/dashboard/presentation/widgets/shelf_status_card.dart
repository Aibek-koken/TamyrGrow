import 'package:flutter/material.dart';

import '../../models/shelf.dart';

class ShelfStatusCard extends StatelessWidget {
  const ShelfStatusCard({
    super.key,
    required this.shelfName,
    required this.status,
    required this.temperature,
    required this.humidity,
    required this.co2,
    required this.tvoc,
    this.onTap,
    this.selected = false,
  });

  final String shelfName;
  final ShelfStatus status;
  final double? temperature;
  final double? humidity;
  final int? co2;
  final int? tvoc;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, label) = _statusVisual(status);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : Colors.white.withValues(alpha: 0.08),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shelfName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(
                    icon: icon,
                    color: color,
                    label: label,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MetricRow(
                icon: Icons.device_thermostat_rounded,
                label: 'Temp',
                value: temperature == null
                    ? '—'
                    : '${temperature!.toStringAsFixed(1)}°C',
              ),
              const SizedBox(height: 6),
              _MetricRow(
                icon: Icons.water_drop_rounded,
                label: 'RH',
                value:
                    humidity == null ? '—' : '${humidity!.toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 6),
              _MetricRow(
                icon: Icons.air_rounded,
                label: 'CO₂',
                value: co2 == null ? '—' : '${co2} ppm',
              ),
              const SizedBox(height: 6),
              _MetricRow(
                icon: Icons.blur_on_rounded,
                label: 'TVOC',
                value: tvoc == null ? '—' : '${tvoc} ppb',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}

(IconData, Color, String) _statusVisual(ShelfStatus status) {
  switch (status) {
    case ShelfStatus.ok:
      return (Icons.check_circle_rounded, const Color(0xFF00E676), 'OK');
    case ShelfStatus.warning:
      return (Icons.warning_rounded, const Color(0xFFFFD54F), 'WARN');
    case ShelfStatus.critical:
      return (Icons.error_rounded, const Color(0xFFFF5252), 'CRIT');
  }
}
