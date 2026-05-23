import 'package:flutter/material.dart';
import 'package:after/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.checkoutBookingConfirmed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = widget.nights * widget.pricePerNight;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
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
                Text(l10n.checkoutHostedBy(widget.hostName)),
                const Divider(height: 32),
                Text(l10n.checkoutYourTrip),
                const SizedBox(height: 8),
                Text(l10n.checkoutNights(widget.nights)),
                const SizedBox(height: 4),
                Text(l10n.checkoutPricePerNight(widget.pricePerNight)),
                const Divider(height: 32),
                Text(l10n.checkoutTotal(total)),
                const SizedBox(height: 4),
                Text(l10n.checkoutFreeCancellation),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _confirm,
                  child: Text(l10n.checkoutBookNow),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(height: 24),
                Text(l10n.checkoutPolicyAgreement),
              ],
            ),
    );
  }
}
