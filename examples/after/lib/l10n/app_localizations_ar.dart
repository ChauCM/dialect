// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get checkoutAgreementNotice =>
      'بالحجز، فإنك توافق على قواعد المنزل وسياسة الإلغاء.';

  @override
  String get checkoutAppBarTitle => 'التأكيد والدفع';

  @override
  String get checkoutBookNow => 'احجز الآن';

  @override
  String get checkoutBookingConfirmedSnack =>
      'تم تأكيد الحجز. راجع رحلاتك لمزيد من التفاصيل.';

  @override
  String get checkoutFreeCancellation => 'إلغاء مجاني خلال 48 ساعة';

  @override
  String checkoutHostedBy(String hostName) {
    return 'المضيف: $hostName';
  }

  @override
  String checkoutNights(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nights ليلة',
      many: '$nights ليلة',
      few: '$nights ليالٍ',
      two: 'ليلتان',
      one: 'ليلة واحدة',
      zero: 'لا ليالٍ',
    );
    return '$_temp0';
  }

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight لكل ليلة';
  }

  @override
  String checkoutTotal(int amount) {
    return 'الإجمالي: \$$amount';
  }

  @override
  String get checkoutYourTrip => 'رحلتك';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonLoading => 'جارٍ التحميل...';

  @override
  String get homeOpenSettings => 'فتح الإعدادات';

  @override
  String get homeYourTrips => 'رحلاتك';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsAccountActions => 'إجراءات الحساب';

  @override
  String get settingsAppBarTitle => 'الإعدادات';

  @override
  String get settingsDarkMode => 'الوضع الداكن';

  @override
  String get settingsDeleteAccount => 'حذف الحساب';

  @override
  String get settingsDeleteAccountDialogBody =>
      'سيؤدي ذلك إلى إزالة حجوزاتك ورحلاتك وقوائمك كمضيف نهائيًا. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get settingsDeleteAccountDialogTitle => 'هل تريد حذف الحساب؟';

  @override
  String get settingsEditProfile => 'اضغط لتعديل ملفك الشخصي';

  @override
  String get settingsEmail => 'البريد الإلكتروني';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsNotificationsDescription =>
      'تحديثات الرحلة، رسائل المضيف، وتذكيرات الحجز.';

  @override
  String get settingsPreferences => 'التفضيلات';

  @override
  String get settingsSignOut => 'تسجيل الخروج';
}
