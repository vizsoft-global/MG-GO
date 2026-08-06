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
      'Exclude the app from battery restrictions while In.';

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
  String get accountNotActive => 'Your account is not active';

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
  String get profilePictureUpdated => 'Profile picture updated';

  @override
  String get uploadedPreviewFailed =>
      'Uploaded, but preview could not load. Pull down to refresh — contact support if it persists.';

  @override
  String get notificationsSettingsComingSoon =>
      'Notifications settings are coming soon';

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
  String get cancelOrder => 'Cancel Order';

  @override
  String get confirmCancel => 'Confirm Cancel';

  @override
  String get cancelledAt => 'Cancelled at';

  @override
  String get cancelReasonLabel => 'Cancel reason';

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
  String get duplicateOrderId => 'This order ID is already logged';

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
}
