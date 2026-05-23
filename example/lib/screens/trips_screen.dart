import 'package:flutter/material.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My trips'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UpcomingTrips(),
            _PastTrips(),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTrips extends StatelessWidget {
  const _UpcomingTrips();

  @override
  Widget build(BuildContext context) {
    // Demo data — would normally come from a repository. None of this is
    // user-facing copy; it's data that varies per user.
    final upcoming = <_TripSummary>[
      _TripSummary(
        listingTitle: 'Lakeside cabin in Sapa',
        hostName: 'Minh',
        nights: 4,
        startsInDays: 2,
        status: _TripStatus.confirmed,
      ),
      _TripSummary(
        listingTitle: 'Beach house in Phu Quoc',
        hostName: 'An',
        nights: 7,
        startsInDays: 26,
        status: _TripStatus.pendingHostApproval,
      ),
    ];

    if (upcoming.isEmpty) {
      return _EmptyState(
        title: 'No upcoming trips yet',
        body: "Find a place you'll love and your next stay will appear here.",
        cta: 'Find a place to stay',
        onTap: () {},
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            // Plural with =0/=1/other + placeholder mirror.
            upcoming.length == 1
                ? '1 upcoming trip'
                : '${upcoming.length} upcoming trips',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final t in upcoming) _TripCard(trip: t),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {},
          child: const Text('Find another place to stay'),
        ),
      ],
    );
  }
}

class _PastTrips extends StatelessWidget {
  const _PastTrips();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      title: 'No past trips',
      body: "Trips you've completed will show up here so you can rebook a "
          'favorite or leave a review for the Host.',
      cta: null,
      onTap: null,
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final _TripSummary trip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.listingTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Hosted by ${trip.hostName}'),
            const SizedBox(height: 8),
            // Plural form + relative-time UI label. The "{n} days" is data;
            // the surrounding phrasing ("Starts in", "Tonight", "Tomorrow")
            // is UI copy that varies per locale.
            Text(
              switch (trip.startsInDays) {
                0 => 'Starts tonight',
                1 => 'Starts tomorrow',
                _ => 'Starts in ${trip.startsInDays} days',
              },
            ),
            const SizedBox(height: 4),
            Text(
              trip.nights == 1 ? '1 night' : '${trip.nights} nights',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _StatusChip(status: trip.status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _TripStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      _TripStatus.confirmed => 'Confirmed',
      _TripStatus.pendingHostApproval => 'Pending Host approval',
      _TripStatus.cancelled => 'Cancelled',
    };
    return Chip(label: Text(label));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String body;
  final String? cta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (cta != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onTap, child: Text(cta!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripSummary {
  _TripSummary({
    required this.listingTitle,
    required this.hostName,
    required this.nights,
    required this.startsInDays,
    required this.status,
  });

  final String listingTitle;
  final String hostName;
  final int nights;
  final int startsInDays;
  final _TripStatus status;
}

enum _TripStatus { confirmed, pendingHostApproval, cancelled }
