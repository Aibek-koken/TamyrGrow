import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shelf.dart';
import '../state/dashboard_provider.dart';
import 'widgets/shelf_status_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final shelves = provider.summary?.shelves ?? const <Shelf>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: provider.isLoading ? null : provider.load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (_) {
            if (provider.isLoading && shelves.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null && shelves.isEmpty) {
              return _ErrorState(
                message: provider.error ?? 'Unknown error',
                onRetry: provider.load,
              );
            }

            if (shelves.isEmpty) {
              return const _EmptyState();
            }

            return GridView.builder(
              itemCount: shelves.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final shelf = shelves[index];
                final current = provider.currentByShelfId[shelf.id];
                final sensor = current?.latestSensor;
                return ShelfStatusCard(
                  shelfName: shelf.name,
                  status: shelf.status,
                  temperature: sensor?.temperature,
                  humidity: sensor?.humidity,
                  co2: sensor?.co2,
                  tvoc: sensor?.tvoc,
                  selected: provider.selectedShelfId == shelf.id,
                  onTap: () => provider.selectShelf(shelf.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sensors_off_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 12),
          Text(
            'No shelves found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Seed the database or connect to your API.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load dashboard',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
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
