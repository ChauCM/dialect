// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get checkoutBookNow => 'Đặt ngay';

  @override
  String get checkoutBookingConfirmed =>
      'Đặt phòng thành công. Kiểm tra chuyến đi của bạn để biết thêm chi tiết.';

  @override
  String get checkoutFreeCancellation => 'Hủy miễn phí trong 48 giờ';

  @override
  String checkoutHostedBy(String hostName) {
    return 'Chủ nhà: $hostName';
  }

  @override
  String checkoutNights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count đêm',
      one: '1 đêm',
    );
    return '$_temp0';
  }

  @override
  String get checkoutPolicyAgreement =>
      'Bằng cách đặt phòng, bạn đồng ý với Nội quy nhà và Chính sách hủy phòng.';

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight mỗi đêm';
  }

  @override
  String get checkoutTitle => 'Xác nhận và thanh toán';

  @override
  String checkoutTotal(int total) {
    return 'Tổng: \$$total';
  }

  @override
  String get checkoutYourTrip => 'Chuyến đi của bạn';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonLoading => 'Đang tải...';

  @override
  String get homeOpenSettings => 'Mở cài đặt';

  @override
  String get homeYourTrips => 'Chuyến đi của bạn';

  @override
  String get settingsDarkMode => 'Chế độ tối';

  @override
  String get settingsDeleteAccount => 'Xóa tài khoản';

  @override
  String get settingsDeleteAccountDialogBody =>
      'Thao tác này sẽ xóa vĩnh viễn các đặt phòng, chuyến đi và danh sách nhà của bạn. Không thể hoàn tác.';

  @override
  String get settingsDeleteAccountDialogConfirm => 'Xóa';

  @override
  String get settingsDeleteAccountDialogTitle => 'Xóa tài khoản?';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsNotifications => 'Thông báo';

  @override
  String get settingsNotificationsSubtitle =>
      'Cập nhật chuyến đi, tin nhắn từ chủ nhà và nhắc nhở đặt phòng.';

  @override
  String get settingsSectionAccount => 'Tài khoản';

  @override
  String get settingsSectionAccountActions => 'Thao tác tài khoản';

  @override
  String get settingsSectionPreferences => 'Tùy chọn';

  @override
  String get settingsSignOut => 'Đăng xuất';

  @override
  String get settingsTapToEditProfile => 'Nhấn để chỉnh sửa hồ sơ của bạn';

  @override
  String get settingsTitle => 'Cài đặt';
}
