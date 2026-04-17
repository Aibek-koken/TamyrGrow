import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../../core/network/api_service.dart';
import '../../dashboard/models/sensor_log.dart';
import '../../dashboard/models/shelf.dart';
import '../../dashboard/models/shelf_current.dart';
import '../../dashboard/state/dashboard_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int? _selectedShelfId;
  late Future<_AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shelves = context.watch<DashboardProvider>().summary?.shelves ?? const <Shelf>[];
    if (_selectedShelfId == null && shelves.isNotEmpty) {
      _selectedShelfId = shelves.first.id;
      _future = _load();
    }
  }

  Future<_AnalyticsData> _load() async {
    final api = context.read<ApiService>();
    final shelfId = _selectedShelfId ?? 1;
    final results = await Future.wait([
      api.getShelfCurrent(shelfId),
      api.getShelfSensorLogs(shelfId, limit: 240),
    ]);
    return _AnalyticsData(
      current: results[0] as ShelfCurrent,
      logs: results[1] as List<SensorLog>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final shelves = provider.summary?.shelves ?? const <Shelf>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analytics'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _ShelfSelector(
                        shelves: shelves,
                        value: _selectedShelfId,
                        onChanged: (value) {
                          setState(() {
                            _selectedShelfId = value;
                            _future = _load();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.hasError)
                        _ErrorCard(
                          message: snapshot.error.toString(),
                          onRetry: () => setState(() => _future = _load()),
                        )
                      else if (isLoading && data == null)
                        const _LoadingCard()
                      else if (data == null)
                        const _EmptyCard()
                      else
                        _AnalyticsBody(data: data),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.data});

  final _AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = data.current.latestSensor ?? (data.logs.isEmpty ? null : data.logs.last);
    final vpd = latest == null
        ? null
        : calculateVpd(temperature: latest.temperature, humidity: latest.humidity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Microclimate Score',
          subtitle: vpd == null ? 'Waiting for sensor data…' : 'Current VPD: ${vpd.toStringAsFixed(3)} kPa',
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.75 : 1.45,
              ),
              children: [
                _VpdGaugeCard(vpd: vpd),
                _AiTipCard(
                  vpd: vpd,
                  temperature: latest?.temperature,
                  humidity: latest?.humidity,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Historical Trends',
          subtitle: data.logs.isEmpty
              ? 'No history yet for this shelf.'
              : 'Last ${data.logs.length} readings',
        ),
        const SizedBox(height: 10),
        _TrendsCard(
          title: 'Temperature & Humidity',
          subtitle: 'Dual-line microclimate trend',
          child: _TempHumidityChart(logs: data.logs),
        ),
        const SizedBox(height: 12),
        _TrendsCard(
          title: 'CO₂ & TVOC',
          subtitle: 'Air quality trend',
          child: _Co2TvocChart(logs: data.logs),
        ),
        const SizedBox(height: 12),
        Text(
          'Plant Comfort Index',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ShelfSelector extends StatelessWidget {
  const _ShelfSelector({
    required this.shelves,
    required this.value,
    required this.onChanged,
  });

  final List<Shelf> shelves;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.layers_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: value,
                items: shelves
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: shelves.isEmpty ? null : onChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Selected shelf',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VpdGaugeCard extends StatelessWidget {
  const _VpdGaugeCard({required this.vpd});

  final double? vpd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (vpd ?? 0).clamp(0.0, 2.0);
    final comfort = _comfortLabel(vpd);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.radar_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VPD Gauge',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _Pill(text: comfort, color: _comfortColor(context, vpd)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    minimum: 0,
                    maximum: 2,
                    interval: 0.5,
                    showTicks: true,
                    showLabels: true,
                    labelOffset: 12,
                    axisLabelStyle: GaugeTextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      fontSize: 11,
                    ),
                    axisLineStyle: AxisLineStyle(
                      thickness: 14,
                      color: Colors.white.withValues(alpha: 0.06),
                      thicknessUnit: GaugeSizeUnit.logicalPixel,
                      cornerStyle: CornerStyle.bothCurve,
                    ),
                    ranges: [
                      GaugeRange(startValue: 0.0, endValue: 0.4, color: Color(0xFFFF3B30)),
                      GaugeRange(startValue: 0.4, endValue: 0.8, color: Color(0xFFFFCC00)),
                      GaugeRange(startValue: 0.8, endValue: 1.2, color: Color(0xFF00E676)),
                      GaugeRange(startValue: 1.2, endValue: 1.6, color: Color(0xFFFFCC00)),
                      GaugeRange(startValue: 1.6, endValue: 2.0, color: Color(0xFFFF3B30)),
                    ],
                    pointers: [
                      NeedlePointer(
                        value: value,
                        needleColor: theme.colorScheme.onSurface,
                        knobStyle: KnobStyle(
                          color: theme.colorScheme.primary,
                          borderColor: Colors.white.withValues(alpha: 0.20),
                          borderWidth: 2,
                        ),
                      ),
                    ],
                    annotations: [
                      GaugeAnnotation(
                        angle: 90,
                        positionFactor: 0.15,
                        widget: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              vpd == null ? '—' : '${vpd!.toStringAsFixed(3)} kPa',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Plant Comfort Index',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiTipCard extends StatelessWidget {
  const _AiTipCard({
    required this.vpd,
    required this.temperature,
    required this.humidity,
  });

  final double? vpd;
  final double? temperature;
  final double? humidity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tip = buildAgronomistTip(
      vpd: vpd,
      temperature: temperature,
      humidity: humidity,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('AI Agronomist Tip', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tip,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.psychology_alt_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tip adapts to your current VPD.',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendsCard extends StatelessWidget {
  const _TrendsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _TempHumidityChart extends StatelessWidget {
  const _TempHumidityChart({required this.logs});

  final List<SensorLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.length < 2) {
      return const _ChartEmptyState();
    }

    final tempColor = Theme.of(context).colorScheme.primary;
    const humColor = Color(0xFF64B5F6);

    final tempSpots = <FlSpot>[];
    final humSpots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      tempSpots.add(FlSpot(i.toDouble(), logs[i].temperature));
      humSpots.add(FlSpot(i.toDouble(), logs[i].humidity));
    }

    return _LineChart(
      logs: logs,
      minY: 0,
      maxY: 100,
      series: [
        _LineSeries(
          name: 'Temp (°C)',
          color: tempColor,
          spots: tempSpots,
        ),
        _LineSeries(
          name: 'Humidity (%)',
          color: humColor,
          spots: humSpots,
        ),
      ],
    );
  }
}

class _Co2TvocChart extends StatelessWidget {
  const _Co2TvocChart({required this.logs});

  final List<SensorLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.length < 2) {
      return const _ChartEmptyState();
    }

    const co2Color = Color(0xFFB388FF);
    const tvocColor = Color(0xFFFFAB91);

    final co2Spots = <FlSpot>[];
    final tvocSpots = <FlSpot>[];
    var maxY = 0.0;
    for (var i = 0; i < logs.length; i++) {
      final co2 = logs[i].co2.toDouble();
      final tvoc = logs[i].tvoc.toDouble();
      maxY = [maxY, co2, tvoc].reduce((a, b) => a > b ? a : b);
      co2Spots.add(FlSpot(i.toDouble(), co2));
      tvocSpots.add(FlSpot(i.toDouble(), tvoc));
    }

    return _LineChart(
      logs: logs,
      minY: 0,
      maxY: (maxY * 1.15).clamp(200.0, 5000.0),
      series: [
        _LineSeries(
          name: 'CO₂ (ppm)',
          color: co2Color,
          spots: co2Spots,
        ),
        _LineSeries(
          name: 'TVOC (ppb)',
          color: tvocColor,
          spots: tvocSpots,
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.logs,
    required this.series,
    required this.minY,
    required this.maxY,
  });

  final List<SensorLog> logs;
  final List<_LineSeries> series;
  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.Hm();
    final axisColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final gridColor = Colors.white.withValues(alpha: 0.06);

    String labelForX(double value) {
      final idx = value.round().clamp(0, logs.length - 1);
      return timeFormat.format(logs[idx].timestamp.toLocal());
    }

    final every = (logs.length / 4).ceil().clamp(1, 9999);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (logs.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) <= 0 ? 10 : (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: axisColor, width: 1),
            left: BorderSide(color: axisColor, width: 1),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(color: axisColor),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: every.toDouble(),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    labelForX(value),
                    style: theme.textTheme.labelSmall?.copyWith(color: axisColor),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.all(10),
            tooltipMargin: 12,
            getTooltipColor: (_) => theme.colorScheme.surface.withValues(alpha: 0.95),
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return const [];
              final idx = touchedSpots.first.x.round().clamp(0, logs.length - 1);
              final time = DateFormat('MMM d, HH:mm').format(logs[idx].timestamp.toLocal());
              return touchedSpots.map((spot) {
                final seriesName = series[spot.barIndex].name;
                return LineTooltipItem(
                  '$seriesName\n${spot.y.toStringAsFixed(1)}\n$time',
                  (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                );
              }).toList(growable: false);
            },
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: s.spots,
              isCurved: true,
              curveSmoothness: 0.20,
              color: s.color,
              barWidth: 2.3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: s.color.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 280),
    );
  }
}

class _LineSeries {
  const _LineSeries({required this.name, required this.color, required this.spots});

  final String name;
  final Color color;
  final List<FlSpot> spots;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Not enough data yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator()),
            SizedBox(width: 12),
            Expanded(child: Text('Loading analytics…')),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Select a shelf to view analytics.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to load analytics',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsData {
  const _AnalyticsData({required this.current, required this.logs});

  final ShelfCurrent current;
  final List<SensorLog> logs;
}

double calculateVpd({required double temperature, required double humidity}) {
  if (humidity < 0 || humidity > 100) {
    throw ArgumentError.value(humidity, 'humidity', 'must be between 0 and 100');
  }

  final saturation = 0.6108 * _exp((17.27 * temperature) / (temperature + 237.3));
  final actual = saturation * (humidity / 100.0);
  return _roundTo(saturation - actual, 3);
}

String buildAgronomistTip({
  required double? vpd,
  required double? temperature,
  required double? humidity,
}) {
  if (vpd == null) {
    return 'Waiting for a fresh sensor reading. Once data arrives, I’ll generate a VPD-based microclimate tip.';
  }

  final v = vpd;
  final vText = v.toStringAsFixed(3);

  if (v < 0.8) {
    final delta = ((0.8 - v) * 10).clamp(3, 10).round();
    return 'VPD is $vText kPa. Transpiration is low. Consider decreasing humidity by ~$delta% or gently increasing airflow to reduce condensation and keep leaves dry.';
  }

  if (v <= 1.2) {
    return 'VPD is $vText kPa. Microclimate looks comfortable. Keep steady airflow and avoid sudden swings in temperature or humidity.';
  }

  final delta = ((v - 1.2) * 10).clamp(3, 12).round();
  final humHint = humidity == null ? '' : ' (current RH ~${humidity.toStringAsFixed(0)}%)';
  final tempHint = temperature == null ? '' : ' (temp ~${temperature.toStringAsFixed(1)}°C)';
  return 'VPD is $vText kPa. Transpiration is high. Consider increasing humidity by ~$delta%$humHint or lowering canopy temperature slightly$tempHint to avoid leaf-edge stress.';
}

String _comfortLabel(double? vpd) {
  if (vpd == null) return 'No data';
  if (vpd >= 0.8 && vpd <= 1.2) return 'Green';
  if (vpd >= 0.4 && vpd < 0.8) return 'Low';
  if (vpd > 1.2 && vpd <= 1.6) return 'High';
  return 'Extreme';
}

Color _comfortColor(BuildContext context, double? vpd) {
  if (vpd == null) return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);
  if (vpd >= 0.8 && vpd <= 1.2) return const Color(0xFF00E676);
  if ((vpd >= 0.4 && vpd < 0.8) || (vpd > 1.2 && vpd <= 1.6)) return const Color(0xFFFFCC00);
  return const Color(0xFFFF3B30);
}

double _roundTo(double value, int places) {
  final m = _pow10(places);
  return (value * m).round() / m;
}

double _pow10(int places) {
  var v = 1.0;
  for (var i = 0; i < places; i++) {
    v *= 10.0;
  }
  return v;
}

double _exp(double x) => math.exp(x);

