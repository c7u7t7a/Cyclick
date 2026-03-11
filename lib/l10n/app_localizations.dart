import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

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
    Locale('ro')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Cyclick'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Pedaling Sector 2 Together'**
  String get tagline;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @rentals.
  ///
  /// In en, this message translates to:
  /// **'Rentals'**
  String get rentals;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @startRide.
  ///
  /// In en, this message translates to:
  /// **'Start Ride'**
  String get startRide;

  /// No description provided for @finishRide.
  ///
  /// In en, this message translates to:
  /// **'Finish Ride'**
  String get finishRide;

  /// No description provided for @reportHazard.
  ///
  /// In en, this message translates to:
  /// **'Report Hazard'**
  String get reportHazard;

  /// No description provided for @pothole.
  ///
  /// In en, this message translates to:
  /// **'Pothole'**
  String get pothole;

  /// No description provided for @dangerousIntersection.
  ///
  /// In en, this message translates to:
  /// **'Dangerous Intersection'**
  String get dangerousIntersection;

  /// No description provided for @blockedLane.
  ///
  /// In en, this message translates to:
  /// **'Blocked Lane'**
  String get blockedLane;

  /// No description provided for @safeZone.
  ///
  /// In en, this message translates to:
  /// **'Safe Zone'**
  String get safeZone;

  /// No description provided for @uncleanedPath.
  ///
  /// In en, this message translates to:
  /// **'Uncleaned Path'**
  String get uncleanedPath;

  /// No description provided for @weatherAlerts.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weatherAlerts;

  /// No description provided for @nearestRental.
  ///
  /// In en, this message translates to:
  /// **'Nearest rental'**
  String get nearestRental;

  /// No description provided for @walkingDistance.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min walk'**
  String walkingDistance(int minutes);

  /// No description provided for @availableBikes.
  ///
  /// In en, this message translates to:
  /// **'{count} bikes'**
  String availableBikes(int count);

  /// No description provided for @communityRoutes.
  ///
  /// In en, this message translates to:
  /// **'Community Routes'**
  String get communityRoutes;

  /// No description provided for @addRoute.
  ///
  /// In en, this message translates to:
  /// **'Add Route'**
  String get addRoute;

  /// No description provided for @myStats.
  ///
  /// In en, this message translates to:
  /// **'My Stats'**
  String get myStats;

  /// No description provided for @totalKm.
  ///
  /// In en, this message translates to:
  /// **'Total km'**
  String get totalKm;

  /// No description provided for @totalRides.
  ///
  /// In en, this message translates to:
  /// **'Rides'**
  String get totalRides;

  /// No description provided for @co2Saved.
  ///
  /// In en, this message translates to:
  /// **'CO₂ Saved'**
  String get co2Saved;

  /// No description provided for @bicycleType.
  ///
  /// In en, this message translates to:
  /// **'Bicycle type'**
  String get bicycleType;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @rentalStations.
  ///
  /// In en, this message translates to:
  /// **'Rental Stations'**
  String get rentalStations;

  /// No description provided for @parkingSpots.
  ///
  /// In en, this message translates to:
  /// **'Parking Spots'**
  String get parkingSpots;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get errorLoading;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @safetyRating.
  ///
  /// In en, this message translates to:
  /// **'Safety Rating'**
  String get safetyRating;

  /// No description provided for @feedbackTags.
  ///
  /// In en, this message translates to:
  /// **'What was it like?'**
  String get feedbackTags;

  /// No description provided for @messageToCity.
  ///
  /// In en, this message translates to:
  /// **'Message to City Hall (optional)'**
  String get messageToCity;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @spots.
  ///
  /// In en, this message translates to:
  /// **'{n} spots left'**
  String spots(int n);
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
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
