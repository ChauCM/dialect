import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

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
    Locale('en'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// Primary CTA button on the checkout screen. 'Book' is a verb meaning 'make a reservation', NOT a physical book.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get checkoutBookNow;

  /// Snackbar message shown after a booking is successfully completed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed. Check your trips for details.'**
  String get checkoutBookingConfirmed;

  /// Policy note on the checkout screen informing the user they can cancel for free within 48 hours of booking.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation for 48 hours'**
  String get checkoutFreeCancellation;

  /// Line below the listing title showing the host's name.
  ///
  /// In en, this message translates to:
  /// **'Hosted by {hostName}'**
  String checkoutHostedBy(String hostName);

  /// Number of nights for the stay. Singular '1 night' or plural '{n} nights'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 night} other{{count} nights}}'**
  String checkoutNights(int count);

  /// Legal disclaimer at the bottom of the checkout screen. 'House Rules' and 'Cancellation Policy' are proper nouns for the host's policy documents.
  ///
  /// In en, this message translates to:
  /// **'By booking you agree to the House Rules and Cancellation Policy.'**
  String get checkoutPolicyAgreement;

  /// Nightly rate shown on the checkout screen. The dollar sign is part of the value; do not move or translate the symbol — currency repositioning is handled at runtime.
  ///
  /// In en, this message translates to:
  /// **'\${pricePerNight} per night'**
  String checkoutPricePerNight(int pricePerNight);

  /// App bar title on the checkout screen where the user reviews and pays for a booking.
  ///
  /// In en, this message translates to:
  /// **'Confirm and pay'**
  String get checkoutTitle;

  /// Total cost for the stay shown on the checkout screen. The dollar sign is part of the value.
  ///
  /// In en, this message translates to:
  /// **'Total: \${total}'**
  String checkoutTotal(int total);

  /// Section heading on the checkout screen summarising the stay details (duration, price).
  ///
  /// In en, this message translates to:
  /// **'Your trip'**
  String get checkoutYourTrip;

  /// Generic cancel action used across dialogs and screens.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic loading state indicator shown while waiting for async operations.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// Button on the home screen that navigates to the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get homeOpenSettings;

  /// App bar title on the home screen listing the user's booked travel stays.
  ///
  /// In en, this message translates to:
  /// **'Your trips'**
  String get homeYourTrips;

  /// Toggle label for the dark mode switch on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// List tile label for the delete-account action on the Settings screen. Shown in red to signal a destructive action.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Body text of the delete-account confirmation dialog explaining the consequences.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes your bookings, trips, and host listings. This cannot be undone.'**
  String get settingsDeleteAccountDialogBody;

  /// Confirm button in the delete-account dialog. Destructive — do NOT soften the wording.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDeleteAccountDialogConfirm;

  /// Title of the confirmation dialog shown before the user deletes their account.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteAccountDialogTitle;

  /// Label for the email address list tile on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// Label for the language picker tile on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Toggle label for the notifications switch on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Subtitle under the Notifications toggle describing what kinds of notifications the user will receive.
  ///
  /// In en, this message translates to:
  /// **'Trip updates, host messages, and booking reminders.'**
  String get settingsNotificationsSubtitle;

  /// Section header for the Account section on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// Section header for the Account actions section on the Settings screen (sign out, delete account).
  ///
  /// In en, this message translates to:
  /// **'Account actions'**
  String get settingsSectionAccountActions;

  /// Section header for the Preferences section on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// List tile label for the sign-out action on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// Subtitle on the profile list tile prompting the user to tap to edit their profile details.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit your profile'**
  String get settingsTapToEditProfile;

  /// App bar title on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
