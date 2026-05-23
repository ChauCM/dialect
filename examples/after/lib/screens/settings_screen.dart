import 'package:flutter/material.dart';
import 'package:after/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notifications = true;

  static const _localeNames = {
    'en': 'English',
    'es': 'Español',
    'ja': '日本語',
    'ar': 'العربية',
    'de': 'Deutsch',
    'vi': 'Tiếng Việt',
  };

  String get _currentLocaleName {
    final tag = Localizations.localeOf(context).languageCode;
    return _localeNames[tag] ?? tag;
  }

  Future<void> _pickLanguage() async {
    final supported = AppLocalizations.supportedLocales;
    final chosen = await showDialog<Locale>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.settingsLanguage),
        children: supported.map((locale) {
          final name = _localeNames[locale.languageCode] ?? locale.languageCode;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(locale),
            child: Text(name),
          );
        }).toList(),
      ),
    );
    if (chosen != null) widget.onLocaleChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsSectionAccount),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Linh Nguyen'),
            subtitle: Text(l10n.settingsTapToEditProfile),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(l10n.settingsEmail),
            subtitle: const Text('linh@example.com'),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionPreferences),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.settingsDarkMode),
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.settingsNotifications),
            subtitle: Text(l10n.settingsNotificationsSubtitle),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(_currentLocaleName),
            onTap: _pickLanguage,
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionAccountActions),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.settingsSignOut),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              l10n.settingsDeleteAccount,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.settingsDeleteAccountDialogTitle),
                content: Text(l10n.settingsDeleteAccountDialogBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.settingsDeleteAccountDialogConfirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
