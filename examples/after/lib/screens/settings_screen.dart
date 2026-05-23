import 'package:flutter/material.dart';
import 'package:after/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// Self-names — intentionally NOT translated. The Spanish UI still
// shows "Español" in its picker so users can find their language.
const _languageSelfNames = <String, String>{
  'en': 'English',
  'es': 'Español',
  'de': 'Deutsch',
  'ja': '日本語',
  'vi': 'Tiếng Việt',
  'ar': 'العربية',
};

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notifications = true;

  String _currentLanguageLabel() {
    final code = widget.locale?.languageCode ?? 'en';
    return _languageSelfNames[code] ?? code;
  }

  Future<void> _pickLanguage() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(ctx)!.settingsLanguage),
        children: [
          for (final entry in _languageSelfNames.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (selected != null) {
      widget.onLocaleChanged(Locale(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAppBarTitle)),
      body: ListView(
        children: [
          _SectionHeader(l.settingsAccount),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Linh Nguyen'),
            subtitle: Text(l.settingsEditProfile),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(l.settingsEmail),
            subtitle: const Text('linh@example.com'),
          ),
          const Divider(),
          _SectionHeader(l.settingsPreferences),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(l.settingsDarkMode),
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l.settingsNotifications),
            subtitle: Text(l.settingsNotificationsDescription),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.settingsLanguage),
            subtitle: Text(_currentLanguageLabel()),
            onTap: _pickLanguage,
          ),
          const Divider(),
          _SectionHeader(l.settingsAccountActions),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.settingsSignOut),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              l.settingsDeleteAccount,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.settingsDeleteAccountDialogTitle),
                content: Text(l.settingsDeleteAccountDialogBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l.commonDelete),
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
