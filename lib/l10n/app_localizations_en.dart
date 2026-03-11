// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Cyclick';

  @override
  String get tagline => 'Pedaling Sector 2 Together';

  @override
  String get map => 'Map';

  @override
  String get history => 'History';

  @override
  String get community => 'Community';

  @override
  String get profile => 'Profile';

  @override
  String get rentals => 'Rentals';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get logout => 'Log out';

  @override
  String get startRide => 'Start Ride';

  @override
  String get finishRide => 'Finish Ride';

  @override
  String get reportHazard => 'Report Hazard';

  @override
  String get pothole => 'Pothole';

  @override
  String get dangerousIntersection => 'Dangerous Intersection';

  @override
  String get blockedLane => 'Blocked Lane';

  @override
  String get safeZone => 'Safe Zone';

  @override
  String get uncleanedPath => 'Uncleaned Path';

  @override
  String get weatherAlerts => 'Weather';

  @override
  String get nearestRental => 'Nearest rental';

  @override
  String walkingDistance(int minutes) {
    return '$minutes min walk';
  }

  @override
  String availableBikes(int count) {
    return '$count bikes';
  }

  @override
  String get communityRoutes => 'Community Routes';

  @override
  String get addRoute => 'Add Route';

  @override
  String get myStats => 'My Stats';

  @override
  String get totalKm => 'Total km';

  @override
  String get totalRides => 'Rides';

  @override
  String get co2Saved => 'CO₂ Saved';

  @override
  String get bicycleType => 'Bicycle type';

  @override
  String get language => 'Language';

  @override
  String get adminPanel => 'Admin Panel';

  @override
  String get rentalStations => 'Rental Stations';

  @override
  String get parkingSpots => 'Parking Spots';

  @override
  String get feedback => 'Feedback';

  @override
  String get submit => 'Submit';

  @override
  String get cancel => 'Cancel';

  @override
  String get loading => 'Loading…';

  @override
  String get errorLoading => 'Could not load data';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get safetyRating => 'Safety Rating';

  @override
  String get feedbackTags => 'What was it like?';

  @override
  String get messageToCity => 'Message to City Hall (optional)';

  @override
  String get join => 'Join';

  @override
  String get leave => 'Leave';

  @override
  String spots(int n) {
    return '$n spots left';
  }
}
