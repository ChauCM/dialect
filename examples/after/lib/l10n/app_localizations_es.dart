// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get checkoutAgreementNotice =>
      'Al reservar aceptas las Normas de la casa y la Política de cancelación.';

  @override
  String get checkoutAppBarTitle => 'Confirma y paga';

  @override
  String get checkoutBookNow => 'Reservar ahora';

  @override
  String get checkoutBookingConfirmedSnack =>
      'Reserva confirmada. Consulta tus viajes para ver los detalles.';

  @override
  String get checkoutFreeCancellation =>
      'Cancelación gratuita durante 48 horas';

  @override
  String checkoutHostedBy(String hostName) {
    return 'Anfitrión: $hostName';
  }

  @override
  String checkoutNights(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: '$nights noches',
      one: '$nights noche',
    );
    return '$_temp0';
  }

  @override
  String checkoutPricePerNight(int pricePerNight) {
    return '\$$pricePerNight por noche';
  }

  @override
  String checkoutTotal(int amount) {
    return 'Total: \$$amount';
  }

  @override
  String get checkoutYourTrip => 'Tu viaje';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get homeOpenSettings => 'Abrir ajustes';

  @override
  String get homeYourTrips => 'Tus viajes';

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsAccountActions => 'Acciones de la cuenta';

  @override
  String get settingsAppBarTitle => 'Ajustes';

  @override
  String get settingsDarkMode => 'Modo oscuro';

  @override
  String get settingsDeleteAccount => 'Eliminar cuenta';

  @override
  String get settingsDeleteAccountDialogBody =>
      'Esto elimina permanentemente tus reservas, viajes y anuncios como anfitrión. No se puede deshacer.';

  @override
  String get settingsDeleteAccountDialogTitle => '¿Eliminar cuenta?';

  @override
  String get settingsEditProfile => 'Toca para editar tu perfil';

  @override
  String get settingsEmail => 'Correo electrónico';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsNotificationsDescription =>
      'Actualizaciones de viajes, mensajes del anfitrión y recordatorios de reservas.';

  @override
  String get settingsPreferences => 'Preferencias';

  @override
  String get settingsSignOut => 'Cerrar sesión';
}
