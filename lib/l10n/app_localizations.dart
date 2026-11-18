import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ms'),
    Locale('zh'),
  ];

  /// No description provided for @scanAddToItinerary.
  ///
  /// In en, this message translates to:
  /// **'Add to itinerary'**
  String get scanAddToItinerary;

  /// No description provided for @scanAddedToPlan.
  ///
  /// In en, this message translates to:
  /// **'Added to plan'**
  String get scanAddedToPlan;

  /// No description provided for @scanPlanPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places selected for your plan'**
  String get scanPlanPlaces;

  /// No description provided for @scanPlanOnePlace.
  ///
  /// In en, this message translates to:
  /// **'1 place'**
  String get scanPlanOnePlace;

  /// No description provided for @scanAddToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to wishlist'**
  String get scanAddToWishlist;

  /// No description provided for @scanWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get scanWishlist;

  /// No description provided for @scanClearWishlist.
  ///
  /// In en, this message translates to:
  /// **'Clear wishlist'**
  String get scanClearWishlist;

  /// No description provided for @scanRemoveSelected.
  ///
  /// In en, this message translates to:
  /// **'Remove selected'**
  String get scanRemoveSelected;

  /// No description provided for @scanClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get scanClearAll;

  /// No description provided for @scanSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get scanSelectAll;

  /// No description provided for @scanViewWishlist.
  ///
  /// In en, this message translates to:
  /// **'View wishlist'**
  String get scanViewWishlist;

  /// No description provided for @scanWishlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Places you add to your wishlist will appear here.'**
  String get scanWishlistEmpty;

  /// No description provided for @scanOriginalPhoto.
  ///
  /// In en, this message translates to:
  /// **'Original Photo'**
  String get scanOriginalPhoto;

  /// No description provided for @scanResult.
  ///
  /// In en, this message translates to:
  /// **'Scan result'**
  String get scanResult;

  /// No description provided for @scanQuickLandmarks.
  ///
  /// In en, this message translates to:
  /// **'Explore landmarks near you'**
  String get scanQuickLandmarks;

  /// No description provided for @scanQuickLandmarksMap.
  ///
  /// In en, this message translates to:
  /// **'Landmarks near {area}'**
  String scanQuickLandmarksMap(String area);

  /// No description provided for @scanQuickLandmarksHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a place to see its story and details.'**
  String get scanQuickLandmarksHint;

  /// No description provided for @scanScannedLandmark.
  ///
  /// In en, this message translates to:
  /// **'the scanned landmark'**
  String get scanScannedLandmark;

  /// No description provided for @scanMapLocation.
  ///
  /// In en, this message translates to:
  /// **'your current location'**
  String get scanMapLocation;

  /// No description provided for @scanDistanceWalk.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min walk · {distance} from {origin}'**
  String scanDistanceWalk(int minutes, String distance, String origin);

  /// No description provided for @scanDistanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} from {origin}'**
  String scanDistanceAway(String distance, String origin);

  /// No description provided for @scanDistanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Distance unavailable until location is known'**
  String get scanDistanceUnavailable;

  /// No description provided for @scanMapSearchHelp.
  ///
  /// In en, this message translates to:
  /// **'Search more places on Google Maps'**
  String get scanMapSearchHelp;

  /// No description provided for @scanNoItinerary.
  ///
  /// In en, this message translates to:
  /// **'Save an itinerary first, then choose a day to add this place.'**
  String get scanNoItinerary;

  /// No description provided for @scanStopAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'This place is already on that day.'**
  String get scanStopAlreadyAdded;

  /// No description provided for @scanStopLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The place location is unavailable. Try again when place details load.'**
  String get scanStopLocationUnavailable;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed.'**
  String get languageChanged;

  /// No description provided for @languageSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'Language changed for this session. Could not save your preference.'**
  String get languageSessionOnly;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @recognize.
  ///
  /// In en, this message translates to:
  /// **'Recognize'**
  String get recognize;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @ai.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get ai;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allValue.
  ///
  /// In en, this message translates to:
  /// **'All ({arg0})'**
  String allValue(String arg0);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @readLess.
  ///
  /// In en, this message translates to:
  /// **'Read less'**
  String get readLess;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get viewOnMap;

  /// No description provided for @openInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInGoogleMaps;

  /// No description provided for @sharePlace.
  ///
  /// In en, this message translates to:
  /// **'Share place'**
  String get sharePlace;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @addressCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard!'**
  String get addressCopiedToClipboard;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Address unavailable'**
  String get addressUnavailable;

  /// No description provided for @descriptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Description unavailable.'**
  String get descriptionUnavailable;

  /// No description provided for @detailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Details unavailable'**
  String get detailsUnavailable;

  /// No description provided for @placeDetailsAreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Place details are unavailable.'**
  String get placeDetailsAreUnavailable;

  /// No description provided for @nameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Name unavailable'**
  String get nameUnavailable;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @phoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Phone unavailable'**
  String get phoneUnavailable;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @websiteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Website unavailable'**
  String get websiteUnavailable;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @ratingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Rating unavailable'**
  String get ratingUnavailable;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @reviewCountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Review count unavailable'**
  String get reviewCountUnavailable;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @openingHoursUnavailableCheckBeforeVisiting.
  ///
  /// In en, this message translates to:
  /// **'Opening hours unavailable. Check before visiting.'**
  String get openingHoursUnavailableCheckBeforeVisiting;

  /// No description provided for @operatingHoursMayVaryDuringPublicHolidaysOrSpecialEvents.
  ///
  /// In en, this message translates to:
  /// **'Operating hours may vary during public holidays or special events.'**
  String get operatingHoursMayVaryDuringPublicHolidaysOrSpecialEvents;

  /// No description provided for @hoursUnverified.
  ///
  /// In en, this message translates to:
  /// **'Hours unverified'**
  String get hoursUnverified;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get photoUnavailable;

  /// No description provided for @loadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Load photo'**
  String get loadPhoto;

  /// No description provided for @retryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Retry photo'**
  String get retryPhoto;

  /// No description provided for @photoValue.
  ///
  /// In en, this message translates to:
  /// **'Photo: {arg0}'**
  String photoValue(String arg0);

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @indoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get indoor;

  /// No description provided for @outdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get outdoor;

  /// No description provided for @attraction.
  ///
  /// In en, this message translates to:
  /// **'Attraction'**
  String get attraction;

  /// No description provided for @attractions.
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get attractions;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @culture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get culture;

  /// No description provided for @nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// No description provided for @adventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get adventure;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @museum.
  ///
  /// In en, this message translates to:
  /// **'Museum'**
  String get museum;

  /// No description provided for @sight.
  ///
  /// In en, this message translates to:
  /// **'Sight'**
  String get sight;

  /// No description provided for @science.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get science;

  /// No description provided for @nightlife.
  ///
  /// In en, this message translates to:
  /// **'Nightlife'**
  String get nightlife;

  /// No description provided for @landmarks.
  ///
  /// In en, this message translates to:
  /// **'Landmarks'**
  String get landmarks;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @airConditioned.
  ///
  /// In en, this message translates to:
  /// **'Air-conditioned'**
  String get airConditioned;

  /// No description provided for @comfortableFootwearAdvised.
  ///
  /// In en, this message translates to:
  /// **'Comfortable footwear advised'**
  String get comfortableFootwearAdvised;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @selamatDatang.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get selamatDatang;

  /// No description provided for @smartTravelPlanning.
  ///
  /// In en, this message translates to:
  /// **'Smart Travel\nPlanning'**
  String get smartTravelPlanning;

  /// No description provided for @smartTravelPlanner.
  ///
  /// In en, this message translates to:
  /// **'Smart Travel Planner'**
  String get smartTravelPlanner;

  /// No description provided for @smartTravelPlanning2.
  ///
  /// In en, this message translates to:
  /// **'Smart Travel Planning'**
  String get smartTravelPlanning2;

  /// No description provided for @yourSmartTravelCompanionInMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Your Smart Travel Companion\nin Malaysia'**
  String get yourSmartTravelCompanionInMalaysia;

  /// No description provided for @autoSmartScheduling.
  ///
  /// In en, this message translates to:
  /// **'Auto Smart Scheduling'**
  String get autoSmartScheduling;

  /// No description provided for @planTheBestRouteForYou.
  ///
  /// In en, this message translates to:
  /// **'Plan the best route for you'**
  String get planTheBestRouteForYou;

  /// No description provided for @realTimeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Real-time Updates'**
  String get realTimeUpdates;

  /// No description provided for @weatherTrafficOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'Weather, traffic & opening hours'**
  String get weatherTrafficOpeningHours;

  /// No description provided for @multiLanguageSupport.
  ///
  /// In en, this message translates to:
  /// **'Multi-language Support'**
  String get multiLanguageSupport;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @logInSignUp.
  ///
  /// In en, this message translates to:
  /// **'Log In / Sign Up'**
  String get logInSignUp;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @registerAccount.
  ///
  /// In en, this message translates to:
  /// **'Register Account'**
  String get registerAccount;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @malaysiaTravelPortal.
  ///
  /// In en, this message translates to:
  /// **'Malaysia Travel Portal'**
  String get malaysiaTravelPortal;

  /// No description provided for @accessAiItinerariesWeatherAlertsAndSmartRouteOptimization.
  ///
  /// In en, this message translates to:
  /// **'Access AI itineraries, weather alerts, and smart route optimization.'**
  String get accessAiItinerariesWeatherAlertsAndSmartRouteOptimization;

  /// No description provided for @signInToManageYourMalaysiaTravelPlans.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your Malaysia travel plans.'**
  String get signInToManageYourMalaysiaTravelPlans;

  /// No description provided for @registerAsANewTouristToPlanYourPersonalizedTripsInMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Register as a new tourist to plan your personalized trips in Malaysia.'**
  String get registerAsANewTouristToPlanYourPersonalizedTripsInMalaysia;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullName2.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName2;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @enterStrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter strong password'**
  String get enterStrongPassword;

  /// No description provided for @reEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter password'**
  String get reEnterPassword;

  /// No description provided for @eGAliBinAhmad.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ali Bin Ahmad'**
  String get eGAliBinAhmad;

  /// No description provided for @eGTouristExampleCom.
  ///
  /// In en, this message translates to:
  /// **'e.g. tourist@example.com'**
  String get eGTouristExampleCom;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @pleaseEnterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterAValidEmail;

  /// No description provided for @pleaseEnterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterYourPassword;

  /// No description provided for @passwordMustBeAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMustBeAtLeast6Characters;

  /// No description provided for @passwordStrengthPolicyC3.
  ///
  /// In en, this message translates to:
  /// **'Password Strength Policy (C3):'**
  String get passwordStrengthPolicyC3;

  /// No description provided for @atLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8Characters;

  /// No description provided for @oneLowercaseLetterAZ.
  ///
  /// In en, this message translates to:
  /// **'One lowercase letter (a-z)'**
  String get oneLowercaseLetterAZ;

  /// No description provided for @oneUppercaseLetterAZ.
  ///
  /// In en, this message translates to:
  /// **'One uppercase letter (A-Z)'**
  String get oneUppercaseLetterAZ;

  /// No description provided for @oneNumber09.
  ///
  /// In en, this message translates to:
  /// **'One number (0-9)'**
  String get oneNumber09;

  /// No description provided for @oneSpecialCharacter.
  ///
  /// In en, this message translates to:
  /// **'One special character (!@#\$%^&*)'**
  String get oneSpecialCharacter;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @ifThisEmailCanBeRegisteredAConfirmationEmailWillBeSentOpenTheLinkInThatEmailThenReturnHere.
  ///
  /// In en, this message translates to:
  /// **'If this email can be registered, a confirmation email will be sent. Open the link in that email, then return here and log in. You are not signed in yet.'**
  String
  get ifThisEmailCanBeRegisteredAConfirmationEmailWillBeSentOpenTheLinkInThatEmailThenReturnHere;

  /// No description provided for @loggedInAsGuestTraveler.
  ///
  /// In en, this message translates to:
  /// **'Logged in as Guest Traveler!'**
  String get loggedInAsGuestTraveler;

  /// No description provided for @successfullyLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Successfully logged out.'**
  String get successfullyLoggedOut;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @noActiveProfileFound.
  ///
  /// In en, this message translates to:
  /// **'No active profile found.'**
  String get noActiveProfileFound;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @editProfile2.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile2;

  /// No description provided for @changeYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Change your full name'**
  String get changeYourFullName;

  /// No description provided for @areYouSureYouWantToLogOutOfYourTravelProfile.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your travel profile?'**
  String get areYouSureYouWantToLogOutOfYourTravelProfile;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @darkModeIsNotSupportedInTheDemoVersion.
  ///
  /// In en, this message translates to:
  /// **'Dark mode is not supported in the demo version.'**
  String get darkModeIsNotSupportedInTheDemoVersion;

  /// No description provided for @privacyTerms.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Terms'**
  String get privacyTerms;

  /// No description provided for @privacyPolicyTerms.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy & Terms'**
  String get privacyPolicyTerms;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @aboutSmartTravelPlanner.
  ///
  /// In en, this message translates to:
  /// **'About Smart Travel Planner'**
  String get aboutSmartTravelPlanner;

  /// No description provided for @tripsPlanned.
  ///
  /// In en, this message translates to:
  /// **'Trips Planned'**
  String get tripsPlanned;

  /// No description provided for @placesVisited.
  ///
  /// In en, this message translates to:
  /// **'Places Visited'**
  String get placesVisited;

  /// No description provided for @traveler.
  ///
  /// In en, this message translates to:
  /// **'Traveler'**
  String get traveler;

  /// No description provided for @smartTourist.
  ///
  /// In en, this message translates to:
  /// **'Smart Tourist'**
  String get smartTourist;

  /// No description provided for @exploreMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Explore Malaysia'**
  String get exploreMalaysia;

  /// No description provided for @discoverAttractionsPlaces.
  ///
  /// In en, this message translates to:
  /// **'Discover attractions & places'**
  String get discoverAttractionsPlaces;

  /// No description provided for @imageRecognition.
  ///
  /// In en, this message translates to:
  /// **'Image Recognition'**
  String get imageRecognition;

  /// No description provided for @imageRecognition2.
  ///
  /// In en, this message translates to:
  /// **'Image recognition'**
  String get imageRecognition2;

  /// No description provided for @discoverMalaysiaThroughYourCamera.
  ///
  /// In en, this message translates to:
  /// **'Discover Malaysia through your camera'**
  String get discoverMalaysiaThroughYourCamera;

  /// No description provided for @planYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Plan Your Trip'**
  String get planYourTrip;

  /// No description provided for @tellUsYourPreferences.
  ///
  /// In en, this message translates to:
  /// **'Tell us your preferences'**
  String get tellUsYourPreferences;

  /// No description provided for @tripAssistant.
  ///
  /// In en, this message translates to:
  /// **'Trip Assistant'**
  String get tripAssistant;

  /// No description provided for @aiHelpTranslationAndWeatherAlerts.
  ///
  /// In en, this message translates to:
  /// **'AI help, translation and weather alerts'**
  String get aiHelpTranslationAndWeatherAlerts;

  /// No description provided for @helloValue.
  ///
  /// In en, this message translates to:
  /// **'Hello, {arg0}!'**
  String helloValue(String arg0);

  /// No description provided for @welcomeBackValue.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {arg0}!'**
  String welcomeBackValue(String arg0);

  /// No description provided for @whereWouldYouLikeToExploreToday.
  ///
  /// In en, this message translates to:
  /// **'Where would you like to explore today?'**
  String get whereWouldYouLikeToExploreToday;

  /// No description provided for @whereToNext.
  ///
  /// In en, this message translates to:
  /// **'Where to next?'**
  String get whereToNext;

  /// No description provided for @popularAttractions.
  ///
  /// In en, this message translates to:
  /// **'Popular Attractions'**
  String get popularAttractions;

  /// No description provided for @topMustVisitDestinationsInMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Top must-visit destinations in Malaysia'**
  String get topMustVisitDestinationsInMalaysia;

  /// No description provided for @browseAttractions.
  ///
  /// In en, this message translates to:
  /// **'Browse Attractions'**
  String get browseAttractions;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTrips;

  /// No description provided for @viewSavedItinerariesAndYourCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'View saved itineraries and your current plan'**
  String get viewSavedItinerariesAndYourCurrentPlan;

  /// No description provided for @viewItinerary.
  ///
  /// In en, this message translates to:
  /// **'View Itinerary'**
  String get viewItinerary;

  /// No description provided for @viewNearby.
  ///
  /// In en, this message translates to:
  /// **'View Nearby'**
  String get viewNearby;

  /// No description provided for @aiItinerary.
  ///
  /// In en, this message translates to:
  /// **'AI itinerary'**
  String get aiItinerary;

  /// No description provided for @routeOptimizer.
  ///
  /// In en, this message translates to:
  /// **'Route optimizer'**
  String get routeOptimizer;

  /// No description provided for @weatherUpdates.
  ///
  /// In en, this message translates to:
  /// **'Weather updates'**
  String get weatherUpdates;

  /// No description provided for @budgetFilter.
  ///
  /// In en, this message translates to:
  /// **'Budget filter'**
  String get budgetFilter;

  /// No description provided for @multiLanguage.
  ///
  /// In en, this message translates to:
  /// **'Multi-language'**
  String get multiLanguage;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @itineraryLabelsReadyInEnglishMalayAndChinese.
  ///
  /// In en, this message translates to:
  /// **'Itinerary labels ready in English, Malay and Chinese.'**
  String get itineraryLabelsReadyInEnglishMalayAndChinese;

  /// No description provided for @aTripThatFitsYou.
  ///
  /// In en, this message translates to:
  /// **'A trip that fits you'**
  String get aTripThatFitsYou;

  /// No description provided for @whereAndWhenWouldYouLikeToGo.
  ///
  /// In en, this message translates to:
  /// **'Where and when would you like to go?'**
  String get whereAndWhenWouldYouLikeToGo;

  /// No description provided for @chooseYourDatesDailyPaceAndFavouriteThingsToDo.
  ///
  /// In en, this message translates to:
  /// **'Choose your dates, daily pace, and favourite things to do.'**
  String get chooseYourDatesDailyPaceAndFavouriteThingsToDo;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @travelDates.
  ///
  /// In en, this message translates to:
  /// **'Travel dates'**
  String get travelDates;

  /// No description provided for @selectTravelDates.
  ///
  /// In en, this message translates to:
  /// **'Select travel dates'**
  String get selectTravelDates;

  /// No description provided for @selectTravelDates2.
  ///
  /// In en, this message translates to:
  /// **'Select Travel Dates'**
  String get selectTravelDates2;

  /// No description provided for @selectDestination.
  ///
  /// In en, this message translates to:
  /// **'Select Destination'**
  String get selectDestination;

  /// No description provided for @selectState.
  ///
  /// In en, this message translates to:
  /// **'Select State'**
  String get selectState;

  /// No description provided for @yourDailyPace.
  ///
  /// In en, this message translates to:
  /// **'Your daily pace'**
  String get yourDailyPace;

  /// No description provided for @dailyStartTime.
  ///
  /// In en, this message translates to:
  /// **'Daily Start Time'**
  String get dailyStartTime;

  /// No description provided for @dailyEndTime.
  ///
  /// In en, this message translates to:
  /// **'Daily End Time'**
  String get dailyEndTime;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @chooseASuggestedSchedule.
  ///
  /// In en, this message translates to:
  /// **'Choose a suggested schedule'**
  String get chooseASuggestedSchedule;

  /// No description provided for @setAsideTimeForAttractionsMealsAndGettingAround.
  ///
  /// In en, this message translates to:
  /// **'Set aside time for attractions, meals, and getting around.'**
  String get setAsideTimeForAttractionsMealsAndGettingAround;

  /// No description provided for @relaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get relaxed;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @plannedDuration.
  ///
  /// In en, this message translates to:
  /// **'Planned duration'**
  String get plannedDuration;

  /// No description provided for @makeItYourKindOfTrip.
  ///
  /// In en, this message translates to:
  /// **'Make it your kind of trip'**
  String get makeItYourKindOfTrip;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @pickOneOrMoreInterestsWeLlUseTheseToFindPlacesForYou.
  ///
  /// In en, this message translates to:
  /// **'Pick one or more interests. We’ll use these to find places for you.'**
  String get pickOneOrMoreInterestsWeLlUseTheseToFindPlacesForYou;

  /// No description provided for @chooseYourDailyBudget.
  ///
  /// In en, this message translates to:
  /// **'Choose your daily budget'**
  String get chooseYourDailyBudget;

  /// No description provided for @dailyBudget.
  ///
  /// In en, this message translates to:
  /// **'Daily budget'**
  String get dailyBudget;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @underRm150.
  ///
  /// In en, this message translates to:
  /// **'Under RM150'**
  String get underRm150;

  /// No description provided for @overRm300.
  ///
  /// In en, this message translates to:
  /// **'Over RM300'**
  String get overRm300;

  /// No description provided for @perPersonIncludingMealsAttractionTicketsAndLocalTransport.
  ///
  /// In en, this message translates to:
  /// **'Per person, including meals, attraction tickets, and local transport.'**
  String get perPersonIncludingMealsAttractionTicketsAndLocalTransport;

  /// No description provided for @gettingAround.
  ///
  /// In en, this message translates to:
  /// **'Getting around'**
  String get gettingAround;

  /// No description provided for @chooseHowYouWillTravelBetweenPlaces.
  ///
  /// In en, this message translates to:
  /// **'Choose how you will travel between places.'**
  String get chooseHowYouWillTravelBetweenPlaces;

  /// No description provided for @driving.
  ///
  /// In en, this message translates to:
  /// **'Driving'**
  String get driving;

  /// No description provided for @walking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get walking;

  /// No description provided for @transit.
  ///
  /// In en, this message translates to:
  /// **'Transit'**
  String get transit;

  /// No description provided for @publicTransport.
  ///
  /// In en, this message translates to:
  /// **'Public Transport'**
  String get publicTransport;

  /// No description provided for @exploreFurtherByCarOrEHailing.
  ///
  /// In en, this message translates to:
  /// **'Explore further by car or e-hailing.'**
  String get exploreFurtherByCarOrEHailing;

  /// No description provided for @enjoyNearbyPlacesAtAWalkingPace.
  ///
  /// In en, this message translates to:
  /// **'Enjoy nearby places at a walking pace.'**
  String get enjoyNearbyPlacesAtAWalkingPace;

  /// No description provided for @generateMyItinerary.
  ///
  /// In en, this message translates to:
  /// **'Generate My Itinerary'**
  String get generateMyItinerary;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// No description provided for @buildingItineraryFromSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Building itinerary from saved places…'**
  String get buildingItineraryFromSavedPlaces;

  /// No description provided for @checkYourTripPreferences.
  ///
  /// In en, this message translates to:
  /// **'Check your trip preferences'**
  String get checkYourTripPreferences;

  /// No description provided for @chooseADestination.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination.'**
  String get chooseADestination;

  /// No description provided for @chooseYourTravelDates.
  ///
  /// In en, this message translates to:
  /// **'Choose your travel dates.'**
  String get chooseYourTravelDates;

  /// No description provided for @chooseATime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time.'**
  String get chooseATime;

  /// No description provided for @chooseAtLeastOneInterest.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one interest.'**
  String get chooseAtLeastOneInterest;

  /// No description provided for @chooseADailyBudget.
  ///
  /// In en, this message translates to:
  /// **'Choose a daily budget.'**
  String get chooseADailyBudget;

  /// No description provided for @chooseATravelMode.
  ///
  /// In en, this message translates to:
  /// **'Choose a travel mode.'**
  String get chooseATravelMode;

  /// No description provided for @transitPlanningIsNotAvailableYetChooseDrivingOrWalkingToGenerateYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Transit planning is not available yet. Choose driving or walking to generate your trip.'**
  String
  get transitPlanningIsNotAvailableYetChooseDrivingOrWalkingToGenerateYourTrip;

  /// No description provided for @itineraryGeneratedOpeningPreview.
  ///
  /// In en, this message translates to:
  /// **'Itinerary generated — opening preview.'**
  String get itineraryGeneratedOpeningPreview;

  /// No description provided for @myItinerary.
  ///
  /// In en, this message translates to:
  /// **'My Itinerary'**
  String get myItinerary;

  /// No description provided for @yourValueItineraryIsReady.
  ///
  /// In en, this message translates to:
  /// **'Your {arg0} Itinerary is Ready!'**
  String yourValueItineraryIsReady(String arg0);

  /// No description provided for @saveItinerary.
  ///
  /// In en, this message translates to:
  /// **'Save Itinerary'**
  String get saveItinerary;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get tripDetails;

  /// No description provided for @tripDetails2.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetails2;

  /// No description provided for @travelTime.
  ///
  /// In en, this message translates to:
  /// **'Travel Time'**
  String get travelTime;

  /// No description provided for @estCost.
  ///
  /// In en, this message translates to:
  /// **'Est. Cost'**
  String get estCost;

  /// No description provided for @estDistance.
  ///
  /// In en, this message translates to:
  /// **'Est. Distance'**
  String get estDistance;

  /// No description provided for @estVisit.
  ///
  /// In en, this message translates to:
  /// **'Est. Visit'**
  String get estVisit;

  /// No description provided for @dayValue.
  ///
  /// In en, this message translates to:
  /// **'Day {arg0}'**
  String dayValue(String arg0);

  /// No description provided for @dayValueTheme.
  ///
  /// In en, this message translates to:
  /// **'Day {arg0} Theme'**
  String dayValueTheme(String arg0);

  /// No description provided for @dayRoute.
  ///
  /// In en, this message translates to:
  /// **'Day Route'**
  String get dayRoute;

  /// No description provided for @day1Plan.
  ///
  /// In en, this message translates to:
  /// **'Day 1 Plan'**
  String get day1Plan;

  /// No description provided for @editDayValue.
  ///
  /// In en, this message translates to:
  /// **'Edit Day {arg0}'**
  String editDayValue(String arg0);

  /// No description provided for @editDayValueSchedule.
  ///
  /// In en, this message translates to:
  /// **'Edit Day {arg0} Schedule'**
  String editDayValueSchedule(String arg0);

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @regenerateItinerary.
  ///
  /// In en, this message translates to:
  /// **'Regenerate itinerary'**
  String get regenerateItinerary;

  /// No description provided for @regenerateItinerary2.
  ///
  /// In en, this message translates to:
  /// **'Regenerate itinerary?'**
  String get regenerateItinerary2;

  /// No description provided for @yourCurrentUnsavedChangesWillBeReplacedSavedTripsWillRemainAvailable.
  ///
  /// In en, this message translates to:
  /// **'Your current unsaved changes will be replaced. Saved trips will remain available.'**
  String
  get yourCurrentUnsavedChangesWillBeReplacedSavedTripsWillRemainAvailable;

  /// No description provided for @completeTripPreferencesInPlanBeforeRegenerating.
  ///
  /// In en, this message translates to:
  /// **'Complete trip preferences in Plan before regenerating.'**
  String get completeTripPreferencesInPlanBeforeRegenerating;

  /// No description provided for @deleteItinerary.
  ///
  /// In en, this message translates to:
  /// **'Delete Itinerary?'**
  String get deleteItinerary;

  /// No description provided for @areYouSureYouWantToDeleteValue.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{arg0}\"?'**
  String areYouSureYouWantToDeleteValue(String arg0);

  /// No description provided for @deleteOrClearItinerary.
  ///
  /// In en, this message translates to:
  /// **'Delete or clear itinerary'**
  String get deleteOrClearItinerary;

  /// No description provided for @unableToDeleteThisItinerary.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete this itinerary.'**
  String get unableToDeleteThisItinerary;

  /// No description provided for @unableToSaveItineraryChangesOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Unable to save itinerary changes on this device.'**
  String get unableToSaveItineraryChangesOnThisDevice;

  /// No description provided for @noItinerariesYet.
  ///
  /// In en, this message translates to:
  /// **'No Itineraries Yet'**
  String get noItinerariesYet;

  /// No description provided for @noActiveTripPlanned.
  ///
  /// In en, this message translates to:
  /// **'No Active Trip Planned'**
  String get noActiveTripPlanned;

  /// No description provided for @youHaveNoActiveOrSavedTripsSetYourTravelPreferencesToGenerateASmartDayByDaySchedule.
  ///
  /// In en, this message translates to:
  /// **'You have no active or saved trips. Set your travel preferences to generate a smart day-by-day schedule.'**
  String
  get youHaveNoActiveOrSavedTripsSetYourTravelPreferencesToGenerateASmartDayByDaySchedule;

  /// No description provided for @tapToPlanYourSmartSchedule.
  ///
  /// In en, this message translates to:
  /// **'Tap to plan your smart schedule'**
  String get tapToPlanYourSmartSchedule;

  /// No description provided for @tapToViewScheduleDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap to view schedule & details'**
  String get tapToViewScheduleDetails;

  /// No description provided for @activeGeneratedPlan.
  ///
  /// In en, this message translates to:
  /// **'Active Generated Plan'**
  String get activeGeneratedPlan;

  /// No description provided for @activePlannedTrip.
  ///
  /// In en, this message translates to:
  /// **'Active Planned Trip'**
  String get activePlannedTrip;

  /// No description provided for @activeItinerary.
  ///
  /// In en, this message translates to:
  /// **'Active itinerary'**
  String get activeItinerary;

  /// No description provided for @activeTripPlanCleared.
  ///
  /// In en, this message translates to:
  /// **'Active trip plan cleared'**
  String get activeTripPlanCleared;

  /// No description provided for @clearActivePlan.
  ///
  /// In en, this message translates to:
  /// **'Clear Active Plan?'**
  String get clearActivePlan;

  /// No description provided for @areYouSureYouWantToClearYourCurrentGeneratedTripAndResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear your current generated trip and reset to default?'**
  String get areYouSureYouWantToClearYourCurrentGeneratedTripAndResetToDefault;

  /// No description provided for @addStop.
  ///
  /// In en, this message translates to:
  /// **'Add Stop'**
  String get addStop;

  /// No description provided for @addStopToDaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Add Stop to Day Schedule'**
  String get addStopToDaySchedule;

  /// No description provided for @addToPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to Plan'**
  String get addToPlan;

  /// No description provided for @addToMyItinerary.
  ///
  /// In en, this message translates to:
  /// **'Add to My Itinerary'**
  String get addToMyItinerary;

  /// No description provided for @addToTravelPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to Travel Plan'**
  String get addToTravelPlan;

  /// No description provided for @addToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Wishlist'**
  String get addToWishlist;

  /// No description provided for @selectAnAttractionToAppendToYourDayRoute.
  ///
  /// In en, this message translates to:
  /// **'Select an attraction to append to your day route'**
  String get selectAnAttractionToAppendToYourDayRoute;

  /// No description provided for @removeStop.
  ///
  /// In en, this message translates to:
  /// **'Remove stop'**
  String get removeStop;

  /// No description provided for @swapAttraction.
  ///
  /// In en, this message translates to:
  /// **'Swap Attraction'**
  String get swapAttraction;

  /// No description provided for @swapAttraction2.
  ///
  /// In en, this message translates to:
  /// **'Swap attraction'**
  String get swapAttraction2;

  /// No description provided for @dragItemsByTheHandleToReorderTapSwapToReplaceWithIndoorPlaces.
  ///
  /// In en, this message translates to:
  /// **'Drag items by the handle to reorder. Tap Swap to replace with indoor places.'**
  String get dragItemsByTheHandleToReorderTapSwapToReplaceWithIndoorPlaces;

  /// No description provided for @anItineraryDayMustHaveAtLeast1Stop.
  ///
  /// In en, this message translates to:
  /// **'An itinerary day must have at least 1 stop.'**
  String get anItineraryDayMustHaveAtLeast1Stop;

  /// No description provided for @duplicateStopToday.
  ///
  /// In en, this message translates to:
  /// **'Duplicate stop today'**
  String get duplicateStopToday;

  /// No description provided for @inOtherDay.
  ///
  /// In en, this message translates to:
  /// **'In other day'**
  String get inOtherDay;

  /// No description provided for @duplicateAttractionsDetectedTodayPleaseRemoveOrSwapThemToSave.
  ///
  /// In en, this message translates to:
  /// **'Duplicate attractions detected today. Please remove or swap them to save.'**
  String get duplicateAttractionsDetectedTodayPleaseRemoveOrSwapThemToSave;

  /// No description provided for @cannotSaveThisOrderExceedsDailyHoursOpeningHoursBudgetOrWeatherConstraints.
  ///
  /// In en, this message translates to:
  /// **'Cannot save: this order exceeds daily hours, opening hours, budget, or weather constraints.'**
  String
  get cannotSaveThisOrderExceedsDailyHoursOpeningHoursBudgetOrWeatherConstraints;

  /// No description provided for @cannotSaveValueAppearsMultipleTimesTodayPleaseRemoveOrSwapTheDuplicateStop.
  ///
  /// In en, this message translates to:
  /// **'Cannot save: \"{arg0}\" appears multiple times today. Please remove or swap the duplicate stop.'**
  String
  cannotSaveValueAppearsMultipleTimesTodayPleaseRemoveOrSwapTheDuplicateStop(
    String arg0,
  );

  /// No description provided for @cannotSaveValueIsAlreadyScheduledOnAnotherDayOfThisItinerary.
  ///
  /// In en, this message translates to:
  /// **'Cannot save: \"{arg0}\" is already scheduled on another day of this itinerary.'**
  String cannotSaveValueIsAlreadyScheduledOnAnotherDayOfThisItinerary(
    String arg0,
  );

  /// No description provided for @connectToRefreshGooglePlaceLocationsBeforeSavingScheduleChanges.
  ///
  /// In en, this message translates to:
  /// **'Connect to refresh Google place locations before saving schedule changes.'**
  String get connectToRefreshGooglePlaceLocationsBeforeSavingScheduleChanges;

  /// No description provided for @stopReorderedScheduleTimesAutomaticallyAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Stop reordered. Schedule times automatically adjusted.'**
  String get stopReorderedScheduleTimesAutomaticallyAdjusted;

  /// No description provided for @removedValueTimesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Removed \"{arg0}\". Times updated.'**
  String removedValueTimesUpdated(String arg0);

  /// No description provided for @addedValueToDayValue.
  ///
  /// In en, this message translates to:
  /// **'Added {arg0} to Day {arg1}'**
  String addedValueToDayValue(String arg0, String arg1);

  /// No description provided for @swappedValueWithValue.
  ///
  /// In en, this message translates to:
  /// **'Swapped \"{arg0}\" with \"{arg1}\"'**
  String swappedValueWithValue(String arg0, String arg1);

  /// No description provided for @dayValuePlanUpdatedValueStops.
  ///
  /// In en, this message translates to:
  /// **'Day {arg0} plan updated ({arg1} stops)'**
  String dayValuePlanUpdatedValueStops(String arg0, String arg1);

  /// No description provided for @replacingValueValue.
  ///
  /// In en, this message translates to:
  /// **'Replacing \"{arg0}\" ({arg1})'**
  String replacingValueValue(String arg0, String arg1);

  /// No description provided for @rainForecastedTodaySwappingToAnIndoorAttractionIsRecommended.
  ///
  /// In en, this message translates to:
  /// **'Rain forecasted today. Swapping to an Indoor attraction is recommended.'**
  String get rainForecastedTodaySwappingToAnIndoorAttractionIsRecommended;

  /// No description provided for @goodWeatherTodayYouCanKeepItIndoorOrSwapToAnOutdoorSight.
  ///
  /// In en, this message translates to:
  /// **'Good weather today! You can keep it indoor or swap to an outdoor sight.'**
  String get goodWeatherTodayYouCanKeepItIndoorOrSwapToAnOutdoorSight;

  /// No description provided for @scheduledTime.
  ///
  /// In en, this message translates to:
  /// **'Scheduled time'**
  String get scheduledTime;

  /// No description provided for @scheduledVisit.
  ///
  /// In en, this message translates to:
  /// **'Scheduled visit'**
  String get scheduledVisit;

  /// No description provided for @suggestedTime.
  ///
  /// In en, this message translates to:
  /// **'Suggested time'**
  String get suggestedTime;

  /// No description provided for @indoorActivity.
  ///
  /// In en, this message translates to:
  /// **'Indoor activity'**
  String get indoorActivity;

  /// No description provided for @outdoorSight.
  ///
  /// In en, this message translates to:
  /// **'Outdoor sight'**
  String get outdoorSight;

  /// No description provided for @indoorAttractionWeatherSafe.
  ///
  /// In en, this message translates to:
  /// **'Indoor attraction • Weather safe'**
  String get indoorAttractionWeatherSafe;

  /// No description provided for @outdoorSightseeing.
  ///
  /// In en, this message translates to:
  /// **'Outdoor sightseeing'**
  String get outdoorSightseeing;

  /// No description provided for @rainProofBackup.
  ///
  /// In en, this message translates to:
  /// **'Rain-proof backup'**
  String get rainProofBackup;

  /// No description provided for @valueDays.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Days'**
  String valueDays(String arg0);

  /// No description provided for @valueDaysItinerary.
  ///
  /// In en, this message translates to:
  /// **'{arg0} days itinerary'**
  String valueDaysItinerary(String arg0);

  /// No description provided for @valueHoursOfSightseeingPerDay.
  ///
  /// In en, this message translates to:
  /// **'{arg0} hours of sightseeing per day'**
  String valueHoursOfSightseeingPerDay(String arg0);

  /// No description provided for @valueHoursValueMinutesOfSightseeingPerDay.
  ///
  /// In en, this message translates to:
  /// **'{arg0} hours {arg1} minutes of sightseeing per day'**
  String valueHoursValueMinutesOfSightseeingPerDay(String arg0, String arg1);

  /// No description provided for @valueMin.
  ///
  /// In en, this message translates to:
  /// **'{arg0} min'**
  String valueMin(String arg0);

  /// No description provided for @valueH.
  ///
  /// In en, this message translates to:
  /// **'{arg0} h'**
  String valueH(String arg0);

  /// No description provided for @valueHValueMin.
  ///
  /// In en, this message translates to:
  /// **'{arg0} h {arg1} min'**
  String valueHValueMin(String arg0, String arg1);

  /// No description provided for @valueStopsRmValueEstimated.
  ///
  /// In en, this message translates to:
  /// **'{arg0} stops • RM {arg1} estimated'**
  String valueStopsRmValueEstimated(String arg0, String arg1);

  /// No description provided for @aboveRmvalueTotal.
  ///
  /// In en, this message translates to:
  /// **'Above ~RM{arg0} total'**
  String aboveRmvalueTotal(String arg0);

  /// No description provided for @upToRmvalueTotal.
  ///
  /// In en, this message translates to:
  /// **'Up to ~RM{arg0} total'**
  String upToRmvalueTotal(String arg0);

  /// No description provided for @rmvalueRmvalueTotal.
  ///
  /// In en, this message translates to:
  /// **'~RM{arg0} – RM{arg1} total'**
  String rmvalueRmvalueTotal(String arg0, String arg1);

  /// No description provided for @routeMap.
  ///
  /// In en, this message translates to:
  /// **'Route Map'**
  String get routeMap;

  /// No description provided for @mapView.
  ///
  /// In en, this message translates to:
  /// **'Map View'**
  String get mapView;

  /// No description provided for @reCenter.
  ///
  /// In en, this message translates to:
  /// **'Re-center'**
  String get reCenter;

  /// No description provided for @optimizeRoute.
  ///
  /// In en, this message translates to:
  /// **'Optimize Route'**
  String get optimizeRoute;

  /// No description provided for @optimizedOrder.
  ///
  /// In en, this message translates to:
  /// **'Optimized order'**
  String get optimizedOrder;

  /// No description provided for @optimizingRoute.
  ///
  /// In en, this message translates to:
  /// **'Optimizing route…'**
  String get optimizingRoute;

  /// No description provided for @calculatingRouteEstimate.
  ///
  /// In en, this message translates to:
  /// **'Calculating route estimate...'**
  String get calculatingRouteEstimate;

  /// No description provided for @tapMapPinsToViewPlaceDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap map pins to view place details'**
  String get tapMapPinsToViewPlaceDetails;

  /// No description provided for @select25LocationsToDrawARoute.
  ///
  /// In en, this message translates to:
  /// **'Select 2-5 locations to draw a route'**
  String get select25LocationsToDrawARoute;

  /// No description provided for @mapCenteredOnYourCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Map centered on your current location.'**
  String get mapCenteredOnYourCurrentLocation;

  /// No description provided for @unableToOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Google Maps.'**
  String get unableToOpenGoogleMaps;

  /// No description provided for @unableToOpenThisLink.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this link.'**
  String get unableToOpenThisLink;

  /// No description provided for @googleMapsIsNotConfiguredForThisPlatformYetYourSavedPlacesRemainAvailableInTheList.
  ///
  /// In en, this message translates to:
  /// **'Google Maps is not configured for this platform yet. Your saved places remain available in the list.'**
  String
  get googleMapsIsNotConfiguredForThisPlatformYetYourSavedPlacesRemainAvailableInTheList;

  /// No description provided for @valueKmValueStops.
  ///
  /// In en, this message translates to:
  /// **'{arg0} km • {arg1} stops'**
  String valueKmValueStops(String arg0, String arg1);

  /// No description provided for @valueKmValueStops2.
  ///
  /// In en, this message translates to:
  /// **'~{arg0} km • {arg1} stops'**
  String valueKmValueStops2(String arg0, String arg1);

  /// No description provided for @valueKmAway.
  ///
  /// In en, this message translates to:
  /// **'{arg0} km away'**
  String valueKmAway(String arg0);

  /// No description provided for @valueMAway.
  ///
  /// In en, this message translates to:
  /// **'{arg0} m away'**
  String valueMAway(String arg0);

  /// No description provided for @valueKmValueMinWalk.
  ///
  /// In en, this message translates to:
  /// **'{arg0} km • ~{arg1} min walk'**
  String valueKmValueMinWalk(String arg0, String arg1);

  /// No description provided for @routeEstValueKmValueMinDriving.
  ///
  /// In en, this message translates to:
  /// **'Route est: {arg0} km • ~{arg1} min driving'**
  String routeEstValueKmValueMinDriving(String arg0, String arg1);

  /// No description provided for @searchCityDestination.
  ///
  /// In en, this message translates to:
  /// **'Search City / Destination'**
  String get searchCityDestination;

  /// No description provided for @searchAttractionsFoodCulture.
  ///
  /// In en, this message translates to:
  /// **'Search attractions, food, culture...'**
  String get searchAttractionsFoodCulture;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// No description provided for @searchInThisArea.
  ///
  /// In en, this message translates to:
  /// **'Search in this area'**
  String get searchInThisArea;

  /// No description provided for @chooseState.
  ///
  /// In en, this message translates to:
  /// **'Choose State'**
  String get chooseState;

  /// No description provided for @chooseAreaCity.
  ///
  /// In en, this message translates to:
  /// **'Choose Area / City'**
  String get chooseAreaCity;

  /// No description provided for @exploreNewLocation.
  ///
  /// In en, this message translates to:
  /// **'Explore New Location'**
  String get exploreNewLocation;

  /// No description provided for @currentDestination.
  ///
  /// In en, this message translates to:
  /// **'CURRENT DESTINATION'**
  String get currentDestination;

  /// No description provided for @resetSearchFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset Search & Filters'**
  String get resetSearchFilters;

  /// No description provided for @noPlacesFound.
  ///
  /// In en, this message translates to:
  /// **'No Places Found'**
  String get noPlacesFound;

  /// No description provided for @noSavedPlacesYet.
  ///
  /// In en, this message translates to:
  /// **'No Saved Places Yet'**
  String get noSavedPlacesYet;

  /// No description provided for @noAttractionsMatchValueTryCheckingForTyposOrSearchingABroaderTerm.
  ///
  /// In en, this message translates to:
  /// **'No attractions match \"{arg0}\". Try checking for typos or searching a broader term.'**
  String noAttractionsMatchValueTryCheckingForTyposOrSearchingABroaderTerm(
    String arg0,
  );

  /// No description provided for @noAttractionsMatchThisFilterInThisCity.
  ///
  /// In en, this message translates to:
  /// **'No attractions match this filter in this city.'**
  String get noAttractionsMatchThisFilterInThisCity;

  /// No description provided for @noSpotsFoundInThisCategoryNearValueTryChoosingAnotherCategoryOrSelectingANewLocation.
  ///
  /// In en, this message translates to:
  /// **'No spots found in this category near {arg0}. Try choosing another category or selecting a new location.'**
  String
  noSpotsFoundInThisCategoryNearValueTryChoosingAnotherCategoryOrSelectingANewLocation(
    String arg0,
  );

  /// No description provided for @unableToLoadAttractionsPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Unable to load attractions. Please try again.'**
  String get unableToLoadAttractionsPleaseTryAgain;

  /// No description provided for @unableToLoadDetailsRetry.
  ///
  /// In en, this message translates to:
  /// **'Unable to load details. Retry.'**
  String get unableToLoadDetailsRetry;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @savedAttractions.
  ///
  /// In en, this message translates to:
  /// **'Saved Attractions'**
  String get savedAttractions;

  /// No description provided for @yourSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Your Saved Places'**
  String get yourSavedPlaces;

  /// No description provided for @saveAttraction.
  ///
  /// In en, this message translates to:
  /// **'Save attraction'**
  String get saveAttraction;

  /// No description provided for @removeFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFromSaved;

  /// No description provided for @savedListCanHoldUpTo10Attractions.
  ///
  /// In en, this message translates to:
  /// **'Saved list can hold up to 10 attractions.'**
  String get savedListCanHoldUpTo10Attractions;

  /// No description provided for @savedValueToYourList.
  ///
  /// In en, this message translates to:
  /// **'Saved \"{arg0}\" to your list.'**
  String savedValueToYourList(String arg0);

  /// No description provided for @removedValueFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed \"{arg0}\" from Saved.'**
  String removedValueFromSaved(String arg0);

  /// No description provided for @removedFromSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved places'**
  String get removedFromSavedPlaces;

  /// No description provided for @savedToFavoritePlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved to favorite places'**
  String get savedToFavoritePlaces;

  /// No description provided for @browseAttractionsInValueAndTapSaveToBuildYourPersonalizedTravelWishlist.
  ///
  /// In en, this message translates to:
  /// **'Browse attractions in {arg0} and tap \"Save\" to build your personalized travel wishlist.'**
  String
  browseAttractionsInValueAndTapSaveToBuildYourPersonalizedTravelWishlist(
    String arg0,
  );

  /// No description provided for @savedPlacesCanBeViewedOnTheMapTabToSeeOptimalDrivingPathsOrVisitThePlanTabToAutomaticallyS.
  ///
  /// In en, this message translates to:
  /// **'Saved places can be viewed on the Map tab to see optimal driving paths, or visit the Plan tab to automatically schedule them into your multi-day trip.'**
  String
  get savedPlacesCanBeViewedOnTheMapTabToSeeOptimalDrivingPathsOrVisitThePlanTabToAutomaticallyS;

  /// No description provided for @topIconicSpotsInValue.
  ///
  /// In en, this message translates to:
  /// **'Top iconic spots in {arg0}'**
  String topIconicSpotsInValue(String arg0);

  /// No description provided for @topMalaysianAttraction.
  ///
  /// In en, this message translates to:
  /// **'Top Malaysian Attraction'**
  String get topMalaysianAttraction;

  /// No description provided for @malaysianIconicAttraction.
  ///
  /// In en, this message translates to:
  /// **'Malaysian Iconic Attraction'**
  String get malaysianIconicAttraction;

  /// No description provided for @mustVisitHighlights.
  ///
  /// In en, this message translates to:
  /// **'Must-Visit Highlights'**
  String get mustVisitHighlights;

  /// No description provided for @travelerTipsGoodToKnow.
  ///
  /// In en, this message translates to:
  /// **'Traveler Tips & Good to Know'**
  String get travelerTipsGoodToKnow;

  /// No description provided for @helpfulTips.
  ///
  /// In en, this message translates to:
  /// **'Helpful Tips'**
  String get helpfulTips;

  /// No description provided for @activityStatus.
  ///
  /// In en, this message translates to:
  /// **'Activity Status'**
  String get activityStatus;

  /// No description provided for @entry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get entry;

  /// No description provided for @curatedSpotsWithin5Km.
  ///
  /// In en, this message translates to:
  /// **'Curated spots within 5 km'**
  String get curatedSpotsWithin5Km;

  /// No description provided for @text5KmRadius.
  ///
  /// In en, this message translates to:
  /// **'5 km radius'**
  String get text5KmRadius;

  /// No description provided for @exploreSpot.
  ///
  /// In en, this message translates to:
  /// **'Explore spot'**
  String get exploreSpot;

  /// No description provided for @viewPlaceDetails.
  ///
  /// In en, this message translates to:
  /// **'View place details'**
  String get viewPlaceDetails;

  /// No description provided for @liveGoogleInformation.
  ///
  /// In en, this message translates to:
  /// **'Live Google information'**
  String get liveGoogleInformation;

  /// No description provided for @livePlaceDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live place details unavailable.'**
  String get livePlaceDetailsUnavailable;

  /// No description provided for @showingAvailablePlaceInformation.
  ///
  /// In en, this message translates to:
  /// **'Showing available place information.'**
  String get showingAvailablePlaceInformation;

  /// No description provided for @googlePlacesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Places unavailable'**
  String get googlePlacesUnavailable;

  /// No description provided for @attractionDetailsMapLinkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Attraction details & map link copied to clipboard!'**
  String get attractionDetailsMapLinkCopiedToClipboard;

  /// No description provided for @valueReviews.
  ///
  /// In en, this message translates to:
  /// **'({arg0} reviews)'**
  String valueReviews(String arg0);

  /// No description provided for @valueReviews2.
  ///
  /// In en, this message translates to:
  /// **'{arg0} reviews'**
  String valueReviews2(String arg0);

  /// No description provided for @ratingValue5.
  ///
  /// In en, this message translates to:
  /// **'Rating: {arg0} / 5'**
  String ratingValue5(String arg0);

  /// No description provided for @valuePlaces.
  ///
  /// In en, this message translates to:
  /// **'{arg0} places'**
  String valuePlaces(String arg0);

  /// No description provided for @text0Places.
  ///
  /// In en, this message translates to:
  /// **'0 places'**
  String get text0Places;

  /// No description provided for @valueSpots.
  ///
  /// In en, this message translates to:
  /// **'{arg0} spots'**
  String valueSpots(String arg0);

  /// No description provided for @valueItems.
  ///
  /// In en, this message translates to:
  /// **'{arg0} items'**
  String valueItems(String arg0);

  /// No description provided for @valueItems2.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Items'**
  String valueItems2(String arg0);

  /// No description provided for @matchingValue.
  ///
  /// In en, this message translates to:
  /// **'Matching \"{arg0}\"'**
  String matchingValue(String arg0);

  /// No description provided for @askPlacesFoodWeatherOrPlans.
  ///
  /// In en, this message translates to:
  /// **'Ask places, food, weather, or plans...'**
  String get askPlacesFoodWeatherOrPlans;

  /// No description provided for @sendPrompt.
  ///
  /// In en, this message translates to:
  /// **'Send Prompt'**
  String get sendPrompt;

  /// No description provided for @geminiIsThinking.
  ///
  /// In en, this message translates to:
  /// **'Gemini is thinking...'**
  String get geminiIsThinking;

  /// No description provided for @gemini15FlashMalaysianTravelAi.
  ///
  /// In en, this message translates to:
  /// **'Gemini 1.5 Flash • Malaysian Travel AI'**
  String get gemini15FlashMalaysianTravelAi;

  /// No description provided for @assistantResponseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Assistant response language'**
  String get assistantResponseLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @assistantLanguageSetToValue.
  ///
  /// In en, this message translates to:
  /// **'Assistant language set to {arg0}.'**
  String assistantLanguageSetToValue(String arg0);

  /// No description provided for @clearChatHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear Chat History?'**
  String get clearChatHistory;

  /// No description provided for @thisWillResetYourConversationWithTheTravelAssistant.
  ///
  /// In en, this message translates to:
  /// **'This will reset your conversation with the travel assistant.'**
  String get thisWillResetYourConversationWithTheTravelAssistant;

  /// No description provided for @chatHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Chat history cleared.'**
  String get chatHistoryCleared;

  /// No description provided for @resetConversation.
  ///
  /// In en, this message translates to:
  /// **'Reset Conversation'**
  String get resetConversation;

  /// No description provided for @voiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Voice Search'**
  String get voiceSearch;

  /// No description provided for @voiceTravelAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice Travel Assistant'**
  String get voiceTravelAssistant;

  /// No description provided for @trySpokenQuery.
  ///
  /// In en, this message translates to:
  /// **'Try Spoken Query'**
  String get trySpokenQuery;

  /// No description provided for @isItGoingToRainInKlToday.
  ///
  /// In en, this message translates to:
  /// **'🌧️ Is it going to rain in KL today?'**
  String get isItGoingToRainInKlToday;

  /// No description provided for @bestHalalFoodNearBukitBintang.
  ///
  /// In en, this message translates to:
  /// **'🍜 Best Halal food near Bukit Bintang'**
  String get bestHalalFoodNearBukitBintang;

  /// No description provided for @culturalEtiquetteForBatuCaves.
  ///
  /// In en, this message translates to:
  /// **'🏛️ Cultural etiquette for Batu Caves'**
  String get culturalEtiquetteForBatuCaves;

  /// No description provided for @howToGetFromKlSentralToKlcc.
  ///
  /// In en, this message translates to:
  /// **'🚇 How to get from KL Sentral to KLCC'**
  String get howToGetFromKlSentralToKlcc;

  /// No description provided for @usefulMalayTravelPhrases.
  ///
  /// In en, this message translates to:
  /// **'🗣️ Useful Malay travel phrases'**
  String get usefulMalayTravelPhrases;

  /// No description provided for @topIndoorShoppingAndMuseums.
  ///
  /// In en, this message translates to:
  /// **'🛍️ Top indoor shopping and museums'**
  String get topIndoorShoppingAndMuseums;

  /// No description provided for @valueRain.
  ///
  /// In en, this message translates to:
  /// **'{arg0}% Rain'**
  String valueRain(String arg0);

  /// No description provided for @scanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get scanner;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyValue.
  ///
  /// In en, this message translates to:
  /// **'History ({arg0})'**
  String historyValue(String arg0);

  /// No description provided for @demoResults.
  ///
  /// In en, this message translates to:
  /// **'Demo Results'**
  String get demoResults;

  /// No description provided for @discoverALandmarkOrALocalDish.
  ///
  /// In en, this message translates to:
  /// **'Discover a landmark or a local dish'**
  String get discoverALandmarkOrALocalDish;

  /// No description provided for @chooseAPhotoReviewItThenIdentifyWhatYouSee.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo, review it, then identify what you see.'**
  String get chooseAPhotoReviewItThenIdentifyWhatYouSee;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @uploadFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Upload from Gallery'**
  String get uploadFromGallery;

  /// No description provided for @launchYourCameraToCaptureALandmarkOrFood.
  ///
  /// In en, this message translates to:
  /// **'Launch your camera to capture a landmark or food'**
  String get launchYourCameraToCaptureALandmarkOrFood;

  /// No description provided for @selectAPhotoFromYourPhotoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Select a photo from your photo library'**
  String get selectAPhotoFromYourPhotoLibrary;

  /// No description provided for @yourPhotoIsReady.
  ///
  /// In en, this message translates to:
  /// **'Your photo is ready'**
  String get yourPhotoIsReady;

  /// No description provided for @photoPreview.
  ///
  /// In en, this message translates to:
  /// **'PHOTO PREVIEW'**
  String get photoPreview;

  /// No description provided for @samplePreview.
  ///
  /// In en, this message translates to:
  /// **'SAMPLE PREVIEW'**
  String get samplePreview;

  /// No description provided for @photoPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo preview unavailable'**
  String get photoPreviewUnavailable;

  /// No description provided for @recognizePhoto.
  ///
  /// In en, this message translates to:
  /// **'Recognize photo'**
  String get recognizePhoto;

  /// No description provided for @recognizingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Recognizing photo…'**
  String get recognizingPhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake Photo'**
  String get retakePhoto;

  /// No description provided for @chooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose Another'**
  String get chooseAnother;

  /// No description provided for @readyToDiscoverWhatYouFound.
  ///
  /// In en, this message translates to:
  /// **'Ready to discover what you found?'**
  String get readyToDiscoverWhatYouFound;

  /// No description provided for @forTheBestResultUseOneClearLandmarkOrDishKeepItCentredAndAvoidBlurryOrVeryDarkPhotos.
  ///
  /// In en, this message translates to:
  /// **'For the best result, use one clear landmark or dish, keep it centred, and avoid blurry or very dark photos.'**
  String
  get forTheBestResultUseOneClearLandmarkOrDishKeepItCentredAndAvoidBlurryOrVeryDarkPhotos;

  /// No description provided for @forBetterAccuracyKeepTheLandmarkOrFoodDishWellLitAndCentered.
  ///
  /// In en, this message translates to:
  /// **'For better accuracy, keep the landmark or food dish well-lit and centered.'**
  String get forBetterAccuracyKeepTheLandmarkOrFoodDishWellLitAndCentered;

  /// No description provided for @sampleScansWorkOfflineLiveRecognitionAndTranslationRequireAnOnlineAccount.
  ///
  /// In en, this message translates to:
  /// **'Sample scans work offline. Live recognition and translation require an online account.'**
  String
  get sampleScansWorkOfflineLiveRecognitionAndTranslationRequireAnOnlineAccount;

  /// No description provided for @onlyResultTextIsSavedInYourLocalHistoryThePhotoIsNotStoredByTheApp.
  ///
  /// In en, this message translates to:
  /// **'Only result text is saved in your local history; the photo is not stored by the app.'**
  String get onlyResultTextIsSavedInYourLocalHistoryThePhotoIsNotStoredByTheApp;

  /// No description provided for @recognizeSendsThisPhotoToGoogleVisionThroughOurSecureService.
  ///
  /// In en, this message translates to:
  /// **'Recognize sends this photo to Google Vision through our secure service. '**
  String get recognizeSendsThisPhotoToGoogleVisionThroughOurSecureService;

  /// No description provided for @scanCameraAccessError.
  ///
  /// In en, this message translates to:
  /// **'Camera or photo library unavailable. Check access in Settings.'**
  String get scanCameraAccessError;

  /// No description provided for @restartTheAppToEnableTheCameraAndPhotoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Restart the app to enable the camera and photo library.'**
  String get restartTheAppToEnableTheCameraAndPhotoLibrary;

  /// No description provided for @scanOpenPhotoError.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be opened. Try another photo.'**
  String get scanOpenPhotoError;

  /// No description provided for @chooseAPhotoSmallerThan4Mb.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo smaller than 4 MB.'**
  String get chooseAPhotoSmallerThan4Mb;

  /// No description provided for @scanRecognitionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image recognition is temporarily unavailable. Try again later.'**
  String get scanRecognitionUnavailable;

  /// No description provided for @recentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent scans'**
  String get recentScans;

  /// No description provided for @noScansYet.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get noScansYet;

  /// No description provided for @yourCompletedRecognitionResultsWillAppearHereDemoResultsStaySeparateHistoryIsCurrentlyStor.
  ///
  /// In en, this message translates to:
  /// **'Your completed recognition results will appear here. Demo results stay separate. History is currently stored on this device.'**
  String
  get yourCompletedRecognitionResultsWillAppearHereDemoResultsStaySeparateHistoryIsCurrentlyStor;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearScanHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear scan history?'**
  String get clearScanHistory;

  /// No description provided for @removeAllScanResultsSavedOnThisDeviceThisCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'Remove all scan results saved on this device? This cannot be undone.'**
  String get removeAllScanResultsSavedOnThisDeviceThisCannotBeUndone;

  /// No description provided for @goToScanner.
  ///
  /// In en, this message translates to:
  /// **'Go to Scanner'**
  String get goToScanner;

  /// No description provided for @tryPreparedRecognitionResults.
  ///
  /// In en, this message translates to:
  /// **'Try prepared recognition results'**
  String get tryPreparedRecognitionResults;

  /// No description provided for @browsePreparedLandmarkAndFoodResultsToUnderstandWhatTheFinishedRecognitionScreenWillShow.
  ///
  /// In en, this message translates to:
  /// **'Browse prepared landmark and food results to understand what the finished recognition screen will show.'**
  String
  get browsePreparedLandmarkAndFoodResultsToUnderstandWhatTheFinishedRecognitionScreenWillShow;

  /// No description provided for @thisIsAPreparedDemoResultItHasNotAnalysedYourUploadedPhotoAndIsNotAddedToScanHistory.
  ///
  /// In en, this message translates to:
  /// **'This is a prepared demo result. It has not analysed your uploaded photo and is not added to scan history.'**
  String
  get thisIsAPreparedDemoResultItHasNotAnalysedYourUploadedPhotoAndIsNotAddedToScanHistory;

  /// No description provided for @noPreparedTestResultIsAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'No prepared test result is available yet.'**
  String get noPreparedTestResultIsAvailableYet;

  /// No description provided for @runTestRecognition.
  ///
  /// In en, this message translates to:
  /// **'Run test recognition'**
  String get runTestRecognition;

  /// No description provided for @testRecognitionUsesPreparedCatalogResultsToPreviewTheFlow.
  ///
  /// In en, this message translates to:
  /// **'Test recognition uses prepared catalog results to preview the flow.'**
  String get testRecognitionUsesPreparedCatalogResultsToPreviewTheFlow;

  /// No description provided for @viewDemoResult.
  ///
  /// In en, this message translates to:
  /// **'View demo result'**
  String get viewDemoResult;

  /// No description provided for @viewDemoResults.
  ///
  /// In en, this message translates to:
  /// **'View demo results'**
  String get viewDemoResults;

  /// No description provided for @exploreThisResult.
  ///
  /// In en, this message translates to:
  /// **'Explore this result'**
  String get exploreThisResult;

  /// No description provided for @detectedLabels.
  ///
  /// In en, this message translates to:
  /// **'Detected labels'**
  String get detectedLabels;

  /// No description provided for @referenceScanSource.
  ///
  /// In en, this message translates to:
  /// **'Photo scan · Reference photos'**
  String get referenceScanSource;

  /// No description provided for @scanTryAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Try another photo'**
  String get scanTryAnotherPhoto;

  /// No description provided for @scanAnotherPhotoHelp.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t identify a specific landmark from this photo. Retake it or choose a clearer image from your gallery.'**
  String get scanAnotherPhotoHelp;

  /// No description provided for @scanIdentifyLandmark.
  ///
  /// In en, this message translates to:
  /// **'Scan a place or dish'**
  String get scanIdentifyLandmark;

  /// No description provided for @scanPhotoIntro.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a Malaysian landmark, restaurant sign, or local dish—or choose one from your gallery.'**
  String get scanPhotoIntro;

  /// No description provided for @scanListedPlaceDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} is listed as {category} at {address}. Check the place listing for more details.'**
  String scanListedPlaceDescription(
    String name,
    String category,
    String address,
  );

  /// No description provided for @scanPlaceDescriptionPending.
  ///
  /// In en, this message translates to:
  /// **'More details for {name} are not verified yet. Check the place listing before visiting.'**
  String scanPlaceDescriptionPending(String name);

  /// No description provided for @scanPhotoTips.
  ///
  /// In en, this message translates to:
  /// **'Tips for a clearer photo'**
  String get scanPhotoTips;

  /// No description provided for @scanTipLight.
  ///
  /// In en, this message translates to:
  /// **'Use good light'**
  String get scanTipLight;

  /// No description provided for @scanTipLightDetail.
  ///
  /// In en, this message translates to:
  /// **'Hold the camera steady and tap the landmark to focus. Avoid blur, glare and deep shadows.'**
  String get scanTipLightDetail;

  /// No description provided for @scanTipFrame.
  ///
  /// In en, this message translates to:
  /// **'Show the whole landmark'**
  String get scanTipFrame;

  /// No description provided for @scanTipFrameDetail.
  ///
  /// In en, this message translates to:
  /// **'Step back to include its outline and distinctive features. Keep cars and crowds out of the way where possible.'**
  String get scanTipFrameDetail;

  /// No description provided for @scanTipSign.
  ///
  /// In en, this message translates to:
  /// **'Include a readable sign'**
  String get scanTipSign;

  /// No description provided for @scanTipSignDetail.
  ///
  /// In en, this message translates to:
  /// **'If the building is hard to recognise, photograph the entrance or name plaque so the words are legible.'**
  String get scanTipSignDetail;

  /// No description provided for @scanNeedsClue.
  ///
  /// In en, this message translates to:
  /// **'No clear match yet'**
  String get scanNeedsClue;

  /// No description provided for @scanRetakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake photo'**
  String get scanRetakePhoto;

  /// No description provided for @scanUploadAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload another photo'**
  String get scanUploadAnotherPhoto;

  /// No description provided for @scanPhotoClues.
  ///
  /// In en, this message translates to:
  /// **'Clues from your photo'**
  String get scanPhotoClues;

  /// No description provided for @scanAboutLandmark.
  ///
  /// In en, this message translates to:
  /// **'About this landmark'**
  String get scanAboutLandmark;

  /// No description provided for @scanNearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'Nearby attractions & food'**
  String get scanNearbyPlaces;

  /// No description provided for @scanNearbyDistance.
  ///
  /// In en, this message translates to:
  /// **'Guide distances from {place} are straight-line estimates.'**
  String scanNearbyDistance(String place);

  /// No description provided for @scanNearbyArea.
  ///
  /// In en, this message translates to:
  /// **'Places around {place}'**
  String scanNearbyArea(String place);

  /// No description provided for @scanNearbyNoLocation.
  ///
  /// In en, this message translates to:
  /// **'This scan has no confirmed location. Use Maps to explore around you.'**
  String get scanNearbyNoLocation;

  /// No description provided for @scanGuideDishVenues.
  ///
  /// In en, this message translates to:
  /// **'Places in the travel guide that mention this dish'**
  String get scanGuideDishVenues;

  /// No description provided for @scanDishVenuesHelp.
  ///
  /// In en, this message translates to:
  /// **'Restaurants matched to this dish search. Check the menu before visiting.'**
  String get scanDishVenuesHelp;

  /// No description provided for @scanDishAreaFallback.
  ///
  /// In en, this message translates to:
  /// **'Showing restaurants around {area}. Enable location for results near you.'**
  String scanDishAreaFallback(String area);

  /// No description provided for @scanFoodAndCafes.
  ///
  /// In en, this message translates to:
  /// **'Food & Cafés'**
  String get scanFoodAndCafes;

  /// No description provided for @scanFindAttractions.
  ///
  /// In en, this message translates to:
  /// **'Find attractions'**
  String get scanFindAttractions;

  /// No description provided for @scanFindingNearby.
  ///
  /// In en, this message translates to:
  /// **'Looking up nearby places…'**
  String get scanFindingNearby;

  /// No description provided for @scanNoNearbyListings.
  ///
  /// In en, this message translates to:
  /// **'No listings available here. You can also search in Maps.'**
  String get scanNoNearbyListings;

  /// No description provided for @scanTakeAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take another photo'**
  String get scanTakeAnotherPhoto;

  /// No description provided for @scanAreaOnly.
  ///
  /// In en, this message translates to:
  /// **'Area identified'**
  String get scanAreaOnly;

  /// No description provided for @scanPlacesInArea.
  ///
  /// In en, this message translates to:
  /// **'Places in the area'**
  String get scanPlacesInArea;

  /// No description provided for @scanChooseAreaPlace.
  ///
  /// In en, this message translates to:
  /// **'These places are in the detected area. Select one if you recognise it, or add another photo.'**
  String get scanChooseAreaPlace;

  /// No description provided for @scanSuggestedArea.
  ///
  /// In en, this message translates to:
  /// **'Area clue: {area}'**
  String scanSuggestedArea(String area);

  /// No description provided for @scanOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get scanOpenMaps;

  /// No description provided for @scanWebMatchFound.
  ///
  /// In en, this message translates to:
  /// **'Supported by matching web images'**
  String get scanWebMatchFound;

  /// No description provided for @scanSignClue.
  ///
  /// In en, this message translates to:
  /// **'Text on the photo offers a clue'**
  String get scanSignClue;

  /// No description provided for @scanWebSource.
  ///
  /// In en, this message translates to:
  /// **'Photo scan · Web matches'**
  String get scanWebSource;

  /// No description provided for @scanSignSource.
  ///
  /// In en, this message translates to:
  /// **'Photo scan · Text clue'**
  String get scanSignSource;

  /// No description provided for @scanSelectedSource.
  ///
  /// In en, this message translates to:
  /// **'Photo scan · Your selection'**
  String get scanSelectedSource;

  /// No description provided for @scanPlaceListingSource.
  ///
  /// In en, this message translates to:
  /// **'Photo scan · Place listings'**
  String get scanPlaceListingSource;

  /// No description provided for @scanCheckingPlaceDetails.
  ///
  /// In en, this message translates to:
  /// **'Checking place details…'**
  String get scanCheckingPlaceDetails;

  /// No description provided for @scanCheckPlaceDetails.
  ///
  /// In en, this message translates to:
  /// **'Check place details'**
  String get scanCheckPlaceDetails;

  /// No description provided for @scanVisualClueSource.
  ///
  /// In en, this message translates to:
  /// **'Photo scan · Visual clues'**
  String get scanVisualClueSource;

  /// No description provided for @scanHoursVaryByVenue.
  ///
  /// In en, this message translates to:
  /// **'Hours vary by venue.'**
  String get scanHoursVaryByVenue;

  /// No description provided for @scanHoursSource.
  ///
  /// In en, this message translates to:
  /// **'Check published hours'**
  String get scanHoursSource;

  /// No description provided for @referenceMatchFound.
  ///
  /// In en, this message translates to:
  /// **'Strong reference match'**
  String get referenceMatchFound;

  /// No description provided for @referenceMatchSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected by you'**
  String get referenceMatchSelected;

  /// No description provided for @referenceMatchUncertain.
  ///
  /// In en, this message translates to:
  /// **'Match needs confirmation'**
  String get referenceMatchUncertain;

  /// No description provided for @referencePossibleMatches.
  ///
  /// In en, this message translates to:
  /// **'Possible matches'**
  String get referencePossibleMatches;

  /// No description provided for @referenceChooseSubject.
  ///
  /// In en, this message translates to:
  /// **'Choose the subject if you recognise it. If none fit, search for the place.'**
  String get referenceChooseSubject;

  /// No description provided for @visionConfidenceValue.
  ///
  /// In en, this message translates to:
  /// **'Vision confidence {arg0}%'**
  String visionConfidenceValue(String arg0);

  /// No description provided for @identificationUsesVisionDetectionsGuideDescriptionsComeFromTheAppSCuratedCatalog.
  ///
  /// In en, this message translates to:
  /// **'Identification uses Vision detections. Guide descriptions come from the app’s curated catalog.'**
  String
  get identificationUsesVisionDetectionsGuideDescriptionsComeFromTheAppSCuratedCatalog;

  /// No description provided for @resultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Result language'**
  String get resultLanguage;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get translating;

  /// No description provided for @machineTranslatedTextTheOriginalEnglishResultStaysInYourHistory.
  ///
  /// In en, this message translates to:
  /// **'Machine-translated text. The original English result stays in your history.'**
  String get machineTranslatedTextTheOriginalEnglishResultStaysInYourHistory;

  /// No description provided for @translationIsUnavailableYourOriginalResultIsStillAvailable.
  ///
  /// In en, this message translates to:
  /// **'Translation is unavailable. Your original result is still available.'**
  String get translationIsUnavailableYourOriginalResultIsStillAvailable;

  /// No description provided for @findRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Find restaurants'**
  String get findRestaurants;

  /// No description provided for @chooseARestaurantBeforeAddingThisDishToYourTravelPlan.
  ///
  /// In en, this message translates to:
  /// **'Choose a restaurant before adding this dish to your travel plan.'**
  String get chooseARestaurantBeforeAddingThisDishToYourTravelPlan;

  /// No description provided for @theseActionsWillBeAvailableWhenLiveRecognitionAndTourismDetailsAreConnected.
  ///
  /// In en, this message translates to:
  /// **'These actions will be available when live recognition and tourism details are connected.'**
  String
  get theseActionsWillBeAvailableWhenLiveRecognitionAndTourismDetailsAreConnected;

  /// No description provided for @availableAfterSetup.
  ///
  /// In en, this message translates to:
  /// **'Available after setup'**
  String get availableAfterSetup;

  /// No description provided for @afterLiveRecognitionIsConnectedSuccessfulScansWillBeSavedHereAutomatically.
  ///
  /// In en, this message translates to:
  /// **'After live recognition is connected, successful scans will be saved here automatically.'**
  String
  get afterLiveRecognitionIsConnectedSuccessfulScansWillBeSavedHereAutomatically;

  /// No description provided for @adults.
  ///
  /// In en, this message translates to:
  /// **'Adults'**
  String get adults;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @seniors.
  ///
  /// In en, this message translates to:
  /// **'Seniors'**
  String get seniors;

  /// No description provided for @travelers.
  ///
  /// In en, this message translates to:
  /// **'Travelers'**
  String get travelers;

  /// No description provided for @addTravelers.
  ///
  /// In en, this message translates to:
  /// **'Add travelers'**
  String get addTravelers;

  /// No description provided for @addMore.
  ///
  /// In en, this message translates to:
  /// **'Add More'**
  String get addMore;

  /// No description provided for @selectPlannedItinerary.
  ///
  /// In en, this message translates to:
  /// **'Select Planned Itinerary'**
  String get selectPlannedItinerary;

  /// No description provided for @switchBetweenYourActiveTripsAndCustomGeneratedPlans.
  ///
  /// In en, this message translates to:
  /// **'Switch between your active trips and custom generated plans'**
  String get switchBetweenYourActiveTripsAndCustomGeneratedPlans;

  /// No description provided for @smartScheduleDailyStops.
  ///
  /// In en, this message translates to:
  /// **'Smart schedule & daily stops'**
  String get smartScheduleDailyStops;

  /// No description provided for @autoSmartSchedulingForTouristsInMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Auto smart scheduling for tourists in Malaysia'**
  String get autoSmartSchedulingForTouristsInMalaysia;

  /// No description provided for @smartItineraryScheduling.
  ///
  /// In en, this message translates to:
  /// **'Smart Itinerary Scheduling'**
  String get smartItineraryScheduling;

  /// No description provided for @valueAdultvalue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Adult{arg1}'**
  String valueAdultvalue(String arg0, String arg1);

  /// No description provided for @valueChildvalue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Child{arg1}'**
  String valueChildvalue(String arg0, String arg1);

  /// No description provided for @valueSeniorvalue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Senior{arg1}'**
  String valueSeniorvalue(String arg0, String arg1);

  /// No description provided for @valueAddedToYourPlanDraft.
  ///
  /// In en, this message translates to:
  /// **'{arg0} added to your plan draft!'**
  String valueAddedToYourPlanDraft(String arg0);

  /// No description provided for @valueAddedToYourDay2ScheduleDraft.
  ///
  /// In en, this message translates to:
  /// **'{arg0} added to your Day 2 schedule draft!'**
  String valueAddedToYourDay2ScheduleDraft(String arg0);

  /// No description provided for @showingDayValuePlanForValue.
  ///
  /// In en, this message translates to:
  /// **'Showing Day {arg0} Plan for {arg1}'**
  String showingDayValuePlanForValue(String arg0, String arg1);

  /// No description provided for @switchedToValueValueDays.
  ///
  /// In en, this message translates to:
  /// **'Switched to {arg0} ({arg1} Days)'**
  String switchedToValueValueDays(String arg0, String arg1);

  /// No description provided for @swapToIndoorValue.
  ///
  /// In en, this message translates to:
  /// **'Swap to indoor: {arg0}'**
  String swapToIndoorValue(String arg0);

  /// No description provided for @rainSafeScheduleAppliedValueSwappedInForAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Rain-safe schedule applied: {arg0} swapped in for afternoon.'**
  String rainSafeScheduleAppliedValueSwappedInForAfternoon(String arg0);

  /// No description provided for @builtA3DayKlPlanWithFoodAndShoppingStops.
  ///
  /// In en, this message translates to:
  /// **'Built a 3-day KL plan with food and shopping stops.'**
  String get builtA3DayKlPlanWithFoodAndShoppingStops;

  /// No description provided for @reorderedStopsToSaveAbout45MinutesOfTravelTime.
  ///
  /// In en, this message translates to:
  /// **'Reordered stops to save about 45 minutes of travel time.'**
  String get reorderedStopsToSaveAbout45MinutesOfTravelTime;

  /// No description provided for @rainAfter3PmIndoorBackupStopsAddedAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Rain after 3 PM — indoor backup stops added automatically.'**
  String get rainAfter3PmIndoorBackupStopsAddedAutomatically;

  /// No description provided for @dailySpendKeptWithinYourRm150300MediumBudget.
  ///
  /// In en, this message translates to:
  /// **'Daily spend kept within your RM150–300 medium budget.'**
  String get dailySpendKeptWithinYourRm150300MediumBudget;

  /// No description provided for @mapsAndItineraryCachedForUseWithoutMobileData.
  ///
  /// In en, this message translates to:
  /// **'Maps and itinerary cached for use without mobile data.'**
  String get mapsAndItineraryCachedForUseWithoutMobileData;

  /// No description provided for @routeOptimizedTravelTimeReducedBy45Minutes.
  ///
  /// In en, this message translates to:
  /// **'Route optimized — travel time reduced by 45 minutes.'**
  String get routeOptimizedTravelTimeReducedBy45Minutes;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @thisAppIsAPrototypeDesignedForAFinalYearProjectToShowcaseAutomatedRouteSchedulingAndMapVis.
  ///
  /// In en, this message translates to:
  /// **'This app is a prototype designed for a Final Year Project to showcase automated route scheduling and map visualization in Malaysia.'**
  String
  get thisAppIsAPrototypeDesignedForAFinalYearProjectToShowcaseAutomatedRouteSchedulingAndMapVis;

  /// No description provided for @readOurTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Read our terms of service'**
  String get readOurTermsOfService;

  /// No description provided for @byUsingThisAppYouAgreeToOurTermsOfServiceNoRealPersonalDataIsCollectedOrSentToAnyServer.
  ///
  /// In en, this message translates to:
  /// **'By using this app, you agree to our terms of service. No real personal data is collected or sent to any server.'**
  String
  get byUsingThisAppYouAgreeToOurTermsOfServiceNoRealPersonalDataIsCollectedOrSentToAnyServer;

  /// No description provided for @enterYourCredentialsToManageYourMalaysiaTrips.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to manage your Malaysia trips.'**
  String get enterYourCredentialsToManageYourMalaysiaTrips;

  /// No description provided for @invalidEmailOrPasswordMin6Chars.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password (min 6 chars)'**
  String get invalidEmailOrPasswordMin6Chars;

  /// No description provided for @listeningForVoiceCommandsInEnglishMalayOrChineseTapBelowToSendASampleSpokenQuery.
  ///
  /// In en, this message translates to:
  /// **'Listening for voice commands in English, Malay, or Chinese...\n\nTap below to send a sample spoken query.'**
  String
  get listeningForVoiceCommandsInEnglishMalayOrChineseTapBelowToSendASampleSpokenQuery;

  /// No description provided for @recommend2IndoorSpotsIfItRainsNearKlccThisAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Recommend 2 indoor spots if it rains near KLCC this afternoon.'**
  String get recommend2IndoorSpotsIfItRainsNearKlccThisAfternoon;

  /// No description provided for @accountCreatedSuccessfullyRedirectingToHomepage.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully! Redirecting to homepage...'**
  String get accountCreatedSuccessfullyRedirectingToHomepage;

  /// No description provided for @pleaseCompleteAllMandatoryRegistrationFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete all mandatory registration fields.'**
  String get pleaseCompleteAllMandatoryRegistrationFields;

  /// No description provided for @pleaseEnterAValidEmailAddressEGUserExampleCom.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address (e.g., user@example.com).'**
  String get pleaseEnterAValidEmailAddressEGUserExampleCom;

  /// No description provided for @passwordMustContainAtLeast8CharactersIncluding1Uppercase1Lowercase1NumberAnd1SpecialCharac.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 8 characters, including 1 uppercase, 1 lowercase, 1 number, and 1 special character.'**
  String
  get passwordMustContainAtLeast8CharactersIncluding1Uppercase1Lowercase1NumberAnd1SpecialCharac;

  /// No description provided for @passwordAndConfirmPasswordDoNotMatchPleaseReEnter.
  ///
  /// In en, this message translates to:
  /// **'Password and Confirm Password do not match. Please re-enter.'**
  String get passwordAndConfirmPasswordDoNotMatchPleaseReEnter;

  /// No description provided for @thisEmailAddressHasAlreadyBeenRegisteredPleaseLogInOrUseAnotherEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'This email address has already been registered. Please log in or use another email address.'**
  String
  get thisEmailAddressHasAlreadyBeenRegisteredPleaseLogInOrUseAnotherEmailAddress;

  /// No description provided for @registrationTimedOutCheckYourEmailForAConfirmationMessageBeforeTryingAgainAsYourAccountMay.
  ///
  /// In en, this message translates to:
  /// **'Registration timed out. Check your email for a confirmation message before trying again, as your account may have been created.'**
  String
  get registrationTimedOutCheckYourEmailForAConfirmationMessageBeforeTryingAgainAsYourAccountMay;

  /// No description provided for @loginSuccessfulRedirectingToHomepage.
  ///
  /// In en, this message translates to:
  /// **'Login successful. Redirecting to homepage...'**
  String get loginSuccessfulRedirectingToHomepage;

  /// No description provided for @pleaseEnterYourEmailAddressAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address and password.'**
  String get pleaseEnterYourEmailAddressAndPassword;

  /// No description provided for @pleaseEnterAValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get pleaseEnterAValidEmailAddress;

  /// No description provided for @theEmailAddressOrPasswordIsIncorrectPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'The email address or password is incorrect. Please try again.'**
  String get theEmailAddressOrPasswordIsIncorrectPleaseTryAgain;

  /// No description provided for @authenticationServiceIsCurrentlyUnavailablePleaseTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Authentication service is currently unavailable. Please try again later.'**
  String get authenticationServiceIsCurrentlyUnavailablePleaseTryAgainLater;

  /// No description provided for @theLoginRequestTimedOutPleaseCheckYourNetworkAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'The login request timed out. Please check your network and try again.'**
  String get theLoginRequestTimedOutPleaseCheckYourNetworkAndTryAgain;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @fullNameFieldCannotBeEmptyPleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Full Name field cannot be empty. Please enter your name.'**
  String get fullNameFieldCannotBeEmptyPleaseEnterYourName;

  /// No description provided for @unableToSaveProfileChangesPleaseCheckYourNetworkAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Unable to save profile changes. Please check your network and try again.'**
  String get unableToSaveProfileChangesPleaseCheckYourNetworkAndTryAgain;

  /// No description provided for @tripPreferencesRecordedSuccessfullyGeneratingYourItinerary.
  ///
  /// In en, this message translates to:
  /// **'Trip preferences recorded successfully. Generating your itinerary.'**
  String get tripPreferencesRecordedSuccessfullyGeneratingYourItinerary;

  /// No description provided for @pleaseCompleteAllMandatoryTripPreferenceFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete all mandatory trip-preference fields.'**
  String get pleaseCompleteAllMandatoryTripPreferenceFields;

  /// No description provided for @pleaseEnterOrSelectAValidDestination.
  ///
  /// In en, this message translates to:
  /// **'Please enter or select a valid destination.'**
  String get pleaseEnterOrSelectAValidDestination;

  /// No description provided for @pleaseSelectAValidNumberOfTravelDays.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid number of travel days.'**
  String get pleaseSelectAValidNumberOfTravelDays;

  /// No description provided for @dailyEndTimeMustBeLaterThanDailyStartTime.
  ///
  /// In en, this message translates to:
  /// **'Daily end time must be later than daily start time.'**
  String get dailyEndTimeMustBeLaterThanDailyStartTime;

  /// No description provided for @pleaseSelectAtLeastOneTravelInterest.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one travel interest.'**
  String get pleaseSelectAtLeastOneTravelInterest;

  /// No description provided for @pleaseSelectAValidEstimatedBudgetCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid estimated budget category.'**
  String get pleaseSelectAValidEstimatedBudgetCategory;

  /// No description provided for @theSelectedTravelModeIsNotSupportedPleaseSelectDrivingOrWalking.
  ///
  /// In en, this message translates to:
  /// **'The selected travel mode is not supported. Please select Driving or Walking.'**
  String get theSelectedTravelModeIsNotSupportedPleaseSelectDrivingOrWalking;

  /// No description provided for @authenticationRequiredPleaseLogInToSaveYourItinerary.
  ///
  /// In en, this message translates to:
  /// **'Authentication required. Please log in to save your itinerary.'**
  String get authenticationRequiredPleaseLogInToSaveYourItinerary;

  /// No description provided for @deletedOnThisDeviceCloudSyncIsPending.
  ///
  /// In en, this message translates to:
  /// **'Deleted on this device. Cloud sync is pending.'**
  String get deletedOnThisDeviceCloudSyncIsPending;

  /// No description provided for @adminDatabaseHub.
  ///
  /// In en, this message translates to:
  /// **'Admin Database Hub'**
  String get adminDatabaseHub;

  /// No description provided for @adminHubAccess.
  ///
  /// In en, this message translates to:
  /// **'Admin Hub Access'**
  String get adminHubAccess;

  /// No description provided for @adminAccessTapToLogInAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin access (Tap to log in as admin)'**
  String get adminAccessTapToLogInAsAdmin;

  /// No description provided for @loginAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Login as Admin'**
  String get loginAsAdmin;

  /// No description provided for @loggedInAsAdministratorChingKheat.
  ///
  /// In en, this message translates to:
  /// **'Logged in as Administrator (Ching Kheat)'**
  String get loggedInAsAdministratorChingKheat;

  /// No description provided for @theAdminDatabaseHubRequiresAdministratorPrivilegesToFetchSyncAndImportPlacesFromGoogle.
  ///
  /// In en, this message translates to:
  /// **'The Admin Database Hub requires administrator privileges to fetch, sync, and import places from Google.'**
  String
  get theAdminDatabaseHubRequiresAdministratorPrivilegesToFetchSyncAndImportPlacesFromGoogle;

  /// No description provided for @secretDataSeederPortal.
  ///
  /// In en, this message translates to:
  /// **'Secret Data Seeder Portal'**
  String get secretDataSeederPortal;

  /// No description provided for @secretPortalToFetchSyncPlaces.
  ///
  /// In en, this message translates to:
  /// **'Secret portal to fetch & sync places'**
  String get secretPortalToFetchSyncPlaces;

  /// No description provided for @signInAsAnAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Sign in as an administrator.'**
  String get signInAsAnAdministrator;

  /// No description provided for @signInAsAnAdministratorToImportGooglePlaceIds.
  ///
  /// In en, this message translates to:
  /// **'Sign in as an administrator to import Google place IDs.'**
  String get signInAsAnAdministratorToImportGooglePlaceIds;

  /// No description provided for @text1SelectDestinationState.
  ///
  /// In en, this message translates to:
  /// **'1. Select Destination State'**
  String get text1SelectDestinationState;

  /// No description provided for @discoverNewPlaces.
  ///
  /// In en, this message translates to:
  /// **'Discover new places'**
  String get discoverNewPlaces;

  /// No description provided for @discoveringMorePlaces.
  ///
  /// In en, this message translates to:
  /// **'Discovering more places…'**
  String get discoveringMorePlaces;

  /// No description provided for @discoverMorePlacesInValue.
  ///
  /// In en, this message translates to:
  /// **'Discover More Places in {arg0}'**
  String discoverMorePlacesInValue(String arg0);

  /// No description provided for @discoveringNewPlacesExistingRecordsArePreservedUseUpdateSavedPlacesToRefreshTheirDetails.
  ///
  /// In en, this message translates to:
  /// **'Discovering new places. Existing records are preserved; use Update saved places to refresh their details.'**
  String
  get discoveringNewPlacesExistingRecordsArePreservedUseUpdateSavedPlacesToRefreshTheirDetails;

  /// No description provided for @updateSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Update saved places'**
  String get updateSavedPlaces;

  /// No description provided for @updateSavedPlacesInValue.
  ///
  /// In en, this message translates to:
  /// **'Update saved places in {arg0}'**
  String updateSavedPlacesInValue(String arg0);

  /// No description provided for @updateAllSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Update all saved places'**
  String get updateAllSavedPlaces;

  /// No description provided for @startANewUpdateOfAllSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Start a new update of all saved places'**
  String get startANewUpdateOfAllSavedPlaces;

  /// No description provided for @refreshHoursRatingsNamesAndLocationsForAllSavedPlacesDiscoverNewPlacesBelowOnlyAddsNewIds.
  ///
  /// In en, this message translates to:
  /// **'Refresh hours, ratings, names and locations for all saved places. Discover new places below only adds new IDs.'**
  String
  get refreshHoursRatingsNamesAndLocationsForAllSavedPlacesDiscoverNewPlacesBelowOnlyAddsNewIds;

  /// No description provided for @updatesEverySavedGooglePlaceInThisStateIncludingOpeningHoursRatingsNameAndLocationYourCate.
  ///
  /// In en, this message translates to:
  /// **'Updates every saved Google place in this state, including opening hours, ratings, name and location. Your categories and indoor/outdoor choices stay unchanged.'**
  String
  get updatesEverySavedGooglePlaceInThisStateIncludingOpeningHoursRatingsNameAndLocationYourCate;

  /// No description provided for @usesTheFullDetailsAllowanceKeepThisPageOpenLeavingPausesTheUpdateProgressIsSavedOnThisDevi.
  ///
  /// In en, this message translates to:
  /// **'Uses the full-details allowance. Keep this page open. Leaving pauses the update; progress is saved on this device. A successful response with no opening hours marks them unknown.'**
  String
  get usesTheFullDetailsAllowanceKeepThisPageOpenLeavingPausesTheUpdateProgressIsSavedOnThisDevi;

  /// No description provided for @pauseUpdate.
  ///
  /// In en, this message translates to:
  /// **'Pause update'**
  String get pauseUpdate;

  /// No description provided for @resumeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Resume update'**
  String get resumeUpdate;

  /// No description provided for @pausing.
  ///
  /// In en, this message translates to:
  /// **'Pausing…'**
  String get pausing;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get updating;

  /// No description provided for @retryPlacesWithIssues.
  ///
  /// In en, this message translates to:
  /// **'Retry places with issues'**
  String get retryPlacesWithIssues;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @needsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get needsReview;

  /// No description provided for @placesNeedingReview.
  ///
  /// In en, this message translates to:
  /// **'Places needing review'**
  String get placesNeedingReview;

  /// No description provided for @reviewSavedPlace.
  ///
  /// In en, this message translates to:
  /// **'Review saved place'**
  String get reviewSavedPlace;

  /// No description provided for @reviewStoredDataLoadLiveDetails.
  ///
  /// In en, this message translates to:
  /// **'Review stored data / load live details'**
  String get reviewStoredDataLoadLiveDetails;

  /// No description provided for @incompleteImportNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Incomplete import — needs review'**
  String get incompleteImportNeedsReview;

  /// No description provided for @appCategory.
  ///
  /// In en, this message translates to:
  /// **'App category'**
  String get appCategory;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get setting;

  /// No description provided for @confirmedSetting.
  ///
  /// In en, this message translates to:
  /// **'Confirmed setting'**
  String get confirmedSetting;

  /// No description provided for @confirmAndSaveReview.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save review'**
  String get confirmAndSaveReview;

  /// No description provided for @onlyAppCategoryAndSettingAreSavedExistingGoogleDetailsAreNotStored.
  ///
  /// In en, this message translates to:
  /// **'Only app category and setting are saved. Existing Google details are not stored.'**
  String get onlyAppCategoryAndSettingAreSavedExistingGoogleDetailsAreNotStored;

  /// No description provided for @loadRetryLiveDetails.
  ///
  /// In en, this message translates to:
  /// **'Load / retry live details'**
  String get loadRetryLiveDetails;

  /// No description provided for @loadLiveDetailsToSeeTheNameAndAddress.
  ///
  /// In en, this message translates to:
  /// **'Load live details to see the name and address.'**
  String get loadLiveDetailsToSeeTheNameAndAddress;

  /// No description provided for @googleTypeValue.
  ///
  /// In en, this message translates to:
  /// **'Google type: {arg0}'**
  String googleTypeValue(String arg0);

  /// No description provided for @settingSuggestionValueConfirmUsingYourKnowledgeThisIsNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Setting suggestion: {arg0} — confirm using your knowledge; this is not verified.'**
  String settingSuggestionValueConfirmUsingYourKnowledgeThisIsNotVerified(
    String arg0,
  );

  /// No description provided for @howToReviewCategoriesAndSettings.
  ///
  /// In en, this message translates to:
  /// **'How to review categories and settings'**
  String get howToReviewCategoriesAndSettings;

  /// No description provided for @openReviewOnASavedPlaceLoadLiveDetailsCheckTheSuggestionThenConfirmItsCategoryAndSettingNo.
  ///
  /// In en, this message translates to:
  /// **'Open Review on a saved place. Load live details, check the suggestion, then confirm its category and setting. No bulk changes are made.'**
  String
  get openReviewOnASavedPlaceLoadLiveDetailsCheckTheSuggestionThenConfirmItsCategoryAndSettingNo;

  /// No description provided for @savedPlacesInspector.
  ///
  /// In en, this message translates to:
  /// **'Saved Places Inspector'**
  String get savedPlacesInspector;

  /// No description provided for @viewAdminSyncedPlacesInspectSavedData.
  ///
  /// In en, this message translates to:
  /// **'View admin-synced places & inspect saved data'**
  String get viewAdminSyncedPlacesInspectSavedData;

  /// No description provided for @storedDatabaseInformation.
  ///
  /// In en, this message translates to:
  /// **'Stored database information'**
  String get storedDatabaseInformation;

  /// No description provided for @databaseUnavailableReconnectToCheckYourSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Database unavailable. Reconnect to check your saved places.'**
  String get databaseUnavailableReconnectToCheckYourSavedPlaces;

  /// No description provided for @unableToReadSavedPlacesRefreshTheDatabaseListBeforeStartingAnotherImport.
  ///
  /// In en, this message translates to:
  /// **'Unable to read saved places. Refresh the database list before starting another import.'**
  String
  get unableToReadSavedPlacesRefreshTheDatabaseListBeforeStartingAnotherImport;

  /// No description provided for @savedPlacesAreUnavailableTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Saved places are unavailable. Try again later.'**
  String get savedPlacesAreUnavailableTryAgainLater;

  /// No description provided for @savedPlaceIdsAndAppCategoriesGoogleDetailsWereNotStored.
  ///
  /// In en, this message translates to:
  /// **'Saved place IDs and app categories. Google details were not stored.'**
  String get savedPlaceIdsAndAppCategoriesGoogleDetailsWereNotStored;

  /// No description provided for @savedGooglePlace.
  ///
  /// In en, this message translates to:
  /// **'Saved Google place'**
  String get savedGooglePlace;

  /// No description provided for @placesInDatabaseValue.
  ///
  /// In en, this message translates to:
  /// **'Places in Database ({arg0})'**
  String placesInDatabaseValue(String arg0);

  /// No description provided for @placesInValue.
  ///
  /// In en, this message translates to:
  /// **'Places in {arg0}'**
  String placesInValue(String arg0);

  /// No description provided for @noPlacesStoredForValueYet.
  ///
  /// In en, this message translates to:
  /// **'No places stored for {arg0} yet.'**
  String noPlacesStoredForValueYet(String arg0);

  /// No description provided for @noSavedPlacesFoundInValue.
  ///
  /// In en, this message translates to:
  /// **'No saved places found in {arg0}.'**
  String noSavedPlacesFoundInValue(String arg0);

  /// No description provided for @databaseCountForValue.
  ///
  /// In en, this message translates to:
  /// **'Database Count for {arg0}:'**
  String databaseCountForValue(String arg0);

  /// No description provided for @checkingDatabaseSchema.
  ///
  /// In en, this message translates to:
  /// **'Checking database schema...'**
  String get checkingDatabaseSchema;

  /// No description provided for @readingSavedDatabase.
  ///
  /// In en, this message translates to:
  /// **'Reading saved database...'**
  String get readingSavedDatabase;

  /// No description provided for @refreshingTheValueDatabaseList.
  ///
  /// In en, this message translates to:
  /// **'Refreshing the {arg0} database list'**
  String refreshingTheValueDatabaseList(String arg0);

  /// No description provided for @valueDatabaseListRefreshed.
  ///
  /// In en, this message translates to:
  /// **'{arg0} database list refreshed'**
  String valueDatabaseListRefreshed(String arg0);

  /// No description provided for @checkingSyncHistoryForValue.
  ///
  /// In en, this message translates to:
  /// **'Checking sync history for {arg0}…'**
  String checkingSyncHistoryForValue(String arg0);

  /// No description provided for @checkingVerifiedGoogleAllowance.
  ///
  /// In en, this message translates to:
  /// **'Checking verified Google allowance…'**
  String get checkingVerifiedGoogleAllowance;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @keepExistingData.
  ///
  /// In en, this message translates to:
  /// **'Keep existing data'**
  String get keepExistingData;

  /// No description provided for @syncAgain.
  ///
  /// In en, this message translates to:
  /// **'Sync again'**
  String get syncAgain;

  /// No description provided for @syncValueAgain.
  ///
  /// In en, this message translates to:
  /// **'Sync {arg0} again?'**
  String syncValueAgain(String arg0);

  /// No description provided for @syncingPlaces.
  ///
  /// In en, this message translates to:
  /// **'Syncing places...'**
  String get syncingPlaces;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @lastSuccessfulSyncValueValueSyncingAgainWillUseGoogleApiQuotaYouCanKeepTheExistingDataInst.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync: {arg0} ({arg1}).\n\nSyncing again will use Google API quota. You can keep the existing data instead.'**
  String
  lastSuccessfulSyncValueValueSyncingAgainWillUseGoogleApiQuotaYouCanKeepTheExistingDataInst(
    String arg0,
    String arg1,
  );

  /// No description provided for @thisStateAlreadyHasStoredPlacesButItsPreviousSyncTimeWasNotRecordedSyncingAgainWillUseGoog.
  ///
  /// In en, this message translates to:
  /// **'This state already has stored places, but its previous sync time was not recorded. Syncing again will use Google API quota.'**
  String
  get thisStateAlreadyHasStoredPlacesButItsPreviousSyncTimeWasNotRecordedSyncingAgainWillUseGoog;

  /// No description provided for @thisStateHasNoSavedRecordsSyncingItWillUseGoogleApiQuota.
  ///
  /// In en, this message translates to:
  /// **'This state has no saved records. Syncing it will use Google API quota.'**
  String get thisStateHasNoSavedRecordsSyncingItWillUseGoogleApiQuota;

  /// No description provided for @olderImportsHaveNoRecordedDateCheckTheExistingPlacesBeforeSyncingAgain.
  ///
  /// In en, this message translates to:
  /// **'Older imports have no recorded date. Check the existing places before syncing again.'**
  String
  get olderImportsHaveNoRecordedDateCheckTheExistingPlacesBeforeSyncingAgain;

  /// No description provided for @someOlderImportsHaveUnverifiedCountriesOrStatesTheseAreMarkedForReviewRepeatingTheFullSync.
  ///
  /// In en, this message translates to:
  /// **'Some older imports have unverified countries or states. These are marked for review; repeating the full sync will not repair them.'**
  String
  get someOlderImportsHaveUnverifiedCountriesOrStatesTheseAreMarkedForReviewRepeatingTheFullSync;

  /// No description provided for @showingSavedHistoryCloudHistoryIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Showing saved history; cloud history is unavailable.'**
  String get showingSavedHistoryCloudHistoryIsUnavailable;

  /// No description provided for @timestampSavedOnThisDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Timestamp saved on this device only.'**
  String get timestampSavedOnThisDeviceOnly;

  /// No description provided for @fetchSyncIsBlockedUntilTheCurrentGoogleAllowanceIsVerifiedWithAtLeast48RequestsRemainingSa.
  ///
  /// In en, this message translates to:
  /// **'Fetch & Sync is blocked until the current Google allowance is verified with at least 48 requests remaining. Saved IDs and schedules remain available.'**
  String
  get fetchSyncIsBlockedUntilTheCurrentGoogleAllowanceIsVerifiedWithAtLeast48RequestsRemainingSa;

  /// No description provided for @pendingSyncTapFetchAndSave.
  ///
  /// In en, this message translates to:
  /// **'Pending sync — tap Fetch and save'**
  String get pendingSyncTapFetchAndSave;

  /// No description provided for @fetchAndSaveThisPage.
  ///
  /// In en, this message translates to:
  /// **'Fetch and save this page'**
  String get fetchAndSaveThisPage;

  /// No description provided for @fetchSaveFailedValue.
  ///
  /// In en, this message translates to:
  /// **'Fetch/save failed: {arg0}'**
  String fetchSaveFailedValue(String arg0);

  /// No description provided for @fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching...'**
  String get fetching;

  /// No description provided for @loadingNames.
  ///
  /// In en, this message translates to:
  /// **'Loading names…'**
  String get loadingNames;

  /// No description provided for @loadsUpTo20NamesFromGoogleUsingTheCurrentAllowance.
  ///
  /// In en, this message translates to:
  /// **'Loads up to 20 names from Google using the current allowance.'**
  String get loadsUpTo20NamesFromGoogleUsingTheCurrentAllowance;

  /// No description provided for @previous20.
  ///
  /// In en, this message translates to:
  /// **'Previous 20'**
  String get previous20;

  /// No description provided for @next20.
  ///
  /// In en, this message translates to:
  /// **'Next 20'**
  String get next20;

  /// No description provided for @importStopped.
  ///
  /// In en, this message translates to:
  /// **'Import stopped'**
  String get importStopped;

  /// No description provided for @manuallyDiscoverGooglePlacesForTheSelectedStateSaveIdsAndAppCategoriesLoadCurrentDetailsWh.
  ///
  /// In en, this message translates to:
  /// **'Manually discover Google places for the selected state. Save IDs and app categories; load current details when needed.'**
  String
  get manuallyDiscoverGooglePlacesForTheSelectedStateSaveIdsAndAppCategoriesLoadCurrentDetailsWh;

  /// No description provided for @queryingTopPlacesInValue.
  ///
  /// In en, this message translates to:
  /// **'Querying top places in {arg0}…'**
  String queryingTopPlacesInValue(String arg0);

  /// No description provided for @searchingGoogleForValue.
  ///
  /// In en, this message translates to:
  /// **'Searching Google for {arg0}'**
  String searchingGoogleForValue(String arg0);

  /// No description provided for @clearValuePlaces.
  ///
  /// In en, this message translates to:
  /// **'Clear {arg0} Places?'**
  String clearValuePlaces(String arg0);

  /// No description provided for @thisWillDeleteAllCachedPlacesForValueFromTheSupabaseDatabase.
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached places for {arg0} from the Supabase database.'**
  String thisWillDeleteAllCachedPlacesForValueFromTheSupabaseDatabase(
    String arg0,
  );

  /// No description provided for @clearingPlacesForValue.
  ///
  /// In en, this message translates to:
  /// **'Clearing places for {arg0}...'**
  String clearingPlacesForValue(String arg0);

  /// No description provided for @deletingRecordsFromSupabase.
  ///
  /// In en, this message translates to:
  /// **'Deleting records from Supabase'**
  String get deletingRecordsFromSupabase;

  /// No description provided for @allCachedPlacesForValueRemoved.
  ///
  /// In en, this message translates to:
  /// **'All cached places for {arg0} removed'**
  String allCachedPlacesForValueRemoved(String arg0);

  /// No description provided for @errorDeletingPlaces.
  ///
  /// In en, this message translates to:
  /// **'Error deleting places'**
  String get errorDeletingPlaces;

  /// No description provided for @errorLoadingPlacesValue.
  ///
  /// In en, this message translates to:
  /// **'Error loading places: {arg0}'**
  String errorLoadingPlacesValue(String arg0);

  /// No description provided for @batchCacheRealPhotos.
  ///
  /// In en, this message translates to:
  /// **'Batch Cache Real Photos'**
  String get batchCacheRealPhotos;

  /// No description provided for @cacheTop30Photos.
  ///
  /// In en, this message translates to:
  /// **'Cache Top 30 Photos'**
  String get cacheTop30Photos;

  /// No description provided for @cachingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Caching photos…'**
  String get cachingPhotos;

  /// No description provided for @cachingRealPhotos0Value.
  ///
  /// In en, this message translates to:
  /// **'Caching real photos (0/{arg0})…'**
  String cachingRealPhotos0Value(String arg0);

  /// No description provided for @cachedValueOfValueInspectedValueTarget.
  ///
  /// In en, this message translates to:
  /// **'Cached {arg0} of {arg1} inspected ({arg2} target)…'**
  String cachedValueOfValueInspectedValueTarget(
    String arg0,
    String arg1,
    String arg2,
  );

  /// No description provided for @finishedValueRealPhotosCachedToSupabaseStorage.
  ///
  /// In en, this message translates to:
  /// **'Finished! {arg0} real photos cached to Supabase Storage.'**
  String finishedValueRealPhotosCachedToSupabaseStorage(String arg0);

  /// No description provided for @pausedPhotoCachingCachedValuePhotos.
  ///
  /// In en, this message translates to:
  /// **'Paused photo caching. Cached {arg0} photos.'**
  String pausedPhotoCachingCachedValuePhotos(String arg0);

  /// No description provided for @photoCachingFailedValue.
  ///
  /// In en, this message translates to:
  /// **'Photo caching failed: {arg0}'**
  String photoCachingFailedValue(String arg0);

  /// No description provided for @downloadsOfficialGooglePhotosForTopPlacesAndSavesThemToSupabaseStoragePlacesAlreadyCachedA.
  ///
  /// In en, this message translates to:
  /// **'Downloads official Google photos for top places and saves them to Supabase Storage. Places already cached are skipped automatically to conserve your API quota.'**
  String
  get downloadsOfficialGooglePhotosForTopPlacesAndSavesThemToSupabaseStoragePlacesAlreadyCachedA;

  /// No description provided for @autoSaveTop5Highlights.
  ///
  /// In en, this message translates to:
  /// **'Auto-Save Top 5 Highlights'**
  String get autoSaveTop5Highlights;

  /// No description provided for @savedValueTopHighlightsToYourList.
  ///
  /// In en, this message translates to:
  /// **'Saved {arg0} top highlights to your list!'**
  String savedValueTopHighlightsToYourList(String arg0);

  /// No description provided for @retrieve.
  ///
  /// In en, this message translates to:
  /// **'Retrieve'**
  String get retrieve;

  /// No description provided for @retrievedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Retrieved Places'**
  String get retrievedPlaces;

  /// No description provided for @noPlacesRetrievedYet.
  ///
  /// In en, this message translates to:
  /// **'No places retrieved yet.'**
  String get noPlacesRetrievedYet;

  /// No description provided for @liveGooglePlacesApiActiveForMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Live Google Places API active for Malaysia'**
  String get liveGooglePlacesApiActiveForMalaysia;

  /// No description provided for @rawJsonOutput.
  ///
  /// In en, this message translates to:
  /// **'Raw JSON Output'**
  String get rawJsonOutput;

  /// No description provided for @hideRawLogs.
  ///
  /// In en, this message translates to:
  /// **'Hide Raw Logs'**
  String get hideRawLogs;

  /// No description provided for @viewRawTerminalLogsValueLines.
  ///
  /// In en, this message translates to:
  /// **'View Raw Terminal Logs ({arg0} lines)'**
  String viewRawTerminalLogsValueLines(String arg0);

  /// No description provided for @selectADestinationInMalaysiaOrSimulateGpsPositions.
  ///
  /// In en, this message translates to:
  /// **'Select a destination in Malaysia or simulate GPS positions.'**
  String get selectADestinationInMalaysiaOrSimulateGpsPositions;

  /// No description provided for @mockDeviceCoordinatesInMalaysia.
  ///
  /// In en, this message translates to:
  /// **'Mock Device coordinates in Malaysia'**
  String get mockDeviceCoordinatesInMalaysia;

  /// No description provided for @detectedStateValue.
  ///
  /// In en, this message translates to:
  /// **'Detected state: {arg0}'**
  String detectedStateValue(String arg0);

  /// No description provided for @text13StatesKl.
  ///
  /// In en, this message translates to:
  /// **'13 States + KL'**
  String get text13StatesKl;

  /// No description provided for @simulateGps.
  ///
  /// In en, this message translates to:
  /// **'📍 Simulate GPS'**
  String get simulateGps;

  /// No description provided for @browseStates.
  ///
  /// In en, this message translates to:
  /// **'🗺️ Browse States'**
  String get browseStates;

  /// No description provided for @indoor2.
  ///
  /// In en, this message translates to:
  /// **'🏠 Indoor'**
  String get indoor2;

  /// No description provided for @indoor3.
  ///
  /// In en, this message translates to:
  /// **'🏢 Indoor'**
  String get indoor3;

  /// No description provided for @outdoor2.
  ///
  /// In en, this message translates to:
  /// **'☀️ Outdoor'**
  String get outdoor2;

  /// No description provided for @topRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get topRated;

  /// No description provided for @sights.
  ///
  /// In en, this message translates to:
  /// **'🏛️ Sights'**
  String get sights;

  /// No description provided for @nature2.
  ///
  /// In en, this message translates to:
  /// **'🌳 Nature'**
  String get nature2;

  /// No description provided for @food2.
  ///
  /// In en, this message translates to:
  /// **'🍔 Food'**
  String get food2;

  /// No description provided for @cafes.
  ///
  /// In en, this message translates to:
  /// **'☕ Cafes'**
  String get cafes;

  /// No description provided for @shops.
  ///
  /// In en, this message translates to:
  /// **'🛍️ Shops'**
  String get shops;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'👑 Admin'**
  String get admin;

  /// No description provided for @review2.
  ///
  /// In en, this message translates to:
  /// **'❓ Review'**
  String get review2;

  /// No description provided for @indoorValue.
  ///
  /// In en, this message translates to:
  /// **'🏛️ Indoor ({arg0})'**
  String indoorValue(String arg0);

  /// No description provided for @outdoorValue.
  ///
  /// In en, this message translates to:
  /// **'🏞️ Outdoor ({arg0})'**
  String outdoorValue(String arg0);

  /// No description provided for @valueUpdatedValueNeedReviewValueRemaining.
  ///
  /// In en, this message translates to:
  /// **'{arg0} updated · {arg1} need review · {arg2} remaining'**
  String valueUpdatedValueNeedReviewValueRemaining(
    String arg0,
    String arg1,
    String arg2,
  );

  /// No description provided for @uc100FlowTestingTools.
  ///
  /// In en, this message translates to:
  /// **'UC100 Flow Testing Tools'**
  String get uc100FlowTestingTools;

  /// No description provided for @uc200FlowTestingTools.
  ///
  /// In en, this message translates to:
  /// **'UC200 Flow Testing Tools'**
  String get uc200FlowTestingTools;

  /// No description provided for @uc300FlowTestingTools.
  ///
  /// In en, this message translates to:
  /// **'UC300 Flow Testing Tools'**
  String get uc300FlowTestingTools;

  /// No description provided for @quicklyTestMessagesM1M6AlternativeFlowsA1A3.
  ///
  /// In en, this message translates to:
  /// **'Quickly test messages M1–M6 & alternative flows A1–A3'**
  String get quicklyTestMessagesM1M6AlternativeFlowsA1A3;

  /// No description provided for @quicklyTestMessagesM1M6AlternativeFlowsA1A5.
  ///
  /// In en, this message translates to:
  /// **'Quickly test messages M1–M6 & alternative flows A1–A5'**
  String get quicklyTestMessagesM1M6AlternativeFlowsA1A5;

  /// No description provided for @quicklyTestMessagesM1M8AlternativeFlowsA1A7.
  ///
  /// In en, this message translates to:
  /// **'Quickly test messages M1–M8 & alternative flows A1–A7'**
  String get quicklyTestMessagesM1M8AlternativeFlowsA1A7;

  /// No description provided for @fillValidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Fill Valid Credentials'**
  String get fillValidCredentials;

  /// No description provided for @fillValidForm.
  ///
  /// In en, this message translates to:
  /// **'Fill Valid Form'**
  String get fillValidForm;

  /// No description provided for @testA1EmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Test A1 (Empty Fields)'**
  String get testA1EmptyFields;

  /// No description provided for @testA2BadDestination.
  ///
  /// In en, this message translates to:
  /// **'Test A2 (Bad Destination)'**
  String get testA2BadDestination;

  /// No description provided for @testA2InvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Test A2 (Invalid Email)'**
  String get testA2InvalidEmail;

  /// No description provided for @testA3InvalidDays.
  ///
  /// In en, this message translates to:
  /// **'Test A3 (Invalid Days)'**
  String get testA3InvalidDays;

  /// No description provided for @testA3NoAccount.
  ///
  /// In en, this message translates to:
  /// **'Test A3 (No Account)'**
  String get testA3NoAccount;

  /// No description provided for @testA3WeakPwd.
  ///
  /// In en, this message translates to:
  /// **'Test A3 (Weak Pwd)'**
  String get testA3WeakPwd;

  /// No description provided for @testA3WrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Test A3 (Wrong Password)'**
  String get testA3WrongPassword;

  /// No description provided for @testA4BadTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Test A4 (Bad Time Range)'**
  String get testA4BadTimeRange;

  /// No description provided for @testA4Mismatch.
  ///
  /// In en, this message translates to:
  /// **'Test A4 (Mismatch)'**
  String get testA4Mismatch;

  /// No description provided for @testA5EmailExists.
  ///
  /// In en, this message translates to:
  /// **'Test A5 (Email Exists)'**
  String get testA5EmailExists;

  /// No description provided for @testA5NoInterests.
  ///
  /// In en, this message translates to:
  /// **'Test A5 (No Interests)'**
  String get testA5NoInterests;

  /// No description provided for @testA7Transit.
  ///
  /// In en, this message translates to:
  /// **'Test A7 (Transit)'**
  String get testA7Transit;

  /// No description provided for @recognizeSendsThisPhotoToGoogleVisionThroughOurSecureServiceOnlyResultTextIsSavedInYourLoc.
  ///
  /// In en, this message translates to:
  /// **'Recognize sends this photo to Google Vision through our secure service. Only result text is saved in your local history; the photo is not stored by the app.'**
  String
  get recognizeSendsThisPhotoToGoogleVisionThroughOurSecureServiceOnlyResultTextIsSavedInYourLoc;

  /// No description provided for @skipPlaceValueAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Skip place ({arg0}) and continue'**
  String skipPlaceValueAndContinue(String arg0);

  /// No description provided for @valueTopPicks.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Top Picks'**
  String valueTopPicks(String arg0);

  /// No description provided for @valueCustomSchedule.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Custom Schedule'**
  String valueCustomSchedule(String arg0);

  /// No description provided for @valueSmartSchedule.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Smart Schedule'**
  String valueSmartSchedule(String arg0);

  /// No description provided for @valueDayValueHighlights.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Day {arg1} Highlights'**
  String valueDayValueHighlights(String arg0, String arg1);

  /// No description provided for @valueYourScheduledTimeRemainsSaved.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Your scheduled time remains saved.'**
  String valueYourScheduledTimeRemainsSaved(String arg0);

  /// No description provided for @valueKmValueMinvalue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} km • {arg1} min{arg2}'**
  String valueKmValueMinvalue(String arg0, String arg1, String arg2);

  /// No description provided for @valueLastSyncedValue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} — last synced {arg1}'**
  String valueLastSyncedValue(String arg0, String arg1);

  /// No description provided for @valueSyncTimeNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'{arg0} — sync time not recorded'**
  String valueSyncTimeNotRecorded(String arg0);

  /// No description provided for @valueValueSavedInValue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} {arg1} saved in {arg2}'**
  String valueValueSavedInValue(String arg0, String arg1, String arg2);

  /// No description provided for @valueValuePlacesFoundValueSearchRequestsInThatSyncReviewTheExistingPlacesBeforeUsingMoreAp.
  ///
  /// In en, this message translates to:
  /// **'{arg0}\n{arg1} places found · {arg2} search requests in that sync.\nReview the existing places before using more API quota.'**
  String
  valueValuePlacesFoundValueSearchRequestsInThatSyncReviewTheExistingPlacesBeforeUsingMoreAp(
    String arg0,
    String arg1,
    String arg2,
  );

  /// No description provided for @valueValueOfValue.
  ///
  /// In en, this message translates to:
  /// **'{arg0}–{arg1} of {arg2}'**
  String valueValueOfValue(String arg0, String arg1, String arg2);

  /// No description provided for @categoryValueLocationValueValue.
  ///
  /// In en, this message translates to:
  /// **'Category: {arg0}\nLocation: ({arg1}, {arg2})'**
  String categoryValueLocationValueValue(String arg0, String arg1, String arg2);

  /// No description provided for @alreadyRanItTapToRefreshDismiss.
  ///
  /// In en, this message translates to:
  /// **'Already Ran It? Tap to Refresh & Dismiss'**
  String get alreadyRanItTapToRefreshDismiss;

  /// No description provided for @demoInfoTapLogInToSignInWithPreFilledTestUser.
  ///
  /// In en, this message translates to:
  /// **'Demo Info: Tap Log In to sign in with pre-filled test user.'**
  String get demoInfoTapLogInToSignInWithPreFilledTestUser;

  /// No description provided for @missingReviewCountColumnInSupabase.
  ///
  /// In en, this message translates to:
  /// **'Missing Review Count Column in Supabase'**
  String get missingReviewCountColumnInSupabase;

  /// No description provided for @placesInValueAreCurrentlySavedWithoutReviewCountsToRankByPopularityScoreAndDisplayReviewsE.
  ///
  /// In en, this message translates to:
  /// **'Places in {arg0} are currently saved without review counts. To rank by Popularity Score and display reviews (e.g. 12.4k), run this in Supabase SQL Editor and tap Fetch & Sync again:'**
  String
  placesInValueAreCurrentlySavedWithoutReviewCountsToRankByPopularityScoreAndDisplayReviewsE(
    String arg0,
  );

  /// No description provided for @sqlCommandCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'SQL command copied to clipboard!'**
  String get sqlCommandCopiedToClipboard;

  /// No description provided for @supabaseRowLevelSecurityRlsLocked.
  ///
  /// In en, this message translates to:
  /// **'Supabase Row-Level Security (RLS) Locked'**
  String get supabaseRowLevelSecurityRlsLocked;

  /// No description provided for @toAllowSavingPlacesRunThis1LineCommandInYourSupabaseSqlEditor.
  ///
  /// In en, this message translates to:
  /// **'To allow saving places, run this 1-line command in your Supabase SQL Editor:'**
  String get toAllowSavingPlacesRunThis1LineCommandInYourSupabaseSqlEditor;

  /// No description provided for @text8Am10Pm.
  ///
  /// In en, this message translates to:
  /// **'8 AM – 10 PM'**
  String get text8Am10Pm;

  /// No description provided for @text9Am6Pm.
  ///
  /// In en, this message translates to:
  /// **'9 AM – 6 PM'**
  String get text9Am6Pm;

  /// No description provided for @text9Am9Pm.
  ///
  /// In en, this message translates to:
  /// **'9 AM – 9 PM'**
  String get text9Am9Pm;

  /// No description provided for @estimatedForValueDaysPerPerson.
  ///
  /// In en, this message translates to:
  /// **'Estimated for {arg0} days · per person'**
  String estimatedForValueDaysPerPerson(String arg0);

  /// No description provided for @here.
  ///
  /// In en, this message translates to:
  /// **'here'**
  String get here;

  /// No description provided for @thisArea.
  ///
  /// In en, this message translates to:
  /// **'this area'**
  String get thisArea;

  /// No description provided for @forecastUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Forecast unavailable'**
  String get forecastUnavailable;

  /// No description provided for @outdoorFriendly.
  ///
  /// In en, this message translates to:
  /// **'Outdoor Friendly'**
  String get outdoorFriendly;

  /// No description provided for @highRainRiskIndoorRecommended.
  ///
  /// In en, this message translates to:
  /// **'High Rain Risk (Indoor Recommended)'**
  String get highRainRiskIndoorRecommended;

  /// No description provided for @scatteredShowersCarryUmbrella.
  ///
  /// In en, this message translates to:
  /// **'Scattered Showers (Carry Umbrella)'**
  String get scatteredShowersCarryUmbrella;

  /// No description provided for @partlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly Cloudy'**
  String get partlyCloudy;

  /// No description provided for @noAdditionalPlacesFitThisDayTryFewerDaysOrWiderDailyHours.
  ///
  /// In en, this message translates to:
  /// **'No additional places fit this day. Try fewer days or wider daily hours.'**
  String get noAdditionalPlacesFitThisDayTryFewerDaysOrWiderDailyHours;

  /// No description provided for @forecastUnavailableForThisDateWeatherFilteringWasNotApplied.
  ///
  /// In en, this message translates to:
  /// **'Forecast unavailable for this date; weather filtering was not applied.'**
  String get forecastUnavailableForThisDateWeatherFilteringWasNotApplied;

  /// No description provided for @travelTimesAreDistanceBasedEstimates.
  ///
  /// In en, this message translates to:
  /// **'Travel times are distance-based estimates.'**
  String get travelTimesAreDistanceBasedEstimates;

  /// No description provided for @someOpeningHoursAreUnverifiedConfirmBeforeVisiting.
  ///
  /// In en, this message translates to:
  /// **'Some opening hours are unverified. Confirm before visiting.'**
  String get someOpeningHoursAreUnverifiedConfirmBeforeVisiting;

  /// No description provided for @costsArePlanningEstimatesExcludingAccommodationAndTravelToTheFirstStop.
  ///
  /// In en, this message translates to:
  /// **'Costs are planning estimates, excluding accommodation and travel to the first stop.'**
  String
  get costsArePlanningEstimatesExcludingAccommodationAndTravelToTheFirstStop;

  /// No description provided for @itinerarySavedSuccessfullyToYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Itinerary saved successfully to your profile!'**
  String get itinerarySavedSuccessfullyToYourProfile;

  /// No description provided for @savedOnThisDeviceCloudSyncIsPending.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. Cloud sync is pending.'**
  String get savedOnThisDeviceCloudSyncIsPending;

  /// No description provided for @unableToSaveItineraryOnThisDevicePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Unable to save itinerary on this device. Please try again.'**
  String get unableToSaveItineraryOnThisDevicePleaseTryAgain;

  /// No description provided for @savedItineraryLoadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved itinerary loaded successfully.'**
  String get savedItineraryLoadedSuccessfully;

  /// No description provided for @youHaveNoSavedTripsYetTapPlanATripToGenerateYourFirstItinerary.
  ///
  /// In en, this message translates to:
  /// **'You have no saved trips yet. Tap \"Plan a Trip\" to generate your first itinerary!'**
  String get youHaveNoSavedTripsYetTapPlanATripToGenerateYourFirstItinerary;

  /// No description provided for @unableToLoadSavedTripsPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Unable to load saved trips. Please try again.'**
  String get unableToLoadSavedTripsPleaseTryAgain;

  /// No description provided for @savedTripCouldNotBeFound.
  ///
  /// In en, this message translates to:
  /// **'Saved trip could not be found.'**
  String get savedTripCouldNotBeFound;

  /// No description provided for @allSavedPlacesUpdated.
  ///
  /// In en, this message translates to:
  /// **'All saved places updated.'**
  String get allSavedPlacesUpdated;

  /// No description provided for @passFinishedWithIssuesRetryToReviewFailedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Pass finished with issues. Retry to review failed places.'**
  String get passFinishedWithIssuesRetryToReviewFailedPlaces;

  /// No description provided for @pausedResumeToContinueFromTheNextPlace.
  ///
  /// In en, this message translates to:
  /// **'Paused. Resume to continue from the next place.'**
  String get pausedResumeToContinueFromTheNextPlace;

  /// No description provided for @unableToSaveProgressStopAndRetryBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Unable to save progress. Stop and retry before continuing.'**
  String get unableToSaveProgressStopAndRetryBeforeContinuing;

  /// No description provided for @skippedByAdministratorExistingDataPreserved.
  ///
  /// In en, this message translates to:
  /// **'Skipped by administrator; existing data preserved.'**
  String get skippedByAdministratorExistingDataPreserved;

  /// No description provided for @skippedValueResumeToContinueUpdatingPlacesInValue.
  ///
  /// In en, this message translates to:
  /// **'Skipped {arg0}. Resume to continue updating places in {arg1}.'**
  String skippedValueResumeToContinueUpdatingPlacesInValue(
    String arg0,
    String arg1,
  );

  /// No description provided for @googlePlaceUnavailableValueExistingDataPreserved.
  ///
  /// In en, this message translates to:
  /// **'Google place unavailable ({arg0}); existing data preserved.'**
  String googlePlaceUnavailableValueExistingDataPreserved(String arg0);

  /// No description provided for @valueResumeToRetryValue.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Resume to retry {arg1}.'**
  String valueResumeToRetryValue(String arg0, String arg1);

  /// No description provided for @thisStateIsAlreadyUpdating.
  ///
  /// In en, this message translates to:
  /// **'This state is already updating.'**
  String get thisStateIsAlreadyUpdating;

  /// No description provided for @stoppedBeforeRefreshStarted.
  ///
  /// In en, this message translates to:
  /// **'Stopped before refresh started.'**
  String get stoppedBeforeRefreshStarted;

  /// No description provided for @returnedValueStateAcceptedValueUniqueValueWrongStateValueInvalidValueCategoryReviewValue.
  ///
  /// In en, this message translates to:
  /// **'Returned {arg0} · state accepted {arg1} · unique {arg2} · wrong state {arg3} · invalid {arg4} · category review {arg5}'**
  String
  returnedValueStateAcceptedValueUniqueValueWrongStateValueInvalidValueCategoryReviewValue(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  );

  /// No description provided for @landmark.
  ///
  /// In en, this message translates to:
  /// **'landmark'**
  String get landmark;

  /// No description provided for @dish.
  ///
  /// In en, this message translates to:
  /// **'dish'**
  String get dish;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @pleaseEnterATravelQuestionOrTapASuggestion.
  ///
  /// In en, this message translates to:
  /// **'Please enter a travel question or tap a suggestion.'**
  String get pleaseEnterATravelQuestionOrTapASuggestion;

  /// No description provided for @promptIsTooShortPleaseBeMoreSpecific.
  ///
  /// In en, this message translates to:
  /// **'Prompt is too short. Please be more specific.'**
  String get promptIsTooShortPleaseBeMoreSpecific;

  /// No description provided for @activeSmartItinerary.
  ///
  /// In en, this message translates to:
  /// **'Active Smart Itinerary'**
  String get activeSmartItinerary;

  /// No description provided for @text3DaysPersonalizedSchedule.
  ///
  /// In en, this message translates to:
  /// **'3 days personalized schedule'**
  String get text3DaysPersonalizedSchedule;

  /// No description provided for @text5DaysCulturalSchedule.
  ///
  /// In en, this message translates to:
  /// **'5 days cultural schedule'**
  String get text5DaysCulturalSchedule;

  /// No description provided for @text7DaysIslandSchedule.
  ///
  /// In en, this message translates to:
  /// **'7 days island schedule'**
  String get text7DaysIslandSchedule;

  /// No description provided for @heritageStreetArtRoute.
  ///
  /// In en, this message translates to:
  /// **'Heritage & Street Art Route'**
  String get heritageStreetArtRoute;

  /// No description provided for @beachNatureExcursion.
  ///
  /// In en, this message translates to:
  /// **'Beach & Nature Excursion'**
  String get beachNatureExcursion;

  /// No description provided for @estimatedFor1DayPerPerson.
  ///
  /// In en, this message translates to:
  /// **'Estimated for 1 day · per person'**
  String get estimatedFor1DayPerPerson;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @identifyMalaysianLandmarksAndLocalDishes.
  ///
  /// In en, this message translates to:
  /// **'Identify Malaysian landmarks and local dishes'**
  String get identifyMalaysianLandmarksAndLocalDishes;

  /// No description provided for @scanningPhoto.
  ///
  /// In en, this message translates to:
  /// **'Scanning photo…'**
  String get scanningPhoto;

  /// No description provided for @cancelRecognition.
  ///
  /// In en, this message translates to:
  /// **'Cancel recognition'**
  String get cancelRecognition;

  /// No description provided for @howToTakeAGoodPhoto.
  ///
  /// In en, this message translates to:
  /// **'How to take a good photo'**
  String get howToTakeAGoodPhoto;

  /// No description provided for @frameOneDishOrLandmarkSoItsEasyToIdentify.
  ///
  /// In en, this message translates to:
  /// **'Frame one dish or landmark so it’s easy to identify.'**
  String get frameOneDishOrLandmarkSoItsEasyToIdentify;

  /// No description provided for @tipFoodCategory.
  ///
  /// In en, this message translates to:
  /// **'01  FOOD'**
  String get tipFoodCategory;

  /// No description provided for @centerTheSubject.
  ///
  /// In en, this message translates to:
  /// **'Center the subject'**
  String get centerTheSubject;

  /// No description provided for @shootFromAboveAndLeaveALittleSpaceAroundTheWholePlate.
  ///
  /// In en, this message translates to:
  /// **'Shoot from above and leave a little space around the whole plate.'**
  String get shootFromAboveAndLeaveALittleSpaceAroundTheWholePlate;

  /// No description provided for @tipLandmarkCategory.
  ///
  /// In en, this message translates to:
  /// **'02  LANDMARK'**
  String get tipLandmarkCategory;

  /// No description provided for @includeTheKeyFeature.
  ///
  /// In en, this message translates to:
  /// **'Include the key feature'**
  String get includeTheKeyFeature;

  /// No description provided for @stepBackToFitTheStatueAndStepsWaitForAClearView.
  ///
  /// In en, this message translates to:
  /// **'Step back to fit the statue and steps. Wait for a clear view.'**
  String get stepBackToFitTheStatueAndStepsWaitForAClearView;

  /// No description provided for @aPlateOfNasiLemakCenteredInTheFrame.
  ///
  /// In en, this message translates to:
  /// **'A plate of nasi lemak centered in the frame'**
  String get aPlateOfNasiLemakCenteredInTheFrame;

  /// No description provided for @theGoldenStatueAndStepsAtBatuCaves.
  ///
  /// In en, this message translates to:
  /// **'The golden statue and steps at Batu Caves'**
  String get theGoldenStatueAndStepsAtBatuCaves;

  /// No description provided for @checkTheLightAndFocus.
  ///
  /// In en, this message translates to:
  /// **'Check the light and focus'**
  String get checkTheLightAndFocus;

  /// No description provided for @useSoftLightFromTheFrontOrSideTapTheSubjectToFocusAndHoldYourPhoneSteady.
  ///
  /// In en, this message translates to:
  /// **'Use soft light from the front or side. Tap the subject to focus and hold your phone steady.'**
  String
  get useSoftLightFromTheFrontOrSideTapTheSubjectToFocusAndHoldYourPhoneSteady;

  /// No description provided for @scanHistoryPhotoPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Selected photos are sent to Google for recognition. The photo and result are saved in History on this device.'**
  String get scanHistoryPhotoPrivacy;

  /// No description provided for @planPersonalize.
  ///
  /// In en, this message translates to:
  /// **'Customize trip preferences'**
  String get planPersonalize;

  /// No description provided for @planArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival time'**
  String get planArrival;

  /// No description provided for @planDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure time'**
  String get planDeparture;

  /// No description provided for @planAirport.
  ///
  /// In en, this message translates to:
  /// **'Airport departure · allow 3 hours'**
  String get planAirport;

  /// No description provided for @planAccommodation.
  ///
  /// In en, this message translates to:
  /// **'Daily starting point'**
  String get planAccommodation;

  /// No description provided for @planOptionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Optional trip details'**
  String get planOptionalDetails;

  /// No description provided for @planLocalTime.
  ///
  /// In en, this message translates to:
  /// **'Times are local to your destination.'**
  String get planLocalTime;

  /// No description provided for @planSetArrival.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get planSetArrival;

  /// No description provided for @planSetDeparture.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get planSetDeparture;

  /// No description provided for @planChooseStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get planChooseStartingPoint;

  /// No description provided for @planUndecided.
  ///
  /// In en, this message translates to:
  /// **'Undecided'**
  String get planUndecided;

  /// No description provided for @planTravelers.
  ///
  /// In en, this message translates to:
  /// **'Traveler type'**
  String get planTravelers;

  /// No description provided for @planPace.
  ///
  /// In en, this message translates to:
  /// **'Sightseeing pace'**
  String get planPace;

  /// No description provided for @planDiet.
  ///
  /// In en, this message translates to:
  /// **'Dining preference'**
  String get planDiet;

  /// No description provided for @planMustVisit.
  ///
  /// In en, this message translates to:
  /// **'Must-visit attractions (up to 3)'**
  String get planMustVisit;

  /// No description provided for @planPresets.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get planPresets;

  /// No description provided for @planClassic.
  ///
  /// In en, this message translates to:
  /// **'First-time explorer · culture and KL landmarks'**
  String get planClassic;

  /// No description provided for @planFood.
  ///
  /// In en, this message translates to:
  /// **'Malaysian food explorer · relaxed and street food'**
  String get planFood;

  /// No description provided for @planFamily.
  ///
  /// In en, this message translates to:
  /// **'Family getaway · relaxed and family activities'**
  String get planFamily;

  /// No description provided for @planSolo.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get planSolo;

  /// No description provided for @planCouple.
  ///
  /// In en, this message translates to:
  /// **'Couple'**
  String get planCouple;

  /// No description provided for @planFamilyType.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get planFamilyType;

  /// No description provided for @planFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get planFriends;

  /// No description provided for @planSeniors.
  ///
  /// In en, this message translates to:
  /// **'Seniors'**
  String get planSeniors;

  /// No description provided for @planRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed (2–3 visits/day)'**
  String get planRelaxed;

  /// No description provided for @planBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced (3–4 visits/day)'**
  String get planBalanced;

  /// No description provided for @planPacked.
  ///
  /// In en, this message translates to:
  /// **'Packed (5+ visits/day)'**
  String get planPacked;

  /// No description provided for @planNoRestriction.
  ///
  /// In en, this message translates to:
  /// **'No restriction'**
  String get planNoRestriction;

  /// No description provided for @planHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal-friendly'**
  String get planHalal;

  /// No description provided for @planVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get planVegetarian;

  /// No description provided for @planStreetFood.
  ///
  /// In en, this message translates to:
  /// **'Street food enthusiast'**
  String get planStreetFood;

  /// No description provided for @planRail.
  ///
  /// In en, this message translates to:
  /// **'Also open to MRT / LRT'**
  String get planRail;

  /// No description provided for @planWalk.
  ///
  /// In en, this message translates to:
  /// **'Also open to walking'**
  String get planWalk;

  /// No description provided for @planEditPreferences.
  ///
  /// In en, this message translates to:
  /// **'Edit preferences'**
  String get planEditPreferences;

  /// No description provided for @planSmartFill.
  ///
  /// In en, this message translates to:
  /// **'Smart Fill'**
  String get planSmartFill;

  /// No description provided for @planDescribeTrip.
  ///
  /// In en, this message translates to:
  /// **'Describe the trip you want'**
  String get planDescribeTrip;

  /// No description provided for @planSuggest.
  ///
  /// In en, this message translates to:
  /// **'Suggest preferences'**
  String get planSuggest;

  /// No description provided for @planFillNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No supported preferences found. You can fill in the form below.'**
  String get planFillNoMatch;

  /// No description provided for @planFillLocal.
  ///
  /// In en, this message translates to:
  /// **'Local suggestions applied. Review your preferences below.'**
  String get planFillLocal;

  /// No description provided for @planFillReview.
  ///
  /// In en, this message translates to:
  /// **'Gemini suggestions applied. Review your preferences below.'**
  String get planFillReview;

  /// No description provided for @planHailing.
  ///
  /// In en, this message translates to:
  /// **'Grab / E-hailing'**
  String get planHailing;

  /// No description provided for @planSearchOnline.
  ///
  /// In en, this message translates to:
  /// **'Search online with Google Places'**
  String get planSearchOnline;

  /// No description provided for @planNoPlaces.
  ///
  /// In en, this message translates to:
  /// **'No matching places. Try another search.'**
  String get planNoPlaces;

  /// No description provided for @planAirportTransfer.
  ///
  /// In en, this message translates to:
  /// **'Estimated transfer time to the airport'**
  String get planAirportTransfer;

  /// No description provided for @planBasics.
  ///
  /// In en, this message translates to:
  /// **'Trip basics'**
  String get planBasics;

  /// No description provided for @planWhoPace.
  ///
  /// In en, this message translates to:
  /// **'Who & pace'**
  String get planWhoPace;

  /// No description provided for @planBudgetDining.
  ///
  /// In en, this message translates to:
  /// **'Budget & dining'**
  String get planBudgetDining;

  /// No description provided for @planHighlightsInterests.
  ///
  /// In en, this message translates to:
  /// **'Highlights & interests'**
  String get planHighlightsInterests;

  /// No description provided for @planHalalBranchNote.
  ///
  /// In en, this message translates to:
  /// **'Optional dining stop. Nando’s Malaysia reports JAKIM certification. Check the branch’s current status before visiting.'**
  String get planHalalBranchNote;

  /// No description provided for @planHalalDirectoryNote.
  ///
  /// In en, this message translates to:
  /// **'Check current certification for a specific food premise in JAKIM’s directory.'**
  String get planHalalDirectoryNote;

  /// No description provided for @planVegetarianBranchNote.
  ///
  /// In en, this message translates to:
  /// **'Optional dining stop. The restaurant publishes its vegetarian menu and address.'**
  String get planVegetarianBranchNote;

  /// No description provided for @planRestaurantSource.
  ///
  /// In en, this message translates to:
  /// **'Restaurant website'**
  String get planRestaurantSource;

  /// No description provided for @planVerifyHalal.
  ///
  /// In en, this message translates to:
  /// **'Check JAKIM directory'**
  String get planVerifyHalal;

  /// No description provided for @planContinueWho.
  ///
  /// In en, this message translates to:
  /// **'Continue to traveler & pace'**
  String get planContinueWho;

  /// Helper hint above step advance buttons indicating to tap to proceed
  ///
  /// In en, this message translates to:
  /// **'Tap below to proceed to the next step'**
  String get planTapToProceed;

  /// No description provided for @planUnlockDates.
  ///
  /// In en, this message translates to:
  /// **'Select travel dates above to continue'**
  String get planUnlockDates;

  /// No description provided for @planUnlockBasics.
  ///
  /// In en, this message translates to:
  /// **'Confirm your trip basics above first'**
  String get planUnlockBasics;

  /// No description provided for @planUnlockHours.
  ///
  /// In en, this message translates to:
  /// **'Set valid daily sightseeing hours above'**
  String get planUnlockHours;

  /// No description provided for @planUnlockMode.
  ///
  /// In en, this message translates to:
  /// **'Select how you will get around above'**
  String get planUnlockMode;

  /// No description provided for @planUnlockBudget.
  ///
  /// In en, this message translates to:
  /// **'Choose a daily budget above to continue'**
  String get planUnlockBudget;

  /// No description provided for @planUnlockInterests.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one interest above to continue'**
  String get planUnlockInterests;

  /// No description provided for @planContinueHours.
  ///
  /// In en, this message translates to:
  /// **'Continue to daily hours'**
  String get planContinueHours;

  /// No description provided for @planContinueBudget.
  ///
  /// In en, this message translates to:
  /// **'Continue to budget & dining'**
  String get planContinueBudget;

  /// No description provided for @planLogisticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Add times and a starting point to help plan your days. All fields are optional.'**
  String get planLogisticsHelp;

  /// No description provided for @planContinueHighlights.
  ///
  /// In en, this message translates to:
  /// **'Continue to highlights & interests'**
  String get planContinueHighlights;

  /// No description provided for @profileTravelPreferences.
  ///
  /// In en, this message translates to:
  /// **'Travel Preferences'**
  String get profileTravelPreferences;

  /// No description provided for @profilePace.
  ///
  /// In en, this message translates to:
  /// **'Travel Pace'**
  String get profilePace;

  /// No description provided for @profileModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get profileModerate;

  /// No description provided for @profileFastPaced.
  ///
  /// In en, this message translates to:
  /// **'Fast-paced'**
  String get profileFastPaced;

  /// No description provided for @profileBudgetTier.
  ///
  /// In en, this message translates to:
  /// **'Budget Tier'**
  String get profileBudgetTier;

  /// No description provided for @profileBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get profileBudget;

  /// No description provided for @profileLuxury.
  ///
  /// In en, this message translates to:
  /// **'Luxury'**
  String get profileLuxury;

  /// No description provided for @profileDiet.
  ///
  /// In en, this message translates to:
  /// **'Dietary Requirement'**
  String get profileDiet;

  /// No description provided for @profileNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get profileNone;

  /// No description provided for @profileHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal Certified'**
  String get profileHalal;

  /// No description provided for @profileVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get profileVegetarian;

  /// No description provided for @profileEditPreferences.
  ///
  /// In en, this message translates to:
  /// **'Edit travel preferences'**
  String get profileEditPreferences;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit;

  /// No description provided for @profilePending.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. Cloud sync is pending.'**
  String get profilePending;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save on this device. Try again.'**
  String get profileSaveFailed;

  /// No description provided for @profileRegions.
  ///
  /// In en, this message translates to:
  /// **'States & territories'**
  String get profileRegions;

  /// No description provided for @profileRegionsVisited.
  ///
  /// In en, this message translates to:
  /// **'States and Territories Visited'**
  String get profileRegionsVisited;

  /// No description provided for @profileCoverage.
  ///
  /// In en, this message translates to:
  /// **'Malaysia has 13 states and 3 federal territories. Coverage counts recorded visits with a verified location.'**
  String get profileCoverage;

  /// No description provided for @profileNoRegions.
  ///
  /// In en, this message translates to:
  /// **'No recorded visits have a confirmed state or territory yet.'**
  String get profileNoRegions;

  /// No description provided for @profileFootprint.
  ///
  /// In en, this message translates to:
  /// **'Travel Footprint'**
  String get profileFootprint;

  /// No description provided for @profileNoVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits recorded for your saved trips yet. Mark a stop as visited in Today’s Plan to see it here.'**
  String get profileNoVisits;

  /// No description provided for @profileCurrency.
  ///
  /// In en, this message translates to:
  /// **'Preferred Currency'**
  String get profileCurrency;

  /// No description provided for @profileMyr.
  ///
  /// In en, this message translates to:
  /// **'Malaysian Ringgit'**
  String get profileMyr;

  /// No description provided for @profileSgd.
  ///
  /// In en, this message translates to:
  /// **'Singapore Dollar'**
  String get profileSgd;

  /// No description provided for @profileUsd.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get profileUsd;

  /// No description provided for @profileCny.
  ///
  /// In en, this message translates to:
  /// **'Chinese Yuan'**
  String get profileCny;

  /// No description provided for @profileEur.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get profileEur;

  /// No description provided for @profileHotlines.
  ///
  /// In en, this message translates to:
  /// **'Tourist Emergency Hotlines'**
  String get profileHotlines;

  /// No description provided for @profileHotlinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency numbers in Malaysia'**
  String get profileHotlinesSubtitle;

  /// No description provided for @profilePoliceAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Police & Ambulance'**
  String get profilePoliceAmbulance;

  /// No description provided for @profilePoliceAmbulanceInfo.
  ///
  /// In en, this message translates to:
  /// **'Malaysia’s national emergency number.'**
  String get profilePoliceAmbulanceInfo;

  /// No description provided for @profileMobileEmergency.
  ///
  /// In en, this message translates to:
  /// **'Mobile Emergency'**
  String get profileMobileEmergency;

  /// No description provided for @profileMobileEmergencyInfo.
  ///
  /// In en, this message translates to:
  /// **'Alternate emergency number from a mobile phone.'**
  String get profileMobileEmergencyInfo;

  /// No description provided for @profileTouristPolice.
  ///
  /// In en, this message translates to:
  /// **'MaTiC Tourist Police Station'**
  String get profileTouristPolice;

  /// No description provided for @profileTouristPoliceInfo.
  ///
  /// In en, this message translates to:
  /// **'Kuala Lumpur station contact for tourist police reports and assistance.'**
  String get profileTouristPoliceInfo;

  /// No description provided for @profileCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get profileCall;

  /// No description provided for @profileDialerError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone dialer.'**
  String get profileDialerError;

  /// No description provided for @profileAdminSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign out and sign in with an administrator account to access the hub.'**
  String get profileAdminSignIn;

  /// No description provided for @notificationMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationMarkAllRead;

  /// No description provided for @notificationEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get notificationEmptyTitle;

  /// No description provided for @notificationEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Upcoming trip reminders and comments on your posts will appear here.'**
  String get notificationEmptyBody;

  /// No description provided for @notificationTripReminder.
  ///
  /// In en, this message translates to:
  /// **'Trip starting soon'**
  String get notificationTripReminder;

  /// No description provided for @notificationCommunityComment.
  ///
  /// In en, this message translates to:
  /// **'New comment'**
  String get notificationCommunityComment;

  /// No description provided for @notificationTripMessage.
  ///
  /// In en, this message translates to:
  /// **'{title} in {destination} starts on {date}.'**
  String notificationTripMessage(Object title, Object destination, Object date);

  /// No description provided for @notificationCommentMessage.
  ///
  /// In en, this message translates to:
  /// **'Someone commented: “{comment}”'**
  String notificationCommentMessage(Object comment);

  /// No description provided for @notificationViewTrip.
  ///
  /// In en, this message translates to:
  /// **'View trip'**
  String get notificationViewTrip;

  /// No description provided for @notificationViewPost.
  ///
  /// In en, this message translates to:
  /// **'View post'**
  String get notificationViewPost;

  /// No description provided for @notificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This trip or post is no longer available.'**
  String get notificationUnavailable;

  /// No description provided for @offlineEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Save without route check?'**
  String get offlineEditTitle;

  /// No description provided for @offlineRemovalWarning.
  ///
  /// In en, this message translates to:
  /// **'Place locations are unavailable. The remaining stop times will be kept, but travel time, distance and opening hours cannot be verified. Check the route when online.'**
  String get offlineRemovalWarning;

  /// No description provided for @offlineSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get offlineSaveAnyway;

  /// No description provided for @dietaryVerificationNotice.
  ///
  /// In en, this message translates to:
  /// **'Dietary suitability is not verified automatically. Recognized restaurants are excluded from the schedule; other places may still serve food. Check directly before visiting.'**
  String get dietaryVerificationNotice;

  /// No description provided for @offlineRemovalRetainsTimes.
  ///
  /// In en, this message translates to:
  /// **'Stop removed. Remaining times are unchanged until locations are available.'**
  String get offlineRemovalRetainsTimes;

  /// No description provided for @savedRouteNeedsVerification.
  ///
  /// In en, this message translates to:
  /// **'Some place locations are unavailable. Route times and distance may be out of date. Refresh the place details and review the route when online.'**
  String get savedRouteNeedsVerification;

  /// No description provided for @offlineReorderNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable. The order will need checking when online.'**
  String get offlineReorderNeedsReview;

  /// No description provided for @offlineReorderWarning.
  ///
  /// In en, this message translates to:
  /// **'The existing time slots will be assigned to the new order. Travel times, visit lengths and opening hours cannot be verified. Review the route and schedule when online.'**
  String get offlineReorderWarning;

  /// No description provided for @googleRouteReviewReminder.
  ///
  /// In en, this message translates to:
  /// **'Review the route and opening hours before traveling, especially after offline edits.'**
  String get googleRouteReviewReminder;

  /// No description provided for @todayPlan.
  ///
  /// In en, this message translates to:
  /// **'Today’s plan'**
  String get todayPlan;

  /// No description provided for @todayPlanEndPrompt.
  ///
  /// In en, this message translates to:
  /// **'End today’s trip?'**
  String get todayPlanEndPrompt;

  /// No description provided for @todayPlanEnd.
  ///
  /// In en, this message translates to:
  /// **'End day'**
  String get todayPlanEnd;

  /// No description provided for @todayPlanTripActions.
  ///
  /// In en, this message translates to:
  /// **'Trip actions'**
  String get todayPlanTripActions;

  /// No description provided for @todayPlanPause.
  ///
  /// In en, this message translates to:
  /// **'Pause trip'**
  String get todayPlanPause;

  /// No description provided for @todayPlanSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip stop'**
  String get todayPlanSkip;

  /// No description provided for @todayPlanDelay.
  ///
  /// In en, this message translates to:
  /// **'Delay 15 min'**
  String get todayPlanDelay;

  /// No description provided for @todayPlanUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating trip plan'**
  String get todayPlanUpdating;

  /// No description provided for @todayPlanTimeline.
  ///
  /// In en, this message translates to:
  /// **'Route timeline'**
  String get todayPlanTimeline;

  /// No description provided for @todayPlanMarkVisited.
  ///
  /// In en, this message translates to:
  /// **'Mark visited'**
  String get todayPlanMarkVisited;

  /// No description provided for @todayPlanResume.
  ///
  /// In en, this message translates to:
  /// **'Resume trip'**
  String get todayPlanResume;

  /// No description provided for @todayPlanStart.
  ///
  /// In en, this message translates to:
  /// **'Start trip'**
  String get todayPlanStart;

  /// No description provided for @todayPlanEnded.
  ///
  /// In en, this message translates to:
  /// **'Day ended'**
  String get todayPlanEnded;

  /// No description provided for @todayPlanComplete.
  ///
  /// In en, this message translates to:
  /// **'Day complete'**
  String get todayPlanComplete;

  /// No description provided for @todayPlanPaused.
  ///
  /// In en, this message translates to:
  /// **'Trip paused'**
  String get todayPlanPaused;

  /// No description provided for @todayPlanCurrentStop.
  ///
  /// In en, this message translates to:
  /// **'Current stop'**
  String get todayPlanCurrentStop;

  /// No description provided for @todayPlanFirstStop.
  ///
  /// In en, this message translates to:
  /// **'First stop'**
  String get todayPlanFirstStop;

  /// No description provided for @todayPlanMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String todayPlanMinutes(int minutes);

  /// No description provided for @todayPlanNext.
  ///
  /// In en, this message translates to:
  /// **'Next · {place} · {time}'**
  String todayPlanNext(String place, String time);

  /// No description provided for @todayPlanProgress.
  ///
  /// In en, this message translates to:
  /// **'{visited} visited · {skipped} skipped · {remaining} remaining'**
  String todayPlanProgress(int visited, int skipped, int remaining);

  /// No description provided for @todayPlanDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get todayPlanDirections;

  /// No description provided for @todayPlanPlanningEstimate.
  ///
  /// In en, this message translates to:
  /// **'Planning estimate'**
  String get todayPlanPlanningEstimate;

  /// No description provided for @todayPlanRouteEstimate.
  ///
  /// In en, this message translates to:
  /// **'Route estimate'**
  String get todayPlanRouteEstimate;

  /// No description provided for @todayPlanTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel · {minutes} min'**
  String todayPlanTravel(int minutes);

  /// No description provided for @todayPlanDirectionsTo.
  ///
  /// In en, this message translates to:
  /// **'Directions to {place}'**
  String todayPlanDirectionsTo(String place);

  /// No description provided for @todayPlanVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get todayPlanVisited;

  /// No description provided for @todayPlanSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get todayPlanSkipped;

  /// No description provided for @viewRoute.
  ///
  /// In en, this message translates to:
  /// **'View route'**
  String get viewRoute;

  /// No description provided for @editVisitDuration.
  ///
  /// In en, this message translates to:
  /// **'Edit visit duration'**
  String get editVisitDuration;

  /// No description provided for @openFullscreenMap.
  ///
  /// In en, this message translates to:
  /// **'Open fullscreen map'**
  String get openFullscreenMap;

  /// No description provided for @resumePageScrolling.
  ///
  /// In en, this message translates to:
  /// **'Resume page scrolling'**
  String get resumePageScrolling;

  /// No description provided for @enableMapPanning.
  ///
  /// In en, this message translates to:
  /// **'Enable map panning'**
  String get enableMapPanning;

  /// No description provided for @recenterRoute.
  ///
  /// In en, this message translates to:
  /// **'Recenter route'**
  String get recenterRoute;

  /// No description provided for @zoomInMap.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomInMap;

  /// No description provided for @zoomOutMap.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOutMap;

  /// No description provided for @journeySegments.
  ///
  /// In en, this message translates to:
  /// **'Journey segments'**
  String get journeySegments;

  /// No description provided for @journeySegmentMetrics.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {distance} km'**
  String journeySegmentMetrics(String duration, String distance);

  /// No description provided for @journeySegmentLate.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min late'**
  String journeySegmentLate(int minutes);

  /// No description provided for @journeySegmentBuffer.
  ///
  /// In en, this message translates to:
  /// **'+{minutes} min buffer'**
  String journeySegmentBuffer(int minutes);

  /// No description provided for @journeySegmentLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading route…'**
  String get journeySegmentLoading;

  /// No description provided for @journeySegmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable'**
  String get journeySegmentUnavailable;

  /// No description provided for @journeySegmentMissingCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable · Missing coordinates'**
  String get journeySegmentMissingCoordinates;

  /// No description provided for @journeySegmentDayOffset.
  ///
  /// In en, this message translates to:
  /// **'{time} (+{days, plural, one{1 day} other{{days} days}})'**
  String journeySegmentDayOffset(String time, int days);
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
      <String>['en', 'ms', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
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
