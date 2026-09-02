// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitleDefault => 'Musallam Delivery';

  @override
  String get appSubtitleDefault => 'Delivery Partner';

  @override
  String get loginHintDefault => 'Enter your ID and passcode from admin';

  @override
  String get maintenanceMessageDefault =>
      'The driver app is temporarily unavailable. Please try again later.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get exit => 'Exit';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutQuestion => 'Sign out?';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String comingSoonMessage(String featureName) {
    return '$featureName is coming soon.';
  }

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get sessionExpired => 'Session expired. Please sign in again.';

  @override
  String get serverUpdateRequired => 'Server update required. Contact support.';

  @override
  String get contactAdmin => 'Contact your admin for details.';

  @override
  String get contactSupport => 'Contact support.';

  @override
  String get notificationFallback => 'Notification';

  @override
  String get justNow => 'just now';

  @override
  String get now => 'now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get paid => 'Paid';

  @override
  String get approved => 'Approved';

  @override
  String get pending => 'Pending';

  @override
  String get verified => 'Verified';

  @override
  String get rejected => 'Rejected';

  @override
  String get underReview => 'Under Review';

  @override
  String get yes => 'yes';

  @override
  String get no => 'no';

  @override
  String get notProvided => 'Not provided';

  @override
  String get driverFallback => 'Driver';

  @override
  String orderIdPrefix(String orderId) {
    return 'Order #$orderId';
  }

  @override
  String get deliverySingular => 'Delivery';

  @override
  String get deliveryPlural => 'Deliveries';

  @override
  String deliveriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Deliveries',
      one: '1 Delivery',
    );
    return '$_temp0';
  }

  @override
  String get takePhoto => 'Take photo';

  @override
  String get verifyIdentityTitle => 'Verify identity';

  @override
  String get verifyIdentityMessage =>
      'Look at the camera and blink once to prove you are present. A photo is taken after a successful blink. Required once per day.';

  @override
  String get verifyIdentityPermissionDenied =>
      'Camera permission is required to verify your identity. Grant camera access to continue. You cannot skip this step.';

  @override
  String get verifyIdentityBlinkInstruction => 'Blink once';

  @override
  String get verifyIdentityFaceNotFound => 'Position your face in the frame';

  @override
  String get verifyIdentityBlinkTimeout => 'Blink not detected, try again';

  @override
  String get verifyIdentityInitError =>
      'Camera or face detection failed to start. Tap retry to try again. You cannot skip this step.';

  @override
  String get verifyIdentityBlinkSuccess => 'Blink detected';

  @override
  String get verifyIdentityRetake => 'Retake';

  @override
  String get verifyIdentityConfirm => 'Confirm photo';

  @override
  String get verifyIdentitySaving => 'Saving photo…';

  @override
  String get chooseImageSource => 'Choose Image Source';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get imgLabel => 'IMG';

  @override
  String get required => 'Required';

  @override
  String uploadingProgress(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get readyToUpload => 'Ready to upload';

  @override
  String readyToUploadWithSizeKb(String sizeKb) {
    return '$sizeKb KB · Ready to upload';
  }

  @override
  String readyToUploadWithSizeMb(String sizeMb) {
    return '$sizeMb MB · Ready to upload';
  }

  @override
  String get photoAttached => 'Photo attached';

  @override
  String photoAttachedWithSizeKb(String sizeKb) {
    return '$sizeKb KB · Photo attached';
  }

  @override
  String photoAttachedWithSizeMb(String sizeMb) {
    return '$sizeMb MB · Photo attached';
  }

  @override
  String get proofUploaded => 'Uploaded';

  @override
  String proofUploadedWithSizeKb(String sizeKb) {
    return '$sizeKb KB · Uploaded';
  }

  @override
  String proofUploadedWithSizeMb(String sizeMb) {
    return '$sizeMb MB · Uploaded';
  }

  @override
  String get viewProofPhoto => 'View photo';

  @override
  String get proofAddHint => 'You can attach up to 5 photos.';

  @override
  String get proofMaxReached => 'Maximum of 5 photos.';

  @override
  String get addAnotherPhoto => 'Add another photo';

  @override
  String get fileEmpty => 'File is empty';

  @override
  String get fileTooLarge10Mb => 'Image must be 10 MB or smaller';

  @override
  String get fileTooLarge2Mb => 'Profile image must be 2 MB or smaller';

  @override
  String get imagesAllowedOnly => 'Only JPG, PNG, or WebP images are allowed';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get signIn => 'Sign in';

  @override
  String get driverId => 'Driver ID';

  @override
  String get employeeId => 'Employee ID';

  @override
  String get passcode => 'Passcode';

  @override
  String get passcodeHint => '6-digit code from your admin panel';

  @override
  String get continueButton => 'Continue';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get deviceConflictTitle => 'Already signed in elsewhere';

  @override
  String get deviceConflictMessage =>
      'This account is active on another device. You can continue using that device or sign in here instead.';

  @override
  String deviceConflictActiveLabel(String device) {
    return 'Active device: $device';
  }

  @override
  String deviceConflictLastSeen(String date, String time) {
    return 'Last active: $date at $time';
  }

  @override
  String get deviceConflictUnknownDevice => 'Unknown device';

  @override
  String get deviceConflictContinueButton => 'Continue on other device';

  @override
  String get deviceConflictSignInHereButton => 'Sign in here';

  @override
  String get signedInOnAnotherDeviceToast =>
      'Signed in on another device. Please sign in again.';

  @override
  String get enterDriverId => 'Enter your 5-digit driver ID.';

  @override
  String get enterEmployeeId => 'Enter your 4–8 digit employee ID.';

  @override
  String get enterPasscode => 'Enter your 6-digit passcode.';

  @override
  String get authNotConfigured =>
      'App is not configured. Add SUPABASE_ANON_KEY when running.';

  @override
  String get authInvalidCredentials =>
      'Invalid employee ID or passcode. Please try again.';

  @override
  String get authDriverNotActive =>
      'Your driver account is not active yet. Contact your admin.';

  @override
  String get authDriverSuspended =>
      'Your driver account has been suspended. Contact your administrator.';

  @override
  String get authDriverArchived =>
      'Your driver account has been archived. Contact your administrator.';

  @override
  String get authStaffNotAllowed => 'This account is for the admin panel only.';

  @override
  String get authProfileSyncFailed =>
      'Signed in but profile setup failed. Contact support.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabDeliveries => 'Deliveries';

  @override
  String get tabEarnings => 'Earnings';

  @override
  String get tabVehicle => 'Vehicle';

  @override
  String get tabProfile => 'Profile';

  @override
  String get exitAppQuestion => 'Exit app?';

  @override
  String get exitAppMessage => 'You are offline and checked out. Exit the app?';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String get offlineModeDescription =>
      'Your changes are saved on the device and will sync automatically once you\'re back online.';

  @override
  String get accessBlocked => 'Access blocked';

  @override
  String get accountBlockedDefault =>
      'Your account has been blocked. Contact your admin for details.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get underMaintenance => 'Under maintenance';

  @override
  String get pullDownToRefresh => 'Pull down to refresh';

  @override
  String get developerModeDetectedTitle => 'Developer options must be off';

  @override
  String get closeApp => 'Close app';

  @override
  String get developerModeDetectedMessage =>
      'This app cannot run while Developer options are enabled. Turn them off in your phone Settings (Developer options), then open the app again. For security and Play Store policy, sideloading and in-app APK updates have been removed — install updates only from Google Play.';

  @override
  String get mockLocationDetectedTitle => 'Mock location detected';

  @override
  String get mockLocationDetectedMessage =>
      'A mock location setting is enabled on this device. This has been recorded.';

  @override
  String get fakeGpsDetectedTitle => 'Fake GPS detected';

  @override
  String get fakeGpsDetectedMessage =>
      'Fake GPS is detected. Delivery and location actions are blocked until it is turned off.';

  @override
  String get fakeGpsBlockedAction =>
      'Fake GPS detected. Turn off mock location and try again.';

  @override
  String get screenCaptureBlockedTitle => 'Screen capture blocked';

  @override
  String get screenCaptureBlockedMessage =>
      'Screenshots and screen recording are not allowed. This attempt has been recorded.';

  @override
  String get sosComingSoon => 'SOS coming soon';

  @override
  String get couldNotStartDuty => 'Could not clock in';

  @override
  String get couldNotUpdateDutyStatus => 'Could not update In/Out status';

  @override
  String get currentSpeed => 'Current speed';

  @override
  String get distanceToday => 'Distance today';

  @override
  String speedValue(String speed) {
    return '$speed km/h';
  }

  @override
  String distanceValue(String distance) {
    return '$distance km';
  }

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get online => 'In';

  @override
  String get offline => 'Out';

  @override
  String get sos => 'SOS';

  @override
  String get bonusOnTrackDefault =>
      'You\'re on track — keep delivering to unlock bonuses';

  @override
  String get addDelivery => 'Add Delivery';

  @override
  String get startDuty => 'Clock in';

  @override
  String get thisWeeksProgress => 'This Week\'s Progress';

  @override
  String get week => 'Week';

  @override
  String get earnings => 'Earnings';

  @override
  String get onlineTime => 'Time in';

  @override
  String get weeklyBumperBonus => 'Weekly Bumper Bonus';

  @override
  String get deliveredOrders => 'Delivered Orders:';

  @override
  String get fewMoreToUnlock => 'Just a few more to unlock your reward 💰';

  @override
  String get weeklyBonusUnlockedCelebration => 'Weekly bonus unlocked 🎉';

  @override
  String get weeklyBonusUnlocked => 'Weekly bonus unlocked!';

  @override
  String get weeklyBonusUnlockedShort => 'Weekly bonus unlocked';

  @override
  String deliveriesAwayFromBonus(int remaining, String reward) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'deliveries',
      one: 'delivery',
    );
    return 'You\'re $remaining $_temp0 away from $reward KWD bonus';
  }

  @override
  String deliverMoreToUnlockKd(int remaining, String reward) {
    return 'Deliver $remaining more orders to unlock KD $reward guaranteed';
  }

  @override
  String get weeklyBonusDefault => 'Weekly Bonus';

  @override
  String get deliveryRuleDefault => 'Delivery rule';

  @override
  String get deliveryRules => 'Delivery Rules';

  @override
  String get allVerifiedCountTowardIncentives =>
      'All verified deliveries count toward incentives';

  @override
  String get confirmedOnceVerified => 'Confirmed once verified';

  @override
  String get countsTowardIncentiveDeliveries =>
      'Counts toward incentive deliveries';

  @override
  String get outsideDeliveryAreaReturnSoon =>
      'Outside zone. Return within 45 minutes.';

  @override
  String get outsideDeliveryAreaReturnAfterDelivery =>
      'Outside zone. Return within 20 minutes.';

  @override
  String get zoneTimeoutCheckedOut =>
      'You were checked out for staying outside your delivery area too long.';

  @override
  String get autoCheckoutOffline =>
      'You were checked out automatically after being offline too long.';

  @override
  String get autoCheckoutOutOfZone =>
      'You were checked out automatically after staying outside your assigned zone too long.';

  @override
  String get autoCheckoutShiftEnd =>
      'You were checked out automatically when your shift ended.';

  @override
  String get completeMoreEarnMore => 'Complete more. Earn more.';

  @override
  String get liveBonusQuestsToday => 'Live bonus quests for today';

  @override
  String get viewAll => 'View all';

  @override
  String extraMore(int count) {
    return '+$count more';
  }

  @override
  String get completed => 'Completed';

  @override
  String get noActiveQuestsRightNow => 'No active quests right now';

  @override
  String get tapToSeeAllOffers =>
      'Tap to see all incentive offers — fresh ones drop every week.';

  @override
  String questUnlockedEarned(String amount) {
    return 'Quest unlocked — earned $amount';
  }

  @override
  String get keepDeliveringEveryOrderPays =>
      'Keep delivering — every order pays out';

  @override
  String get keepDeliveringToEarnBonus => 'Keep delivering to earn this bonus';

  @override
  String remainingMoreToMaxEarnedSoFar(int remaining, String amount) {
    return '$remaining more to max — earned so far $amount';
  }

  @override
  String remainingMoreToUnlock(int remaining, String amount) {
    return '$remaining more to unlock $amount';
  }

  @override
  String unlockReward(String amount) {
    return 'Unlock $amount';
  }

  @override
  String perDeliveryRate(String rate) {
    return '× $rate / delivery';
  }

  @override
  String get periodToday => 'Today';

  @override
  String get periodThisWeek => 'This week';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodThisPeriod => 'This period';

  @override
  String get importantNotifications => 'Important Notifications';

  @override
  String get couldNotLoadNotifications => 'Couldn\'t load notifications.';

  @override
  String get allCaughtUpShort => 'You\'re all caught up.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get clearAllNotifications => 'Clear all';

  @override
  String get clearAllNotificationsTitle => 'Clear all notifications?';

  @override
  String get clearAllNotificationsBody =>
      'They will be removed from your list. This cannot be undone.';

  @override
  String get removeNotification => 'Remove';

  @override
  String get viewMore => 'View More';

  @override
  String get couldNotLoadHomeDashboard => 'Could not load home dashboard';

  @override
  String get readyForDuty => 'Ready to clock in';

  @override
  String get beforeYouGoOnline => 'Before you clock in';

  @override
  String get startDutyChecksSubtitle =>
      'Complete these checks once to start tracking while In.';

  @override
  String get goOnlineChecksSubtitle =>
      'You are still clocked in. Fix anything below, then go In.';

  @override
  String get goOnline => 'Go In';

  @override
  String get refreshChecks => 'Refresh checks';

  @override
  String allChecksPassed(int ok, int total) {
    return 'All required checks passed ($ok/$total).';
  }

  @override
  String someChecksPassed(int ok, int total) {
    return '$ok of $total required checks passed — tap a row to fix.';
  }

  @override
  String get permissionLocationServicesTitle => 'Location services';

  @override
  String get permissionLocationServicesDesc =>
      'GPS must be enabled for zone tracking while In.';

  @override
  String get permissionLocationAccessTitle => 'Location access';

  @override
  String get permissionLocationAccessDesc =>
      'Allow precise location while using the app.';

  @override
  String get permissionBackgroundLocationTitle => 'Background location';

  @override
  String get permissionBackgroundLocationDesc =>
      'Recommended so tracking continues when the app is minimized.';

  @override
  String get permissionNotificationsTitle => 'Notifications';

  @override
  String get permissionNotificationsDesc =>
      'Required for the In foreground service.';

  @override
  String get permissionBatteryOptimizationTitle => 'Battery optimization';

  @override
  String get permissionBatteryOptimizationDesc =>
      'Recommended so tracking stays reliable while In. Skipping this does not block Go In.';

  @override
  String get permissionOemBatteryTitle => 'Autostart / battery saver';

  @override
  String get permissionOemBatteryDesc =>
      'Allow this app to run in the background on this device. This does not block Go In.';

  @override
  String get openOemBatterySettings => 'Open manufacturer settings';

  @override
  String get permissionCameraTitle => 'Camera';

  @override
  String get permissionCameraDesc => 'Needed to photograph delivery proof.';

  @override
  String get openLocationSettings => 'Open location settings';

  @override
  String get openBatterySettings => 'Open battery settings';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get allow => 'Allow';

  @override
  String get goOffline => 'Clock out';

  @override
  String get onDutyTapToOpen => 'In — tap to open';

  @override
  String get onDutySignInAgain => 'In — sign in again';

  @override
  String get onDutyTurnOnGps => 'In — turn on GPS';

  @override
  String get onDutyLocationPermissionNeeded =>
      'In — location permission needed';

  @override
  String get onDutyBatteryRestricted =>
      'In — battery restriction is on. Allow to keep tracking reliable';

  @override
  String get onDutyStationaryGpsPaused => 'In — stationary (GPS paused)';

  @override
  String get onDutyLocationUpdateFailed => 'In — location update failed';

  @override
  String get checkedOutInactive5Min => 'Clocked out — inactive for 5 min';

  @override
  String get onDutyAutoCheckoutFailed => 'In — auto clock out failed';

  @override
  String get onDutyGoOfflineFailed => 'In — clock out failed';

  @override
  String get onDutyFakeGpsDetected => 'In — fake GPS detected';

  @override
  String get inZone => 'In zone';

  @override
  String get outOfZone => 'Out of zone';

  @override
  String get outsideDeliveryArea => 'Outside zone';

  @override
  String get onDuty => 'In';

  @override
  String get moving => 'Moving';

  @override
  String get deliveryLogged => 'Delivery logged';

  @override
  String get idle => 'Idle';

  @override
  String get onDutyTrackingChannelName => 'In tracking';

  @override
  String get onDutyTrackingChannelDesc =>
      'Shows while you are In for GPS tracking.';

  @override
  String get mustBeOnDutyToReportLocation =>
      'You must be In to report location.';

  @override
  String get couldNotReportLocation => 'Could not report location';

  @override
  String get locationReportFailed => 'Location report failed';

  @override
  String pendingDeliveriesWaitingToSync(int count) {
    return '$count pending deliveries waiting to sync';
  }

  @override
  String get couldNotLoadDeliveries => 'Could not load deliveries';

  @override
  String get pendingDeliveries => 'Pending Deliveries';

  @override
  String get noPendingDeliveries => 'No pending deliveries';

  @override
  String pendingSyncedSummary(int pending, int synced) {
    return 'Pending: $pending · Synced: $synced';
  }

  @override
  String get noDeliveriesAdded => 'No deliveries added';

  @override
  String get startAddingDeliveries =>
      'Start adding your deliveries to track your work';

  @override
  String get addOrders => 'Add orders';

  @override
  String get imageFormatsMax10Mb => 'JPG, PNG, or WebP · max 10 MB';

  @override
  String get checkingYourLocation => 'Checking your location…';

  @override
  String get orderId => 'Order ID';

  @override
  String get orderIdHint => 'e.g. 12345';

  @override
  String get uploadOrderProof => 'Upload Order Proof';

  @override
  String get takePhotoOrChooseGallery => 'Take photo or choose from gallery';

  @override
  String get imageFormatsMax10MbShort => 'JPG, PNG, WebP · max 10 MB';

  @override
  String get markAsDelivered => 'Mark as Delivered';

  @override
  String get orderIdRequired => 'Order ID is required';

  @override
  String get deliverySavedOffline => 'Delivery saved offline';

  @override
  String get deliveryAddedSuccessfully => 'Delivery added successfully';

  @override
  String get deliveryWillSyncWhenOnline =>
      'This entry will sync automatically when internet returns.';

  @override
  String get keepGoingEveryDeliveryCounts =>
      'Keep going - every delivery counts!';

  @override
  String get addAnotherDelivery => 'Add Another Delivery';

  @override
  String get offlineModePendingSync => 'Offline mode active: pending sync';

  @override
  String get backToDeliveries => 'Back to Deliveries';

  @override
  String get deliveryDetails => 'Delivery details';

  @override
  String get status => 'Status';

  @override
  String get submitted => 'Submitted';

  @override
  String get partner => 'Partner';

  @override
  String get deliveryProof => 'Delivery proof';

  @override
  String get noProofImageUploaded => 'No proof image uploaded';

  @override
  String get couldNotLoadProofImage => 'Could not load proof image';

  @override
  String get couldNotDisplayImage => 'Could not display image';

  @override
  String get selectDate => 'Select date';

  @override
  String selectedDayVerifiedOrders(int count) {
    return 'Selected day verified orders: $count';
  }

  @override
  String thisMonthVerifiedOrders(int count) {
    return 'This month verified orders: $count';
  }

  @override
  String get apply => 'Apply';

  @override
  String get today => 'Today';

  @override
  String get pleaseSignInAgain => 'Please sign in again';

  @override
  String get accountNotActive =>
      'Your account is inactive or suspended. Please contact your administrator.';

  @override
  String get outsideAllowedDeliveryArea =>
      'You are outside the allowed delivery area. Move closer to your zone or an assigned restaurant.';

  @override
  String get gpsRequiredForDelivery =>
      'GPS location is required to log a delivery';

  @override
  String get zoneNotConfigured => 'Your zone is not configured. Contact admin.';

  @override
  String get noRestaurantsAssigned => 'No restaurants assigned. Contact admin.';

  @override
  String moveWithinRangeToLog(String range, String target) {
    return 'Move within $range of $target to log a delivery.';
  }

  @override
  String outsideRangeDetails(String distance, String range, String target) {
    return 'You are $distance outside range (within $range of $target).';
  }

  @override
  String get yourZone => 'your zone';

  @override
  String get assignedRestaurant => 'an assigned restaurant';

  @override
  String get accountNotSetupAsDriver =>
      'Your account is not set up as a driver.';

  @override
  String get couldNotLoadDeliveryLocationRules =>
      'Could not load delivery location rules. Pull to refresh or try again.';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get proofImageMissing => 'Proof image is missing';

  @override
  String get proofImageNotFound => 'Proof image not found';

  @override
  String get cannotViewProofImage => 'You cannot view this proof image';

  @override
  String get couldNotLoadEarnings => 'Could not load earnings';

  @override
  String get performanceSummary => 'Performance Summary';

  @override
  String get totalDeliveries => 'Total Deliveries';

  @override
  String get workingDays => 'Working Days';

  @override
  String get attendance => 'Attendance';

  @override
  String get incentives => 'Incentives';

  @override
  String get reimbursements => 'Reimbursements';

  @override
  String get deductions => 'Deductions';

  @override
  String get extraEarnings => 'Extra Earnings';

  @override
  String get dailyEarnings => 'Daily Earnings';

  @override
  String get noEarningsActivityThisMonth => 'No earnings activity this month.';

  @override
  String deliveryCountSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '1 delivery',
    );
    return '$_temp0';
  }

  @override
  String bonusesApplied(int count) {
    return '$count bonuses applied';
  }

  @override
  String get bonusSuffix => 'bonus';

  @override
  String get deductionsComingSoonTitle => 'Deductions';

  @override
  String get deductionsComingSoonBody =>
      'Coming soon — a detailed breakdown of any loans or penalties applied to your earnings.';

  @override
  String get payslipHistory => 'Payslip History';

  @override
  String get latestFirst => 'Latest first';

  @override
  String get noPayslipsYet =>
      'No payslips yet. Once your operations team approves a payout, it will appear here.';

  @override
  String deliveriesInPeriod(int count) {
    return '$count deliveries';
  }

  @override
  String deliveriesInPayoutPeriod(int count) {
    return '$count deliveries in this period';
  }

  @override
  String get activeOffers => 'Active Offers';

  @override
  String get noActiveIncentivesRightNow => 'No active incentives right now';

  @override
  String get checkBackLaterIncentives =>
      'Check back later — your operations team configures incentive rules from the admin panel.';

  @override
  String get couldNotLoadExtraEarnings => 'Could not load extra earnings';

  @override
  String get progress => 'Progress';

  @override
  String get bonusDefault => 'Bonus';

  @override
  String get incentiveDefault => 'Incentive';

  @override
  String upToAmount(String amount) {
    return 'up to $amount';
  }

  @override
  String perDeliveryAmount(String amount) {
    return '$amount/delivery';
  }

  @override
  String completeDeliveriesScope(int target, String scope, String period) {
    return 'Complete $target deliveries$scope $period';
  }

  @override
  String earnRewardsScope(String scope, String period) {
    return 'Earn rewards$scope $period';
  }

  @override
  String get periodTodayLower => 'today';

  @override
  String get periodThisWeekLower => 'this week';

  @override
  String get periodThisMonthLower => 'this month';

  @override
  String get periodThisPeriodLower => 'this period';

  @override
  String fromScope(String scope) {
    return 'from $scope';
  }

  @override
  String forScope(String scope) {
    return 'for $scope';
  }

  @override
  String get netEarnings => 'Net earnings';

  @override
  String get eligibleDeliveries => 'Eligible deliveries';

  @override
  String get basePay => 'Base pay';

  @override
  String get noDeliveriesLoggedThisDay => 'No deliveries logged this day.';

  @override
  String get incentiveRules => 'Incentive rules';

  @override
  String get noIncentiveRulesPaidThisDay =>
      'No incentive rules paid out this day.';

  @override
  String overrideRuleApplied(String amount) {
    return 'Override rule applied — final incentive $amount';
  }

  @override
  String eligibleDeliveriesProgress(int current, int target) {
    return '$current / $target eligible deliveries';
  }

  @override
  String eligibleDeliveriesCount(int count) {
    return '$count eligible deliveries';
  }

  @override
  String get couldNotLoadThisDay => 'Could not load this day';

  @override
  String get payslip => 'Payslip';

  @override
  String get netPayable => 'Net payable';

  @override
  String paidAt(String date, String time) {
    return 'Paid $date at $time';
  }

  @override
  String get breakdown => 'Breakdown';

  @override
  String get loanDeduction => 'Loan deduction';

  @override
  String get penalty => 'Penalty';

  @override
  String get adjustment => 'Adjustment';

  @override
  String get notes => 'Notes';

  @override
  String get detailedSnapshot => 'Detailed snapshot';

  @override
  String get frozenAtApproval => 'Frozen at the time this payout was approved.';

  @override
  String get couldNotLoadThisPayslip => 'Could not load this payslip';

  @override
  String get payslipNoLongerAvailable => 'This payslip is no longer available.';

  @override
  String get couldNotLoadAttendance => 'Could not load attendance';

  @override
  String attendanceDaysCompleted(int present, int elapsed) {
    return '$present/$elapsed days completed';
  }

  @override
  String get noLogin => 'No Login';

  @override
  String get lessThanZeroHours => 'Less than 0h';

  @override
  String get moreThanZeroHours => 'More than 0h';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMonUpper => 'MON';

  @override
  String get weekdayTueUpper => 'TUE';

  @override
  String get weekdayWedUpper => 'WED';

  @override
  String get weekdayThuUpper => 'THU';

  @override
  String get weekdayFriUpper => 'FRI';

  @override
  String get weekdaySatUpper => 'SAT';

  @override
  String get weekdaySunUpper => 'SUN';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMayShort => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String profileImageUploadFailed(String error) {
    return 'Profile image upload failed: $error';
  }

  @override
  String get profileCameraPermissionDenied =>
      'Camera access is needed to take a photo. Allow it when asked, or enable Camera in Settings.';

  @override
  String get rearCameraRequired =>
      'Rear camera is required to take an order photo.';

  @override
  String get profilePictureUpdated => 'Profile picture updated';

  @override
  String get uploadedPreviewFailed =>
      'Uploaded, but preview could not load. Pull down to refresh — contact support if it persists.';

  @override
  String get notificationsTurnedOff => 'Notifications turned off';

  @override
  String get notificationsTurnedOn => 'Notifications turned on';

  @override
  String get signOutConfirmBody =>
      'You will need your driver ID and passcode to sign in again.';

  @override
  String get accountSection => 'Account';

  @override
  String get myProfile => 'My Profile';

  @override
  String get attendanceAndLeaves => 'Attendance & Leaves';

  @override
  String get wrongAction => 'Wrong Action';

  @override
  String get paymentDetails => 'Payment Details';

  @override
  String get assets => 'Assets';

  @override
  String get preferencesSection => 'Preferences';

  @override
  String get notifications => 'Notifications';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get trainingSection => 'Training';

  @override
  String get tutorialMaterial => 'Tutorial Material';

  @override
  String get video => 'Video';

  @override
  String get couldNotLoadProfile => 'Could not load profile';

  @override
  String get profileSessionExpiredHint =>
      'Your session may have expired. Try again or sign out and sign back in.';

  @override
  String get profile => 'Profile';

  @override
  String get help => 'Help';

  @override
  String driverIdLabel(String code) {
    return 'ID: $code';
  }

  @override
  String get updateProfilePicture => 'Update profile picture';

  @override
  String couldNotLoadNotificationsWithError(String error) {
    return 'Couldn\'t load notifications.\n$error';
  }

  @override
  String get allCaughtUp => 'You\'re all caught up';

  @override
  String get notificationsEmptyHint =>
      'Important alerts and reminders from Musallam will show up here.';

  @override
  String get musallamAlertsChannelName => 'Musallam alerts';

  @override
  String get musallamAlertsChannelDesc =>
      'Operational alerts and reminders for drivers';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get vehicleComingSoon =>
      'Assigned vehicle and maintenance info. Coming soon.';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String onDutyStatusLabel(String status, String speed, String zone) {
    return '$status$speed · $zone';
  }

  @override
  String get couldNotStartUpload => 'Could not start upload';

  @override
  String get couldNotConfirmUpload => 'Could not confirm upload';

  @override
  String get networkErrorReachingAdminUploadServer =>
      'Network error reaching admin upload server';

  @override
  String uploadFailedWithStatus(int statusCode) {
    return 'Upload failed ($statusCode)';
  }

  @override
  String get availabilitySubmission => 'Availability Submission';

  @override
  String get shiftRequiredToGoIn => 'Submit shift to go In';

  @override
  String get shiftExpiredSubmitNext =>
      'Your shift has ended. Submit your next shift to go In.';

  @override
  String get shiftSubmissionSubtitle =>
      'Set your shift for this period. You can go In/Out freely until it ends, then submit again.';

  @override
  String get shiftSubmissionRequiredSubtitle =>
      'A shift is required before you can go In. This cannot be skipped.';

  @override
  String get shiftType => 'Shift Type';

  @override
  String get selectShift => 'Select Shift';

  @override
  String get singleShift => 'Single Shift';

  @override
  String get splitShift => 'Split Shift';

  @override
  String get setTimeline => 'Set Timeline';

  @override
  String get fromTime => 'From';

  @override
  String get toTime => 'To';

  @override
  String get session2 => 'Session 2';

  @override
  String get selectTime => 'Select time';

  @override
  String get confirm => 'Confirm';

  @override
  String get shiftEndsNextDay => 'Ends next day';

  @override
  String get session1Required => 'Please set session 1 start and end times';

  @override
  String get session2Required => 'Please set session 2 start and end times';

  @override
  String get invalidSessionDuration => 'End time must be after start time';

  @override
  String get sessionTooLong => 'Each session must be 24 hours or less';

  @override
  String get sessionsOverlap => 'Sessions cannot overlap';

  @override
  String get shiftLocked => 'Today\'s shift is locked until it ends';

  @override
  String get couldNotSubmitShift => 'Could not submit shift';

  @override
  String get outsideShiftWindowTitle => 'Outside shift window';

  @override
  String get outsideShiftWindowMessage =>
      'You are outside your submitted shift hours. You can continue anyway, but this may be flagged for review.';

  @override
  String get continueAnyway => 'Continue anyway';

  @override
  String get mustBeOnDutyToAddDelivery => 'You must be In to add a delivery';

  @override
  String get shiftRequiredBeforeDuty => 'Submit today\'s shift before going In';

  @override
  String get pickupOrder => 'Pickup Order';

  @override
  String get confirmPickup => 'Confirm Pickup';

  @override
  String get pickedUpAt => 'Picked up at';

  @override
  String get uploadPickupProof => 'Upload Pickup Proof';

  @override
  String get uploadPickupProofOptional => 'Upload Pickup Proof (optional)';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get confirmCancel => 'Confirm Cancel';

  @override
  String get cancelledAt => 'Cancelled at';

  @override
  String get cancelReasonLabel => 'Cancel reason';

  @override
  String get cancelNoteOptional => 'Note (optional)';

  @override
  String get rejectionReason => 'Rejection reason';

  @override
  String get cancelReasonRequired => 'Cancel reason is required';

  @override
  String get cancelReasonCustomerNoShow => 'Customer no-show';

  @override
  String get cancelReasonCustomerRefused => 'Customer refused';

  @override
  String get cancelReasonWrongAddress => 'Wrong address';

  @override
  String get cancelReasonRestaurantIssue => 'Restaurant issue';

  @override
  String get cancelReasonAccident => 'Accident';

  @override
  String get cancelReasonOther => 'Other';

  @override
  String get cancelNoteHint => 'Add details (optional)';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get activeDeliveryBanner => 'Active delivery';

  @override
  String get noActiveDelivery => 'No active delivery in progress';

  @override
  String get deliveryDuration => 'Duration';

  @override
  String get pickupProof => 'Pickup proof';

  @override
  String get deliveryProofOptional => 'Delivery proof (optional)';

  @override
  String get cancelProof => 'Cancel proof';

  @override
  String get mustCompleteActiveDeliveryFirst =>
      'Complete your current delivery before picking up another order';

  @override
  String get activePickupExists => 'You already have an order in progress';

  @override
  String get duplicateOrderId => 'This Order ID already exists.';

  @override
  String get invalidOrderId => 'Order ID must be 1–32 digits.';

  @override
  String get proofPhotoRequired => 'A proof photo is required';

  @override
  String get finishAsDelivered => 'Finish as delivered';

  @override
  String get finishAsCancelled => 'Finish as cancelled';

  @override
  String get switchOutcome => 'Switch';

  @override
  String get selectReason => 'Select a reason';

  @override
  String get permissionOverlayTitle => 'Display over other apps';

  @override
  String get permissionOverlayDesc =>
      'Shows a floating icon while you are In so you can return quickly.';

  @override
  String get grantOverlayPermission => 'Grant overlay permission';

  @override
  String get onDutyReturnToApp => 'You are In — return to the app';

  @override
  String get onDutyTurnOnGpsOverlay => 'Turn GPS on to continue while In';

  @override
  String get openLocationSettingsAction => 'Open location settings';

  @override
  String get pickupLoggedSuccessfully => 'Pickup logged successfully';

  @override
  String get cancelLoggedSuccessfully => 'Cancellation logged successfully';

  @override
  String get proceedToDeliverWhenReady =>
      'Head to the customer and mark as delivered when done.';

  @override
  String get shiftAdherenceTitle => 'Shift adherence';

  @override
  String minutesLateVsShift(int minutes) {
    return '$minutes min late vs shift';
  }

  @override
  String minutesEarlyOutVsShift(int minutes) {
    return '$minutes min early vs shift';
  }

  @override
  String get onTimeVsShift => 'On time vs shift';

  @override
  String get noShiftSubmitted => 'No shift submitted for today';

  @override
  String timeInToday(String duration) {
    return 'Time in today: $duration';
  }

  @override
  String shiftAdherenceLateShort(int minutes) {
    return '${minutes}m late';
  }

  @override
  String shiftAdherenceEarlyShort(int minutes) {
    return '${minutes}m early';
  }

  @override
  String get shiftAdherenceOnTimeShort => 'On time';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateAvailableBody(String version) {
    return 'Version $version is ready to install.';
  }

  @override
  String get updateDownload => 'Download update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateInstall => 'Install update';

  @override
  String get updateAllowInstallPermission =>
      'Allow Musallam to install app updates, then try again.';

  @override
  String get openInstallSettings => 'Open settings';

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateChecksumFailed =>
      'Download verification failed. Please try again.';

  @override
  String get updateNoInstallerAvailable =>
      'Couldn\'t open the Android installer. Please tap the downloaded APK from your Files app, or contact support.';

  @override
  String get updateApkMissing =>
      'The downloaded update file is missing. Tap Download to try again.';

  @override
  String get supportRequestTypeLeave => 'Leave';

  @override
  String get supportRequestTypeLeaveRequest => 'Leave request';

  @override
  String get supportRequestTypeSickLeave => 'Sick & accident leave';

  @override
  String get supportRequestTypeAsset => 'Asset request';

  @override
  String get supportRequestTypeFuel => 'Fuel reimbursement';

  @override
  String get supportRequestTypeDocument => 'Document request';

  @override
  String get supportRequestTypeDocumentReupload => 'Document re-upload';

  @override
  String get supportRequestTypeComplaint => 'Complaint';

  @override
  String get supportRequestTypeSalaryJustification => 'Salary justification';

  @override
  String get supportRequestTypeLoanAdvance => 'Advance / Loan';

  @override
  String get supportRequestTypeLoanRequest => 'Loan request';

  @override
  String get supportRequestTypeGeneric => 'Request';

  @override
  String get supportStatusAwaitingAck => 'Awaiting ack';

  @override
  String get supportStatusAcknowledged => 'Acknowledged';

  @override
  String get supportStatusInProgress => 'In progress';

  @override
  String get supportStatusSolved => 'Solved';

  @override
  String get supportStatusOverdue => 'Overdue';

  @override
  String get supportActionRequired => 'Action required';

  @override
  String get supportMyRequestsTitle => 'My requests';

  @override
  String get supportTabRequestSent => 'Request Sent';

  @override
  String get supportTabRequestReceived => 'Request Recieved';

  @override
  String supportCouldNotLoadRequests(String error) {
    return 'Could not load requests.\n$error';
  }

  @override
  String get supportNoRequestsSent => 'No requests sent yet';

  @override
  String get supportNoRequestsReceived => 'No requests received';

  @override
  String supportRequestsNeedResponse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests need your response',
      one: '1 request need your response',
    );
    return '$_temp0';
  }

  @override
  String get supportReasonAwaitingAck => 'Awaiting your acknowledgement';

  @override
  String get supportReasonLoanDetailsChanged => 'Loan details changed';

  @override
  String get supportReasonClarificationNeeded => 'Clarification needed';

  @override
  String get supportActionAcknowledgeUpdate => 'Acknowledge update';

  @override
  String get supportActionDocumentToSign => 'Document to sign';

  @override
  String supportCouldNotLoad(String error) {
    return 'Could not load.\n$error';
  }

  @override
  String get supportNoActionRequired => 'No action required right now';

  @override
  String get supportHubTitle => 'Help & support';

  @override
  String get supportSectionRaiseRequest => 'RAISE A REQUEST';

  @override
  String get supportTileSickAccidentLeave => 'Sick / Accident Leave';

  @override
  String get supportTileSalaryJustification => 'Salary Justification';

  @override
  String get supportTileLoanRequest => 'Loan Request';

  @override
  String get supportSectionVisitUs => 'VISIT US';

  @override
  String get supportScheduleVisitTitle => 'Schedule a visit to Central Tower';

  @override
  String get supportScheduleVisitSubtitle =>
      'Book a time slot for in-person help';

  @override
  String get supportSectionYourActivity => 'YOUR ACTIVITY';

  @override
  String get supportMyRequestsSubtitle => 'Track your requests';

  @override
  String get supportMyVisitsTitle => 'My visits';

  @override
  String get supportMyVisitsSubtitle => 'Booked tower visits';

  @override
  String get supportDocumentsToSign => 'Documents to sign';

  @override
  String get supportAppointments => 'Appointments';

  @override
  String supportBadgeNewCount(int count) {
    return '$count new';
  }

  @override
  String get supportFormTitleSickLeave => 'Sick / Accident leave';

  @override
  String get supportFormTitleLoan => 'Loan / Advance';

  @override
  String get supportFormTitleFuel => 'Fuel claim';

  @override
  String get supportFormTitleNew => 'New request';

  @override
  String get supportErrorLeaveTypeDatesRequired =>
      'Leave type and dates are required';

  @override
  String get supportErrorFromDateRequired => 'From date is required';

  @override
  String get supportErrorToDateRequired => 'To date is required';

  @override
  String get supportErrorToDateBeforeFrom =>
      'To date cannot be before From date';

  @override
  String get supportErrorNeededByInPast =>
      'Need by cannot be earlier than today';

  @override
  String get supportFieldLeaveSubtypeOther => 'Specify leave type';

  @override
  String get supportAttachmentPickFailed =>
      'Could not attach the file. Try again or take a photo.';

  @override
  String get supportErrorJustificationRequired => 'Justification is required';

  @override
  String get supportErrorSymptomsRequired => 'Symptoms / details are required';

  @override
  String get supportErrorMedicalDocsRequired =>
      'Medical documents are required';

  @override
  String get supportErrorAmountTenureRequired =>
      'Amount and tenure are required';

  @override
  String get supportErrorNeededByReasonRequired =>
      'Needed-by date and reason are required';

  @override
  String get supportErrorAssetFieldsRequired =>
      'Asset type, mode and status are required';

  @override
  String get supportErrorAmountPeriodRequired =>
      'Amount and period are required';

  @override
  String get supportErrorFuelReceiptsRequired => 'Fuel receipts are required';

  @override
  String get supportErrorDocumentFieldsRequired =>
      'Document fields are required';

  @override
  String get supportErrorComplaintFieldsRequired =>
      'Category, severity, subject and description required';

  @override
  String get supportErrorSalaryFieldsRequired => 'Salary fields are required';

  @override
  String get supportErrorAcceptDeclaration => 'Please accept the declaration';

  @override
  String get supportLeaveTypeAnnual => 'Annual';

  @override
  String get supportLeaveTypeEmergency => 'Emergency';

  @override
  String get supportLeaveTypeAccident => 'Accident';

  @override
  String get supportLeaveTypeUnpaid => 'Unpaid Leave';

  @override
  String get supportSickTypeSickLeave => 'Sick leave';

  @override
  String get supportSickTypeInjury => 'Injury';

  @override
  String get supportOptionOther => 'Other';

  @override
  String get supportAssetSimCard => 'SIM card';

  @override
  String get supportAssetFuelCard => 'Fuel card';

  @override
  String get supportAssetFuelLimitChange => 'Fuel limit change';

  @override
  String get supportAssetRaincoat => 'Raincoat';

  @override
  String get supportAssetDeliveryBag => 'Delivery bag';

  @override
  String get supportAssetReflectiveVest => 'Reflective vest';

  @override
  String get supportAssetWinterJacket => 'Winter jacket';

  @override
  String get supportAssetDeliveryAttire => 'Delivery attire';

  @override
  String get supportAssetDeliveryPants => 'Delivery pants';

  @override
  String get supportAssetNewBike => 'New bike';

  @override
  String get supportAssetHelmet => 'Helmet';

  @override
  String get supportAssetDeliveryBox => 'Delivery box';

  @override
  String get supportAssetFuelChip => 'Fuel chip';

  @override
  String get supportAssetPhone => 'Phone';

  @override
  String get supportAssetMobileHolder => 'Mobile holder';

  @override
  String get supportDocTypeCivilIdCopy => 'Civil ID copy';

  @override
  String get supportDocTypeLicenseCopy => 'License Copy';

  @override
  String get supportDocTypeWorkPermitCopy => 'Work permit copy';

  @override
  String get supportDocTypeRegistrationCopy => 'Registration copy';

  @override
  String get supportDocTypeVehicleDocumentCopy => 'Vehicle document copy';

  @override
  String get supportDocTypeSalaryCertification => 'Salary certification';

  @override
  String get supportRequestModeRenewal => 'Renewal';

  @override
  String get supportRequestModeFirstTime => 'First Time';

  @override
  String get supportAssetStatusLost => 'Lost';

  @override
  String get supportAssetStatusDamaged => 'Damaged';

  @override
  String get supportDeliveryMethodEmail => 'Email';

  @override
  String get supportDeliveryMethodPickup => 'Pickup';

  @override
  String get supportSeverityLow => 'Low';

  @override
  String get supportSeverityMedium => 'Medium';

  @override
  String get supportSeverityHigh => 'High';

  @override
  String get supportFieldLeaveType => 'Leave type';

  @override
  String get supportFieldFrom => 'From';

  @override
  String get supportFieldTo => 'To';

  @override
  String get supportFieldCommentOptional => 'Comment (optional)';

  @override
  String get supportFieldComment => 'Comment';

  @override
  String get supportHintMentionHere => 'Mention here';

  @override
  String get supportFieldJustificationRequired => 'Justification *';

  @override
  String supportFieldRequiredNamed(String field) {
    return '$field is required';
  }

  @override
  String supportErrorAttachmentsMin(int count) {
    return 'Attach at least $count file(s)';
  }

  @override
  String get supportAttachmentRequired => 'Attachment *';

  @override
  String get supportRequestTypeUnknown => 'This request type is not available.';

  @override
  String get supportRequestTypeNoFields =>
      'This request type has no form yet. Please try again later.';

  @override
  String get supportAttachmentOptional => 'Attachment (optional)';

  @override
  String supportFilesSelected(int count) {
    return '$count file(s) selected';
  }

  @override
  String get supportFieldSymptomsRequired => 'Symptoms / details *';

  @override
  String get supportUploadMedicalCertificate => 'Upload medical certificate *';

  @override
  String get supportFieldAmountKwdRequired => 'Amount (KWD) *';

  @override
  String get supportLoanTenureUnavailable =>
      'Tenure options are not configured yet. Loan requests are temporarily unavailable.';

  @override
  String get supportFieldTenureRequired => 'Tenure *';

  @override
  String get supportFieldNeededBy => 'Needed by';

  @override
  String get supportFieldReasonRequired => 'Reason *';

  @override
  String get supportFieldAssetType => 'Asset type';

  @override
  String get supportFieldQuantity => 'Quantity';

  @override
  String get supportFieldPeriodMonth => 'Period (month)';

  @override
  String get supportFieldDistanceKm => 'Distance (km)';

  @override
  String get supportUploadFuelReceipts => 'Upload fuel receipts *';

  @override
  String get supportFieldDocumentType => 'Document type';

  @override
  String get supportComplaintCategoriesUnavailable =>
      'Complaint categories are not configured yet. Complaints are temporarily unavailable.';

  @override
  String get supportFieldCategoryRequired => 'Category *';

  @override
  String get supportFieldCategory => 'Category';

  @override
  String get supportFieldSubjectRequired => 'Subject *';

  @override
  String get supportFieldSubject => 'Subject';

  @override
  String get supportFieldDescriptionRequired => 'Description *';

  @override
  String get supportFieldDescription => 'Description';

  @override
  String get supportFieldSeverity => 'Severity';

  @override
  String get supportAddAttachment => 'Add attachment';

  @override
  String get supportAddAttachmentHint =>
      'Attach a photo or document (optional)';

  @override
  String get supportFieldSalaryMonth => 'Salary Month';

  @override
  String get supportFieldExpectedAmountRequired => 'Expected amount *';

  @override
  String get supportFieldReceivedAmountRequired => 'Received amount *';

  @override
  String get supportSupportingDocument => 'Supporting document';

  @override
  String get supportPhotoOptional => 'Photo (optional)';

  @override
  String get supportAttachPayslipOptional => 'Attach payslip (optional)';

  @override
  String get supportDeclarationLeave =>
      'Declaration: I am entitled to return on time, otherwise the company to apply the list of penalties in case of late return.';

  @override
  String get supportDeclarationLoan =>
      'Declaration: I am committed to pay the full amount to the company or the company to deduct it as per the installments from my salary.';

  @override
  String get supportDeclarationAsset =>
      'Declaration: In the case of lost or damaged item replacement i am entitled for any charges from the company to receive a new one.';

  @override
  String get supportTemporarilyUnavailable => 'Temporarily unavailable';

  @override
  String get supportSubmitRequest => 'Submit request';

  @override
  String get supportChooseSource => 'Choose Source';

  @override
  String get supportChooseFromGallery => 'Choose from gallery';

  @override
  String get supportTakeAPhoto => 'Take a photo';

  @override
  String get supportResponseSubmitted => 'Response submitted';

  @override
  String get supportAskQuestion => 'Ask a question';

  @override
  String get supportAskQuestionBody =>
      'Send a note to the ops team about this request. They will reply here.';

  @override
  String get supportAskQuestionHint =>
      'e.g. Which side of the Emirates ID do you need?';

  @override
  String get supportSendQuestion => 'Send question';

  @override
  String get supportAttachDocumentFirst =>
      'Please attach the requested document first';

  @override
  String get supportRequestDetailsTitle => 'Request details';

  @override
  String get supportFromManagement => 'From management';

  @override
  String get supportApprovalProgress => 'Approval progress';

  @override
  String get supportUploadRequestedDocument => 'Upload requested document';

  @override
  String get supportUploadHintChooseOrCapture =>
      'Choose image or capture the delivery proof';

  @override
  String get supportYourResponse => 'Your response';

  @override
  String get supportResponseRequired => 'Enter a response before submitting';

  @override
  String get supportQuestionRequired => 'Enter a question before sending';

  @override
  String get supportFieldAmount => 'Amount';

  @override
  String get supportFieldTransferType => 'Transfer type';

  @override
  String get supportTransferTypeCash => 'Cash';

  @override
  String get supportTransferTypeSalary => 'Salary';

  @override
  String get supportRejectionReason => 'Rejection reason';

  @override
  String get supportClarificationFromAdmin => 'From admin';

  @override
  String get supportClarificationYourReply => 'Your reply';

  @override
  String get supportSubmitResponse => 'Submit response';

  @override
  String get supportNoteOptional => 'Note (optional)';

  @override
  String get supportAddNote => 'Add note';

  @override
  String get supportCreatedOnBehalfBy => 'Created on behalf by';

  @override
  String get supportCreatedOnBehalfAt => 'Created on behalf at';

  @override
  String get supportFieldRequestMode => 'Request mode';

  @override
  String get supportUploadDocuments => 'Upload documents';

  @override
  String get supportAcknowledge => 'Acknowledge';

  @override
  String get supportAttachedFile => 'Attached file';

  @override
  String get supportNoneAttached => 'None attached';

  @override
  String get supportFieldRequested => 'Requested';

  @override
  String get supportFieldInstallments => 'Installments';

  @override
  String supportMonthsCount(String count) {
    return '$count months';
  }

  @override
  String get supportFieldPurpose => 'Purpose';

  @override
  String get supportFieldAsset => 'Asset';

  @override
  String supportAssetWithSize(String asset, String size) {
    return '$asset ($size)';
  }

  @override
  String get supportFieldCondition => 'Condition';

  @override
  String get supportFieldEvidence => 'Evidence';

  @override
  String get supportFieldDates => 'Dates';

  @override
  String get supportFieldDuration => 'Duration';

  @override
  String supportDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get supportFieldAttachment => 'Attachment';

  @override
  String get supportStepInReview => 'In review';

  @override
  String supportStepSince(String word, String date) {
    return '$word since $date';
  }

  @override
  String supportStepDecidedAt(String word, String dateTime) {
    return '$word · $dateTime';
  }

  @override
  String get supportReason => 'Reason';

  @override
  String get supportAdminResponse => 'Admin response';

  @override
  String get supportCommentFromAdmin => 'Comment from admin';

  @override
  String get supportFieldRequestedAmount => 'Requested amount';

  @override
  String get supportFieldApprovedAmount => 'Approved amount';

  @override
  String get supportFieldDeductionStarts => 'Deduction starts';

  @override
  String get supportFieldApprovedBy => 'Approved by';

  @override
  String get supportFieldPenaltyAmount => 'Penalty amount';

  @override
  String get supportFieldRequestedBy => 'Requested by';

  @override
  String get supportStatusOnHold => 'On hold';

  @override
  String get supportFieldRequired => 'Required';

  @override
  String get supportNotSpecified => 'Not specified';

  @override
  String get supportBadgeAmountChanged => 'Amount changed';

  @override
  String get supportBadgeUpdate => 'Update';

  @override
  String get supportBadgePenaltyApplied => 'Penalty applied';

  @override
  String get supportBadgeReviewRequired => 'Review required';

  @override
  String get supportBadgeDocumentsRequired => 'Documents required';

  @override
  String supportFilesReady(int count) {
    return '$count file(s) ready';
  }

  @override
  String get supportUpload => 'Upload';

  @override
  String get supportCapture => 'Capture';

  @override
  String get supportSubmittedTitle => 'Submitted';

  @override
  String get supportRequestSubmitted => 'Request submitted';

  @override
  String get supportRequestSubmittedBody =>
      'We have received your request and will review it shortly. You can track its status anytime.';

  @override
  String get supportFieldRequestId => 'Request ID';

  @override
  String get supportFieldType => 'Type';

  @override
  String get supportTrackRequest => 'Track request';

  @override
  String get supportBackToSupport => 'Back to support';

  @override
  String get supportAcknowledgedTitle => 'Acknowledged';

  @override
  String get supportResponseAcknowledged => 'Response acknowledged';

  @override
  String get supportResponseAcknowledgedBody =>
      'Thanks. We\'ve let the admin know you\'ve seen and accepted their response.';

  @override
  String supportCodeWithType(String code, String type) {
    return '$code · $type';
  }

  @override
  String get supportBackToMyRequests => 'Back to my requests';

  @override
  String get weekdayInitialSun => 'S';

  @override
  String get weekdayInitialMon => 'M';

  @override
  String get weekdayInitialTue => 'T';

  @override
  String get weekdayInitialWed => 'W';

  @override
  String get weekdayInitialThu => 'T';

  @override
  String get weekdayInitialFri => 'F';

  @override
  String get weekdayInitialSat => 'S';

  @override
  String get visitCentralTower => 'Central Tower';

  @override
  String get visitStepReason => 'Visit reason';

  @override
  String get visitStepSelectDate => 'Select date';

  @override
  String get visitStepReviewConfirm => 'Review & confirm';

  @override
  String get visitBooking => 'Booking…';

  @override
  String get visitConfirmBooking => 'Confirm booking';

  @override
  String get visitDefaultBranchName => 'Musallam Central Tower';

  @override
  String get visitHeadOfficeSubtitle => 'Head office - rider services';

  @override
  String get visitFieldLocation => 'Location';

  @override
  String get visitFieldWorkingHours => 'Working hours';

  @override
  String get visitFieldContact => 'Contact';

  @override
  String get visitBookASlot => 'Book a slot';

  @override
  String get visitSkipQueueHint =>
      'Booking a slot helps you skip the queue and get seen faster.';

  @override
  String get visitSelectDepartment => 'SELECT A DEPARTMENT';

  @override
  String get visitAddNoteOptional => 'Add a note (optional)';

  @override
  String get visitNoteHint => 'Briefly describe your issue';

  @override
  String get visitChange => 'Change';

  @override
  String get visitNoSlotsForDate => 'No slots available for this date.';

  @override
  String get visitSectionMorning => 'MORNING';

  @override
  String get visitSectionAfternoon => 'AFTERNOON';

  @override
  String get visitLunchBreak => 'Lunch break';

  @override
  String get visitSlotFull => 'Full';

  @override
  String visitSlotRemaining(int count) {
    return '$count left';
  }

  @override
  String visitSlotRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String get visitFieldDepartment => 'Department';

  @override
  String get visitFieldDate => 'Date';

  @override
  String get visitFieldTime => 'Time';

  @override
  String get visitFieldNote => 'Note';

  @override
  String get visitArriveEarlyHint =>
      'Please arrive 10 minutes early and carry your rider ID.';

  @override
  String get visitBookedTitle => 'Visit Booked';

  @override
  String get visitBookedBody =>
      'Your visit is confirmed. Show this ticket at the Central Tower reception.';

  @override
  String get visitTicketHeader => 'CENTRAL TOWER VISIT';

  @override
  String get visitScanAtReception => 'Scan at reception';

  @override
  String visitBookingTokenHint(String code) {
    return 'Booking token $code. Keep this ready on arrival.';
  }

  @override
  String get visitViewMyVisits => 'View my visits';

  @override
  String get visitTabUpcoming => 'Upcoming';

  @override
  String get visitTabPast => 'Past';

  @override
  String get visitNoUpcoming => 'No upcoming visits';

  @override
  String get visitNoPast => 'No past visits';

  @override
  String get visitRescheduleTitle => 'Reschedule visit?';

  @override
  String visitRescheduleBody(String code) {
    return 'Cancel $code and book a new slot?';
  }

  @override
  String get visitKeep => 'Keep';

  @override
  String get visitReschedule => 'Reschedule';

  @override
  String get visitStatusConfirmed => 'Confirmed';

  @override
  String get visitStatusCheckedIn => 'Checked in';

  @override
  String get visitMonthJanUpper => 'JAN';

  @override
  String get visitMonthFebUpper => 'FEB';

  @override
  String get visitMonthMarUpper => 'MAR';

  @override
  String get visitMonthAprUpper => 'APR';

  @override
  String get visitMonthMayUpper => 'MAY';

  @override
  String get visitMonthJunUpper => 'JUN';

  @override
  String get visitMonthJulUpper => 'JUL';

  @override
  String get visitMonthAugUpper => 'AUG';

  @override
  String get visitMonthSepUpper => 'SEP';

  @override
  String get visitMonthOctUpper => 'OCT';

  @override
  String get visitMonthNovUpper => 'NOV';

  @override
  String get visitMonthDecUpper => 'DEC';

  @override
  String get esignNoDocumentsToSign => 'No documents to sign';

  @override
  String get esignSectionPending => 'Pending';

  @override
  String get esignSectionSigned => 'Signed';

  @override
  String get esignSectionDeclined => 'Declined';

  @override
  String esignDueOn(String date) {
    return 'Due $date';
  }

  @override
  String esignSignedOn(String date) {
    return 'Signed $date';
  }

  @override
  String get esignDeclineDocument => 'Decline document';

  @override
  String get esignDeclineBody =>
      'Let admin know why you cannot sign this document.';

  @override
  String get esignDeclineReasonHint => 'Reason (optional)';

  @override
  String get esignDocumentDeclined => 'Document declined';

  @override
  String get esignDocumentTitle => 'Document';

  @override
  String get esignReviewDocument => 'Review document';

  @override
  String get esignNoDocumentAttached => 'No document attached.';

  @override
  String get esignPreviewLoadFailed => 'Could not load document preview.';

  @override
  String get esignPreviewUnavailable =>
      'Preview unavailable — open externally.';

  @override
  String get esignPdfDocument => 'PDF document';

  @override
  String get esignTapToOpen => 'Tap to open';

  @override
  String get esignOpenFullDocument => 'Open full document';

  @override
  String get esignFromAdmin => 'From admin';

  @override
  String esignMetaLine(String code, String category, String source) {
    return '$code$category · $source';
  }

  @override
  String get esignDecline => 'Decline';

  @override
  String get esignSignDocument => 'Sign document';

  @override
  String get esignAddYourSignature => 'Add your signature';

  @override
  String get esignDrawSignatureHint => 'Draw your signature in the box below';

  @override
  String get esignClear => 'Clear';

  @override
  String get esignLegalDeclaration =>
      'I agree this is my legal electronic signature.';

  @override
  String get esignPleaseDrawSignature => 'Please draw your signature';

  @override
  String get esignCapturedWith => 'Captured with your signature:';

  @override
  String get esignSignerYou => 'You';

  @override
  String get esignSubmitting => 'Submitting…';

  @override
  String get esignConfirmSignature => 'Confirm signature';

  @override
  String get esignSignedTitle => 'Signed';

  @override
  String get esignDocumentSigned => 'Document signed';

  @override
  String get esignDocumentSignedBody =>
      'Your signature has been sent to admin and saved to your records.';

  @override
  String get esignSignatureProof => 'Signature proof';

  @override
  String get esignFieldSignedBy => 'Signed by';

  @override
  String get esignFieldDateTime => 'Date & time';

  @override
  String get esignFieldIpAddress => 'IP address';

  @override
  String get esignNotCaptured => 'Not captured';

  @override
  String get esignFieldDevice => 'Device';

  @override
  String get esignDownloadSignedCopy => 'Download signed copy';

  @override
  String get esignDownloadDocument => 'Download document';

  @override
  String get esignNoDocumentToDownload => 'No document available to download';

  @override
  String get esignSignedCopyReady =>
      'Your signature is stamped on the last page of this copy.';

  @override
  String get esignSignedCopyPending =>
      'Preparing your signed copy — this is the original document until it is ready. Reopen this screen in a moment.';

  @override
  String get esignSignedCopyUnavailable =>
      'Signed copy unavailable, so this is the original document you were sent. Your signature is stored with the request.';

  @override
  String get esignBackToDocuments => 'Back to documents';

  @override
  String get visitDefaultWorkingHours => 'Sun - Thu, 9:00 AM - 5:00 PM';

  @override
  String get esignScreenshotsRestricted =>
      'Screenshots disabled for this document';

  @override
  String get esignContentHidden => 'Content hidden';

  @override
  String get apptNoneScheduled => 'No appointments scheduled';

  @override
  String get apptRequestTitle => 'Appointment request';

  @override
  String get apptNotFound => 'Appointment not found';

  @override
  String apptFromRequester(String code, String name) {
    return '$code · From $name';
  }

  @override
  String get apptRequesterAdmin => 'admin';

  @override
  String get apptDetails => 'Details';

  @override
  String get apptFieldPurpose => 'Purpose';

  @override
  String get apptFieldProposedDateTime => 'Proposed date/time';

  @override
  String get apptFieldLocation => 'Location';

  @override
  String get apptFieldNote => 'Note';

  @override
  String get apptFieldYourProposedTime => 'Your proposed time';

  @override
  String get apptFieldYourNote => 'Your note';

  @override
  String get apptNoticeAccepted =>
      'You accepted this appointment. Arrive on time at reception.';

  @override
  String get apptNoticeRejected => 'You rejected this appointment.';

  @override
  String get apptNoticeRescheduleRequested =>
      'You proposed a new time. Waiting for admin to confirm.';

  @override
  String get apptNoticeScheduled =>
      'Your appointment is scheduled. Arrive on time at reception.';

  @override
  String get apptReject => 'Reject';

  @override
  String get apptProposeTime => 'Propose time';

  @override
  String get apptAcceptAppointment => 'Accept appointment';

  @override
  String get apptRejectAppointment => 'Reject appointment';

  @override
  String get apptRejectBody => 'Let admin know why you cannot make it.';

  @override
  String get supportReasonOptionalHint => 'Reason (optional)';

  @override
  String get apptRejected => 'Appointment rejected';

  @override
  String get apptProposeNewTime => 'Propose a new time';

  @override
  String get apptNoteForAdminHint => 'Note for admin (optional)';

  @override
  String get apptSendProposedTime => 'Send proposed time';

  @override
  String get apptProposedTimeSent => 'Proposed time sent to admin';

  @override
  String get apptConfirmedTitle => 'Appointment confirmed';

  @override
  String get apptConfirmedBody =>
      'It\'s been added to your schedule. We\'ll remind you before it starts.';

  @override
  String get apptDone => 'Done';

  @override
  String get apptViewInCalendar => 'View in calendar';

  @override
  String apptTitleWithTime(String title, String time) {
    return '$title · $time';
  }

  @override
  String get supportStatusRescheduled => 'Rescheduled';

  @override
  String get supportStatusResponded => 'Responded';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportActionRescheduleProposed => 'New dates proposed';

  @override
  String get supportRescheduleProposedTitle => 'New dates proposed';

  @override
  String get supportRescheduleNewStart => 'New start date';

  @override
  String get supportRescheduleNewEnd => 'New end date';

  @override
  String get supportRescheduleProposedBy => 'Proposed by';

  @override
  String get supportRescheduleAccept => 'Accept dates';

  @override
  String get supportRescheduleDecline => 'Decline';

  @override
  String get supportRescheduleAccepted =>
      'Dates accepted. Your request is back under review.';

  @override
  String get supportRescheduleDeclined =>
      'Dates declined. Your request is back under review.';
}
