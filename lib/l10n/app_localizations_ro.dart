// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appName => 'Cyclick';

  @override
  String get tagline => 'Pedalăm Sectorul 2 Împreună';

  @override
  String get map => 'Hartă';

  @override
  String get history => 'Istoric';

  @override
  String get community => 'Comunitate';

  @override
  String get profile => 'Profil';

  @override
  String get rentals => 'Închirieri';

  @override
  String get signIn => 'Conectare';

  @override
  String get signUp => 'Înregistrare';

  @override
  String get email => 'Email';

  @override
  String get password => 'Parolă';

  @override
  String get name => 'Nume';

  @override
  String get logout => 'Deconectare';

  @override
  String get startRide => 'Pornește Cursa';

  @override
  String get finishRide => 'Termină Cursa';

  @override
  String get reportHazard => 'Raportează Pericol';

  @override
  String get pothole => 'Groapă';

  @override
  String get dangerousIntersection => 'Intersecție Periculoasă';

  @override
  String get blockedLane => 'Pistă Blocată';

  @override
  String get safeZone => 'Zonă Sigură';

  @override
  String get uncleanedPath => 'Pistă Necurățată';

  @override
  String get weatherAlerts => 'Vreme';

  @override
  String get nearestRental => 'Cel mai apropiat loc de închiriat';

  @override
  String walkingDistance(int minutes) {
    return '$minutes min pe jos';
  }

  @override
  String availableBikes(int count) {
    return '$count biciclete';
  }

  @override
  String get communityRoutes => 'Rute Comunitate';

  @override
  String get addRoute => 'Adaugă Rută';

  @override
  String get myStats => 'Statisticile Mele';

  @override
  String get totalKm => 'Total km';

  @override
  String get totalRides => 'Curse';

  @override
  String get co2Saved => 'CO₂ Economisit';

  @override
  String get bicycleType => 'Tip bicicletă';

  @override
  String get language => 'Limbă';

  @override
  String get adminPanel => 'Panou Admin';

  @override
  String get rentalStations => 'Stații de Închiriere';

  @override
  String get parkingSpots => 'Parcări';

  @override
  String get feedback => 'Feedback';

  @override
  String get submit => 'Trimite';

  @override
  String get cancel => 'Anulează';

  @override
  String get loading => 'Se încarcă…';

  @override
  String get errorLoading => 'Nu s-au putut încărca datele';

  @override
  String get nowPlaying => 'Redare';

  @override
  String get safetyRating => 'Evaluare Siguranță';

  @override
  String get feedbackTags => 'Cum a fost?';

  @override
  String get messageToCity => 'Mesaj pentru Primărie (opțional)';

  @override
  String get join => 'Alătură-te';

  @override
  String get leave => 'Ieși';

  @override
  String spots(int n) {
    return 'Mai $n locuri';
  }
}
