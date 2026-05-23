import 'package:flutter/material.dart';

import 'screens/checkout_screen.dart';
import 'screens/hosting_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trips_screen.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stay Booking Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your trips')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Seaside cottage in Da Nang'),
              subtitle: const Text('Hosted by Linh'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CheckoutScreen(
                    listingTitle: 'Seaside cottage in Da Nang',
                    hostName: 'Linh',
                    nights: 3,
                    pricePerNight: 82,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TripsScreen()),
            ),
            child: const Text('See all my trips'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HostingScreen()),
            ),
            child: const Text('Switch to hosting'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }
}
