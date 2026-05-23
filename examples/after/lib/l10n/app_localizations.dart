import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('ja'),
    Locale('vi'),
  ];

  /// Legal-style notice under the Book Now button. 'House Rules' and 'Cancellation Policy' are document names; treat them as section/document titles, not generic phrases.
  ///
  /// In en, this message translates to:
  /// **'By booking you agree to the House Rules and Cancellation Policy.'**
  String get checkoutAgreementNotice;

  /// AppBar title on the checkout screen, just before the user pays for a booking.
  ///
  /// In en, this message translates to:
  /// **'Confirm and pay'**
  String get checkoutAppBarTitle;

  /// Primary CTA confirming the booking. 'Book' is a verb meaning 'make a reservation', NOT a physical book.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get checkoutBookNow;

  /// SnackBar shown after the user successfully books a stay. 'Booking' is the noun form (the reservation that was just made).
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed. Check your trips for details.'**
  String get checkoutBookingConfirmedSnack;

  /// Reassurance line under the total. 'Cancellation' is the noun form of the cancel-a-booking concept.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation for 48 hours'**
  String get checkoutFreeCancellation;

  /// Attribution line under the listing title on checkout. {hostName} is the host's first name.
  ///
  /// In en, this message translates to:
  /// **'Hosted by {hostName}'**
  String checkoutHostedBy(String hostName);

  /// Number of nights for the stay. Uses ICU plural. Source provides =1 exact-match and other; locales must add their CLDR categories on top.
  ///
  /// In en, this message translates to:
  /// **'{nights, plural, =1{1 night} other{{nights} nights}}'**
  String checkoutNights(int nights);

  /// Per-night rate displayed on checkout. The dollar sign is the currency symbol — keep it in source position; do not translate currency symbols or amounts.
  ///
  /// In en, this message translates to:
  /// **'\${pricePerNight} per night'**
  String checkoutPricePerNight(int pricePerNight);

  /// Total amount due. The dollar sign is the currency symbol; do not translate the symbol or the amount.
  ///
  /// In en, this message translates to:
  /// **'Total: \${amount}'**
  String checkoutTotal(int amount);

  /// Section heading above the per-stay details (nights, price). 'Trip' = the booked stay.
  ///
  /// In en, this message translates to:
  /// **'Your trip'**
  String get checkoutYourTrip;

  /// Generic cancel action — dismisses a dialog or aborts a flow without saving.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic destructive confirmation in a dialog. Imperative verb.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Default placeholder text shown next to a spinner while content is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// Outlined button on the home screen that navigates to the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get homeOpenSettings;

  /// Home screen AppBar title. 'Trips' means booked stays (not generic travel).
  ///
  /// In en, this message translates to:
  /// **'Your trips'**
  String get homeYourTrips;

  /// Section header for the user's account info (name, email). Rendered uppercase by the UI — translate in normal case; the UI applies the casing.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Section header above destructive account actions (sign out, delete account).
  ///
  /// In en, this message translates to:
  /// **'Account actions'**
  String get settingsAccountActions;

  /// AppBar title on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsAppBarTitle;

  /// Toggle label for switching the app to dark color scheme.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// Destructive action that opens the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Warning body in the delete-account dialog. 'Bookings' = reservations the user made; 'trips' = booked stays; 'host listings' = listings the user has put up for others to book.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes your bookings, trips, and host listings. This cannot be undone.'**
  String get settingsDeleteAccountDialogBody;

  /// Title of the confirmation dialog shown before account deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteAccountDialogTitle;

  /// Subtitle hint under the user's display name in the Account section.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit your profile'**
  String get settingsEditProfile;

  /// Label for the user's email address row in the Account section.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// Label for the language picker row.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Toggle label for enabling push notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Subtitle under the Notifications toggle, explaining what notifications cover. 'Trip' = a booked stay; 'host' = the person renting out the listing; 'booking' = noun form, the reservation.
  ///
  /// In en, this message translates to:
  /// **'Trip updates, host messages, and booking reminders.'**
  String get settingsNotificationsDescription;

  /// Section header for in-app preference toggles (dark mode, notifications, language).
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// Action that logs the user out of the app.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'ja',
    'vi',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
