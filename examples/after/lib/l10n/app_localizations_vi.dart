// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get checkoutAgreementNotice =>
      'Khi đặt phòng, bạn đồng ý với Nội quy nhà và Chính sách hủy.';

  @override
  String get checkoutAppBarTitle => 'Xác nhận và thanh toán';

  @override
  String get checkoutBookNow => 'Đặt ngay';

  @override
  String get checkoutBookingConfirmedSnack =>
      'Đã xác nhận đặt phòng. Xem chi tiết trong Chuyến đi của bạn.';

  @override
  String get checkoutFreeCancellation => 'Miễn phí hủy trong vòng 48 giờ';

  @override
  String checkoutHostedBy(String hostName) {
    return 'Chủ nhà: $hostName';
  }

  @override
  String checkoutNights(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nights đêm',
      one: '1 đêm',
    );
    return '$_temp0';
  }

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight mỗi đêm';
  }

  @override
  String checkoutTotal(int amount) {
    return 'Tổng: \$$amount';
  }

  @override
  String get checkoutYourTrip => 'Chuyến đi của bạn';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get commonLoading => 'Đang tải...';

  @override
  String get homeOpenSettings => 'Mở cài đặt';

  @override
  String get homeYourTrips => 'Chuyến đi của bạn';

  @override
  String get settingsAccount => 'Tài khoản';

  @override
  String get settingsAccountActions => 'Thao tác tài khoản';

  @override
  String get settingsAppBarTitle => 'Cài đặt';

  @override
  String get settingsDarkMode => 'Chế độ tối';

  @override
  String get settingsDeleteAccount => 'Xóa tài khoản';

  @override
  String get settingsDeleteAccountDialogBody =>
      'Thao tác này sẽ xóa vĩnh viễn đặt phòng, chuyến đi và danh sách Chủ nhà của bạn. Không thể hoàn tác.';

  @override
  String get settingsDeleteAccountDialogTitle => 'Xóa tài khoản?';

  @override
  String get settingsEditProfile => 'Nhấn để chỉnh sửa hồ sơ';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsNotifications => 'Thông báo';

  @override
  String get settingsNotificationsDescription =>
      'Cập nhật chuyến đi, tin nhắn từ chủ nhà và lời nhắc đặt phòng.';

  @override
  String get settingsPreferences => 'Tùy chọn';

  @override
  String get settingsSignOut => 'Đăng xuất';
}
