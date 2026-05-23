// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get checkoutAgreementNotice =>
      '予約することで、ハウスルールおよびキャンセルポリシーに同意したものとみなされます。';

  @override
  String get checkoutAppBarTitle => '確認して支払う';

  @override
  String get checkoutBookNow => '今すぐ予約する';

  @override
  String get checkoutBookingConfirmedSnack => '予約が確定しました。詳細は「あなたの旅行」をご確認ください。';

  @override
  String get checkoutFreeCancellation => '48時間以内なら無料でキャンセルできます';

  @override
  String checkoutHostedBy(String hostName) {
    return 'ホスト: $hostName';
  }

  @override
  String checkoutNights(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nights泊',
      one: '1泊',
    );
    return '$_temp0';
  }

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '1泊 \$$pricePerNight';
  }

  @override
  String checkoutTotal(int amount) {
    return '合計: \$$amount';
  }

  @override
  String get checkoutYourTrip => 'あなたの旅行';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonDelete => '削除';

  @override
  String get commonLoading => '読み込み中...';

  @override
  String get homeOpenSettings => '設定を開く';

  @override
  String get homeYourTrips => 'あなたの旅行';

  @override
  String get settingsAccount => 'アカウント';

  @override
  String get settingsAccountActions => 'アカウント操作';

  @override
  String get settingsAppBarTitle => '設定';

  @override
  String get settingsDarkMode => 'ダークモード';

  @override
  String get settingsDeleteAccount => 'アカウントを削除';

  @override
  String get settingsDeleteAccountDialogBody =>
      '予約、旅行、ホストとしての掲載が完全に削除されます。この操作は取り消せません。';

  @override
  String get settingsDeleteAccountDialogTitle => 'アカウントを削除しますか？';

  @override
  String get settingsEditProfile => 'タップしてプロフィールを編集';

  @override
  String get settingsEmail => 'メールアドレス';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsNotificationsDescription => '旅行の更新、ホストからのメッセージ、予約のリマインダー。';

  @override
  String get settingsPreferences => '環境設定';

  @override
  String get settingsSignOut => 'サインアウト';
}
