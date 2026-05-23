// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get checkoutBookNow => '立即预订';

  @override
  String get checkoutBookingConfirmed => '预订已确认。请在我的行程中查看详情。';

  @override
  String get checkoutFreeCancellation => '48小时内免费取消';

  @override
  String checkoutHostedBy(String hostName) {
    return '房东：$hostName';
  }

  @override
  String checkoutNights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count晚',
      one: '1晚',
    );
    return '$_temp0';
  }

  @override
  String get checkoutPolicyAgreement => '预订即表示您同意房屋规则和取消政策。';

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight元/晚';
  }

  @override
  String get checkoutTitle => '确认并付款';

  @override
  String checkoutTotal(int total) {
    return '总计：\$$total';
  }

  @override
  String get checkoutYourTrip => '您的行程';

  @override
  String get commonCancel => '取消';

  @override
  String get commonLoading => '加载中...';

  @override
  String get homeOpenSettings => '打开设置';

  @override
  String get homeYourTrips => '我的行程';

  @override
  String get settingsDarkMode => '深色模式';

  @override
  String get settingsDeleteAccount => '删除账户';

  @override
  String get settingsDeleteAccountDialogBody => '这将永久删除您的预订、行程和房东列表。此操作无法撤销。';

  @override
  String get settingsDeleteAccountDialogConfirm => '删除';

  @override
  String get settingsDeleteAccountDialogTitle => '删除账户？';

  @override
  String get settingsEmail => '邮箱';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsNotificationsSubtitle => '行程更新、房东消息和预订提醒。';

  @override
  String get settingsSectionAccount => '账户';

  @override
  String get settingsSectionAccountActions => '账户操作';

  @override
  String get settingsSectionPreferences => '偏好设置';

  @override
  String get settingsSignOut => '退出登录';

  @override
  String get settingsTapToEditProfile => '点击编辑您的个人资料';

  @override
  String get settingsTitle => '设置';
}
