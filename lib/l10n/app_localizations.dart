import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Musallam Delivery'**
  String get appTitleDefault;

  /// No description provided for @appSubtitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Delivery Partner'**
  String get appSubtitleDefault;

  /// No description provided for @loginHintDefault.
  ///
  /// In en, this message translates to:
  /// **'Enter your ID and passcode from admin'**
  String get loginHintDefault;

  /// No description provided for @maintenanceMessageDefault.
  ///
  /// In en, this message translates to:
  /// **'The driver app is temporarily unavailable. Please try again later.'**
  String get maintenanceMessageDefault;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutQuestion;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @comingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'{featureName} is coming soon.'**
  String comingSoonMessage(String featureName);

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @serverUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Server update required. Contact support.'**
  String get serverUpdateRequired;

  /// No description provided for @contactAdmin.
  ///
  /// In en, this message translates to:
  /// **'Contact your admin for details.'**
  String get contactAdmin;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support.'**
  String get contactSupport;

  /// No description provided for @notificationFallback.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationFallback;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get now;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReview;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @driverFallback.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverFallback;

  /// No description provided for @orderIdPrefix.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId}'**
  String orderIdPrefix(String orderId);

  /// No description provided for @deliverySingular.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliverySingular;

  /// No description provided for @deliveryPlural.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveryPlural;

  /// No description provided for @deliveriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Delivery} other{{count} Deliveries}}'**
  String deliveriesCount(int count);

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @verifyIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify identity'**
  String get verifyIdentityTitle;

  /// No description provided for @verifyIdentityMessage.
  ///
  /// In en, this message translates to:
  /// **'Look at the camera and blink once to prove you are present. A photo is taken after a successful blink. Required once per day.'**
  String get verifyIdentityMessage;

  /// No description provided for @verifyIdentityPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to verify your identity. Grant camera access to continue. You cannot skip this step.'**
  String get verifyIdentityPermissionDenied;

  /// No description provided for @verifyIdentityBlinkInstruction.
  ///
  /// In en, this message translates to:
  /// **'Blink once'**
  String get verifyIdentityBlinkInstruction;

  /// No description provided for @verifyIdentityFaceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Position your face in the frame'**
  String get verifyIdentityFaceNotFound;

  /// No description provided for @verifyIdentityBlinkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Blink not detected, try again'**
  String get verifyIdentityBlinkTimeout;

  /// No description provided for @verifyIdentityInitError.
  ///
  /// In en, this message translates to:
  /// **'Camera or face detection failed to start. Tap retry to try again. You cannot skip this step.'**
  String get verifyIdentityInitError;

  /// No description provided for @verifyIdentityBlinkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Blink detected'**
  String get verifyIdentityBlinkSuccess;

  /// No description provided for @verifyIdentityRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get verifyIdentityRetake;

  /// No description provided for @verifyIdentityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm photo'**
  String get verifyIdentityConfirm;

  /// No description provided for @verifyIdentitySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving photo…'**
  String get verifyIdentitySaving;

  /// No description provided for @chooseImageSource.
  ///
  /// In en, this message translates to:
  /// **'Choose Image Source'**
  String get chooseImageSource;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @imgLabel.
  ///
  /// In en, this message translates to:
  /// **'IMG'**
  String get imgLabel;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @uploadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {percent}%'**
  String uploadingProgress(int percent);

  /// No description provided for @readyToUpload.
  ///
  /// In en, this message translates to:
  /// **'Ready to upload'**
  String get readyToUpload;

  /// No description provided for @readyToUploadWithSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{sizeKb} KB · Ready to upload'**
  String readyToUploadWithSizeKb(String sizeKb);

  /// No description provided for @readyToUploadWithSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{sizeMb} MB · Ready to upload'**
  String readyToUploadWithSizeMb(String sizeMb);

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty'**
  String get fileEmpty;

  /// No description provided for @fileTooLarge10Mb.
  ///
  /// In en, this message translates to:
  /// **'Image must be 10 MB or smaller'**
  String get fileTooLarge10Mb;

  /// No description provided for @fileTooLarge2Mb.
  ///
  /// In en, this message translates to:
  /// **'Profile image must be 2 MB or smaller'**
  String get fileTooLarge2Mb;

  /// No description provided for @imagesAllowedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only JPG, PNG, or WebP images are allowed'**
  String get imagesAllowedOnly;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @driverId.
  ///
  /// In en, this message translates to:
  /// **'Driver ID'**
  String get driverId;

  /// No description provided for @employeeId.
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get employeeId;

  /// No description provided for @passcode.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcode;

  /// No description provided for @passcodeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code from your admin panel'**
  String get passcodeHint;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @deviceConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Already signed in elsewhere'**
  String get deviceConflictTitle;

  /// No description provided for @deviceConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'This account is active on another device. You can continue using that device or sign in here instead.'**
  String get deviceConflictMessage;

  /// No description provided for @deviceConflictActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active device: {device}'**
  String deviceConflictActiveLabel(String device);

  /// No description provided for @deviceConflictLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last active: {date} at {time}'**
  String deviceConflictLastSeen(String date, String time);

  /// No description provided for @deviceConflictUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get deviceConflictUnknownDevice;

  /// No description provided for @deviceConflictContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue on other device'**
  String get deviceConflictContinueButton;

  /// No description provided for @deviceConflictSignInHereButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in here'**
  String get deviceConflictSignInHereButton;

  /// No description provided for @signedInOnAnotherDeviceToast.
  ///
  /// In en, this message translates to:
  /// **'Signed in on another device. Please sign in again.'**
  String get signedInOnAnotherDeviceToast;

  /// No description provided for @enterDriverId.
  ///
  /// In en, this message translates to:
  /// **'Enter your 5-digit driver ID.'**
  String get enterDriverId;

  /// No description provided for @enterEmployeeId.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4–8 digit employee ID.'**
  String get enterEmployeeId;

  /// No description provided for @enterPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter your 6-digit passcode.'**
  String get enterPasscode;

  /// No description provided for @authNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'App is not configured. Add SUPABASE_ANON_KEY when running.'**
  String get authNotConfigured;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid employee ID or passcode. Please try again.'**
  String get authInvalidCredentials;

  /// No description provided for @authDriverNotActive.
  ///
  /// In en, this message translates to:
  /// **'Your driver account is not active yet. Contact your admin.'**
  String get authDriverNotActive;

  /// No description provided for @authDriverSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your driver account has been suspended. Contact your administrator.'**
  String get authDriverSuspended;

  /// No description provided for @authStaffNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This account is for the admin panel only.'**
  String get authStaffNotAllowed;

  /// No description provided for @authProfileSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Signed in but profile setup failed. Contact support.'**
  String get authProfileSyncFailed;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get tabDeliveries;

  /// No description provided for @tabEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get tabEarnings;

  /// No description provided for @tabVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get tabVehicle;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @exitAppQuestion.
  ///
  /// In en, this message translates to:
  /// **'Exit app?'**
  String get exitAppQuestion;

  /// No description provided for @exitAppMessage.
  ///
  /// In en, this message translates to:
  /// **'You are offline and checked out. Exit the app?'**
  String get exitAppMessage;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @offlineModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Your changes are saved on the device and will sync automatically once you\'re back online.'**
  String get offlineModeDescription;

  /// No description provided for @accessBlocked.
  ///
  /// In en, this message translates to:
  /// **'Access blocked'**
  String get accessBlocked;

  /// No description provided for @accountBlockedDefault.
  ///
  /// In en, this message translates to:
  /// **'Your account has been blocked. Contact your admin for details.'**
  String get accountBlockedDefault;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @underMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Under maintenance'**
  String get underMaintenance;

  /// No description provided for @pullDownToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get pullDownToRefresh;

  /// No description provided for @developerModeDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer options must be off'**
  String get developerModeDetectedTitle;

  /// No description provided for @closeApp.
  ///
  /// In en, this message translates to:
  /// **'Close app'**
  String get closeApp;

  /// No description provided for @developerModeDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'This app cannot run while Developer options are enabled. Turn them off in your phone Settings (Developer options), then open the app again. For security and Play Store policy, sideloading and in-app APK updates have been removed — install updates only from Google Play.'**
  String get developerModeDetectedMessage;

  /// No description provided for @mockLocationDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock location detected'**
  String get mockLocationDetectedTitle;

  /// No description provided for @mockLocationDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'A mock location setting is enabled on this device. This has been recorded.'**
  String get mockLocationDetectedMessage;

  /// No description provided for @fakeGpsDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS detected'**
  String get fakeGpsDetectedTitle;

  /// No description provided for @fakeGpsDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS is detected. Delivery and location actions are blocked until it is turned off.'**
  String get fakeGpsDetectedMessage;

  /// No description provided for @fakeGpsBlockedAction.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS detected. Turn off mock location and try again.'**
  String get fakeGpsBlockedAction;

  /// No description provided for @screenCaptureBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen capture blocked'**
  String get screenCaptureBlockedTitle;

  /// No description provided for @screenCaptureBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Screenshots and screen recording are not allowed. This attempt has been recorded.'**
  String get screenCaptureBlockedMessage;

  /// No description provided for @sosComingSoon.
  ///
  /// In en, this message translates to:
  /// **'SOS coming soon'**
  String get sosComingSoon;

  /// No description provided for @couldNotStartDuty.
  ///
  /// In en, this message translates to:
  /// **'Could not clock in'**
  String get couldNotStartDuty;

  /// No description provided for @couldNotUpdateDutyStatus.
  ///
  /// In en, this message translates to:
  /// **'Could not update In/Out status'**
  String get couldNotUpdateDutyStatus;

  /// No description provided for @currentSpeed.
  ///
  /// In en, this message translates to:
  /// **'Current speed'**
  String get currentSpeed;

  /// No description provided for @distanceToday.
  ///
  /// In en, this message translates to:
  /// **'Distance today'**
  String get distanceToday;

  /// No description provided for @speedValue.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String speedValue(String speed);

  /// No description provided for @distanceValue.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String distanceValue(String distance);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get offline;

  /// No description provided for @sos.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sos;

  /// No description provided for @bonusOnTrackDefault.
  ///
  /// In en, this message translates to:
  /// **'You\'re on track — keep delivering to unlock bonuses'**
  String get bonusOnTrackDefault;

  /// No description provided for @addDelivery.
  ///
  /// In en, this message translates to:
  /// **'Add Delivery'**
  String get addDelivery;

  /// No description provided for @startDuty.
  ///
  /// In en, this message translates to:
  /// **'Clock in'**
  String get startDuty;

  /// No description provided for @thisWeeksProgress.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Progress'**
  String get thisWeeksProgress;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @onlineTime.
  ///
  /// In en, this message translates to:
  /// **'Time in'**
  String get onlineTime;

  /// No description provided for @weeklyBumperBonus.
  ///
  /// In en, this message translates to:
  /// **'Weekly Bumper Bonus'**
  String get weeklyBumperBonus;

  /// No description provided for @deliveredOrders.
  ///
  /// In en, this message translates to:
  /// **'Delivered Orders:'**
  String get deliveredOrders;

  /// No description provided for @fewMoreToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Just a few more to unlock your reward 💰'**
  String get fewMoreToUnlock;

  /// No description provided for @weeklyBonusUnlockedCelebration.
  ///
  /// In en, this message translates to:
  /// **'Weekly bonus unlocked 🎉'**
  String get weeklyBonusUnlockedCelebration;

  /// No description provided for @weeklyBonusUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Weekly bonus unlocked!'**
  String get weeklyBonusUnlocked;

  /// No description provided for @weeklyBonusUnlockedShort.
  ///
  /// In en, this message translates to:
  /// **'Weekly bonus unlocked'**
  String get weeklyBonusUnlockedShort;

  /// No description provided for @deliveriesAwayFromBonus.
  ///
  /// In en, this message translates to:
  /// **'You\'re {remaining} {remaining, plural, =1{delivery} other{deliveries}} away from {reward} KWD bonus'**
  String deliveriesAwayFromBonus(int remaining, String reward);

  /// No description provided for @deliverMoreToUnlockKd.
  ///
  /// In en, this message translates to:
  /// **'Deliver {remaining} more orders to unlock KD {reward} guaranteed'**
  String deliverMoreToUnlockKd(int remaining, String reward);

  /// No description provided for @weeklyBonusDefault.
  ///
  /// In en, this message translates to:
  /// **'Weekly Bonus'**
  String get weeklyBonusDefault;

  /// No description provided for @deliveryRuleDefault.
  ///
  /// In en, this message translates to:
  /// **'Delivery rule'**
  String get deliveryRuleDefault;

  /// No description provided for @deliveryRules.
  ///
  /// In en, this message translates to:
  /// **'Delivery Rules'**
  String get deliveryRules;

  /// No description provided for @allVerifiedCountTowardIncentives.
  ///
  /// In en, this message translates to:
  /// **'All verified deliveries count toward incentives'**
  String get allVerifiedCountTowardIncentives;

  /// No description provided for @countsTowardIncentiveDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Counts toward incentive deliveries'**
  String get countsTowardIncentiveDeliveries;

  /// No description provided for @outsideDeliveryAreaReturnSoon.
  ///
  /// In en, this message translates to:
  /// **'Outside zone. Return within 45 minutes.'**
  String get outsideDeliveryAreaReturnSoon;

  /// No description provided for @outsideDeliveryAreaReturnAfterDelivery.
  ///
  /// In en, this message translates to:
  /// **'Outside zone. Return within 20 minutes.'**
  String get outsideDeliveryAreaReturnAfterDelivery;

  /// No description provided for @zoneTimeoutCheckedOut.
  ///
  /// In en, this message translates to:
  /// **'You were checked out for staying outside your delivery area too long.'**
  String get zoneTimeoutCheckedOut;

  /// No description provided for @autoCheckoutOffline.
  ///
  /// In en, this message translates to:
  /// **'You were checked out automatically after being offline too long.'**
  String get autoCheckoutOffline;

  /// No description provided for @autoCheckoutOutOfZone.
  ///
  /// In en, this message translates to:
  /// **'You were checked out automatically after staying outside your assigned zone too long.'**
  String get autoCheckoutOutOfZone;

  /// No description provided for @completeMoreEarnMore.
  ///
  /// In en, this message translates to:
  /// **'Complete more. Earn more.'**
  String get completeMoreEarnMore;

  /// No description provided for @liveBonusQuestsToday.
  ///
  /// In en, this message translates to:
  /// **'Live bonus quests for today'**
  String get liveBonusQuestsToday;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @extraMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String extraMore(int count);

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @noActiveQuestsRightNow.
  ///
  /// In en, this message translates to:
  /// **'No active quests right now'**
  String get noActiveQuestsRightNow;

  /// No description provided for @tapToSeeAllOffers.
  ///
  /// In en, this message translates to:
  /// **'Tap to see all incentive offers — fresh ones drop every week.'**
  String get tapToSeeAllOffers;

  /// No description provided for @questUnlockedEarned.
  ///
  /// In en, this message translates to:
  /// **'Quest unlocked — earned {amount}'**
  String questUnlockedEarned(String amount);

  /// No description provided for @keepDeliveringEveryOrderPays.
  ///
  /// In en, this message translates to:
  /// **'Keep delivering — every order pays out'**
  String get keepDeliveringEveryOrderPays;

  /// No description provided for @keepDeliveringToEarnBonus.
  ///
  /// In en, this message translates to:
  /// **'Keep delivering to earn this bonus'**
  String get keepDeliveringToEarnBonus;

  /// No description provided for @remainingMoreToMaxEarnedSoFar.
  ///
  /// In en, this message translates to:
  /// **'{remaining} more to max — earned so far {amount}'**
  String remainingMoreToMaxEarnedSoFar(int remaining, String amount);

  /// No description provided for @remainingMoreToUnlock.
  ///
  /// In en, this message translates to:
  /// **'{remaining} more to unlock {amount}'**
  String remainingMoreToUnlock(int remaining, String amount);

  /// No description provided for @unlockReward.
  ///
  /// In en, this message translates to:
  /// **'Unlock {amount}'**
  String unlockReward(String amount);

  /// No description provided for @perDeliveryRate.
  ///
  /// In en, this message translates to:
  /// **'× {rate} / delivery'**
  String perDeliveryRate(String rate);

  /// No description provided for @periodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// No description provided for @periodThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get periodThisWeek;

  /// No description provided for @periodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get periodThisMonth;

  /// No description provided for @periodThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'This period'**
  String get periodThisPeriod;

  /// No description provided for @importantNotifications.
  ///
  /// In en, this message translates to:
  /// **'Important Notifications'**
  String get importantNotifications;

  /// No description provided for @couldNotLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications.'**
  String get couldNotLoadNotifications;

  /// No description provided for @allCaughtUpShort.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get allCaughtUpShort;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @viewMore.
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// No description provided for @couldNotLoadHomeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Could not load home dashboard'**
  String get couldNotLoadHomeDashboard;

  /// No description provided for @readyForDuty.
  ///
  /// In en, this message translates to:
  /// **'Ready to clock in'**
  String get readyForDuty;

  /// No description provided for @beforeYouGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Before you clock in'**
  String get beforeYouGoOnline;

  /// No description provided for @startDutyChecksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete these checks once to start tracking while In.'**
  String get startDutyChecksSubtitle;

  /// No description provided for @goOnlineChecksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are still clocked in. Fix anything below, then go In.'**
  String get goOnlineChecksSubtitle;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go In'**
  String get goOnline;

  /// No description provided for @refreshChecks.
  ///
  /// In en, this message translates to:
  /// **'Refresh checks'**
  String get refreshChecks;

  /// No description provided for @allChecksPassed.
  ///
  /// In en, this message translates to:
  /// **'All required checks passed ({ok}/{total}).'**
  String allChecksPassed(int ok, int total);

  /// No description provided for @someChecksPassed.
  ///
  /// In en, this message translates to:
  /// **'{ok} of {total} required checks passed — tap a row to fix.'**
  String someChecksPassed(int ok, int total);

  /// No description provided for @permissionLocationServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Location services'**
  String get permissionLocationServicesTitle;

  /// No description provided for @permissionLocationServicesDesc.
  ///
  /// In en, this message translates to:
  /// **'GPS must be enabled for zone tracking while In.'**
  String get permissionLocationServicesDesc;

  /// No description provided for @permissionLocationAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get permissionLocationAccessTitle;

  /// No description provided for @permissionLocationAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow precise location while using the app.'**
  String get permissionLocationAccessDesc;

  /// No description provided for @permissionBackgroundLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get permissionBackgroundLocationTitle;

  /// No description provided for @permissionBackgroundLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Recommended so tracking continues when the app is minimized.'**
  String get permissionBackgroundLocationDesc;

  /// No description provided for @permissionNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionNotificationsTitle;

  /// No description provided for @permissionNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Required for the In foreground service.'**
  String get permissionNotificationsDesc;

  /// No description provided for @permissionBatteryOptimizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get permissionBatteryOptimizationTitle;

  /// No description provided for @permissionBatteryOptimizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Exclude the app from battery restrictions while In.'**
  String get permissionBatteryOptimizationDesc;

  /// No description provided for @permissionCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get permissionCameraTitle;

  /// No description provided for @permissionCameraDesc.
  ///
  /// In en, this message translates to:
  /// **'Needed to photograph delivery proof.'**
  String get permissionCameraDesc;

  /// No description provided for @openLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open location settings'**
  String get openLocationSettings;

  /// No description provided for @openBatterySettings.
  ///
  /// In en, this message translates to:
  /// **'Open battery settings'**
  String get openBatterySettings;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get openAppSettings;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Clock out'**
  String get goOffline;

  /// No description provided for @onDutyTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'In — tap to open'**
  String get onDutyTapToOpen;

  /// No description provided for @onDutySignInAgain.
  ///
  /// In en, this message translates to:
  /// **'In — sign in again'**
  String get onDutySignInAgain;

  /// No description provided for @onDutyTurnOnGps.
  ///
  /// In en, this message translates to:
  /// **'In — turn on GPS'**
  String get onDutyTurnOnGps;

  /// No description provided for @onDutyLocationPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'In — location permission needed'**
  String get onDutyLocationPermissionNeeded;

  /// No description provided for @onDutyStationaryGpsPaused.
  ///
  /// In en, this message translates to:
  /// **'In — stationary (GPS paused)'**
  String get onDutyStationaryGpsPaused;

  /// No description provided for @onDutyLocationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'In — location update failed'**
  String get onDutyLocationUpdateFailed;

  /// No description provided for @checkedOutInactive5Min.
  ///
  /// In en, this message translates to:
  /// **'Clocked out — inactive for 5 min'**
  String get checkedOutInactive5Min;

  /// No description provided for @onDutyAutoCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'In — auto clock out failed'**
  String get onDutyAutoCheckoutFailed;

  /// No description provided for @onDutyGoOfflineFailed.
  ///
  /// In en, this message translates to:
  /// **'In — clock out failed'**
  String get onDutyGoOfflineFailed;

  /// No description provided for @onDutyFakeGpsDetected.
  ///
  /// In en, this message translates to:
  /// **'In — fake GPS detected'**
  String get onDutyFakeGpsDetected;

  /// No description provided for @inZone.
  ///
  /// In en, this message translates to:
  /// **'In zone'**
  String get inZone;

  /// No description provided for @outOfZone.
  ///
  /// In en, this message translates to:
  /// **'Out of zone'**
  String get outOfZone;

  /// No description provided for @outsideDeliveryArea.
  ///
  /// In en, this message translates to:
  /// **'Outside zone'**
  String get outsideDeliveryArea;

  /// No description provided for @onDuty.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get onDuty;

  /// No description provided for @moving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get moving;

  /// No description provided for @deliveryLogged.
  ///
  /// In en, this message translates to:
  /// **'Delivery logged'**
  String get deliveryLogged;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @onDutyTrackingChannelName.
  ///
  /// In en, this message translates to:
  /// **'In tracking'**
  String get onDutyTrackingChannelName;

  /// No description provided for @onDutyTrackingChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows while you are In for GPS tracking.'**
  String get onDutyTrackingChannelDesc;

  /// No description provided for @mustBeOnDutyToReportLocation.
  ///
  /// In en, this message translates to:
  /// **'You must be In to report location.'**
  String get mustBeOnDutyToReportLocation;

  /// No description provided for @couldNotReportLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not report location'**
  String get couldNotReportLocation;

  /// No description provided for @locationReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Location report failed'**
  String get locationReportFailed;

  /// No description provided for @pendingDeliveriesWaitingToSync.
  ///
  /// In en, this message translates to:
  /// **'{count} pending deliveries waiting to sync'**
  String pendingDeliveriesWaitingToSync(int count);

  /// No description provided for @couldNotLoadDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Could not load deliveries'**
  String get couldNotLoadDeliveries;

  /// No description provided for @pendingDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Pending Deliveries'**
  String get pendingDeliveries;

  /// No description provided for @noPendingDeliveries.
  ///
  /// In en, this message translates to:
  /// **'No pending deliveries'**
  String get noPendingDeliveries;

  /// No description provided for @pendingSyncedSummary.
  ///
  /// In en, this message translates to:
  /// **'Pending: {pending} · Synced: {synced}'**
  String pendingSyncedSummary(int pending, int synced);

  /// No description provided for @noDeliveriesAdded.
  ///
  /// In en, this message translates to:
  /// **'No deliveries added'**
  String get noDeliveriesAdded;

  /// No description provided for @startAddingDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Start adding your deliveries to track your work'**
  String get startAddingDeliveries;

  /// No description provided for @addOrders.
  ///
  /// In en, this message translates to:
  /// **'Add orders'**
  String get addOrders;

  /// No description provided for @imageFormatsMax10Mb.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, or WebP · max 10 MB'**
  String get imageFormatsMax10Mb;

  /// No description provided for @checkingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Checking your location…'**
  String get checkingYourLocation;

  /// No description provided for @orderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderId;

  /// No description provided for @orderIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 12345'**
  String get orderIdHint;

  /// No description provided for @uploadOrderProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Order Proof'**
  String get uploadOrderProof;

  /// No description provided for @takePhotoOrChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Take photo or choose from gallery'**
  String get takePhotoOrChooseGallery;

  /// No description provided for @imageFormatsMax10MbShort.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, WebP · max 10 MB'**
  String get imageFormatsMax10MbShort;

  /// No description provided for @markAsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as Delivered'**
  String get markAsDelivered;

  /// No description provided for @orderIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Order ID is required'**
  String get orderIdRequired;

  /// No description provided for @deliverySavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Delivery saved offline'**
  String get deliverySavedOffline;

  /// No description provided for @deliveryAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Delivery added successfully'**
  String get deliveryAddedSuccessfully;

  /// No description provided for @deliveryWillSyncWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'This entry will sync automatically when internet returns.'**
  String get deliveryWillSyncWhenOnline;

  /// No description provided for @keepGoingEveryDeliveryCounts.
  ///
  /// In en, this message translates to:
  /// **'Keep going - every delivery counts!'**
  String get keepGoingEveryDeliveryCounts;

  /// No description provided for @addAnotherDelivery.
  ///
  /// In en, this message translates to:
  /// **'Add Another Delivery'**
  String get addAnotherDelivery;

  /// No description provided for @offlineModePendingSync.
  ///
  /// In en, this message translates to:
  /// **'Offline mode active: pending sync'**
  String get offlineModePendingSync;

  /// No description provided for @backToDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Back to Deliveries'**
  String get backToDeliveries;

  /// No description provided for @deliveryDetails.
  ///
  /// In en, this message translates to:
  /// **'Delivery details'**
  String get deliveryDetails;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @deliveryProof.
  ///
  /// In en, this message translates to:
  /// **'Delivery proof'**
  String get deliveryProof;

  /// No description provided for @noProofImageUploaded.
  ///
  /// In en, this message translates to:
  /// **'No proof image uploaded'**
  String get noProofImageUploaded;

  /// No description provided for @couldNotLoadProofImage.
  ///
  /// In en, this message translates to:
  /// **'Could not load proof image'**
  String get couldNotLoadProofImage;

  /// No description provided for @couldNotDisplayImage.
  ///
  /// In en, this message translates to:
  /// **'Could not display image'**
  String get couldNotDisplayImage;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @selectedDayVerifiedOrders.
  ///
  /// In en, this message translates to:
  /// **'Selected day verified orders: {count}'**
  String selectedDayVerifiedOrders(int count);

  /// No description provided for @thisMonthVerifiedOrders.
  ///
  /// In en, this message translates to:
  /// **'This month verified orders: {count}'**
  String thisMonthVerifiedOrders(int count);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @pleaseSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get pleaseSignInAgain;

  /// No description provided for @accountNotActive.
  ///
  /// In en, this message translates to:
  /// **'Your account is not active'**
  String get accountNotActive;

  /// No description provided for @outsideAllowedDeliveryArea.
  ///
  /// In en, this message translates to:
  /// **'You are outside the allowed delivery area. Move closer to your zone or an assigned restaurant.'**
  String get outsideAllowedDeliveryArea;

  /// No description provided for @gpsRequiredForDelivery.
  ///
  /// In en, this message translates to:
  /// **'GPS location is required to log a delivery'**
  String get gpsRequiredForDelivery;

  /// No description provided for @zoneNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Your zone is not configured. Contact admin.'**
  String get zoneNotConfigured;

  /// No description provided for @noRestaurantsAssigned.
  ///
  /// In en, this message translates to:
  /// **'No restaurants assigned. Contact admin.'**
  String get noRestaurantsAssigned;

  /// No description provided for @moveWithinRangeToLog.
  ///
  /// In en, this message translates to:
  /// **'Move within {range} of {target} to log a delivery.'**
  String moveWithinRangeToLog(String range, String target);

  /// No description provided for @outsideRangeDetails.
  ///
  /// In en, this message translates to:
  /// **'You are {distance} outside range (within {range} of {target}).'**
  String outsideRangeDetails(String distance, String range, String target);

  /// No description provided for @yourZone.
  ///
  /// In en, this message translates to:
  /// **'your zone'**
  String get yourZone;

  /// No description provided for @assignedRestaurant.
  ///
  /// In en, this message translates to:
  /// **'an assigned restaurant'**
  String get assignedRestaurant;

  /// No description provided for @accountNotSetupAsDriver.
  ///
  /// In en, this message translates to:
  /// **'Your account is not set up as a driver.'**
  String get accountNotSetupAsDriver;

  /// No description provided for @couldNotLoadDeliveryLocationRules.
  ///
  /// In en, this message translates to:
  /// **'Could not load delivery location rules. Pull to refresh or try again.'**
  String get couldNotLoadDeliveryLocationRules;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @proofImageMissing.
  ///
  /// In en, this message translates to:
  /// **'Proof image is missing'**
  String get proofImageMissing;

  /// No description provided for @proofImageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Proof image not found'**
  String get proofImageNotFound;

  /// No description provided for @cannotViewProofImage.
  ///
  /// In en, this message translates to:
  /// **'You cannot view this proof image'**
  String get cannotViewProofImage;

  /// No description provided for @couldNotLoadEarnings.
  ///
  /// In en, this message translates to:
  /// **'Could not load earnings'**
  String get couldNotLoadEarnings;

  /// No description provided for @performanceSummary.
  ///
  /// In en, this message translates to:
  /// **'Performance Summary'**
  String get performanceSummary;

  /// No description provided for @totalDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Total Deliveries'**
  String get totalDeliveries;

  /// No description provided for @workingDays.
  ///
  /// In en, this message translates to:
  /// **'Working Days'**
  String get workingDays;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @incentives.
  ///
  /// In en, this message translates to:
  /// **'Incentives'**
  String get incentives;

  /// No description provided for @reimbursements.
  ///
  /// In en, this message translates to:
  /// **'Reimbursements'**
  String get reimbursements;

  /// No description provided for @deductions.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get deductions;

  /// No description provided for @extraEarnings.
  ///
  /// In en, this message translates to:
  /// **'Extra Earnings'**
  String get extraEarnings;

  /// No description provided for @dailyEarnings.
  ///
  /// In en, this message translates to:
  /// **'Daily Earnings'**
  String get dailyEarnings;

  /// No description provided for @noEarningsActivityThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No earnings activity this month.'**
  String get noEarningsActivityThisMonth;

  /// No description provided for @deliveryCountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 delivery} other{{count} deliveries}}'**
  String deliveryCountSubtitle(int count);

  /// No description provided for @bonusesApplied.
  ///
  /// In en, this message translates to:
  /// **'{count} bonuses applied'**
  String bonusesApplied(int count);

  /// No description provided for @bonusSuffix.
  ///
  /// In en, this message translates to:
  /// **'bonus'**
  String get bonusSuffix;

  /// No description provided for @deductionsComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get deductionsComingSoonTitle;

  /// No description provided for @deductionsComingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Coming soon — a detailed breakdown of any loans or penalties applied to your earnings.'**
  String get deductionsComingSoonBody;

  /// No description provided for @payslipHistory.
  ///
  /// In en, this message translates to:
  /// **'Payslip History'**
  String get payslipHistory;

  /// No description provided for @latestFirst.
  ///
  /// In en, this message translates to:
  /// **'Latest first'**
  String get latestFirst;

  /// No description provided for @noPayslipsYet.
  ///
  /// In en, this message translates to:
  /// **'No payslips yet. Once your operations team approves a payout, it will appear here.'**
  String get noPayslipsYet;

  /// No description provided for @deliveriesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'{count} deliveries'**
  String deliveriesInPeriod(int count);

  /// No description provided for @deliveriesInPayoutPeriod.
  ///
  /// In en, this message translates to:
  /// **'{count} deliveries in this period'**
  String deliveriesInPayoutPeriod(int count);

  /// No description provided for @activeOffers.
  ///
  /// In en, this message translates to:
  /// **'Active Offers'**
  String get activeOffers;

  /// No description provided for @noActiveIncentivesRightNow.
  ///
  /// In en, this message translates to:
  /// **'No active incentives right now'**
  String get noActiveIncentivesRightNow;

  /// No description provided for @checkBackLaterIncentives.
  ///
  /// In en, this message translates to:
  /// **'Check back later — your operations team configures incentive rules from the admin panel.'**
  String get checkBackLaterIncentives;

  /// No description provided for @couldNotLoadExtraEarnings.
  ///
  /// In en, this message translates to:
  /// **'Could not load extra earnings'**
  String get couldNotLoadExtraEarnings;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @bonusDefault.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get bonusDefault;

  /// No description provided for @incentiveDefault.
  ///
  /// In en, this message translates to:
  /// **'Incentive'**
  String get incentiveDefault;

  /// No description provided for @upToAmount.
  ///
  /// In en, this message translates to:
  /// **'up to {amount}'**
  String upToAmount(String amount);

  /// No description provided for @perDeliveryAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount}/delivery'**
  String perDeliveryAmount(String amount);

  /// No description provided for @completeDeliveriesScope.
  ///
  /// In en, this message translates to:
  /// **'Complete {target} deliveries{scope} {period}'**
  String completeDeliveriesScope(int target, String scope, String period);

  /// No description provided for @earnRewardsScope.
  ///
  /// In en, this message translates to:
  /// **'Earn rewards{scope} {period}'**
  String earnRewardsScope(String scope, String period);

  /// No description provided for @periodTodayLower.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get periodTodayLower;

  /// No description provided for @periodThisWeekLower.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get periodThisWeekLower;

  /// No description provided for @periodThisMonthLower.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get periodThisMonthLower;

  /// No description provided for @periodThisPeriodLower.
  ///
  /// In en, this message translates to:
  /// **'this period'**
  String get periodThisPeriodLower;

  /// No description provided for @fromScope.
  ///
  /// In en, this message translates to:
  /// **'from {scope}'**
  String fromScope(String scope);

  /// No description provided for @forScope.
  ///
  /// In en, this message translates to:
  /// **'for {scope}'**
  String forScope(String scope);

  /// No description provided for @netEarnings.
  ///
  /// In en, this message translates to:
  /// **'Net earnings'**
  String get netEarnings;

  /// No description provided for @eligibleDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Eligible deliveries'**
  String get eligibleDeliveries;

  /// No description provided for @basePay.
  ///
  /// In en, this message translates to:
  /// **'Base pay'**
  String get basePay;

  /// No description provided for @noDeliveriesLoggedThisDay.
  ///
  /// In en, this message translates to:
  /// **'No deliveries logged this day.'**
  String get noDeliveriesLoggedThisDay;

  /// No description provided for @incentiveRules.
  ///
  /// In en, this message translates to:
  /// **'Incentive rules'**
  String get incentiveRules;

  /// No description provided for @noIncentiveRulesPaidThisDay.
  ///
  /// In en, this message translates to:
  /// **'No incentive rules paid out this day.'**
  String get noIncentiveRulesPaidThisDay;

  /// No description provided for @overrideRuleApplied.
  ///
  /// In en, this message translates to:
  /// **'Override rule applied — final incentive {amount}'**
  String overrideRuleApplied(String amount);

  /// No description provided for @eligibleDeliveriesProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} eligible deliveries'**
  String eligibleDeliveriesProgress(int current, int target);

  /// No description provided for @eligibleDeliveriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} eligible deliveries'**
  String eligibleDeliveriesCount(int count);

  /// No description provided for @couldNotLoadThisDay.
  ///
  /// In en, this message translates to:
  /// **'Could not load this day'**
  String get couldNotLoadThisDay;

  /// No description provided for @payslip.
  ///
  /// In en, this message translates to:
  /// **'Payslip'**
  String get payslip;

  /// No description provided for @netPayable.
  ///
  /// In en, this message translates to:
  /// **'Net payable'**
  String get netPayable;

  /// No description provided for @paidAt.
  ///
  /// In en, this message translates to:
  /// **'Paid {date} at {time}'**
  String paidAt(String date, String time);

  /// No description provided for @breakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get breakdown;

  /// No description provided for @loanDeduction.
  ///
  /// In en, this message translates to:
  /// **'Loan deduction'**
  String get loanDeduction;

  /// No description provided for @penalty.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get penalty;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @detailedSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Detailed snapshot'**
  String get detailedSnapshot;

  /// No description provided for @frozenAtApproval.
  ///
  /// In en, this message translates to:
  /// **'Frozen at the time this payout was approved.'**
  String get frozenAtApproval;

  /// No description provided for @couldNotLoadThisPayslip.
  ///
  /// In en, this message translates to:
  /// **'Could not load this payslip'**
  String get couldNotLoadThisPayslip;

  /// No description provided for @payslipNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This payslip is no longer available.'**
  String get payslipNoLongerAvailable;

  /// No description provided for @couldNotLoadAttendance.
  ///
  /// In en, this message translates to:
  /// **'Could not load attendance'**
  String get couldNotLoadAttendance;

  /// No description provided for @attendanceDaysCompleted.
  ///
  /// In en, this message translates to:
  /// **'{present}/{elapsed} days completed'**
  String attendanceDaysCompleted(int present, int elapsed);

  /// No description provided for @noLogin.
  ///
  /// In en, this message translates to:
  /// **'No Login'**
  String get noLogin;

  /// No description provided for @lessThanZeroHours.
  ///
  /// In en, this message translates to:
  /// **'Less than 0h'**
  String get lessThanZeroHours;

  /// No description provided for @moreThanZeroHours.
  ///
  /// In en, this message translates to:
  /// **'More than 0h'**
  String get moreThanZeroHours;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @weekdayMonUpper.
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get weekdayMonUpper;

  /// No description provided for @weekdayTueUpper.
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get weekdayTueUpper;

  /// No description provided for @weekdayWedUpper.
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get weekdayWedUpper;

  /// No description provided for @weekdayThuUpper.
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get weekdayThuUpper;

  /// No description provided for @weekdayFriUpper.
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get weekdayFriUpper;

  /// No description provided for @weekdaySatUpper.
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get weekdaySatUpper;

  /// No description provided for @weekdaySunUpper.
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get weekdaySunUpper;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMayShort.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMayShort;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @profileImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile image upload failed: {error}'**
  String profileImageUploadFailed(String error);

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated'**
  String get profilePictureUpdated;

  /// No description provided for @uploadedPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Uploaded, but preview could not load. Pull down to refresh — contact support if it persists.'**
  String get uploadedPreviewFailed;

  /// No description provided for @notificationsSettingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications settings are coming soon'**
  String get notificationsSettingsComingSoon;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will need your driver ID and passcode to sign in again.'**
  String get signOutConfirmBody;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @attendanceAndLeaves.
  ///
  /// In en, this message translates to:
  /// **'Attendance & Leaves'**
  String get attendanceAndLeaves;

  /// No description provided for @wrongAction.
  ///
  /// In en, this message translates to:
  /// **'Wrong Action'**
  String get wrongAction;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// No description provided for @assets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assets;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @trainingSection.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingSection;

  /// No description provided for @tutorialMaterial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial Material'**
  String get tutorialMaterial;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile'**
  String get couldNotLoadProfile;

  /// No description provided for @profileSessionExpiredHint.
  ///
  /// In en, this message translates to:
  /// **'Your session may have expired. Try again or sign out and sign back in.'**
  String get profileSessionExpiredHint;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @driverIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {code}'**
  String driverIdLabel(String code);

  /// No description provided for @updateProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Update profile picture'**
  String get updateProfilePicture;

  /// No description provided for @couldNotLoadNotificationsWithError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications.\n{error}'**
  String couldNotLoadNotificationsWithError(String error);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get allCaughtUp;

  /// No description provided for @notificationsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Important alerts and reminders from Musallam will show up here.'**
  String get notificationsEmptyHint;

  /// No description provided for @musallamAlertsChannelName.
  ///
  /// In en, this message translates to:
  /// **'Musallam alerts'**
  String get musallamAlertsChannelName;

  /// No description provided for @musallamAlertsChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Operational alerts and reminders for drivers'**
  String get musallamAlertsChannelDesc;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @vehicleComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Assigned vehicle and maintenance info. Coming soon.'**
  String get vehicleComingSoon;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @onDutyStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'{status}{speed} · {zone}'**
  String onDutyStatusLabel(String status, String speed, String zone);

  /// No description provided for @couldNotStartUpload.
  ///
  /// In en, this message translates to:
  /// **'Could not start upload'**
  String get couldNotStartUpload;

  /// No description provided for @couldNotConfirmUpload.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm upload'**
  String get couldNotConfirmUpload;

  /// No description provided for @networkErrorReachingAdminUploadServer.
  ///
  /// In en, this message translates to:
  /// **'Network error reaching admin upload server'**
  String get networkErrorReachingAdminUploadServer;

  /// No description provided for @uploadFailedWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Upload failed ({statusCode})'**
  String uploadFailedWithStatus(int statusCode);

  /// No description provided for @availabilitySubmission.
  ///
  /// In en, this message translates to:
  /// **'Availability Submission'**
  String get availabilitySubmission;

  /// No description provided for @shiftRequiredToGoIn.
  ///
  /// In en, this message translates to:
  /// **'Submit shift to go In'**
  String get shiftRequiredToGoIn;

  /// No description provided for @shiftExpiredSubmitNext.
  ///
  /// In en, this message translates to:
  /// **'Your shift has ended. Submit your next shift to go In.'**
  String get shiftExpiredSubmitNext;

  /// No description provided for @shiftSubmissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set your shift for this period. You can go In/Out freely until it ends, then submit again.'**
  String get shiftSubmissionSubtitle;

  /// No description provided for @shiftSubmissionRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A shift is required before you can go In. This cannot be skipped.'**
  String get shiftSubmissionRequiredSubtitle;

  /// No description provided for @shiftType.
  ///
  /// In en, this message translates to:
  /// **'Shift Type'**
  String get shiftType;

  /// No description provided for @selectShift.
  ///
  /// In en, this message translates to:
  /// **'Select Shift'**
  String get selectShift;

  /// No description provided for @singleShift.
  ///
  /// In en, this message translates to:
  /// **'Single Shift'**
  String get singleShift;

  /// No description provided for @splitShift.
  ///
  /// In en, this message translates to:
  /// **'Split Shift'**
  String get splitShift;

  /// No description provided for @setTimeline.
  ///
  /// In en, this message translates to:
  /// **'Set Timeline'**
  String get setTimeline;

  /// No description provided for @fromTime.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromTime;

  /// No description provided for @toTime.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toTime;

  /// No description provided for @session2.
  ///
  /// In en, this message translates to:
  /// **'Session 2'**
  String get session2;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @shiftEndsNextDay.
  ///
  /// In en, this message translates to:
  /// **'Ends next day'**
  String get shiftEndsNextDay;

  /// No description provided for @session1Required.
  ///
  /// In en, this message translates to:
  /// **'Please set session 1 start and end times'**
  String get session1Required;

  /// No description provided for @session2Required.
  ///
  /// In en, this message translates to:
  /// **'Please set session 2 start and end times'**
  String get session2Required;

  /// No description provided for @invalidSessionDuration.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get invalidSessionDuration;

  /// No description provided for @sessionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Each session must be 24 hours or less'**
  String get sessionTooLong;

  /// No description provided for @sessionsOverlap.
  ///
  /// In en, this message translates to:
  /// **'Sessions cannot overlap'**
  String get sessionsOverlap;

  /// No description provided for @shiftLocked.
  ///
  /// In en, this message translates to:
  /// **'Today\'s shift is locked until it ends'**
  String get shiftLocked;

  /// No description provided for @couldNotSubmitShift.
  ///
  /// In en, this message translates to:
  /// **'Could not submit shift'**
  String get couldNotSubmitShift;

  /// No description provided for @outsideShiftWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Outside shift window'**
  String get outsideShiftWindowTitle;

  /// No description provided for @outsideShiftWindowMessage.
  ///
  /// In en, this message translates to:
  /// **'You are outside your submitted shift hours. You can continue anyway, but this may be flagged for review.'**
  String get outsideShiftWindowMessage;

  /// No description provided for @continueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get continueAnyway;

  /// No description provided for @mustBeOnDutyToAddDelivery.
  ///
  /// In en, this message translates to:
  /// **'You must be In to add a delivery'**
  String get mustBeOnDutyToAddDelivery;

  /// No description provided for @shiftRequiredBeforeDuty.
  ///
  /// In en, this message translates to:
  /// **'Submit today\'s shift before going In'**
  String get shiftRequiredBeforeDuty;

  /// No description provided for @pickupOrder.
  ///
  /// In en, this message translates to:
  /// **'Pickup Order'**
  String get pickupOrder;

  /// No description provided for @confirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup'**
  String get confirmPickup;

  /// No description provided for @pickedUpAt.
  ///
  /// In en, this message translates to:
  /// **'Picked up at'**
  String get pickedUpAt;

  /// No description provided for @uploadPickupProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Pickup Proof'**
  String get uploadPickupProof;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @confirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cancel'**
  String get confirmCancel;

  /// No description provided for @cancelledAt.
  ///
  /// In en, this message translates to:
  /// **'Cancelled at'**
  String get cancelledAt;

  /// No description provided for @cancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel reason'**
  String get cancelReasonLabel;

  /// No description provided for @cancelReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Cancel reason is required'**
  String get cancelReasonRequired;

  /// No description provided for @cancelReasonCustomerNoShow.
  ///
  /// In en, this message translates to:
  /// **'Customer no-show'**
  String get cancelReasonCustomerNoShow;

  /// No description provided for @cancelReasonCustomerRefused.
  ///
  /// In en, this message translates to:
  /// **'Customer refused'**
  String get cancelReasonCustomerRefused;

  /// No description provided for @cancelReasonWrongAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get cancelReasonWrongAddress;

  /// No description provided for @cancelReasonRestaurantIssue.
  ///
  /// In en, this message translates to:
  /// **'Restaurant issue'**
  String get cancelReasonRestaurantIssue;

  /// No description provided for @cancelReasonAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get cancelReasonAccident;

  /// No description provided for @cancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cancelReasonOther;

  /// No description provided for @cancelNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get cancelNoteHint;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @activeDeliveryBanner.
  ///
  /// In en, this message translates to:
  /// **'Active delivery'**
  String get activeDeliveryBanner;

  /// No description provided for @noActiveDelivery.
  ///
  /// In en, this message translates to:
  /// **'No active delivery in progress'**
  String get noActiveDelivery;

  /// No description provided for @deliveryDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get deliveryDuration;

  /// No description provided for @pickupProof.
  ///
  /// In en, this message translates to:
  /// **'Pickup proof'**
  String get pickupProof;

  /// No description provided for @deliveryProofOptional.
  ///
  /// In en, this message translates to:
  /// **'Delivery proof (optional)'**
  String get deliveryProofOptional;

  /// No description provided for @cancelProof.
  ///
  /// In en, this message translates to:
  /// **'Cancel proof'**
  String get cancelProof;

  /// No description provided for @mustCompleteActiveDeliveryFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete your current delivery before picking up another order'**
  String get mustCompleteActiveDeliveryFirst;

  /// No description provided for @activePickupExists.
  ///
  /// In en, this message translates to:
  /// **'You already have an order in progress'**
  String get activePickupExists;

  /// No description provided for @duplicateOrderId.
  ///
  /// In en, this message translates to:
  /// **'This order ID is already logged'**
  String get duplicateOrderId;

  /// No description provided for @proofPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'A proof photo is required'**
  String get proofPhotoRequired;

  /// No description provided for @finishAsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Finish as delivered'**
  String get finishAsDelivered;

  /// No description provided for @finishAsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Finish as cancelled'**
  String get finishAsCancelled;

  /// No description provided for @switchOutcome.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchOutcome;

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select a reason'**
  String get selectReason;

  /// No description provided for @permissionOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display over other apps'**
  String get permissionOverlayTitle;

  /// No description provided for @permissionOverlayDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows a floating icon while you are In so you can return quickly.'**
  String get permissionOverlayDesc;

  /// No description provided for @grantOverlayPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant overlay permission'**
  String get grantOverlayPermission;

  /// No description provided for @onDutyReturnToApp.
  ///
  /// In en, this message translates to:
  /// **'You are In — return to the app'**
  String get onDutyReturnToApp;

  /// No description provided for @onDutyTurnOnGpsOverlay.
  ///
  /// In en, this message translates to:
  /// **'Turn GPS on to continue while In'**
  String get onDutyTurnOnGpsOverlay;

  /// No description provided for @openLocationSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open location settings'**
  String get openLocationSettingsAction;

  /// No description provided for @pickupLoggedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Pickup logged successfully'**
  String get pickupLoggedSuccessfully;

  /// No description provided for @cancelLoggedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Cancellation logged successfully'**
  String get cancelLoggedSuccessfully;

  /// No description provided for @proceedToDeliverWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Head to the customer and mark as delivered when done.'**
  String get proceedToDeliverWhenReady;

  /// No description provided for @shiftAdherenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift adherence'**
  String get shiftAdherenceTitle;

  /// No description provided for @minutesLateVsShift.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min late vs shift'**
  String minutesLateVsShift(int minutes);

  /// No description provided for @minutesEarlyOutVsShift.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min early vs shift'**
  String minutesEarlyOutVsShift(int minutes);

  /// No description provided for @onTimeVsShift.
  ///
  /// In en, this message translates to:
  /// **'On time vs shift'**
  String get onTimeVsShift;

  /// No description provided for @noShiftSubmitted.
  ///
  /// In en, this message translates to:
  /// **'No shift submitted for today'**
  String get noShiftSubmitted;

  /// No description provided for @timeInToday.
  ///
  /// In en, this message translates to:
  /// **'Time in today: {duration}'**
  String timeInToday(String duration);

  /// No description provided for @shiftAdherenceLateShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m late'**
  String shiftAdherenceLateShort(int minutes);

  /// No description provided for @shiftAdherenceEarlyShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m early'**
  String shiftAdherenceEarlyShort(int minutes);

  /// No description provided for @shiftAdherenceOnTimeShort.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get shiftAdherenceOnTimeShort;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready to install.'**
  String updateAvailableBody(String version);

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get updateDownload;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get updateInstall;

  /// No description provided for @updateAllowInstallPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Musallam to install app updates, then try again.'**
  String get updateAllowInstallPermission;

  /// No description provided for @openInstallSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openInstallSettings;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateChecksumFailed.
  ///
  /// In en, this message translates to:
  /// **'Download verification failed. Please try again.'**
  String get updateChecksumFailed;

  /// No description provided for @updateNoInstallerAvailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the Android installer. Please tap the downloaded APK from your Files app, or contact support.'**
  String get updateNoInstallerAvailable;

  /// No description provided for @updateApkMissing.
  ///
  /// In en, this message translates to:
  /// **'The downloaded update file is missing. Tap Download to try again.'**
  String get updateApkMissing;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
