import 'package:flutter/material.dart';
import 'package:after/l10n/app_localizations.dart';

import 'screens/checkout_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Locale? _locale;

  void _setLocale(Locale? locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stay Booking Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(
        locale: _locale,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.homeYourTrips)),
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
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  locale: locale,
                  onLocaleChanged: onLocaleChanged,
                ),
              ),
            ),
            child: Text(l.homeOpenSettings),
          ),
        ],
      ),
    );
  }
}
