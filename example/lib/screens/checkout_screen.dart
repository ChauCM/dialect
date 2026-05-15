import 'package:flutter/material.dart';

import '../widgets/loading_indicator.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.listingTitle,
    required this.hostName,
    required this.nights,
    required this.pricePerNight,
  });

  final String listingTitle;
  final String hostName;
  final int nights;
  final int pricePerNight;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _confirming = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Booking confirmed. Check your trips for details.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.nights * widget.pricePerNight;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm and pay')),
      body: _confirming
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.listingTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text('Hosted by ${widget.hostName}'),
                const Divider(height: 32),
                Text('Your trip'),
                const SizedBox(height: 8),
                Text('${widget.nights} nights'),
                const SizedBox(height: 4),
                Text('\$${widget.pricePerNight} per night'),
                const Divider(height: 32),
                Text('Total: \$$total'),
                const SizedBox(height: 4),
                const Text('Free cancellation for 48 hours'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _confirm,
                  child: const Text('Book Now'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'By booking you agree to the House Rules and Cancellation Policy.',
                ),
              ],
            ),
    );
  }
}
