// App-owned legacy labels and service messages are localized at presentation.
// User/provider content must not be passed through this adapter.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

extension LocalizedLabels on BuildContext {
  AppLocalizations get l10n =>
      (Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn());
  String tr(String label) => localizeLabel(
    (Localizations.of<AppLocalizations>(this, AppLocalizations) ??
        AppLocalizationsEn()),
    label,
  );
  String localDate(DateTime date) =>
      DateFormat.yMMMd(Localizations.localeOf(this).toString()).format(date);
  String localNumber(num value, {int decimals = 0}) =>
      (NumberFormat.decimalPattern(Localizations.localeOf(this).toString())
            ..minimumFractionDigits = decimals
            ..maximumFractionDigits = decimals)
          .format(value);
  String money(num value) => NumberFormat.currency(
    locale: Localizations.localeOf(this).toString(),
    name: 'MYR',
    symbol: 'RM',
  ).format(value);
}

String localizeLabel(AppLocalizations? strings, String label) {
  final l = strings ?? AppLocalizationsEn();
  switch (label) {
    case "App Language":
      return l.appLanguage;
    case "Language changed.":
      return l.languageChanged;
    case "Language changed for this session. Could not save your preference.":
      return l.languageSessionOnly;
    case "Home":
      return l.home;
    case "Explore":
      return l.explore;
    case "Recognize":
      return l.recognize;
    case "Plan":
      return l.plan;
    case "AI":
      return l.ai;
    case "Back":
      return l.back;
    case "Cancel":
      return l.cancel;
    case "Cancelling…":
    case "Cancelling...":
      return l.localeName.startsWith('zh')
          ? '正在取消…'
          : l.localeName.startsWith('ms')
              ? 'Membatalkan…'
              : 'Cancelling…';
    case "Cancelling sync...":
      return l.localeName.startsWith('zh')
          ? '正在取消同步…'
          : l.localeName.startsWith('ms')
              ? 'Membatalkan penyelarasan…'
              : 'Cancelling sync...';
    case "Stopping Google Places search...":
      return l.localeName.startsWith('zh')
          ? '正在停止 Google 地点搜索…'
          : l.localeName.startsWith('ms')
              ? 'Menghentikan carian Google Places…'
              : 'Stopping Google Places search...';
    case "Sync cancelled":
      return l.localeName.startsWith('zh')
          ? '已取消同步'
          : l.localeName.startsWith('ms')
              ? 'Penyelarasan dibatalkan'
              : 'Sync cancelled';
    case "Save":
      return l.save;
    case "Delete":
      return l.delete;
    case "Clear":
      return l.clear;
    case "Close":
      return l.close;
    case "Done":
      return l.done;
    case "Retry":
      return l.retry;
    case "Try Again":
      return l.tryAgain;
    case "OK":
      return l.ok;
    case "Got it":
      return l.gotIt;
    case "Dismiss":
      return l.dismiss;
    case "Change":
      return l.change;
    case "Details":
      return l.details;
    case "About":
      return l.about;
    case "Unavailable":
      return l.unavailable;
    case "Information":
      return l.information;
    case "Ready":
      return l.ready;
    case "Stop":
      return l.stop;
    case "Open":
      return l.open;
    case "All":
      return l.all;
    case "Save Changes":
      return l.saveChanges;
    case "Read more":
      return l.readMore;
    case "Read less":
      return l.readLess;
    case "View All":
      return l.viewAll;
    case "See All":
      return l.seeAll;
    case "View on Map":
      return l.viewOnMap;
    case "Open in Google Maps":
      return l.openInGoogleMaps;
    case "Share place":
      return l.sharePlace;
    case "Copy address":
      return l.copyAddress;
    case "Address copied to clipboard!":
      return l.addressCopiedToClipboard;
    case "Address":
      return l.address;
    case "Address unavailable":
      return l.addressUnavailable;
    case "Description unavailable.":
      return l.descriptionUnavailable;
    case "Details unavailable":
      return l.detailsUnavailable;
    case "Place details are unavailable.":
      return l.placeDetailsAreUnavailable;
    case "Name unavailable":
      return l.nameUnavailable;
    case "Phone":
      return l.phone;
    case "Phone unavailable":
      return l.phoneUnavailable;
    case "Website":
      return l.website;
    case "Website unavailable":
      return l.websiteUnavailable;
    case "Rating":
      return l.rating;
    case "Rating unavailable":
      return l.ratingUnavailable;
    case "Reviews":
      return l.reviews;
    case "Review count unavailable":
      return l.reviewCountUnavailable;
    case "Opening hours":
      return l.openingHours;
    case "Opening hours unavailable. Check before visiting.":
      return l.openingHoursUnavailableCheckBeforeVisiting;
    case "Operating hours may vary during public holidays or special events.":
      return l.operatingHoursMayVaryDuringPublicHolidaysOrSpecialEvents;
    case "Hours unverified":
      return l.hoursUnverified;
    case "Photo unavailable":
      return l.photoUnavailable;
    case "Load photo":
      return l.loadPhoto;
    case "Retry photo":
      return l.retryPhoto;
    case "Source":
      return l.source;
    case "Indoor":
      return l.indoor;
    case "Outdoor":
      return l.outdoor;
    case "Attraction":
      return l.attraction;
    case "Attractions":
      return l.attractions;
    case "Food":
      return l.food;
    case "Shopping":
      return l.shopping;
    case "Culture":
      return l.culture;
    case "Nature":
      return l.nature;
    case "Adventure":
      return l.adventure;
    case "Family":
      return l.family;
    case "Museum":
      return l.museum;
    case "Sight":
      return l.sight;
    case "Science":
      return l.science;
    case "Nightlife":
      return l.nightlife;
    case "Landmarks":
      return l.landmarks;
    case "Nearby":
      return l.nearby;
    case "Popular":
      return l.popular;
    case "Air-conditioned":
      return l.airConditioned;
    case "Comfortable footwear advised":
      return l.comfortableFootwearAdvised;
    case "Welcome Back":
      return l.welcomeBack;
    case "Selamat Datang!":
      return l.selamatDatang;
    case "Smart Travel\nPlanning":
      return l.smartTravelPlanning;
    case "Smart Travel Planner":
      return l.smartTravelPlanner;
    case "Smart Travel Planning":
      return l.smartTravelPlanning2;
    case "Your Smart Travel Companion\nin Malaysia":
      return l.yourSmartTravelCompanionInMalaysia;
    case "Auto Smart Scheduling":
      return l.autoSmartScheduling;
    case "Plan the best route for you":
      return l.planTheBestRouteForYou;
    case "Real-time Updates":
      return l.realTimeUpdates;
    case "Weather, traffic & opening hours":
      return l.weatherTrafficOpeningHours;
    case "Multi-language Support":
      return l.multiLanguageSupport;
    case "Get Started":
      return l.getStarted;
    case "Log In / Sign Up":
      return l.logInSignUp;
    case "Log In":
      return l.logIn;
    case "Create Account":
      return l.createAccount;
    case "Register Account":
      return l.registerAccount;
    case "Log Out":
      return l.logOut;
    case "Malaysia Travel Portal":
      return l.malaysiaTravelPortal;
    case "Access AI itineraries, weather alerts, and smart route optimization.":
      return l.accessAiItinerariesWeatherAlertsAndSmartRouteOptimization;
    case "Sign in to manage your Malaysia travel plans.":
      return l.signInToManageYourMalaysiaTravelPlans;
    case "Register as a new tourist to plan your personalized trips in Malaysia.":
      return l.registerAsANewTouristToPlanYourPersonalizedTripsInMalaysia;
    case "Email Address":
      return l.emailAddress;
    case "Password":
      return l.password;
    case "Confirm Password":
      return l.confirmPassword;
    case "Full Name":
      return l.fullName;
    case "Full name":
      return l.fullName2;
    case "Enter your password":
      return l.enterYourPassword;
    case "Enter strong password":
      return l.enterStrongPassword;
    case "Re-enter password":
      return l.reEnterPassword;
    case "e.g. Ali Bin Ahmad":
      return l.eGAliBinAhmad;
    case "e.g. tourist@example.com":
      return l.eGTouristExampleCom;
    case "Please enter your email":
      return l.pleaseEnterYourEmail;
    case "Please enter a valid email":
      return l.pleaseEnterAValidEmail;
    case "Please enter your password":
      return l.pleaseEnterYourPassword;
    case "Password must be at least 6 characters":
      return l.passwordMustBeAtLeast6Characters;
    case "Password Strength Policy (C3):":
      return l.passwordStrengthPolicyC3;
    case "At least 8 characters":
      return l.atLeast8Characters;
    case "One lowercase letter (a-z)":
      return l.oneLowercaseLetterAZ;
    case "One uppercase letter (A-Z)":
      return l.oneUppercaseLetterAZ;
    case "One number (0-9)":
      return l.oneNumber09;
    case "One special character (!@#\$%^&*)":
      return l.oneSpecialCharacter;
    case "Check your email":
      return l.checkYourEmail;
    case "If this email can be registered, a confirmation email will be sent. Open the link in that email, then return here and log in. You are not signed in yet.":
      return l
          .ifThisEmailCanBeRegisteredAConfirmationEmailWillBeSentOpenTheLinkInThatEmailThenReturnHere;
    case "Logged in as Guest Traveler!":
      return l.loggedInAsGuestTraveler;
    case "Successfully logged out.":
      return l.successfullyLoggedOut;
    case "My Profile":
      return l.myProfile;
    case "No active profile found.":
      return l.noActiveProfileFound;
    case "Account Settings":
      return l.accountSettings;
    case "Edit Profile":
      return l.editProfile;
    case "Edit profile":
      return l.editProfile2;
    case "Change your full name":
      return l.changeYourFullName;
    case "Are you sure you want to log out of your travel profile?":
      return l.areYouSureYouWantToLogOutOfYourTravelProfile;
    case "Push Notifications":
      return l.pushNotifications;
    case "Dark Mode":
      return l.darkMode;
    case "Dark mode is not supported in the demo version.":
      return l.darkModeIsNotSupportedInTheDemoVersion;
    case "Privacy & Terms":
      return l.privacyTerms;
    case "Privacy Policy & Terms":
      return l.privacyPolicyTerms;
    case "About App":
      return l.aboutApp;
    case "About Smart Travel Planner":
      return l.aboutSmartTravelPlanner;
    case "Trips Planned":
      return l.tripsPlanned;
    case "Places Visited":
      return l.placesVisited;
    case "Traveler":
      return l.traveler;
    case "Smart Tourist":
      return l.smartTourist;
    case "Explore Malaysia":
      return l.exploreMalaysia;
    case "Discover attractions & places":
      return l.discoverAttractionsPlaces;
    case "Image Recognition":
      return l.imageRecognition;
    case "Image recognition":
      return l.imageRecognition2;
    case "Discover Malaysia through your camera":
      return l.discoverMalaysiaThroughYourCamera;
    case "Plan Your Trip":
      return l.planYourTrip;
    case "Tell us your preferences":
      return l.tellUsYourPreferences;
    case "Trip Assistant":
      return l.tripAssistant;
    case "AI help, translation and weather alerts":
      return l.aiHelpTranslationAndWeatherAlerts;
    case "Where would you like to explore today?":
      return l.whereWouldYouLikeToExploreToday;
    case "Where to next?":
      return l.whereToNext;
    case "Popular Attractions":
      return l.popularAttractions;
    case "Top must-visit destinations in Malaysia":
      return l.topMustVisitDestinationsInMalaysia;
    case "Browse Attractions":
      return l.browseAttractions;
    case "My Trips":
      return l.myTrips;
    case "View saved itineraries and your current plan":
      return l.viewSavedItinerariesAndYourCurrentPlan;
    case "View Itinerary":
      return l.viewItinerary;
    case "View Nearby":
      return l.viewNearby;
    case "AI itinerary":
      return l.aiItinerary;
    case "Route optimizer":
      return l.routeOptimizer;
    case "Weather updates":
      return l.weatherUpdates;
    case "Budget filter":
      return l.budgetFilter;
    case "Multi-language":
      return l.multiLanguage;
    case "Offline mode":
      return l.offlineMode;
    case "Itinerary labels ready in English, Malay and Chinese.":
      return l.itineraryLabelsReadyInEnglishMalayAndChinese;
    case "A trip that fits you":
      return l.aTripThatFitsYou;
    case "Where and when would you like to go?":
      return l.whereAndWhenWouldYouLikeToGo;
    case "Choose your dates, daily pace, and favourite things to do.":
      return l.chooseYourDatesDailyPaceAndFavouriteThingsToDo;
    case "Destination":
      return l.destination;
    case "Travel dates":
      return l.travelDates;
    case "Select travel dates":
      return l.selectTravelDates;
    case "Select Travel Dates":
      return l.selectTravelDates2;
    case "Select Destination":
      return l.selectDestination;
    case "Select State":
      return l.selectState;
    case "Your daily pace":
      return l.yourDailyPace;
    case "Daily Start Time":
      return l.dailyStartTime;
    case "Daily End Time":
      return l.dailyEndTime;
    case "Select Time":
      return l.selectTime;
    case "Choose a suggested schedule":
      return l.chooseASuggestedSchedule;
    case "Set aside time for attractions, meals, and getting around.":
      return l.setAsideTimeForAttractionsMealsAndGettingAround;
    case "Relaxed":
      return l.relaxed;
    case "Standard":
      return l.standard;
    case "Full":
      return l.full;
    case "Planned duration":
      return l.plannedDuration;
    case "Make it your kind of trip":
      return l.makeItYourKindOfTrip;
    case "Interests":
      return l.interests;
    case "Pick one or more interests. We’ll use these to find places for you.":
      return l.pickOneOrMoreInterestsWeLlUseTheseToFindPlacesForYou;
    case "Choose your daily budget":
      return l.chooseYourDailyBudget;
    case "Daily budget":
      return l.dailyBudget;
    case "Budget":
      return l.budget;
    case "Low":
      return l.low;
    case "Medium":
      return l.medium;
    case "High":
      return l.high;
    case "Under RM150":
      return l.underRm150;
    case "Over RM300":
      return l.overRm300;
    case "Per person, including meals, attraction tickets, and local transport.":
      return l.perPersonIncludingMealsAttractionTicketsAndLocalTransport;
    case "Getting around":
      return l.gettingAround;
    case "Choose how you will travel between places.":
      return l.chooseHowYouWillTravelBetweenPlaces;
    case "Driving":
      return l.driving;
    case "Walking":
      return l.walking;
    case "Transit":
      return l.transit;
    case "Public Transport":
      return l.publicTransport;
    case "Explore further by car or e-hailing.":
      return l.exploreFurtherByCarOrEHailing;
    case "Enjoy nearby places at a walking pace.":
      return l.enjoyNearbyPlacesAtAWalkingPace;
    case "Generate My Itinerary":
      return l.generateMyItinerary;
    case "Generating…":
      return l.generating;
    case "Building itinerary from saved places…":
      return l.buildingItineraryFromSavedPlaces;
    case "Check your trip preferences":
      return l.checkYourTripPreferences;
    case "Choose a destination.":
      return l.chooseADestination;
    case "Choose your travel dates.":
      return l.chooseYourTravelDates;
    case "Choose a time.":
      return l.chooseATime;
    case "Choose at least one interest.":
      return l.chooseAtLeastOneInterest;
    case "Choose a daily budget.":
      return l.chooseADailyBudget;
    case "Choose a travel mode.":
      return l.chooseATravelMode;
    case "Transit planning is not available yet. Choose driving or walking to generate your trip.":
      return l
          .transitPlanningIsNotAvailableYetChooseDrivingOrWalkingToGenerateYourTrip;
    case "Itinerary generated — opening preview.":
      return l.itineraryGeneratedOpeningPreview;
    case "My Itinerary":
      return l.myItinerary;
    case "Save Itinerary":
      return l.saveItinerary;
    case "Trip Details":
      return l.tripDetails;
    case "Trip details":
      return l.tripDetails2;
    case "Travel Time":
      return l.travelTime;
    case "Est. Cost":
      return l.estCost;
    case "Est. Distance":
      return l.estDistance;
    case "Est. Visit":
      return l.estVisit;
    case "Day Route":
      return l.dayRoute;
    case "Day 1 Plan":
      return l.day1Plan;
    case "Regenerate":
      return l.regenerate;
    case "Regenerate itinerary":
      return l.regenerateItinerary;
    case "Regenerate itinerary?":
      return l.regenerateItinerary2;
    case "Your current unsaved changes will be replaced. Saved trips will remain available.":
      return l
          .yourCurrentUnsavedChangesWillBeReplacedSavedTripsWillRemainAvailable;
    case "Complete trip preferences in Plan before regenerating.":
      return l.completeTripPreferencesInPlanBeforeRegenerating;
    case "Delete Itinerary?":
      return l.deleteItinerary;
    case "Delete or clear itinerary":
      return l.deleteOrClearItinerary;
    case "Unable to delete this itinerary.":
      return l.unableToDeleteThisItinerary;
    case "Unable to save itinerary changes on this device.":
      return l.unableToSaveItineraryChangesOnThisDevice;
    case "No Itineraries Yet":
      return l.noItinerariesYet;
    case "No Active Trip Planned":
      return l.noActiveTripPlanned;
    case "You have no active or saved trips. Set your travel preferences to generate a smart day-by-day schedule.":
      return l
          .youHaveNoActiveOrSavedTripsSetYourTravelPreferencesToGenerateASmartDayByDaySchedule;
    case "Tap to plan your smart schedule":
      return l.tapToPlanYourSmartSchedule;
    case "Tap to view schedule & details":
      return l.tapToViewScheduleDetails;
    case "Active Generated Plan":
      return l.activeGeneratedPlan;
    case "Active Planned Trip":
      return l.activePlannedTrip;
    case "ACTIVE ITINERARY":
      return l.activeItinerary;
    case "Active trip plan cleared":
      return l.activeTripPlanCleared;
    case "Clear Active Plan?":
      return l.clearActivePlan;
    case "Are you sure you want to clear your current generated trip and reset to default?":
      return l
          .areYouSureYouWantToClearYourCurrentGeneratedTripAndResetToDefault;
    case "Add Stop":
      return l.addStop;
    case "Add Stop to Day Schedule":
      return l.addStopToDaySchedule;
    case "Add to Plan":
      return l.addToPlan;
    case "Add to My Itinerary":
      return l.addToMyItinerary;
    case "Add to Travel Plan":
      return l.addToTravelPlan;
    case "Add to Wishlist":
      return l.addToWishlist;
    case "Select an attraction to append to your day route":
      return l.selectAnAttractionToAppendToYourDayRoute;
    case "Remove stop":
      return l.removeStop;
    case "Swap Attraction":
      return l.swapAttraction;
    case "Swap attraction":
      return l.swapAttraction2;
    case "Drag items by the handle to reorder. Tap Swap to replace with indoor places.":
      return l.dragItemsByTheHandleToReorderTapSwapToReplaceWithIndoorPlaces;
    case "An itinerary day must have at least 1 stop.":
      return l.anItineraryDayMustHaveAtLeast1Stop;
    case "Duplicate stop today":
      return l.duplicateStopToday;
    case "In other day":
      return l.inOtherDay;
    case "Duplicate attractions detected today. Please remove or swap them to save.":
      return l.duplicateAttractionsDetectedTodayPleaseRemoveOrSwapThemToSave;
    case "Cannot save: this order exceeds daily hours, opening hours, budget, or weather constraints.":
      return l
          .cannotSaveThisOrderExceedsDailyHoursOpeningHoursBudgetOrWeatherConstraints;
    case "Connect to refresh Google place locations before saving schedule changes.":
      return l.connectToRefreshGooglePlaceLocationsBeforeSavingScheduleChanges;
    case "Stop reordered. Schedule times automatically adjusted.":
      return l.stopReorderedScheduleTimesAutomaticallyAdjusted;
    case "Rain forecasted today. Swapping to an Indoor attraction is recommended.":
      return l.rainForecastedTodaySwappingToAnIndoorAttractionIsRecommended;
    case "Good weather today! You can keep it indoor or swap to an outdoor sight.":
      return l.goodWeatherTodayYouCanKeepItIndoorOrSwapToAnOutdoorSight;
    case "Scheduled time":
      return l.scheduledTime;
    case "Scheduled visit":
      return l.scheduledVisit;
    case "Suggested time":
      return l.suggestedTime;
    case "Indoor activity":
      return l.indoorActivity;
    case "Outdoor sight":
      return l.outdoorSight;
    case "Indoor attraction • Weather safe":
      return l.indoorAttractionWeatherSafe;
    case "Outdoor sightseeing":
      return l.outdoorSightseeing;
    case "Rain-proof backup":
      return l.rainProofBackup;
    case "Route Map":
      return l.routeMap;
    case "Map View":
      return l.mapView;
    case "Re-center":
      return l.reCenter;
    case "Optimize Route":
      return l.optimizeRoute;
    case "Optimized order":
      return l.optimizedOrder;
    case "Optimizing route…":
      return l.optimizingRoute;
    case "Calculating route estimate...":
      return l.calculatingRouteEstimate;
    case "Tap map pins to view place details":
      return l.tapMapPinsToViewPlaceDetails;
    case "Select 2-5 locations to draw a route":
      return l.select25LocationsToDrawARoute;
    case "Map centered on your current location.":
      return l.mapCenteredOnYourCurrentLocation;
    case "Unable to open Google Maps.":
      return l.unableToOpenGoogleMaps;
    case "Unable to open this link.":
      return l.unableToOpenThisLink;
    case "Google Maps is not configured for this platform yet. Your saved places remain available in the list.":
      return l
          .googleMapsIsNotConfiguredForThisPlatformYetYourSavedPlacesRemainAvailableInTheList;
    case "Search City / Destination":
      return l.searchCityDestination;
    case "Search attractions, food, culture...":
      return l.searchAttractionsFoodCulture;
    case "Search Results":
      return l.searchResults;
    case "Search in this area":
      return l.searchInThisArea;
    case "Choose State":
      return l.chooseState;
    case "Choose Area / City":
      return l.chooseAreaCity;
    case "Explore New Location":
      return l.exploreNewLocation;
    case "CURRENT DESTINATION":
      return l.currentDestination;
    case "Reset Search & Filters":
      return l.resetSearchFilters;
    case "No Places Found":
      return l.noPlacesFound;
    case "No Saved Places Yet":
      return l.noSavedPlacesYet;
    case "No attractions match this filter in this city.":
      return l.noAttractionsMatchThisFilterInThisCity;
    case "Unable to load attractions. Please try again.":
      return l.unableToLoadAttractionsPleaseTryAgain;
    case "Unable to load details. Retry.":
      return l.unableToLoadDetailsRetry;
    case "Saved":
      return l.saved;
    case "Saved Attractions":
      return l.savedAttractions;
    case "Your Saved Places":
      return l.yourSavedPlaces;
    case "Save attraction":
      return l.saveAttraction;
    case "Remove from saved":
      return l.removeFromSaved;
    case "Saved list can hold up to 10 attractions.":
      return l.savedListCanHoldUpTo10Attractions;
    case "Removed from saved places":
      return l.removedFromSavedPlaces;
    case "Saved to favorite places":
      return l.savedToFavoritePlaces;
    case "Saved places can be viewed on the Map tab to see optimal driving paths, or visit the Plan tab to automatically schedule them into your multi-day trip.":
      return l
          .savedPlacesCanBeViewedOnTheMapTabToSeeOptimalDrivingPathsOrVisitThePlanTabToAutomaticallyS;
    case "Top Malaysian Attraction":
      return l.topMalaysianAttraction;
    case "Malaysian Iconic Attraction":
      return l.malaysianIconicAttraction;
    case "Must-Visit Highlights":
      return l.mustVisitHighlights;
    case "Traveler Tips & Good to Know":
      return l.travelerTipsGoodToKnow;
    case "Helpful Tips":
      return l.helpfulTips;
    case "Activity Status":
      return l.activityStatus;
    case "Entry":
      return l.entry;
    case "Curated spots within 5 km":
      return l.curatedSpotsWithin5Km;
    case "5 km radius":
      return l.text5KmRadius;
    case "Explore spot":
      return l.exploreSpot;
    case "View place details":
      return l.viewPlaceDetails;
    case "Live Google information":
      return l.liveGoogleInformation;
    case "Live place details unavailable.":
      return l.livePlaceDetailsUnavailable;
    case "Showing available place information.":
      return l.showingAvailablePlaceInformation;
    case "Google Places unavailable":
      return l.googlePlacesUnavailable;
    case "Attraction details & map link copied to clipboard!":
      return l.attractionDetailsMapLinkCopiedToClipboard;
    case "0 places":
      return l.text0Places;
    case "Ask places, food, weather, or plans...":
      return l.askPlacesFoodWeatherOrPlans;
    case "Send Prompt":
      return l.sendPrompt;
    case "Gemini is thinking...":
      return l.geminiIsThinking;
    case "Gemini 1.5 Flash • Malaysian Travel AI":
      return l.gemini15FlashMalaysianTravelAi;
    case "Assistant response language":
      return l.assistantResponseLanguage;
    case "Select Language":
      return l.selectLanguage;
    case "Clear Chat History?":
      return l.clearChatHistory;
    case "This will reset your conversation with the travel assistant.":
      return l.thisWillResetYourConversationWithTheTravelAssistant;
    case "Chat history cleared.":
      return l.chatHistoryCleared;
    case "Reset Conversation":
      return l.resetConversation;
    case "Voice Search":
      return l.voiceSearch;
    case "Voice Travel Assistant":
      return l.voiceTravelAssistant;
    case "Try Spoken Query":
      return l.trySpokenQuery;
    case "🌧️ Is it going to rain in KL today?":
      return l.isItGoingToRainInKlToday;
    case "🍜 Best Halal food near Bukit Bintang":
      return l.bestHalalFoodNearBukitBintang;
    case "🏛️ Cultural etiquette for Batu Caves":
      return l.culturalEtiquetteForBatuCaves;
    case "🚇 How to get from KL Sentral to KLCC":
      return l.howToGetFromKlSentralToKlcc;
    case "🗣️ Useful Malay travel phrases":
      return l.usefulMalayTravelPhrases;
    case "🛍️ Top indoor shopping and museums":
      return l.topIndoorShoppingAndMuseums;
    case "Scanner":
      return l.scanner;
    case "History":
      return l.history;
    case "Demo Results":
      return l.demoResults;
    case "Discover a landmark or a local dish":
      return l.discoverALandmarkOrALocalDish;
    case "Choose a photo, review it, then identify what you see.":
      return l.chooseAPhotoReviewItThenIdentifyWhatYouSee;
    case "Take Photo":
      return l.takePhoto;
    case "Upload from Gallery":
      return l.uploadFromGallery;
    case "Launch your camera to capture a landmark or food":
      return l.launchYourCameraToCaptureALandmarkOrFood;
    case "Select a photo from your photo library":
      return l.selectAPhotoFromYourPhotoLibrary;
    case "Your photo is ready":
      return l.yourPhotoIsReady;
    case "PHOTO PREVIEW":
      return l.photoPreview;
    case "SAMPLE PREVIEW":
      return l.samplePreview;
    case "Photo preview unavailable":
      return l.photoPreviewUnavailable;
    case "Recognize photo":
      return l.recognizePhoto;
    case "Recognizing photo…":
      return l.recognizingPhoto;
    case "Retake Photo":
      return l.retakePhoto;
    case "Choose Another":
      return l.chooseAnother;
    case "Ready to discover what you found?":
      return l.readyToDiscoverWhatYouFound;
    case "For the best result, use one clear landmark or dish, keep it centred, and avoid blurry or very dark photos.":
      return l
          .forTheBestResultUseOneClearLandmarkOrDishKeepItCentredAndAvoidBlurryOrVeryDarkPhotos;
    case "For better accuracy, keep the landmark or food dish well-lit and centered.":
      return l.forBetterAccuracyKeepTheLandmarkOrFoodDishWellLitAndCentered;
    case "Sample scans work offline. Live recognition and translation require an online account.":
      return l
          .sampleScansWorkOfflineLiveRecognitionAndTranslationRequireAnOnlineAccount;
    case "Only result text is saved in your local history; the photo is not stored by the app.":
      return l
          .onlyResultTextIsSavedInYourLocalHistoryThePhotoIsNotStoredByTheApp;
    case "Recognize sends this photo to Google Vision through our secure service. ":
      return l.recognizeSendsThisPhotoToGoogleVisionThroughOurSecureService;
    case "Camera or photo library unavailable. Check access in Settings or try a sample.":
      return l.cameraOrPhotoLibraryUnavailableCheckAccessInSettingsOrTryASample;
    case "Restart the app to enable the camera and photo library.":
      return l.restartTheAppToEnableTheCameraAndPhotoLibrary;
    case "This photo could not be opened. Try another photo or a sample.":
      return l.thisPhotoCouldNotBeOpenedTryAnotherPhotoOrASample;
    case "Choose a photo smaller than 4 MB.":
      return l.chooseAPhotoSmallerThan4Mb;
    case "Image recognition is temporarily unavailable. Try a sample.":
      return l.imageRecognitionIsTemporarilyUnavailableTryASample;
    case "Recent scans":
      return l.recentScans;
    case "No scans yet":
      return l.noScansYet;
    case "Your completed recognition results will appear here. Demo results stay separate. History is currently stored on this device.":
      return l
          .yourCompletedRecognitionResultsWillAppearHereDemoResultsStaySeparateHistoryIsCurrentlyStor;
    case "Clear history":
      return l.clearHistory;
    case "Clear scan history?":
      return l.clearScanHistory;
    case "Remove all scan results saved on this device? This cannot be undone.":
      return l.removeAllScanResultsSavedOnThisDeviceThisCannotBeUndone;
    case "Go to Scanner":
      return l.goToScanner;
    case "Try prepared recognition results":
      return l.tryPreparedRecognitionResults;
    case "Browse prepared landmark and food results to understand what the finished recognition screen will show.":
      return l
          .browsePreparedLandmarkAndFoodResultsToUnderstandWhatTheFinishedRecognitionScreenWillShow;
    case "This is a prepared demo result. It has not analysed your uploaded photo and is not added to scan history.":
      return l
          .thisIsAPreparedDemoResultItHasNotAnalysedYourUploadedPhotoAndIsNotAddedToScanHistory;
    case "No prepared test result is available yet.":
      return l.noPreparedTestResultIsAvailableYet;
    case "Run test recognition":
      return l.runTestRecognition;
    case "Test recognition uses prepared catalog results to preview the flow.":
      return l.testRecognitionUsesPreparedCatalogResultsToPreviewTheFlow;
    case "View demo result":
      return l.viewDemoResult;
    case "View demo results":
      return l.viewDemoResults;
    case "Explore this result":
      return l.exploreThisResult;
    case "Detected labels":
      return l.detectedLabels;
    case "Identification uses Vision detections. Guide descriptions come from the app’s curated catalog.":
      return l
          .identificationUsesVisionDetectionsGuideDescriptionsComeFromTheAppSCuratedCatalog;
    case "Result language":
      return l.resultLanguage;
    case "Translating…":
      return l.translating;
    case "Machine-translated text. The original English result stays in your history.":
      return l.machineTranslatedTextTheOriginalEnglishResultStaysInYourHistory;
    case "Translation is unavailable. Your original result is still available.":
      return l.translationIsUnavailableYourOriginalResultIsStillAvailable;
    case "Find Restaurants":
      return l.findRestaurants;
    case "Choose a restaurant before adding this dish to your travel plan.":
      return l.chooseARestaurantBeforeAddingThisDishToYourTravelPlan;
    case "These actions will be available when live recognition and tourism details are connected.":
      return l
          .theseActionsWillBeAvailableWhenLiveRecognitionAndTourismDetailsAreConnected;
    case "Available after setup":
      return l.availableAfterSetup;
    case "After live recognition is connected, successful scans will be saved here automatically.":
      return l
          .afterLiveRecognitionIsConnectedSuccessfulScansWillBeSavedHereAutomatically;
    case "Adults":
      return l.adults;
    case "Children":
      return l.children;
    case "Seniors":
      return l.seniors;
    case "Travelers":
      return l.travelers;
    case "Add travelers":
      return l.addTravelers;
    case "Add More":
      return l.addMore;
    case "Select Planned Itinerary":
      return l.selectPlannedItinerary;
    case "Switch between your active trips and custom generated plans":
      return l.switchBetweenYourActiveTripsAndCustomGeneratedPlans;
    case "Smart schedule & daily stops":
      return l.smartScheduleDailyStops;
    case "Auto smart scheduling for tourists in Malaysia":
      return l.autoSmartSchedulingForTouristsInMalaysia;
    case "Smart Itinerary Scheduling":
      return l.smartItineraryScheduling;
    case "Built a 3-day KL plan with food and shopping stops.":
      return l.builtA3DayKlPlanWithFoodAndShoppingStops;
    case "Reordered stops to save about 45 minutes of travel time.":
      return l.reorderedStopsToSaveAbout45MinutesOfTravelTime;
    case "Rain after 3 PM — indoor backup stops added automatically.":
      return l.rainAfter3PmIndoorBackupStopsAddedAutomatically;
    case "Daily spend kept within your RM150–300 medium budget.":
      return l.dailySpendKeptWithinYourRm150300MediumBudget;
    case "Maps and itinerary cached for use without mobile data.":
      return l.mapsAndItineraryCachedForUseWithoutMobileData;
    case "Route optimized — travel time reduced by 45 minutes.":
      return l.routeOptimizedTravelTimeReducedBy45Minutes;
    case "Notifications":
      return l.notifications;
    case "This app is a prototype designed for a Final Year Project to showcase automated route scheduling and map visualization in Malaysia.":
      return l
          .thisAppIsAPrototypeDesignedForAFinalYearProjectToShowcaseAutomatedRouteSchedulingAndMapVis;
    case "Read our terms of service":
      return l.readOurTermsOfService;
    case "By using this app, you agree to our terms of service. No real personal data is collected or sent to any server.":
      return l
          .byUsingThisAppYouAgreeToOurTermsOfServiceNoRealPersonalDataIsCollectedOrSentToAnyServer;
    case "Enter your credentials to manage your Malaysia trips.":
      return l.enterYourCredentialsToManageYourMalaysiaTrips;
    case "Invalid email or password (min 6 chars)":
      return l.invalidEmailOrPasswordMin6Chars;
    case "Listening for voice commands in English, Malay, or Chinese...\n\nTap below to send a sample spoken query.":
      return l
          .listeningForVoiceCommandsInEnglishMalayOrChineseTapBelowToSendASampleSpokenQuery;
    case "Recommend 2 indoor spots if it rains near KLCC this afternoon.":
      return l.recommend2IndoorSpotsIfItRainsNearKlccThisAfternoon;
    case "Account created successfully! Redirecting to homepage...":
      return l.accountCreatedSuccessfullyRedirectingToHomepage;
    case "Please complete all mandatory registration fields.":
      return l.pleaseCompleteAllMandatoryRegistrationFields;
    case "Please enter a valid email address (e.g., user@example.com).":
      return l.pleaseEnterAValidEmailAddressEGUserExampleCom;
    case "Password must contain at least 8 characters, including 1 uppercase, 1 lowercase, 1 number, and 1 special character.":
      return l
          .passwordMustContainAtLeast8CharactersIncluding1Uppercase1Lowercase1NumberAnd1SpecialCharac;
    case "Password and Confirm Password do not match. Please re-enter.":
      return l.passwordAndConfirmPasswordDoNotMatchPleaseReEnter;
    case "This email address has already been registered. Please log in or use another email address.":
      return l
          .thisEmailAddressHasAlreadyBeenRegisteredPleaseLogInOrUseAnotherEmailAddress;
    case "Registration timed out. Check your email for a confirmation message before trying again, as your account may have been created.":
      return l
          .registrationTimedOutCheckYourEmailForAConfirmationMessageBeforeTryingAgainAsYourAccountMay;
    case "Login successful. Redirecting to homepage...":
      return l.loginSuccessfulRedirectingToHomepage;
    case "Please enter your email address and password.":
      return l.pleaseEnterYourEmailAddressAndPassword;
    case "Please enter a valid email address.":
      return l.pleaseEnterAValidEmailAddress;
    case "The email address or password is incorrect. Please try again.":
      return l.theEmailAddressOrPasswordIsIncorrectPleaseTryAgain;
    case "Authentication service is currently unavailable. Please try again later.":
      return l.authenticationServiceIsCurrentlyUnavailablePleaseTryAgainLater;
    case "The login request timed out. Please check your network and try again.":
      return l.theLoginRequestTimedOutPleaseCheckYourNetworkAndTryAgain;
    case "Profile updated successfully!":
      return l.profileUpdatedSuccessfully;
    case "Full Name field cannot be empty. Please enter your name.":
      return l.fullNameFieldCannotBeEmptyPleaseEnterYourName;
    case "Unable to save profile changes. Please check your network and try again.":
      return l.unableToSaveProfileChangesPleaseCheckYourNetworkAndTryAgain;
    case "Trip preferences recorded successfully. Generating your itinerary.":
      return l.tripPreferencesRecordedSuccessfullyGeneratingYourItinerary;
    case "Please complete all mandatory trip-preference fields.":
      return l.pleaseCompleteAllMandatoryTripPreferenceFields;
    case "Please enter or select a valid destination.":
      return l.pleaseEnterOrSelectAValidDestination;
    case "Please select a valid number of travel days.":
      return l.pleaseSelectAValidNumberOfTravelDays;
    case "Daily end time must be later than daily start time.":
      return l.dailyEndTimeMustBeLaterThanDailyStartTime;
    case "Please select at least one travel interest.":
      return l.pleaseSelectAtLeastOneTravelInterest;
    case "Please select a valid estimated budget category.":
      return l.pleaseSelectAValidEstimatedBudgetCategory;
    case "The selected travel mode is not supported. Please select Driving or Walking.":
      return l.theSelectedTravelModeIsNotSupportedPleaseSelectDrivingOrWalking;
    case "Authentication required. Please log in to save your itinerary.":
      return l.authenticationRequiredPleaseLogInToSaveYourItinerary;
    case "Deleted on this device. Cloud sync is pending.":
      return l.deletedOnThisDeviceCloudSyncIsPending;
    case "Admin Database Hub":
      return l.adminDatabaseHub;
    case "Admin Hub Access":
      return l.adminHubAccess;
    case "Admin access (Tap to log in as admin)":
      return l.adminAccessTapToLogInAsAdmin;
    case "Login as Admin":
      return l.loginAsAdmin;
    case "Logged in as Administrator (Ching Kheat)":
      return l.loggedInAsAdministratorChingKheat;
    case "The Admin Database Hub requires administrator privileges to fetch, sync, and import places from Google.":
      return l
          .theAdminDatabaseHubRequiresAdministratorPrivilegesToFetchSyncAndImportPlacesFromGoogle;
    case "Secret Data Seeder Portal":
      return l.secretDataSeederPortal;
    case "Secret portal to fetch & sync places":
      return l.secretPortalToFetchSyncPlaces;
    case "Sign in as an administrator.":
      return l.signInAsAnAdministrator;
    case "Sign in as an administrator to import Google place IDs.":
      return l.signInAsAnAdministratorToImportGooglePlaceIds;
    case "1. Select Destination State":
      return l.text1SelectDestinationState;
    case "Discover new places":
      return l.discoverNewPlaces;
    case "Discovering more places…":
      return l.discoveringMorePlaces;
    case "Discovering new places. Existing records are preserved; use Update saved places to refresh their details.":
      return l
          .discoveringNewPlacesExistingRecordsArePreservedUseUpdateSavedPlacesToRefreshTheirDetails;
    case "Update saved places":
      return l.updateSavedPlaces;
    case "Update all saved places":
      return l.updateAllSavedPlaces;
    case "Start a new update of all saved places":
      return l.startANewUpdateOfAllSavedPlaces;
    case "Refresh hours, ratings, names and locations for all saved places. Discover new places below only adds new IDs.":
      return l
          .refreshHoursRatingsNamesAndLocationsForAllSavedPlacesDiscoverNewPlacesBelowOnlyAddsNewIds;
    case "Updates every saved Google place in this state, including opening hours, ratings, name and location. Your categories and indoor/outdoor choices stay unchanged.":
      return l
          .updatesEverySavedGooglePlaceInThisStateIncludingOpeningHoursRatingsNameAndLocationYourCate;
    case "Uses the full-details allowance. Keep this page open. Leaving pauses the update; progress is saved on this device. A successful response with no opening hours marks them unknown.":
      return l
          .usesTheFullDetailsAllowanceKeepThisPageOpenLeavingPausesTheUpdateProgressIsSavedOnThisDevi;
    case "Pause update":
      return l.pauseUpdate;
    case "Resume update":
      return l.resumeUpdate;
    case "Pausing…":
      return l.pausing;
    case "Updating…":
      return l.updating;
    case "Retry places with issues":
      return l.retryPlacesWithIssues;
    case "Review":
      return l.review;
    case "Needs review":
      return l.needsReview;
    case "Places needing review":
      return l.placesNeedingReview;
    case "Review saved place":
      return l.reviewSavedPlace;
    case "Review stored data / load live details":
      return l.reviewStoredDataLoadLiveDetails;
    case "Incomplete import — needs review":
      return l.incompleteImportNeedsReview;
    case "App category":
      return l.appCategory;
    case "Setting":
      return l.setting;
    case "Confirmed setting":
      return l.confirmedSetting;
    case "Confirm and save review":
      return l.confirmAndSaveReview;
    case "Only app category and setting are saved. Existing Google details are not stored.":
      return l
          .onlyAppCategoryAndSettingAreSavedExistingGoogleDetailsAreNotStored;
    case "Load / retry live details":
      return l.loadRetryLiveDetails;
    case "Load live details to see the name and address.":
      return l.loadLiveDetailsToSeeTheNameAndAddress;
    case "How to review categories and settings":
      return l.howToReviewCategoriesAndSettings;
    case "Open Review on a saved place. Load live details, check the suggestion, then confirm its category and setting. No bulk changes are made.":
      return l
          .openReviewOnASavedPlaceLoadLiveDetailsCheckTheSuggestionThenConfirmItsCategoryAndSettingNo;
    case "Saved Places Inspector":
      return l.savedPlacesInspector;
    case "View admin-synced places & inspect saved data":
      return l.viewAdminSyncedPlacesInspectSavedData;
    case "Stored database information":
      return l.storedDatabaseInformation;
    case "Database unavailable. Reconnect to check your saved places.":
      return l.databaseUnavailableReconnectToCheckYourSavedPlaces;
    case "Unable to read saved places. Refresh the database list before starting another import.":
      return l
          .unableToReadSavedPlacesRefreshTheDatabaseListBeforeStartingAnotherImport;
    case "Saved places are unavailable. Try again later.":
      return l.savedPlacesAreUnavailableTryAgainLater;
    case "Saved place IDs and app categories. Google details were not stored.":
      return l.savedPlaceIdsAndAppCategoriesGoogleDetailsWereNotStored;
    case "Saved Google place":
      return l.savedGooglePlace;
    case "Checking database schema...":
      return l.checkingDatabaseSchema;
    case "Reading saved database...":
      return l.readingSavedDatabase;
    case "Checking verified Google allowance…":
      return l.checkingVerifiedGoogleAllowance;
    case "Checking…":
      return l.checking;
    case "Keep existing data":
      return l.keepExistingData;
    case "Sync again":
      return l.syncAgain;
    case "Syncing places...":
      return l.syncingPlaces;
    case "Syncing...":
      return l.syncing;
    case "This state already has stored places, but its previous sync time was not recorded. Syncing again will use Google API quota.":
      return l
          .thisStateAlreadyHasStoredPlacesButItsPreviousSyncTimeWasNotRecordedSyncingAgainWillUseGoog;
    case "This state has no saved records. Syncing it will use Google API quota.":
      return l.thisStateHasNoSavedRecordsSyncingItWillUseGoogleApiQuota;
    case "Older imports have no recorded date. Check the existing places before syncing again.":
      return l
          .olderImportsHaveNoRecordedDateCheckTheExistingPlacesBeforeSyncingAgain;
    case "Some older imports have unverified countries or states. These are marked for review; repeating the full sync will not repair them.":
      return l
          .someOlderImportsHaveUnverifiedCountriesOrStatesTheseAreMarkedForReviewRepeatingTheFullSync;
    case "Showing saved history; cloud history is unavailable.":
      return l.showingSavedHistoryCloudHistoryIsUnavailable;
    case "Timestamp saved on this device only.":
      return l.timestampSavedOnThisDeviceOnly;
    case "Fetch & Sync is blocked until the current Google allowance is verified with at least 48 requests remaining. Saved IDs and schedules remain available.":
      return l
          .fetchSyncIsBlockedUntilTheCurrentGoogleAllowanceIsVerifiedWithAtLeast48RequestsRemainingSa;
    case "Pending sync — tap Fetch and save":
      return l.pendingSyncTapFetchAndSave;
    case "Fetch and save this page":
      return l.fetchAndSaveThisPage;
    case "Fetching...":
      return l.fetching;
    case "Loading names…":
      return l.loadingNames;
    case "Loads up to 20 names from Google using the current allowance.":
      return l.loadsUpTo20NamesFromGoogleUsingTheCurrentAllowance;
    case "Previous 20":
      return l.previous20;
    case "Next 20":
      return l.next20;
    case "Import stopped":
      return l.importStopped;
    case "Manually discover Google places for the selected state. Save IDs and app categories; load current details when needed.":
      return l
          .manuallyDiscoverGooglePlacesForTheSelectedStateSaveIdsAndAppCategoriesLoadCurrentDetailsWh;
    case "Deleting records from Supabase":
      return l.deletingRecordsFromSupabase;
    case "Error deleting places":
      return l.errorDeletingPlaces;
    case "Batch Cache Real Photos":
      return l.batchCacheRealPhotos;
    case "Cache Top 30 Photos":
      return l.cacheTop30Photos;
    case "Caching photos…":
      return l.cachingPhotos;
    case "Downloads official Google photos for top places and saves them to Supabase Storage. Places already cached are skipped automatically to conserve your API quota.":
      return l
          .downloadsOfficialGooglePhotosForTopPlacesAndSavesThemToSupabaseStoragePlacesAlreadyCachedA;
    case "Auto-Save Top 5 Highlights":
      return l.autoSaveTop5Highlights;
    case "Retrieve":
      return l.retrieve;
    case "Retrieved Places":
      return l.retrievedPlaces;
    case "No places retrieved yet.":
      return l.noPlacesRetrievedYet;
    case "Live Google Places API active for Malaysia":
      return l.liveGooglePlacesApiActiveForMalaysia;
    case "Raw JSON Output":
      return l.rawJsonOutput;
    case "Hide Raw Logs":
      return l.hideRawLogs;
    case "Select a destination in Malaysia or simulate GPS positions.":
      return l.selectADestinationInMalaysiaOrSimulateGpsPositions;
    case "Mock Device coordinates in Malaysia":
      return l.mockDeviceCoordinatesInMalaysia;
    case "13 States + KL":
      return l.text13StatesKl;
    case "📍 Simulate GPS":
      return l.simulateGps;
    case "🗺️ Browse States":
      return l.browseStates;
    case "🏠 Indoor":
      return l.indoor2;
    case "🏢 Indoor":
      return l.indoor3;
    case "☀️ Outdoor":
      return l.outdoor2;
    case "✨ Top Rated":
      return l.topRated;
    case "🏛️ Sights":
      return l.sights;
    case "🌳 Nature":
      return l.nature2;
    case "🍔 Food":
      return l.food2;
    case "☕ Cafes":
      return l.cafes;
    case "🛍️ Shops":
      return l.shops;
    case "👑 Admin":
      return l.admin;
    case "❓ Review":
      return l.review2;
    case "UC100 Flow Testing Tools":
      return l.uc100FlowTestingTools;
    case "UC200 Flow Testing Tools":
      return l.uc200FlowTestingTools;
    case "UC300 Flow Testing Tools":
      return l.uc300FlowTestingTools;
    case "Quickly test messages M1–M6 & alternative flows A1–A3":
      return l.quicklyTestMessagesM1M6AlternativeFlowsA1A3;
    case "Quickly test messages M1–M6 & alternative flows A1–A5":
      return l.quicklyTestMessagesM1M6AlternativeFlowsA1A5;
    case "Quickly test messages M1–M8 & alternative flows A1–A7":
      return l.quicklyTestMessagesM1M8AlternativeFlowsA1A7;
    case "Fill Valid Credentials":
      return l.fillValidCredentials;
    case "Fill Valid Form":
      return l.fillValidForm;
    case "Test A1 (Empty Fields)":
      return l.testA1EmptyFields;
    case "Test A2 (Bad Destination)":
      return l.testA2BadDestination;
    case "Test A2 (Invalid Email)":
      return l.testA2InvalidEmail;
    case "Test A3 (Invalid Days)":
      return l.testA3InvalidDays;
    case "Test A3 (No Account)":
      return l.testA3NoAccount;
    case "Test A3 (Weak Pwd)":
      return l.testA3WeakPwd;
    case "Test A3 (Wrong Password)":
      return l.testA3WrongPassword;
    case "Test A4 (Bad Time Range)":
      return l.testA4BadTimeRange;
    case "Test A4 (Mismatch)":
      return l.testA4Mismatch;
    case "Test A5 (Email Exists)":
      return l.testA5EmailExists;
    case "Test A5 (No Interests)":
      return l.testA5NoInterests;
    case "Test A7 (Transit)":
      return l.testA7Transit;
    case "Recognize sends this photo to Google Vision through our secure service. Only result text is saved in your local history; the photo is not stored by the app.":
      return l
          .recognizeSendsThisPhotoToGoogleVisionThroughOurSecureServiceOnlyResultTextIsSavedInYourLoc;
    case "Already Ran It? Tap to Refresh & Dismiss":
      return l.alreadyRanItTapToRefreshDismiss;
    case "Demo Info: Tap Log In to sign in with pre-filled test user.":
      return l.demoInfoTapLogInToSignInWithPreFilledTestUser;
    case "Missing Review Count Column in Supabase":
      return l.missingReviewCountColumnInSupabase;
    case "SQL command copied to clipboard!":
      return l.sqlCommandCopiedToClipboard;
    case "Supabase Row-Level Security (RLS) Locked":
      return l.supabaseRowLevelSecurityRlsLocked;
    case "To allow saving places, run this 1-line command in your Supabase SQL Editor:":
      return l.toAllowSavingPlacesRunThis1LineCommandInYourSupabaseSqlEditor;
    case "8 AM – 10 PM":
      return l.text8Am10Pm;
    case "9 AM – 6 PM":
      return l.text9Am6Pm;
    case "9 AM – 9 PM":
      return l.text9Am9Pm;
    case "• Weather alert: light rain expected after 3 PM.\n• Route updated: Jalan Alor moved earlier to avoid crowds.\n• Reminder: Batu Caves opens at 7:00 AM tomorrow.":
      return l
          .weatherAlertLightRainExpectedAfter3PmRouteUpdatedJalanAlorMovedEarlierToAvoidCrowdsReminde;
    case "here":
      return l.here;
    case "this area":
      return l.thisArea;
    case "Forecast unavailable":
      return l.forecastUnavailable;
    case "Outdoor Friendly":
      return l.outdoorFriendly;
    case "High Rain Risk (Indoor Recommended)":
      return l.highRainRiskIndoorRecommended;
    case "Scattered Showers (Carry Umbrella)":
      return l.scatteredShowersCarryUmbrella;
    case "Partly Cloudy":
      return l.partlyCloudy;
    case "No additional places fit this day. Try fewer days or wider daily hours.":
      return l.noAdditionalPlacesFitThisDayTryFewerDaysOrWiderDailyHours;
    case "Forecast unavailable for this date; weather filtering was not applied.":
      return l.forecastUnavailableForThisDateWeatherFilteringWasNotApplied;
    case "Travel times are distance-based estimates.":
      return l.travelTimesAreDistanceBasedEstimates;
    case "Some opening hours are unverified. Confirm before visiting.":
      return l.someOpeningHoursAreUnverifiedConfirmBeforeVisiting;
    case "Costs are planning estimates, excluding accommodation and travel to the first stop.":
      return l
          .costsArePlanningEstimatesExcludingAccommodationAndTravelToTheFirstStop;
    case "Itinerary saved successfully to your profile!":
      return l.itinerarySavedSuccessfullyToYourProfile;
    case "Saved on this device. Cloud sync is pending.":
      return l.savedOnThisDeviceCloudSyncIsPending;
    case "Unable to save itinerary on this device. Please try again.":
      return l.unableToSaveItineraryOnThisDevicePleaseTryAgain;
    case "Saved itinerary loaded successfully.":
      return l.savedItineraryLoadedSuccessfully;
    case "You have no saved trips yet. Tap \"Plan a Trip\" to generate your first itinerary!":
      return l.youHaveNoSavedTripsYetTapPlanATripToGenerateYourFirstItinerary;
    case "Unable to load saved trips. Please try again.":
      return l.unableToLoadSavedTripsPleaseTryAgain;
    case "Saved trip could not be found.":
      return l.savedTripCouldNotBeFound;
    case "All saved places updated.":
      return l.allSavedPlacesUpdated;
    case "Pass finished with issues. Retry to review failed places.":
      return l.passFinishedWithIssuesRetryToReviewFailedPlaces;
    case "Paused. Resume to continue from the next place.":
      return l.pausedResumeToContinueFromTheNextPlace;
    case "Unable to save progress. Stop and retry before continuing.":
      return l.unableToSaveProgressStopAndRetryBeforeContinuing;
    case "Skipped by administrator; existing data preserved.":
      return l.skippedByAdministratorExistingDataPreserved;
    case "This state is already updating.":
      return l.thisStateIsAlreadyUpdating;
    case "Stopped before refresh started.":
      return l.stoppedBeforeRefreshStarted;
    case "landmark":
      return l.landmark;
    case "dish":
      return l.dish;
    case "Show password":
      return l.showPassword;
    case "Hide password":
      return l.hidePassword;
    case "Please enter a travel question or tap a suggestion.":
      return l.pleaseEnterATravelQuestionOrTapASuggestion;
    case "Prompt is too short. Please be more specific.":
      return l.promptIsTooShortPleaseBeMoreSpecific;
    case "Active Smart Itinerary":
      return l.activeSmartItinerary;
    case "3 days personalized schedule":
      return l.text3DaysPersonalizedSchedule;
    case "5 days cultural schedule":
      return l.text5DaysCulturalSchedule;
    case "7 days island schedule":
      return l.text7DaysIslandSchedule;
    case "Heritage & Street Art Route":
      return l.heritageStreetArtRoute;
    case "Beach & Nature Excursion":
      return l.beachNatureExcursion;
    case "Estimated for 1 day · per person":
      return l.estimatedFor1DayPerPerson;
    case "Scan":
      return l.scan;
    case "Identify Malaysian landmarks and local dishes":
      return l.identifyMalaysianLandmarksAndLocalDishes;
  }
  for (final entry in _messagePatterns) {
    final match = entry.$1.firstMatch(label);
    if (match != null) return entry.$2(l, match);
  }
  return label;
}

final _messagePatterns = <(RegExp, String Function(AppLocalizations, Match))>[
  (RegExp("^All\\ \\(([\\s\\S]*?)\\)\$"), (l, m) => l.allValue(m.group(1)!)),
  (RegExp("^Photo:\\ ([\\s\\S]*?)\$"), (l, m) => l.photoValue(m.group(1)!)),
  (RegExp("^Hello,\\ ([\\s\\S]*?)!\$"), (l, m) => l.helloValue(m.group(1)!)),
  (
    RegExp("^Welcome\\ back,\\ ([\\s\\S]*?)!\$"),
    (l, m) => l.welcomeBackValue(m.group(1)!),
  ),
  (
    RegExp("^Your\\ ([\\s\\S]*?)\\ Itinerary\\ is\\ Ready!\$"),
    (l, m) => l.yourValueItineraryIsReady(m.group(1)!),
  ),
  (RegExp("^Day\\ ([\\s\\S]*?)\$"), (l, m) => l.dayValue(m.group(1)!)),
  (
    RegExp("^Day\\ ([\\s\\S]*?)\\ Theme\$"),
    (l, m) => l.dayValueTheme(m.group(1)!),
  ),
  (
    RegExp("^Edit\\ Day\\ ([\\s\\S]*?)\$"),
    (l, m) => l.editDayValue(m.group(1)!),
  ),
  (
    RegExp("^Edit\\ Day\\ ([\\s\\S]*?)\\ Schedule\$"),
    (l, m) => l.editDayValueSchedule(m.group(1)!),
  ),
  (
    RegExp(
      "^Are\\ you\\ sure\\ you\\ want\\ to\\ delete\\ \"([\\s\\S]*?)\"\\?\$",
    ),
    (l, m) => l.areYouSureYouWantToDeleteValue(m.group(1)!),
  ),
  (
    RegExp(
      "^Cannot\\ save:\\ \"([\\s\\S]*?)\"\\ appears\\ multiple\\ times\\ today\\.\\ Please\\ remove\\ or\\ swap\\ the\\ duplicate\\ stop\\.\$",
    ),
    (l, m) => l
        .cannotSaveValueAppearsMultipleTimesTodayPleaseRemoveOrSwapTheDuplicateStop(
          m.group(1)!,
        ),
  ),
  (
    RegExp(
      "^Cannot\\ save:\\ \"([\\s\\S]*?)\"\\ is\\ already\\ scheduled\\ on\\ another\\ day\\ of\\ this\\ itinerary\\.\$",
    ),
    (l, m) => l.cannotSaveValueIsAlreadyScheduledOnAnotherDayOfThisItinerary(
      m.group(1)!,
    ),
  ),
  (
    RegExp("^Removed\\ \"([\\s\\S]*?)\"\\.\\ Times\\ updated\\.\$"),
    (l, m) => l.removedValueTimesUpdated(m.group(1)!),
  ),
  (
    RegExp("^Added\\ ([\\s\\S]*?)\\ to\\ Day\\ ([\\s\\S]*?)\$"),
    (l, m) => l.addedValueToDayValue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^Swapped\\ \"([\\s\\S]*?)\"\\ with\\ \"([\\s\\S]*?)\"\$"),
    (l, m) => l.swappedValueWithValue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp(
      "^Day\\ ([\\s\\S]*?)\\ plan\\ updated\\ \\(([\\s\\S]*?)\\ stops\\)\$",
    ),
    (l, m) => l.dayValuePlanUpdatedValueStops(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^Replacing\\ \"([\\s\\S]*?)\"\\ \\(([\\s\\S]*?)\\)\$"),
    (l, m) => l.replacingValueValue(m.group(1)!, m.group(2)!),
  ),
  (RegExp("^([\\s\\S]*?)\\ Days\$"), (l, m) => l.valueDays(m.group(1)!)),
  (
    RegExp("^([\\s\\S]*?)\\ days\\ itinerary\$"),
    (l, m) => l.valueDaysItinerary(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ hours\\ of\\ sightseeing\\ per\\ day\$"),
    (l, m) => l.valueHoursOfSightseeingPerDay(m.group(1)!),
  ),
  (
    RegExp(
      "^([\\s\\S]*?)\\ hours\\ ([\\s\\S]*?)\\ minutes\\ of\\ sightseeing\\ per\\ day\$",
    ),
    (l, m) =>
        l.valueHoursValueMinutesOfSightseeingPerDay(m.group(1)!, m.group(2)!),
  ),
  (RegExp("^([\\s\\S]*?)\\ min\$"), (l, m) => l.valueMin(m.group(1)!)),
  (RegExp("^([\\s\\S]*?)\\ h\$"), (l, m) => l.valueH(m.group(1)!)),
  (
    RegExp("^([\\s\\S]*?)\\ h\\ ([\\s\\S]*?)\\ min\$"),
    (l, m) => l.valueHValueMin(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ stops\\ •\\ RM\\ ([\\s\\S]*?)\\ estimated\$"),
    (l, m) => l.valueStopsRmValueEstimated(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^Above\\ \\~RM([\\s\\S]*?)\\ total\$"),
    (l, m) => l.aboveRmvalueTotal(m.group(1)!),
  ),
  (
    RegExp("^Up\\ to\\ \\~RM([\\s\\S]*?)\\ total\$"),
    (l, m) => l.upToRmvalueTotal(m.group(1)!),
  ),
  (
    RegExp("^\\~RM([\\s\\S]*?)\\ –\\ RM([\\s\\S]*?)\\ total\$"),
    (l, m) => l.rmvalueRmvalueTotal(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ km\\ •\\ ([\\s\\S]*?)\\ stops\$"),
    (l, m) => l.valueKmValueStops(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^\\~([\\s\\S]*?)\\ km\\ •\\ ([\\s\\S]*?)\\ stops\$"),
    (l, m) => l.valueKmValueStops2(m.group(1)!, m.group(2)!),
  ),
  (RegExp("^([\\s\\S]*?)\\ km\\ away\$"), (l, m) => l.valueKmAway(m.group(1)!)),
  (RegExp("^([\\s\\S]*?)\\ m\\ away\$"), (l, m) => l.valueMAway(m.group(1)!)),
  (
    RegExp("^([\\s\\S]*?)\\ km\\ •\\ \\~([\\s\\S]*?)\\ min\\ walk\$"),
    (l, m) => l.valueKmValueMinWalk(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp(
      "^Route\\ est:\\ ([\\s\\S]*?)\\ km\\ •\\ \\~([\\s\\S]*?)\\ min\\ driving\$",
    ),
    (l, m) => l.routeEstValueKmValueMinDriving(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp(
      "^No\\ attractions\\ match\\ \"([\\s\\S]*?)\"\\.\\ Try\\ checking\\ for\\ typos\\ or\\ searching\\ a\\ broader\\ term\\.\$",
    ),
    (l, m) =>
        l.noAttractionsMatchValueTryCheckingForTyposOrSearchingABroaderTerm(
          m.group(1)!,
        ),
  ),
  (
    RegExp(
      "^No\\ spots\\ found\\ in\\ this\\ category\\ near\\ ([\\s\\S]*?)\\.\\ Try\\ choosing\\ another\\ category\\ or\\ selecting\\ a\\ new\\ location\\.\$",
    ),
    (l, m) => l
        .noSpotsFoundInThisCategoryNearValueTryChoosingAnotherCategoryOrSelectingANewLocation(
          m.group(1)!,
        ),
  ),
  (
    RegExp("^Saved\\ \"([\\s\\S]*?)\"\\ to\\ your\\ list\\.\$"),
    (l, m) => l.savedValueToYourList(m.group(1)!),
  ),
  (
    RegExp("^Removed\\ \"([\\s\\S]*?)\"\\ from\\ Saved\\.\$"),
    (l, m) => l.removedValueFromSaved(m.group(1)!),
  ),
  (
    RegExp(
      "^Browse\\ attractions\\ in\\ ([\\s\\S]*?)\\ and\\ tap\\ \"Save\"\\ to\\ build\\ your\\ personalized\\ travel\\ wishlist\\.\$",
    ),
    (l, m) => l
        .browseAttractionsInValueAndTapSaveToBuildYourPersonalizedTravelWishlist(
          m.group(1)!,
        ),
  ),
  (
    RegExp("^Top\\ iconic\\ spots\\ in\\ ([\\s\\S]*?)\$"),
    (l, m) => l.topIconicSpotsInValue(m.group(1)!),
  ),
  (
    RegExp("^\\(([\\s\\S]*?)\\ reviews\\)\$"),
    (l, m) => l.valueReviews(m.group(1)!),
  ),
  (RegExp("^([\\s\\S]*?)\\ reviews\$"), (l, m) => l.valueReviews2(m.group(1)!)),
  (
    RegExp("^Rating:\\ ([\\s\\S]*?)\\ /\\ 5\$"),
    (l, m) => l.ratingValue5(m.group(1)!),
  ),
  (RegExp("^([\\s\\S]*?)\\ places\$"), (l, m) => l.valuePlaces(m.group(1)!)),
  (RegExp("^([\\s\\S]*?)\\ spots\$"), (l, m) => l.valueSpots(m.group(1)!)),
  (RegExp("^([\\s\\S]*?)\\ items\$"), (l, m) => l.valueItems(m.group(1)!)),
  (RegExp("^([\\s\\S]*?)\\ Items\$"), (l, m) => l.valueItems2(m.group(1)!)),
  (
    RegExp("^Matching\\ \"([\\s\\S]*?)\"\$"),
    (l, m) => l.matchingValue(m.group(1)!),
  ),
  (
    RegExp("^Assistant\\ language\\ set\\ to\\ ([\\s\\S]*?)\\.\$"),
    (l, m) => l.assistantLanguageSetToValue(m.group(1)!),
  ),
  (RegExp("^([\\s\\S]*?)%\\ Rain\$"), (l, m) => l.valueRain(m.group(1)!)),
  (
    RegExp("^History\\ \\(([\\s\\S]*?)\\)\$"),
    (l, m) => l.historyValue(m.group(1)!),
  ),
  (
    RegExp("^Vision\\ confidence\\ ([\\s\\S]*?)%\$"),
    (l, m) => l.visionConfidenceValue(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Adult([\\s\\S]*?)\$"),
    (l, m) => l.valueAdultvalue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Child([\\s\\S]*?)\$"),
    (l, m) => l.valueChildvalue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Senior([\\s\\S]*?)\$"),
    (l, m) => l.valueSeniorvalue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ added\\ to\\ your\\ plan\\ draft!\$"),
    (l, m) => l.valueAddedToYourPlanDraft(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ added\\ to\\ your\\ Day\\ 2\\ schedule\\ draft!\$"),
    (l, m) => l.valueAddedToYourDay2ScheduleDraft(m.group(1)!),
  ),
  (
    RegExp("^Showing\\ Day\\ ([\\s\\S]*?)\\ Plan\\ for\\ ([\\s\\S]*?)\$"),
    (l, m) => l.showingDayValuePlanForValue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^Switched\\ to\\ ([\\s\\S]*?)\\ \\(([\\s\\S]*?)\\ Days\\)\$"),
    (l, m) => l.switchedToValueValueDays(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^Swap\\ to\\ indoor:\\ ([\\s\\S]*?)\$"),
    (l, m) => l.swapToIndoorValue(m.group(1)!),
  ),
  (
    RegExp(
      "^Rain\\-safe\\ schedule\\ applied:\\ ([\\s\\S]*?)\\ swapped\\ in\\ for\\ afternoon\\.\$",
    ),
    (l, m) => l.rainSafeScheduleAppliedValueSwappedInForAfternoon(m.group(1)!),
  ),
  (
    RegExp("^Discover\\ More\\ Places\\ in\\ ([\\s\\S]*?)\$"),
    (l, m) => l.discoverMorePlacesInValue(m.group(1)!),
  ),
  (
    RegExp("^Update\\ saved\\ places\\ in\\ ([\\s\\S]*?)\$"),
    (l, m) => l.updateSavedPlacesInValue(m.group(1)!),
  ),
  (
    RegExp("^Google\\ type:\\ ([\\s\\S]*?)\$"),
    (l, m) => l.googleTypeValue(m.group(1)!),
  ),
  (
    RegExp(
      "^Setting\\ suggestion:\\ ([\\s\\S]*?)\\ —\\ confirm\\ using\\ your\\ knowledge;\\ this\\ is\\ not\\ verified\\.\$",
    ),
    (l, m) =>
        l.settingSuggestionValueConfirmUsingYourKnowledgeThisIsNotVerified(
          m.group(1)!,
        ),
  ),
  (
    RegExp("^Places\\ in\\ Database\\ \\(([\\s\\S]*?)\\)\$"),
    (l, m) => l.placesInDatabaseValue(m.group(1)!),
  ),
  (
    RegExp("^Places\\ in\\ ([\\s\\S]*?)\$"),
    (l, m) => l.placesInValue(m.group(1)!),
  ),
  (
    RegExp("^No\\ places\\ stored\\ for\\ ([\\s\\S]*?)\\ yet\\.\$"),
    (l, m) => l.noPlacesStoredForValueYet(m.group(1)!),
  ),
  (
    RegExp("^No\\ saved\\ places\\ found\\ in\\ ([\\s\\S]*?)\\.\$"),
    (l, m) => l.noSavedPlacesFoundInValue(m.group(1)!),
  ),
  (
    RegExp("^Database\\ Count\\ for\\ ([\\s\\S]*?):\$"),
    (l, m) => l.databaseCountForValue(m.group(1)!),
  ),
  (
    RegExp("^Refreshing\\ the\\ ([\\s\\S]*?)\\ database\\ list\$"),
    (l, m) => l.refreshingTheValueDatabaseList(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ database\\ list\\ refreshed\$"),
    (l, m) => l.valueDatabaseListRefreshed(m.group(1)!),
  ),
  (
    RegExp("^Checking\\ sync\\ history\\ for\\ ([\\s\\S]*?)…\$"),
    (l, m) => l.checkingSyncHistoryForValue(m.group(1)!),
  ),
  (
    RegExp("^Sync\\ ([\\s\\S]*?)\\ again\\?\$"),
    (l, m) => l.syncValueAgain(m.group(1)!),
  ),
  (
    RegExp(
      "^Last\\ successful\\ sync:\\ ([\\s\\S]*?)\\ \\(([\\s\\S]*?)\\)\\.\\\n\\\nSyncing\\ again\\ will\\ use\\ Google\\ API\\ quota\\.\\ You\\ can\\ keep\\ the\\ existing\\ data\\ instead\\.\$",
    ),
    (l, m) => l
        .lastSuccessfulSyncValueValueSyncingAgainWillUseGoogleApiQuotaYouCanKeepTheExistingDataInst(
          m.group(1)!,
          m.group(2)!,
        ),
  ),
  (
    RegExp("^Fetch/save\\ failed:\\ ([\\s\\S]*?)\$"),
    (l, m) => l.fetchSaveFailedValue(m.group(1)!),
  ),
  (
    RegExp("^Querying\\ top\\ places\\ in\\ ([\\s\\S]*?)…\$"),
    (l, m) => l.queryingTopPlacesInValue(m.group(1)!),
  ),
  (
    RegExp("^Searching\\ Google\\ for\\ ([\\s\\S]*?)\$"),
    (l, m) => l.searchingGoogleForValue(m.group(1)!),
  ),
  (
    RegExp("^Clear\\ ([\\s\\S]*?)\\ Places\\?\$"),
    (l, m) => l.clearValuePlaces(m.group(1)!),
  ),
  (
    RegExp(
      "^This\\ will\\ delete\\ all\\ cached\\ places\\ for\\ ([\\s\\S]*?)\\ from\\ the\\ Supabase\\ database\\.\$",
    ),
    (l, m) => l.thisWillDeleteAllCachedPlacesForValueFromTheSupabaseDatabase(
      m.group(1)!,
    ),
  ),
  (
    RegExp("^Clearing\\ places\\ for\\ ([\\s\\S]*?)\\.\\.\\.\$"),
    (l, m) => l.clearingPlacesForValue(m.group(1)!),
  ),
  (
    RegExp("^All\\ cached\\ places\\ for\\ ([\\s\\S]*?)\\ removed\$"),
    (l, m) => l.allCachedPlacesForValueRemoved(m.group(1)!),
  ),
  (
    RegExp("^Error\\ loading\\ places:\\ ([\\s\\S]*?)\$"),
    (l, m) => l.errorLoadingPlacesValue(m.group(1)!),
  ),
  (
    RegExp("^Caching\\ real\\ photos\\ \\(0/([\\s\\S]*?)\\)…\$"),
    (l, m) => l.cachingRealPhotos0Value(m.group(1)!),
  ),
  (
    RegExp(
      "^Cached\\ ([\\s\\S]*?)\\ of\\ ([\\s\\S]*?)\\ inspected\\ \\(([\\s\\S]*?)\\ target\\)…\$",
    ),
    (l, m) => l.cachedValueOfValueInspectedValueTarget(
      m.group(1)!,
      m.group(2)!,
      m.group(3)!,
    ),
  ),
  (
    RegExp(
      "^Finished!\\ ([\\s\\S]*?)\\ real\\ photos\\ cached\\ to\\ Supabase\\ Storage\\.\$",
    ),
    (l, m) => l.finishedValueRealPhotosCachedToSupabaseStorage(m.group(1)!),
  ),
  (
    RegExp(
      "^Paused\\ photo\\ caching\\.\\ Cached\\ ([\\s\\S]*?)\\ photos\\.\$",
    ),
    (l, m) => l.pausedPhotoCachingCachedValuePhotos(m.group(1)!),
  ),
  (
    RegExp("^Photo\\ caching\\ failed:\\ ([\\s\\S]*?)\$"),
    (l, m) => l.photoCachingFailedValue(m.group(1)!),
  ),
  (
    RegExp("^Saved\\ ([\\s\\S]*?)\\ top\\ highlights\\ to\\ your\\ list!\$"),
    (l, m) => l.savedValueTopHighlightsToYourList(m.group(1)!),
  ),
  (
    RegExp("^View\\ Raw\\ Terminal\\ Logs\\ \\(([\\s\\S]*?)\\ lines\\)\$"),
    (l, m) => l.viewRawTerminalLogsValueLines(m.group(1)!),
  ),
  (
    RegExp("^Detected\\ state:\\ ([\\s\\S]*?)\$"),
    (l, m) => l.detectedStateValue(m.group(1)!),
  ),
  (
    RegExp("^🏛️\\ Indoor\\ \\(([\\s\\S]*?)\\)\$"),
    (l, m) => l.indoorValue(m.group(1)!),
  ),
  (
    RegExp("^🏞️\\ Outdoor\\ \\(([\\s\\S]*?)\\)\$"),
    (l, m) => l.outdoorValue(m.group(1)!),
  ),
  (
    RegExp(
      "^([\\s\\S]*?)\\ updated\\ ·\\ ([\\s\\S]*?)\\ need\\ review\\ ·\\ ([\\s\\S]*?)\\ remaining\$",
    ),
    (l, m) => l.valueUpdatedValueNeedReviewValueRemaining(
      m.group(1)!,
      m.group(2)!,
      m.group(3)!,
    ),
  ),
  (
    RegExp("^Skip\\ place\\ \\(([\\s\\S]*?)\\)\\ and\\ continue\$"),
    (l, m) => l.skipPlaceValueAndContinue(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Top\\ Picks\$"),
    (l, m) => l.valueTopPicks(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Custom\\ Schedule\$"),
    (l, m) => l.valueCustomSchedule(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Smart\\ Schedule\$"),
    (l, m) => l.valueSmartSchedule(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Day\\ ([\\s\\S]*?)\\ Highlights\$"),
    (l, m) => l.valueDayValueHighlights(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Your\\ scheduled\\ time\\ remains\\ saved\\.\$"),
    (l, m) => l.valueYourScheduledTimeRemainsSaved(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ km\\ •\\ ([\\s\\S]*?)\\ min([\\s\\S]*?)\$"),
    (l, m) => l.valueKmValueMinvalue(m.group(1)!, m.group(2)!, m.group(3)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ —\\ last\\ synced\\ ([\\s\\S]*?)\$"),
    (l, m) => l.valueLastSyncedValue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ —\\ sync\\ time\\ not\\ recorded\$"),
    (l, m) => l.valueSyncTimeNotRecorded(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ ([\\s\\S]*?)\\ saved\\ in\\ ([\\s\\S]*?)\$"),
    (l, m) => l.valueValueSavedInValue(m.group(1)!, m.group(2)!, m.group(3)!),
  ),
  (
    RegExp(
      "^([\\s\\S]*?)\\\n([\\s\\S]*?)\\ places\\ found\\ ·\\ ([\\s\\S]*?)\\ search\\ requests\\ in\\ that\\ sync\\.\\\nReview\\ the\\ existing\\ places\\ before\\ using\\ more\\ API\\ quota\\.\$",
    ),
    (l, m) => l
        .valueValuePlacesFoundValueSearchRequestsInThatSyncReviewTheExistingPlacesBeforeUsingMoreAp(
          m.group(1)!,
          m.group(2)!,
          m.group(3)!,
        ),
  ),
  (
    RegExp("^([\\s\\S]*?)–([\\s\\S]*?)\\ of\\ ([\\s\\S]*?)\$"),
    (l, m) => l.valueValueOfValue(m.group(1)!, m.group(2)!, m.group(3)!),
  ),
  (
    RegExp(
      "^Category:\\ ([\\s\\S]*?)\\\nLocation:\\ \\(([\\s\\S]*?),\\ ([\\s\\S]*?)\\)\$",
    ),
    (l, m) => l.categoryValueLocationValueValue(
      m.group(1)!,
      m.group(2)!,
      m.group(3)!,
    ),
  ),
  (
    RegExp(
      "^Places\\ in\\ ([\\s\\S]*?)\\ are\\ currently\\ saved\\ without\\ review\\ counts\\.\\ To\\ rank\\ by\\ Popularity\\ Score\\ and\\ display\\ reviews\\ \\(e\\.g\\.\\ 12\\.4k\\),\\ run\\ this\\ in\\ Supabase\\ SQL\\ Editor\\ and\\ tap\\ Fetch\\ \\&\\ Sync\\ again:\$",
    ),
    (l, m) => l
        .placesInValueAreCurrentlySavedWithoutReviewCountsToRankByPopularityScoreAndDisplayReviewsE(
          m.group(1)!,
        ),
  ),
  (
    RegExp("^Estimated\\ for\\ ([\\s\\S]*?)\\ days\\ ·\\ per\\ person\$"),
    (l, m) => l.estimatedForValueDaysPerPerson(m.group(1)!),
  ),
  (
    RegExp(
      "^Skipped\\ ([\\s\\S]*?)\\.\\ Resume\\ to\\ continue\\ updating\\ places\\ in\\ ([\\s\\S]*?)\\.\$",
    ),
    (l, m) => l.skippedValueResumeToContinueUpdatingPlacesInValue(
      m.group(1)!,
      m.group(2)!,
    ),
  ),
  (
    RegExp(
      "^Google\\ place\\ unavailable\\ \\(([\\s\\S]*?)\\);\\ existing\\ data\\ preserved\\.\$",
    ),
    (l, m) => l.googlePlaceUnavailableValueExistingDataPreserved(m.group(1)!),
  ),
  (
    RegExp("^([\\s\\S]*?)\\ Resume\\ to\\ retry\\ ([\\s\\S]*?)\\.\$"),
    (l, m) => l.valueResumeToRetryValue(m.group(1)!, m.group(2)!),
  ),
  (
    RegExp(
      "^Returned\\ ([\\s\\S]*?)\\ ·\\ state\\ accepted\\ ([\\s\\S]*?)\\ ·\\ unique\\ ([\\s\\S]*?)\\ ·\\ wrong\\ state\\ ([\\s\\S]*?)\\ ·\\ invalid\\ ([\\s\\S]*?)\\ ·\\ category\\ review\\ ([\\s\\S]*?)\$",
    ),
    (l, m) => l
        .returnedValueStateAcceptedValueUniqueValueWrongStateValueInvalidValueCategoryReviewValue(
          m.group(1)!,
          m.group(2)!,
          m.group(3)!,
          m.group(4)!,
          m.group(5)!,
          m.group(6)!,
        ),
  ),
];
