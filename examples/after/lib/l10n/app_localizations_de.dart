// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get checkoutAgreementNotice =>
      'Mit Ihrer Buchung akzeptieren Sie die Hausordnung und die Stornierungsbedingungen.';

  @override
  String get checkoutAppBarTitle => 'Bestätigen und bezahlen';

  @override
  String get checkoutBookNow => 'Jetzt buchen';

  @override
  String get checkoutBookingConfirmedSnack =>
      'Buchung bestätigt. Details finden Sie unter „Ihre Reisen“.';

  @override
  String get checkoutFreeCancellation =>
      'Kostenlose Stornierung innerhalb von 48 Stunden';

  @override
  String checkoutHostedBy(String hostName) {
    return 'Gastgeber: $hostName';
  }

  @override
  String checkoutNights(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nights Nächte',
      one: '$nights Nacht',
    );
    return '$_temp0';
  }

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight pro Nacht';
  }

  @override
  String checkoutTotal(int amount) {
    return 'Gesamt: \$$amount';
  }

  @override
  String get checkoutYourTrip => 'Ihre Reise';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonLoading => 'Wird geladen ...';

  @override
  String get homeOpenSettings => 'Einstellungen öffnen';

  @override
  String get homeYourTrips => 'Ihre Reisen';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsAccountActions => 'Kontoaktionen';

  @override
  String get settingsAppBarTitle => 'Einstellungen';

  @override
  String get settingsDarkMode => 'Dunkles Design';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteAccountDialogBody =>
      'Damit werden Ihre Buchungen, Reisen und Gastgeber-Inserate dauerhaft entfernt. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get settingsDeleteAccountDialogTitle => 'Konto löschen?';

  @override
  String get settingsEditProfile => 'Tippen Sie, um Ihr Profil zu bearbeiten';

  @override
  String get settingsEmail => 'E-Mail';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsNotificationsDescription =>
      'Reise-Updates, Nachrichten vom Gastgeber und Buchungserinnerungen.';

  @override
  String get settingsPreferences => 'Präferenzen';

  @override
  String get settingsSignOut => 'Abmelden';
}
