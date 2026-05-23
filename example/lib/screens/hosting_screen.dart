import 'package:flutter/material.dart';

class HostingScreen extends StatelessWidget {
  const HostingScreen({super.key, this.isAlreadyHost = true});

  /// In a real app this comes from the user model. We toggle it here just
  /// to keep both UI states visible to translators.
  final bool isAlreadyHost;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hosting')),
      body: isAlreadyHost
          ? const _HostDashboard(
              hostSinceYear: 2024,
              activeListings: 3,
              reviewCount: 47,
              averageRating: 4.8,
            )
          : const _BecomeAHost(),
    );
  }
}

class _BecomeAHost extends StatelessWidget {
  const _BecomeAHost();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Become a Host',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Earn extra income by hosting travelers in your home. '
          "It only takes a few minutes to list your place, and you're "
          'in control of when guests can book.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {},
          child: const Text('Get started'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {},
          child: const Text('Learn more about hosting'),
        ),
      ],
    );
  }
}

class _HostDashboard extends StatelessWidget {
  const _HostDashboard({
    required this.hostSinceYear,
    required this.activeListings,
    required this.reviewCount,
    required this.averageRating,
  });

  final int hostSinceYear;
  final int activeListings;
  final int reviewCount;
  final double averageRating;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glossary noun + temporal phrasing. Possessive constructions
                // around {year} differ across locales — keep "{year}" alone
                // in the placeholder.
                Text(
                  'Host since $hostSinceYear',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  // Plural over a count with =0 mirror.
                  switch (activeListings) {
                    0 => 'No active listings yet',
                    1 => '1 active listing',
                    _ => '$activeListings active listings',
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  // Distinct plural shape — singular/plural without =0.
                  reviewCount == 1 ? '1 review' : '$reviewCount reviews',
                ),
                const SizedBox(height: 4),
                // Rating + maximum is a numeric format concern; only the
                // word "average" varies by locale.
                Text(
                  '$averageRating average rating',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {},
          child: const Text('Add a new listing'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {},
          child: const Text('Manage listings'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {},
          child: const Text('Hosting resources'),
        ),
      ],
    );
  }
}
