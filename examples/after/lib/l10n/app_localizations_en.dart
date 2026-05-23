// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get checkoutAgreementNotice =>
      'By booking you agree to the House Rules and Cancellation Policy.';

  @override
  String get checkoutAppBarTitle => 'Confirm and pay';

  @override
  String get checkoutBookNow => 'Book Now';

  @override
  String get checkoutBookingConfirmedSnack =>
      'Booking confirmed. Check your trips for details.';

  @override
  String get checkoutFreeCancellation => 'Free cancellation for 48 hours';

  @override
  String checkoutHostedBy(String hostName) {
    return 'Hosted by $hostName';
  }

  @override
  String checkoutNights(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nights nights',
      one: '1 night',
    );
    return '$_temp0';
  }

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight per night';
  }

  @override
  String checkoutTotal(int amount) {
    return 'Total: \$$amount';
  }

  @override
  String get checkoutYourTrip => 'Your trip';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get homeOpenSettings => 'Open settings';

  @override
  String get homeYourTrips => 'Your trips';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAccountActions => 'Account actions';

  @override
  String get settingsAppBarTitle => 'Settings';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountDialogBody =>
      'This permanently removes your bookings, trips, and host listings. This cannot be undone.';

  @override
  String get settingsDeleteAccountDialogTitle => 'Delete account?';

  @override
  String get settingsEditProfile => 'Tap to edit your profile';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsDescription =>
      'Trip updates, host messages, and booking reminders.';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsSignOut => 'Sign out';
}
