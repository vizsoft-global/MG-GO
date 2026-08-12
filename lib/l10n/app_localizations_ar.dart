// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitleDefault => 'مسلم للتوصيل';

  @override
  String get appSubtitleDefault => 'شريك التوصيل';

  @override
  String get loginHintDefault => 'أدخل رقمك ورمز الدخول من لوحة الإدارة';

  @override
  String get maintenanceMessageDefault =>
      'تطبيق السائق غير متاح مؤقتاً. يرجى المحاولة لاحقاً.';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get cancel => 'إلغاء';

  @override
  String get ok => 'موافق';

  @override
  String get exit => 'خروج';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutQuestion => 'تسجيل الخروج؟';

  @override
  String get comingSoon => 'قريباً';

  @override
  String comingSoonMessage(String featureName) {
    return '$featureName قريباً.';
  }

  @override
  String get somethingWentWrong => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get sessionExpired => 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get serverUpdateRequired => 'مطلوب تحديث من الخادم. تواصل مع الدعم.';

  @override
  String get contactAdmin => 'تواصل مع المسؤول للتفاصيل.';

  @override
  String get contactSupport => 'تواصل مع الدعم.';

  @override
  String get notificationFallback => 'إشعار';

  @override
  String get justNow => 'الآن';

  @override
  String get now => 'الآن';

  @override
  String minutesAgo(int minutes) {
    return 'منذ $minutes د';
  }

  @override
  String hoursAgo(int hours) {
    return 'منذ $hours س';
  }

  @override
  String daysAgo(int days) {
    return 'منذ $days ي';
  }

  @override
  String get paid => 'مدفوع';

  @override
  String get approved => 'موافق عليه';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get verified => 'موثّق';

  @override
  String get rejected => 'مرفوض';

  @override
  String get underReview => 'قيد المراجعة';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get notProvided => 'غير متوفر';

  @override
  String get driverFallback => 'سائق';

  @override
  String orderIdPrefix(String orderId) {
    return 'طلب #$orderId';
  }

  @override
  String get deliverySingular => 'توصيل';

  @override
  String get deliveryPlural => 'توصيلات';

  @override
  String deliveriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count توصيل',
      many: '$count توصيلاً',
      few: '$count توصيلات',
      two: 'توصيلان',
      one: 'توصيل واحد',
    );
    return '$_temp0';
  }

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get verifyIdentityTitle => 'التحقق من الهوية';

  @override
  String get verifyIdentityMessage =>
      'انظر إلى الكاميرا ورمش مرة واحدة لإثبات حضورك. تُلتقط الصورة بعد نجاح الرمش. مطلوب مرة واحدة يومياً.';

  @override
  String get verifyIdentityPermissionDenied =>
      'إذن الكاميرا مطلوب للتحقق من هويتك. امنح الوصول إلى الكاميرا للمتابعة. لا يمكن تخطي هذه الخطوة.';

  @override
  String get verifyIdentityBlinkInstruction => 'رمش مرة واحدة';

  @override
  String get verifyIdentityFaceNotFound => 'ضع وجهك داخل الإطار';

  @override
  String get verifyIdentityBlinkTimeout => 'لم يتم اكتشاف الرمش، حاول مرة أخرى';

  @override
  String get verifyIdentityInitError =>
      'فشل تشغيل الكاميرا أو اكتشاف الوجه. اضغط إعادة المحاولة. لا يمكن تخطي هذه الخطوة.';

  @override
  String get verifyIdentityBlinkSuccess => 'تم اكتشاف الرمش';

  @override
  String get verifyIdentityRetake => 'إعادة الالتقاط';

  @override
  String get verifyIdentityConfirm => 'تأكيد الصورة';

  @override
  String get verifyIdentitySaving => 'جاري حفظ الصورة…';

  @override
  String get chooseImageSource => 'اختر مصدر الصورة';

  @override
  String get chooseFromGallery => 'اختر من المعرض';

  @override
  String get imgLabel => 'صورة';

  @override
  String get required => 'مطلوب';

  @override
  String uploadingProgress(int percent) {
    return 'جاري الرفع… $percent%';
  }

  @override
  String get readyToUpload => 'جاهز للرفع';

  @override
  String readyToUploadWithSizeKb(String sizeKb) {
    return '$sizeKb ك.ب · جاهز للرفع';
  }

  @override
  String readyToUploadWithSizeMb(String sizeMb) {
    return '$sizeMb م.ب · جاهز للرفع';
  }

  @override
  String get fileEmpty => 'الملف فارغ';

  @override
  String get fileTooLarge10Mb => 'يجب أن تكون الصورة 10 م.ب أو أقل';

  @override
  String get fileTooLarge2Mb => 'يجب أن تكون صورة الملف 2 م.ب أو أقل';

  @override
  String get imagesAllowedOnly => 'يُسمح فقط بصور JPG أو PNG أو WebP';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get language => 'اللغة';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get driverId => 'رقم السائق';

  @override
  String get employeeId => 'رقم الموظف';

  @override
  String get passcode => 'رمز الدخول';

  @override
  String get passcodeHint => 'رمز مكوّن من 6 أرقام من لوحة الإدارة';

  @override
  String get continueButton => 'متابعة';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get deviceConflictTitle => 'تم تسجيل الدخول على جهاز آخر';

  @override
  String get deviceConflictMessage =>
      'هذا الحساب نشط على جهاز آخر. يمكنك الاستمرار على ذلك الجهاز أو تسجيل الدخول هنا.';

  @override
  String deviceConflictActiveLabel(String device) {
    return 'الجهاز النشط: $device';
  }

  @override
  String deviceConflictLastSeen(String date, String time) {
    return 'آخر نشاط: $date الساعة $time';
  }

  @override
  String get deviceConflictUnknownDevice => 'جهاز غير معروف';

  @override
  String get deviceConflictContinueButton => 'الاستمرار على الجهاز الآخر';

  @override
  String get deviceConflictSignInHereButton => 'تسجيل الدخول هنا';

  @override
  String get signedInOnAnotherDeviceToast =>
      'تم تسجيل الدخول على جهاز آخر. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get enterDriverId => 'أدخل رقم السائق المكوّن من 5 أرقام.';

  @override
  String get enterEmployeeId => 'أدخل رقم الموظف المكوّن من 4 إلى 8 أرقام.';

  @override
  String get enterPasscode => 'أدخل رمز الدخول المكوّن من 6 أرقام.';

  @override
  String get authNotConfigured =>
      'التطبيق غير مهيأ. أضف SUPABASE_ANON_KEY عند التشغيل.';

  @override
  String get authInvalidCredentials =>
      'رقم الموظف أو رمز الدخول غير صحيح. حاول مرة أخرى.';

  @override
  String get authDriverNotActive =>
      'حساب السائق غير نشط بعد. تواصل مع المسؤول.';

  @override
  String get authDriverSuspended => 'تم تعليق حساب السائق. تواصل مع المسؤول.';

  @override
  String get authStaffNotAllowed => 'هذا الحساب مخصص للوحة الإدارة فقط.';

  @override
  String get authProfileSyncFailed =>
      'تم تسجيل الدخول لكن إعداد الملف فشل. تواصل مع الدعم.';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabDeliveries => 'التوصيلات';

  @override
  String get tabEarnings => 'الأرباح';

  @override
  String get tabVehicle => 'المركبة';

  @override
  String get tabProfile => 'الملف';

  @override
  String get exitAppQuestion => 'الخروج من التطبيق؟';

  @override
  String get exitAppMessage => 'أنت غير متصل وخارج الخدمة. الخروج من التطبيق؟';

  @override
  String get offlineMode => 'وضع عدم الاتصال';

  @override
  String get offlineModeDescription =>
      'يتم حفظ تغييراتك على الجهاز وستُزامَن تلقائياً عند عودة الاتصال.';

  @override
  String get accessBlocked => 'الوصول محظور';

  @override
  String get accountBlockedDefault =>
      'تم حظر حسابك. تواصل مع المسؤول للتفاصيل.';

  @override
  String get backToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get underMaintenance => 'تحت الصيانة';

  @override
  String get pullDownToRefresh => 'اسحب للأسفل للتحديث';

  @override
  String get developerModeDetectedTitle => 'يجب إيقاف خيارات المطوّر';

  @override
  String get closeApp => 'إغلاق التطبيق';

  @override
  String get developerModeDetectedMessage =>
      'لا يمكن تشغيل هذا التطبيق أثناء تفعيل خيارات المطوّر. أوقفها من إعدادات الهاتف ثم افتح التطبيق مرة أخرى. تم إزالة التحديث عبر التثبيت الجانبي — حدّث التطبيق فقط من Google Play.';

  @override
  String get mockLocationDetectedTitle => 'تم اكتشاف موقع وهمي';

  @override
  String get mockLocationDetectedMessage =>
      'إعداد الموقع الوهمي مفعّل على هذا الجهاز. تم تسجيل ذلك.';

  @override
  String get fakeGpsDetectedTitle => 'تم اكتشاف GPS وهمي';

  @override
  String get fakeGpsDetectedMessage =>
      'تم اكتشاف GPS وهمي. إجراءات التوصيل والموقع محظورة حتى يتم إيقافه.';

  @override
  String get fakeGpsBlockedAction =>
      'تم اكتشاف GPS وهمي. أوقف الموقع الوهمي وحاول مرة أخرى.';

  @override
  String get screenCaptureBlockedTitle => 'التقاط الشاشة محظور';

  @override
  String get screenCaptureBlockedMessage =>
      'لقطات الشاشة والتسجيل غير مسموحين. تم تسجيل هذه المحاولة.';

  @override
  String get sosComingSoon => 'SOS قريباً';

  @override
  String get couldNotStartDuty => 'تعذّر تسجيل الدخول';

  @override
  String get couldNotUpdateDutyStatus => 'تعذّر تحديث حالة داخل/خارج';

  @override
  String get currentSpeed => 'السرعة الحالية';

  @override
  String get distanceToday => 'المسافة اليوم';

  @override
  String speedValue(String speed) {
    return '$speed كم/س';
  }

  @override
  String distanceValue(String distance) {
    return '$distance كم';
  }

  @override
  String get welcomeBack => 'مرحباً بعودتك،';

  @override
  String get online => 'داخل';

  @override
  String get offline => 'خارج';

  @override
  String get sos => 'SOS';

  @override
  String get bonusOnTrackDefault =>
      'أنت على المسار الصحيح — استمر في التوصيل لفتح المكافآت';

  @override
  String get addDelivery => 'إضافة توصيل';

  @override
  String get startDuty => 'تسجيل الدخول';

  @override
  String get thisWeeksProgress => 'تقدم هذا الأسبوع';

  @override
  String get week => 'أسبوع';

  @override
  String get earnings => 'الأرباح';

  @override
  String get onlineTime => 'وقت العمل';

  @override
  String get weeklyBumperBonus => 'مكافأة الأسبوع';

  @override
  String get deliveredOrders => 'الطلبات المُسلّمة:';

  @override
  String get fewMoreToUnlock => 'بضع توصيلات إضافية لفتح مكافأتك 💰';

  @override
  String get weeklyBonusUnlockedCelebration => 'تم فتح مكافأة الأسبوع 🎉';

  @override
  String get weeklyBonusUnlocked => 'تم فتح مكافأة الأسبوع!';

  @override
  String get weeklyBonusUnlockedShort => 'تم فتح مكافأة الأسبوع';

  @override
  String deliveriesAwayFromBonus(int remaining, String reward) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'توصيلات',
      one: 'توصيل',
    );
    return 'باقي $remaining $_temp0 للحصول على مكافأة $reward د.ك';
  }

  @override
  String deliverMoreToUnlockKd(int remaining, String reward) {
    return 'سلّم $remaining طلبات إضافية لفتح $reward د.ك مضمونة';
  }

  @override
  String get weeklyBonusDefault => 'مكافأة أسبوعية';

  @override
  String get deliveryRuleDefault => 'قاعدة توصيل';

  @override
  String get deliveryRules => 'قواعد التوصيل';

  @override
  String get allVerifiedCountTowardIncentives =>
      'جميع التوصيلات الموثّقة تُحتسب ضمن الحوافز';

  @override
  String get countsTowardIncentiveDeliveries => 'تُحتسب ضمن توصيلات الحوافز';

  @override
  String get outsideDeliveryAreaReturnSoon => 'خارج المنطقة. عد خلال 45 دقيقة.';

  @override
  String get outsideDeliveryAreaReturnAfterDelivery =>
      'خارج المنطقة. عد خلال 20 دقيقة.';

  @override
  String get zoneTimeoutCheckedOut =>
      'تم إخراجك من الخدمة لبقائك خارج منطقة التوصيل لفترة طويلة.';

  @override
  String get autoCheckoutOffline =>
      'تم إخراجك تلقائياً بعد البقاء دون اتصال لفترة طويلة.';

  @override
  String get autoCheckoutOutOfZone =>
      'تم إخراجك تلقائياً بعد البقاء خارج منطقتك المخصصة لفترة طويلة.';

  @override
  String get completeMoreEarnMore => 'أكمل المزيد. اربح المزيد.';

  @override
  String get liveBonusQuestsToday => 'مهام المكافآت النشطة لليوم';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String extraMore(int count) {
    return '+$count أخرى';
  }

  @override
  String get completed => 'مكتمل';

  @override
  String get noActiveQuestsRightNow => 'لا توجد مهام نشطة حالياً';

  @override
  String get tapToSeeAllOffers =>
      'اضغط لعرض جميع عروض الحوافز — عروض جديدة كل أسبوع.';

  @override
  String questUnlockedEarned(String amount) {
    return 'تم فتح المهمة — ربحت $amount';
  }

  @override
  String get keepDeliveringEveryOrderPays => 'استمر في التوصيل — كل طلب يُدفع';

  @override
  String get keepDeliveringToEarnBonus => 'استمر في التوصيل لربح هذه المكافأة';

  @override
  String remainingMoreToMaxEarnedSoFar(int remaining, String amount) {
    return '$remaining متبقية للحد الأقصى — ربحت حتى الآن $amount';
  }

  @override
  String remainingMoreToUnlock(int remaining, String amount) {
    return '$remaining متبقية لفتح $amount';
  }

  @override
  String unlockReward(String amount) {
    return 'افتح $amount';
  }

  @override
  String perDeliveryRate(String rate) {
    return '× $rate / توصيل';
  }

  @override
  String get periodToday => 'اليوم';

  @override
  String get periodThisWeek => 'هذا الأسبوع';

  @override
  String get periodThisMonth => 'هذا الشهر';

  @override
  String get periodThisPeriod => 'هذه الفترة';

  @override
  String get importantNotifications => 'إشعارات مهمة';

  @override
  String get couldNotLoadNotifications => 'تعذّر تحميل الإشعارات.';

  @override
  String get allCaughtUpShort => 'لا توجد إشعارات جديدة.';

  @override
  String get markAllRead => 'تعليم الكل كمقروء';

  @override
  String get viewMore => 'عرض المزيد';

  @override
  String get couldNotLoadHomeDashboard => 'تعذّر تحميل الصفحة الرئيسية';

  @override
  String get readyForDuty => 'جاهز لتسجيل الدخول';

  @override
  String get beforeYouGoOnline => 'قبل تسجيل الدخول';

  @override
  String get startDutyChecksSubtitle =>
      'أكمل هذه الفحوصات مرة واحدة لبدء التتبع أثناء الداخل.';

  @override
  String get goOnlineChecksSubtitle =>
      'ما زلت مسجّل الدخول. أصلح ما يلي ثم ادخل.';

  @override
  String get goOnline => 'ادخل';

  @override
  String get refreshChecks => 'تحديث الفحوصات';

  @override
  String allChecksPassed(int ok, int total) {
    return 'اجتازت جميع الفحوصات ($ok/$total).';
  }

  @override
  String someChecksPassed(int ok, int total) {
    return '$ok من $total فحوصات مطلوبة — اضغط على صف للإصلاح.';
  }

  @override
  String get permissionLocationServicesTitle => 'خدمات الموقع';

  @override
  String get permissionLocationServicesDesc =>
      'يجب تفعيل GPS لتتبع المنطقة أثناء الداخل.';

  @override
  String get permissionLocationAccessTitle => 'صلاحية الموقع';

  @override
  String get permissionLocationAccessDesc =>
      'اسمح بالموقع الدقيق أثناء استخدام التطبيق.';

  @override
  String get permissionBackgroundLocationTitle => 'الموقع في الخلفية';

  @override
  String get permissionBackgroundLocationDesc =>
      'موصى به لاستمرار التتبع عند تصغير التطبيق.';

  @override
  String get permissionNotificationsTitle => 'الإشعارات';

  @override
  String get permissionNotificationsDesc => 'مطلوبة لخدمة التتبع أثناء الداخل.';

  @override
  String get permissionBatteryOptimizationTitle => 'تحسين البطارية';

  @override
  String get permissionBatteryOptimizationDesc =>
      'استثنِ التطبيق من قيود البطارية أثناء الداخل.';

  @override
  String get permissionCameraTitle => 'الكاميرا';

  @override
  String get permissionCameraDesc => 'مطلوبة لتصوير إثبات التوصيل.';

  @override
  String get openLocationSettings => 'فتح إعدادات الموقع';

  @override
  String get openBatterySettings => 'فتح إعدادات البطارية';

  @override
  String get openAppSettings => 'فتح إعدادات التطبيق';

  @override
  String get allow => 'سماح';

  @override
  String get goOffline => 'تسجيل الخروج';

  @override
  String get onDutyTapToOpen => 'داخل — اضغط للفتح';

  @override
  String get onDutySignInAgain => 'داخل — سجّل الدخول مجدداً';

  @override
  String get onDutyTurnOnGps => 'داخل — فعّل GPS';

  @override
  String get onDutyLocationPermissionNeeded => 'داخل — صلاحية الموقع مطلوبة';

  @override
  String get onDutyStationaryGpsPaused => 'داخل — ثابت (GPS متوقف)';

  @override
  String get onDutyLocationUpdateFailed => 'داخل — فشل تحديث الموقع';

  @override
  String get checkedOutInactive5Min => 'تم تسجيل الخروج — غير نشط لـ 5 د';

  @override
  String get onDutyAutoCheckoutFailed => 'داخل — فشل تسجيل الخروج التلقائي';

  @override
  String get onDutyGoOfflineFailed => 'داخل — فشل تسجيل الخروج';

  @override
  String get onDutyFakeGpsDetected => 'داخل — GPS وهمي';

  @override
  String get inZone => 'داخل المنطقة';

  @override
  String get outOfZone => 'خارج المنطقة';

  @override
  String get outsideDeliveryArea => 'خارج المنطقة';

  @override
  String get onDuty => 'داخل';

  @override
  String get moving => 'متحرك';

  @override
  String get deliveryLogged => 'تم تسجيل التوصيل';

  @override
  String get idle => 'خامل';

  @override
  String get onDutyTrackingChannelName => 'تتبع أثناء الداخل';

  @override
  String get onDutyTrackingChannelDesc => 'يظهر أثناء الداخل لتتبع GPS.';

  @override
  String get mustBeOnDutyToReportLocation => 'يجب أن تكون داخل لتبليغ الموقع.';

  @override
  String get couldNotReportLocation => 'تعذّر الإبلاغ عن الموقع';

  @override
  String get locationReportFailed => 'فشل تقرير الموقع';

  @override
  String pendingDeliveriesWaitingToSync(int count) {
    return '$count توصيلات معلّقة بانتظار المزامنة';
  }

  @override
  String get couldNotLoadDeliveries => 'تعذّر تحميل التوصيلات';

  @override
  String get pendingDeliveries => 'توصيلات معلّقة';

  @override
  String get noPendingDeliveries => 'لا توصيلات معلّقة';

  @override
  String pendingSyncedSummary(int pending, int synced) {
    return 'معلّق: $pending · مُزامَن: $synced';
  }

  @override
  String get noDeliveriesAdded => 'لم تُضف توصيلات';

  @override
  String get startAddingDeliveries => 'ابدأ بإضافة توصيلاتك لتتبع عملك';

  @override
  String get addOrders => 'إضافة طلبات';

  @override
  String get imageFormatsMax10Mb => 'JPG أو PNG أو WebP · حد أقصى 10 م.ب';

  @override
  String get checkingYourLocation => 'جاري التحقق من موقعك…';

  @override
  String get orderId => 'رقم الطلب';

  @override
  String get orderIdHint => 'مثال: 12345';

  @override
  String get uploadOrderProof => 'رفع إثبات الطلب';

  @override
  String get takePhotoOrChooseGallery => 'التقط صورة أو اختر من المعرض';

  @override
  String get imageFormatsMax10MbShort => 'JPG, PNG, WebP · حد أقصى 10 م.ب';

  @override
  String get markAsDelivered => 'تعليم كمُسلّم';

  @override
  String get orderIdRequired => 'رقم الطلب مطلوب';

  @override
  String get deliverySavedOffline => 'تم حفظ التوصيل دون اتصال';

  @override
  String get deliveryAddedSuccessfully => 'تمت إضافة التوصيل بنجاح';

  @override
  String get deliveryWillSyncWhenOnline =>
      'ستُزامَن هذه الإدخالات تلقائياً عند عودة الإنترنت.';

  @override
  String get keepGoingEveryDeliveryCounts => 'استمر — كل توصيل يُحتسب!';

  @override
  String get addAnotherDelivery => 'إضافة توصيل آخر';

  @override
  String get offlineModePendingSync => 'وضع عدم الاتصال: مزامنة معلّقة';

  @override
  String get backToDeliveries => 'العودة للتوصيلات';

  @override
  String get deliveryDetails => 'تفاصيل التوصيل';

  @override
  String get status => 'الحالة';

  @override
  String get submitted => 'تم الإرسال';

  @override
  String get partner => 'الشريك';

  @override
  String get deliveryProof => 'إثبات التسليم';

  @override
  String get noProofImageUploaded => 'لم يُرفع إثبات';

  @override
  String get couldNotLoadProofImage => 'تعذّر تحميل إثبات التوصيل';

  @override
  String get couldNotDisplayImage => 'تعذّر عرض الصورة';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String selectedDayVerifiedOrders(int count) {
    return 'طلبات اليوم الموثّقة: $count';
  }

  @override
  String thisMonthVerifiedOrders(int count) {
    return 'طلبات الشهر الموثّقة: $count';
  }

  @override
  String get apply => 'تطبيق';

  @override
  String get today => 'اليوم';

  @override
  String get pleaseSignInAgain => 'يرجى تسجيل الدخول مجدداً';

  @override
  String get accountNotActive => 'حسابك غير نشط';

  @override
  String get outsideAllowedDeliveryArea =>
      'أنت خارج منطقة التوصيل المسموحة. اقترب من منطقتك أو مطعم مُعيَّن.';

  @override
  String get gpsRequiredForDelivery => 'موقع GPS مطلوب لتسجيل التوصيل';

  @override
  String get zoneNotConfigured => 'منطقتك غير مهيأة. تواصل مع المسؤول.';

  @override
  String get noRestaurantsAssigned => 'لا مطاعم مُعيَّنة. تواصل مع المسؤول.';

  @override
  String moveWithinRangeToLog(String range, String target) {
    return 'اقترب ضمن $range من $target لتسجيل التوصيل.';
  }

  @override
  String outsideRangeDetails(String distance, String range, String target) {
    return 'أنت على بعد $distance خارج النطاق (ضمن $range من $target).';
  }

  @override
  String get yourZone => 'منطقتك';

  @override
  String get assignedRestaurant => 'مطعم مُعيَّن';

  @override
  String get accountNotSetupAsDriver => 'حسابك غير مهيأ كسائق.';

  @override
  String get couldNotLoadDeliveryLocationRules =>
      'تعذّر تحميل قواعد موقع التوصيل. اسحب للتحديث أو حاول مجدداً.';

  @override
  String get notSignedIn => 'غير مسجّل الدخول';

  @override
  String get proofImageMissing => 'صورة الإثبات مفقودة';

  @override
  String get proofImageNotFound => 'صورة الإثبات غير موجودة';

  @override
  String get cannotViewProofImage => 'لا يمكنك عرض صورة الإثبات';

  @override
  String get couldNotLoadEarnings => 'تعذّر تحميل الأرباح';

  @override
  String get performanceSummary => 'ملخص الأداء';

  @override
  String get totalDeliveries => 'إجمالي التوصيلات';

  @override
  String get workingDays => 'أيام العمل';

  @override
  String get attendance => 'الحضور';

  @override
  String get incentives => 'الحوافز';

  @override
  String get reimbursements => 'المستردات';

  @override
  String get deductions => 'الخصومات';

  @override
  String get extraEarnings => 'أرباح إضافية';

  @override
  String get dailyEarnings => 'الأرباح اليومية';

  @override
  String get noEarningsActivityThisMonth => 'لا نشاط أرباح هذا الشهر.';

  @override
  String deliveryCountSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count توصيل',
      many: '$count توصيلاً',
      few: '$count توصيلات',
      two: 'توصيلان',
      one: 'توصيل واحد',
    );
    return '$_temp0';
  }

  @override
  String bonusesApplied(int count) {
    return '$count مكافآت مُطبَّقة';
  }

  @override
  String get bonusSuffix => 'مكافأة';

  @override
  String get deductionsComingSoonTitle => 'الخصومات';

  @override
  String get deductionsComingSoonBody =>
      'قريباً — تفصيل القروض أو الغرامات المطبّقة على أرباحك.';

  @override
  String get payslipHistory => 'سجل كشوف الرواتب';

  @override
  String get latestFirst => 'الأحدث أولاً';

  @override
  String get noPayslipsYet =>
      'لا كشوف رواتب بعد. عند موافقة فريق العمليات على دفعة، ستظهر هنا.';

  @override
  String deliveriesInPeriod(int count) {
    return '$count توصيلات';
  }

  @override
  String deliveriesInPayoutPeriod(int count) {
    return '$count توصيلات في هذه الفترة';
  }

  @override
  String get activeOffers => 'عروض نشطة';

  @override
  String get noActiveIncentivesRightNow => 'لا حوافز نشطة حالياً';

  @override
  String get checkBackLaterIncentives =>
      'عد لاحقاً — فريق العمليات يُعد قواعد الحوافز من لوحة الإدارة.';

  @override
  String get couldNotLoadExtraEarnings => 'تعذّر تحميل الأرباح الإضافية';

  @override
  String get progress => 'التقدم';

  @override
  String get bonusDefault => 'مكافأة';

  @override
  String get incentiveDefault => 'حافز';

  @override
  String upToAmount(String amount) {
    return 'حتى $amount';
  }

  @override
  String perDeliveryAmount(String amount) {
    return '$amount/توصيل';
  }

  @override
  String completeDeliveriesScope(int target, String scope, String period) {
    return 'أكمل $target توصيلات$scope $period';
  }

  @override
  String earnRewardsScope(String scope, String period) {
    return 'اربح مكافآت$scope $period';
  }

  @override
  String get periodTodayLower => 'اليوم';

  @override
  String get periodThisWeekLower => 'هذا الأسبوع';

  @override
  String get periodThisMonthLower => 'هذا الشهر';

  @override
  String get periodThisPeriodLower => 'هذه الفترة';

  @override
  String fromScope(String scope) {
    return 'من $scope';
  }

  @override
  String forScope(String scope) {
    return 'لـ $scope';
  }

  @override
  String get netEarnings => 'صافي الأرباح';

  @override
  String get eligibleDeliveries => 'التوصيلات المؤهلة';

  @override
  String get basePay => 'الأجر الأساسي';

  @override
  String get noDeliveriesLoggedThisDay => 'لا توصيلات مسجّلة هذا اليوم.';

  @override
  String get incentiveRules => 'قواعد الحوافز';

  @override
  String get noIncentiveRulesPaidThisDay => 'لا قواعد حوافز دُفعت هذا اليوم.';

  @override
  String overrideRuleApplied(String amount) {
    return 'قاعدة استثناء مُطبَّقة — الحافز النهائي $amount';
  }

  @override
  String eligibleDeliveriesProgress(int current, int target) {
    return '$current / $target توصيلات مؤهلة';
  }

  @override
  String eligibleDeliveriesCount(int count) {
    return '$count توصيلات مؤهلة';
  }

  @override
  String get couldNotLoadThisDay => 'تعذّر تحميل هذا اليوم';

  @override
  String get payslip => 'كشف راتب';

  @override
  String get netPayable => 'صافي المستحق';

  @override
  String paidAt(String date, String time) {
    return 'دُفع $date الساعة $time';
  }

  @override
  String get breakdown => 'التفصيل';

  @override
  String get loanDeduction => 'خصم قرض';

  @override
  String get penalty => 'غرامة';

  @override
  String get adjustment => 'تعديل';

  @override
  String get notes => 'ملاحظات';

  @override
  String get detailedSnapshot => 'لقطة تفصيلية';

  @override
  String get frozenAtApproval => 'مجمّدة وقت الموافقة على هذه الدفعة.';

  @override
  String get couldNotLoadThisPayslip => 'تعذّر تحميل كشف الراتب';

  @override
  String get payslipNoLongerAvailable => 'كشف الراتب لم يعد متاحاً.';

  @override
  String get couldNotLoadAttendance => 'تعذّر تحميل الحضور';

  @override
  String attendanceDaysCompleted(int present, int elapsed) {
    return 'أتم $present/$elapsed يومًا';
  }

  @override
  String get noLogin => 'لم يسجّل دخول';

  @override
  String get lessThanZeroHours => 'أقل من 0 س';

  @override
  String get moreThanZeroHours => 'أكثر من 0 س';

  @override
  String get weekdayMon => 'إث';

  @override
  String get weekdayTue => 'ثل';

  @override
  String get weekdayWed => 'أر';

  @override
  String get weekdayThu => 'خم';

  @override
  String get weekdayFri => 'جم';

  @override
  String get weekdaySat => 'سب';

  @override
  String get weekdaySun => 'أح';

  @override
  String get weekdayMonUpper => 'إث';

  @override
  String get weekdayTueUpper => 'ثل';

  @override
  String get weekdayWedUpper => 'أر';

  @override
  String get weekdayThuUpper => 'خم';

  @override
  String get weekdayFriUpper => 'جم';

  @override
  String get weekdaySatUpper => 'سب';

  @override
  String get weekdaySunUpper => 'أح';

  @override
  String get monthJanuary => 'يناير';

  @override
  String get monthFebruary => 'فبراير';

  @override
  String get monthMarch => 'مارس';

  @override
  String get monthApril => 'أبريل';

  @override
  String get monthMay => 'مايو';

  @override
  String get monthJune => 'يونيو';

  @override
  String get monthJuly => 'يوليو';

  @override
  String get monthAugust => 'أغسطس';

  @override
  String get monthSeptember => 'سبتمبر';

  @override
  String get monthOctober => 'أكتوبر';

  @override
  String get monthNovember => 'نوفمبر';

  @override
  String get monthDecember => 'ديسمبر';

  @override
  String get monthJan => 'ينا';

  @override
  String get monthFeb => 'فبر';

  @override
  String get monthMar => 'مار';

  @override
  String get monthApr => 'أبر';

  @override
  String get monthMayShort => 'ماي';

  @override
  String get monthJun => 'يون';

  @override
  String get monthJul => 'يول';

  @override
  String get monthAug => 'أغس';

  @override
  String get monthSep => 'سبت';

  @override
  String get monthOct => 'أكت';

  @override
  String get monthNov => 'نوف';

  @override
  String get monthDec => 'ديس';

  @override
  String profileImageUploadFailed(String error) {
    return 'فشل رفع صورة الملف: $error';
  }

  @override
  String get profilePictureUpdated => 'تم تحديث صورة الملف';

  @override
  String get uploadedPreviewFailed =>
      'تم الرفع لكن تعذّر عرض المعاينة. اسحب للتحديث — تواصل مع الدعم إن استمر.';

  @override
  String get notificationsSettingsComingSoon => 'إعدادات الإشعارات قريباً';

  @override
  String get signOutConfirmBody =>
      'ستحتاج رقم السائق ورمز الدخول لتسجيل الدخول مجدداً.';

  @override
  String get accountSection => 'الحساب';

  @override
  String get myProfile => 'ملفي الشخصي';

  @override
  String get attendanceAndLeaves => 'الحضور والإجازات';

  @override
  String get wrongAction => 'مخالفة';

  @override
  String get paymentDetails => 'تفاصيل الدفع';

  @override
  String get assets => 'الأصول';

  @override
  String get preferencesSection => 'التفضيلات';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get helpAndSupport => 'المساعدة والدعم';

  @override
  String get termsAndConditions => 'الشروط والأحكام';

  @override
  String get trainingSection => 'التدريب';

  @override
  String get tutorialMaterial => 'مواد تعليمية';

  @override
  String get video => 'فيديو';

  @override
  String get couldNotLoadProfile => 'تعذّر تحميل الملف';

  @override
  String get profileSessionExpiredHint =>
      'ربما انتهت جلستك. حاول مجدداً أو سجّل الخروج والدخول.';

  @override
  String get profile => 'الملف';

  @override
  String get help => 'مساعدة';

  @override
  String driverIdLabel(String code) {
    return 'الرقم: $code';
  }

  @override
  String get updateProfilePicture => 'تحديث صورة الملف';

  @override
  String couldNotLoadNotificationsWithError(String error) {
    return 'تعذّر تحميل الإشعارات.\n$error';
  }

  @override
  String get allCaughtUp => 'لا إشعارات جديدة';

  @override
  String get notificationsEmptyHint =>
      'ستظهر هنا التنبيهات والتذكيرات المهمة من مسلم.';

  @override
  String get musallamAlertsChannelName => 'تنبيهات مسلم';

  @override
  String get musallamAlertsChannelDesc => 'تنبيهات وتذكيرات تشغيلية للسائقين';

  @override
  String get vehicle => 'المركبة';

  @override
  String get vehicleComingSoon => 'معلومات المركبة والصيانة. قريباً.';

  @override
  String get am => 'ص';

  @override
  String get pm => 'م';

  @override
  String onDutyStatusLabel(String status, String speed, String zone) {
    return '$status$speed · $zone';
  }

  @override
  String get couldNotStartUpload => 'تعذّر بدء الرفع';

  @override
  String get couldNotConfirmUpload => 'تعذّر تأكيد الرفع';

  @override
  String get networkErrorReachingAdminUploadServer =>
      'خطأ شبكة عند الاتصال بخادم الرفع';

  @override
  String uploadFailedWithStatus(int statusCode) {
    return 'فشل الرفع ($statusCode)';
  }

  @override
  String get availabilitySubmission => 'تقديم التوفر';

  @override
  String get shiftRequiredToGoIn => 'قدّم الوردية للدخول';

  @override
  String get shiftExpiredSubmitNext =>
      'انتهت ورديتك. قدّم ورديتك التالية للدخول.';

  @override
  String get shiftSubmissionSubtitle =>
      'حدّد ورديتك لهذه الفترة. يمكنك الدخول/الخروج بحرية حتى انتهائها، ثم قدّم وردية جديدة.';

  @override
  String get shiftSubmissionRequiredSubtitle =>
      'الوردية مطلوبة قبل الدخول. لا يمكن تخطي هذه الخطوة.';

  @override
  String get shiftType => 'نوع الوردية';

  @override
  String get selectShift => 'اختر الوردية';

  @override
  String get singleShift => 'وردية واحدة';

  @override
  String get splitShift => 'وردية مقسّمة';

  @override
  String get setTimeline => 'حدّد الوقت';

  @override
  String get fromTime => 'من';

  @override
  String get toTime => 'إلى';

  @override
  String get session2 => 'الجلسة 2';

  @override
  String get selectTime => 'اختر الوقت';

  @override
  String get confirm => 'تأكيد';

  @override
  String get shiftEndsNextDay => 'ينتهي في اليوم التالي';

  @override
  String get session1Required => 'يرجى تحديد وقت بداية ونهاية الجلسة 1';

  @override
  String get session2Required => 'يرجى تحديد وقت بداية ونهاية الجلسة 2';

  @override
  String get invalidSessionDuration =>
      'وقت النهاية يجب أن يكون بعد وقت البداية';

  @override
  String get sessionTooLong => 'كل جلسة يجب ألا تتجاوز 24 ساعة';

  @override
  String get sessionsOverlap => 'لا يمكن أن تتداخل الجلسات';

  @override
  String get shiftLocked => 'وردية اليوم مقفلة حتى انتهائها';

  @override
  String get couldNotSubmitShift => 'تعذّر حفظ الوردية';

  @override
  String get outsideShiftWindowTitle => 'خارج وقت الوردية';

  @override
  String get outsideShiftWindowMessage =>
      'أنت خارج ساعات الوردية المحددة. يمكنك المتابعة، لكن قد يتم مراجعتها.';

  @override
  String get continueAnyway => 'متابعة على أي حال';

  @override
  String get mustBeOnDutyToAddDelivery => 'يجب أن تكون داخل لإضافة توصيل';

  @override
  String get shiftRequiredBeforeDuty => 'قدّم وردية اليوم قبل الدخول';

  @override
  String get pickupOrder => 'استلام الطلب';

  @override
  String get confirmPickup => 'تأكيد الاستلام';

  @override
  String get pickedUpAt => 'تم الاستلام في';

  @override
  String get uploadPickupProof => 'رفع صورة الاستلام';

  @override
  String get uploadPickupProofOptional => 'رفع صورة الاستلام (اختياري)';

  @override
  String get cancelOrder => 'إلغاء الطلب';

  @override
  String get confirmCancel => 'تأكيد الإلغاء';

  @override
  String get cancelledAt => 'تم الإلغاء في';

  @override
  String get cancelReasonLabel => 'سبب الإلغاء';

  @override
  String get cancelReasonRequired => 'سبب الإلغاء مطلوب';

  @override
  String get cancelReasonCustomerNoShow => 'العميل لم يحضر';

  @override
  String get cancelReasonCustomerRefused => 'العميل رفض الطلب';

  @override
  String get cancelReasonWrongAddress => 'عنوان خاطئ';

  @override
  String get cancelReasonRestaurantIssue => 'مشكلة في المطعم';

  @override
  String get cancelReasonAccident => 'حادث';

  @override
  String get cancelReasonOther => 'أخرى';

  @override
  String get cancelNoteHint => 'أضف تفاصيل (اختياري)';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get activeDeliveryBanner => 'توصيل نشط';

  @override
  String get noActiveDelivery => 'لا يوجد توصيل نشط';

  @override
  String get deliveryDuration => 'المدة';

  @override
  String get pickupProof => 'إثبات الاستلام';

  @override
  String get deliveryProofOptional => 'إثبات التسليم (اختياري)';

  @override
  String get cancelProof => 'إثبات الإلغاء';

  @override
  String get mustCompleteActiveDeliveryFirst =>
      'أكمل التوصيل الحالي قبل استلام طلب جديد';

  @override
  String get activePickupExists => 'لديك طلب قيد التنفيذ بالفعل';

  @override
  String get duplicateOrderId => 'رقم الطلب مسجّل مسبقاً';

  @override
  String get proofPhotoRequired => 'صورة الإثبات مطلوبة';

  @override
  String get finishAsDelivered => 'إنهاء كتسليم';

  @override
  String get finishAsCancelled => 'إنهاء كإلغاء';

  @override
  String get switchOutcome => 'تبديل';

  @override
  String get selectReason => 'اختر سبباً';

  @override
  String get permissionOverlayTitle => 'العرض فوق التطبيقات الأخرى';

  @override
  String get permissionOverlayDesc =>
      'يعرض أيقونة عائمة أثناء الداخل للعودة إلى التطبيق بسرعة.';

  @override
  String get grantOverlayPermission => 'منح إذن العرض';

  @override
  String get onDutyReturnToApp => 'أنت داخل — ارجع إلى التطبيق';

  @override
  String get onDutyTurnOnGpsOverlay => 'فعّل GPS للمتابعة أثناء الداخل';

  @override
  String get openLocationSettingsAction => 'فتح إعدادات الموقع';

  @override
  String get pickupLoggedSuccessfully => 'تم تسجيل الاستلام بنجاح';

  @override
  String get cancelLoggedSuccessfully => 'تم تسجيل الإلغاء بنجاح';

  @override
  String get proceedToDeliverWhenReady =>
      'توجّه إلى العميل واضغط تسليم عند الانتهاء.';

  @override
  String get shiftAdherenceTitle => 'الالتزام بالوردية';

  @override
  String minutesLateVsShift(int minutes) {
    return 'تأخير $minutes د عن الوردية';
  }

  @override
  String minutesEarlyOutVsShift(int minutes) {
    return 'خروج مبكر $minutes د عن الوردية';
  }

  @override
  String get onTimeVsShift => 'في الوقت مقارنة بالوردية';

  @override
  String get noShiftSubmitted => 'لم تُقدَّم وردية لليوم';

  @override
  String timeInToday(String duration) {
    return 'وقت العمل اليوم: $duration';
  }

  @override
  String shiftAdherenceLateShort(int minutes) {
    return 'تأخير $minutes د';
  }

  @override
  String shiftAdherenceEarlyShort(int minutes) {
    return 'مبكر $minutes د';
  }

  @override
  String get shiftAdherenceOnTimeShort => 'في الوقت';

  @override
  String get updateAvailableTitle => 'يتوفر تحديث';

  @override
  String get updateRequiredTitle => 'التحديث مطلوب';

  @override
  String updateAvailableBody(String version) {
    return 'الإصدار $version جاهز للتثبيت.';
  }

  @override
  String get updateDownload => 'تنزيل التحديث';

  @override
  String get updateLater => 'لاحقاً';

  @override
  String get updateInstall => 'تثبيت التحديث';

  @override
  String get updateAllowInstallPermission =>
      'اسمح لمسالم بتثبيت التحديثات ثم حاول مرة أخرى.';

  @override
  String get openInstallSettings => 'فتح الإعدادات';

  @override
  String updateDownloading(int percent) {
    return 'جاري التنزيل… $percent٪';
  }

  @override
  String get updateChecksumFailed => 'فشل التحقق من التنزيل. حاول مرة أخرى.';

  @override
  String get updateNoInstallerAvailable =>
      'تعذر فتح مثبت التطبيقات. افتح ملف APK من تطبيق الملفات أو تواصل مع الدعم.';

  @override
  String get updateApkMissing =>
      'ملف التحديث غير موجود. اضغط تنزيل للمحاولة مجددًا.';

  @override
  String get supportRequestTypeLeave => 'إجازة';

  @override
  String get supportRequestTypeLeaveRequest => 'طلب إجازة';

  @override
  String get supportRequestTypeSickLeave => 'إجازة مرضية وحوادث';

  @override
  String get supportRequestTypeAsset => 'طلب عهدة';

  @override
  String get supportRequestTypeFuel => 'استرداد قيمة الوقود';

  @override
  String get supportRequestTypeDocument => 'طلب مستند';

  @override
  String get supportRequestTypeDocumentReupload => 'إعادة رفع المستند';

  @override
  String get supportRequestTypeComplaint => 'شكوى';

  @override
  String get supportRequestTypeSalaryJustification => 'توضيح الراتب';

  @override
  String get supportRequestTypeLoanAdvance => 'سلفة / قرض';

  @override
  String get supportRequestTypeLoanRequest => 'طلب قرض';

  @override
  String get supportRequestTypeGeneric => 'طلب';

  @override
  String get supportStatusAwaitingAck => 'بانتظار الإقرار';

  @override
  String get supportStatusAcknowledged => 'تم الإقرار';

  @override
  String get supportStatusInProgress => 'قيد المعالجة';

  @override
  String get supportStatusSolved => 'تم الحل';

  @override
  String get supportStatusOverdue => 'متأخر';

  @override
  String get supportActionRequired => 'إجراء مطلوب';

  @override
  String get supportMyRequestsTitle => 'طلباتي';

  @override
  String get supportTabRequestSent => 'الطلبات المرسلة';

  @override
  String get supportTabRequestReceived => 'الطلبات الواردة';

  @override
  String supportCouldNotLoadRequests(String error) {
    return 'تعذّر تحميل الطلبات.\n$error';
  }

  @override
  String get supportNoRequestsSent => 'لم تُرسل أي طلبات بعد';

  @override
  String get supportNoRequestsReceived => 'لا توجد طلبات واردة';

  @override
  String supportRequestsNeedResponse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب بحاجة إلى ردك',
      many: '$count طلباً بحاجة إلى ردك',
      few: '$count طلبات بحاجة إلى ردك',
      two: 'طلبان بحاجة إلى ردك',
      one: 'طلب واحد بحاجة إلى ردك',
    );
    return '$_temp0';
  }

  @override
  String get supportReasonAwaitingAck => 'بانتظار إقرارك';

  @override
  String get supportReasonLoanDetailsChanged => 'تم تعديل تفاصيل القرض';

  @override
  String get supportReasonClarificationNeeded => 'مطلوب توضيح';

  @override
  String get supportActionAcknowledgeUpdate => 'الإقرار بالتحديث';

  @override
  String get supportActionDocumentToSign => 'مستند بحاجة إلى توقيع';

  @override
  String supportCouldNotLoad(String error) {
    return 'تعذّر التحميل.\n$error';
  }

  @override
  String get supportNoActionRequired => 'لا يوجد إجراء مطلوب حالياً';

  @override
  String get supportHubTitle => 'المساعدة والدعم';

  @override
  String get supportSectionRaiseRequest => 'تقديم طلب';

  @override
  String get supportTileSickAccidentLeave => 'إجازة مرضية / حادث';

  @override
  String get supportTileSalaryJustification => 'توضيح الراتب';

  @override
  String get supportTileLoanRequest => 'طلب قرض';

  @override
  String get supportSectionVisitUs => 'زيارتنا';

  @override
  String get supportScheduleVisitTitle => 'حجز زيارة إلى البرج المركزي';

  @override
  String get supportScheduleVisitSubtitle =>
      'احجز موعداً للحصول على مساعدة مباشرة';

  @override
  String get supportSectionYourActivity => 'نشاطك';

  @override
  String get supportMyRequestsSubtitle => 'تابع حالة طلباتك';

  @override
  String get supportMyVisitsTitle => 'زياراتي';

  @override
  String get supportMyVisitsSubtitle => 'زيارات البرج المحجوزة';

  @override
  String get supportDocumentsToSign => 'مستندات للتوقيع';

  @override
  String get supportAppointments => 'المواعيد';

  @override
  String supportBadgeNewCount(int count) {
    return '$count جديد';
  }

  @override
  String get supportFormTitleSickLeave => 'إجازة مرضية / حادث';

  @override
  String get supportFormTitleLoan => 'قرض / سلفة';

  @override
  String get supportFormTitleFuel => 'مطالبة وقود';

  @override
  String get supportFormTitleNew => 'طلب جديد';

  @override
  String get supportErrorLeaveTypeDatesRequired =>
      'نوع الإجازة والتواريخ مطلوبة';

  @override
  String get supportErrorJustificationRequired => 'المبرر مطلوب';

  @override
  String get supportErrorSymptomsRequired => 'الأعراض / التفاصيل مطلوبة';

  @override
  String get supportErrorMedicalDocsRequired => 'المستندات الطبية مطلوبة';

  @override
  String get supportErrorAmountTenureRequired => 'المبلغ ومدة السداد مطلوبان';

  @override
  String get supportErrorNeededByReasonRequired =>
      'تاريخ الحاجة والسبب مطلوبان';

  @override
  String get supportErrorAssetFieldsRequired =>
      'نوع العهدة ونوع الطلب والحالة مطلوبة';

  @override
  String get supportErrorAmountPeriodRequired => 'المبلغ والفترة مطلوبان';

  @override
  String get supportErrorFuelReceiptsRequired => 'إيصالات الوقود مطلوبة';

  @override
  String get supportErrorDocumentFieldsRequired => 'حقول المستند مطلوبة';

  @override
  String get supportErrorComplaintFieldsRequired =>
      'الفئة ودرجة الخطورة والموضوع والوصف مطلوبة';

  @override
  String get supportErrorSalaryFieldsRequired => 'حقول الراتب مطلوبة';

  @override
  String get supportErrorAcceptDeclaration => 'يرجى الموافقة على الإقرار';

  @override
  String get supportLeaveTypeAnnual => 'سنوية';

  @override
  String get supportLeaveTypeEmergency => 'طارئة';

  @override
  String get supportLeaveTypeAccident => 'حادث';

  @override
  String get supportLeaveTypeUnpaid => 'إجازة بدون راتب';

  @override
  String get supportSickTypeSickLeave => 'إجازة مرضية';

  @override
  String get supportSickTypeInjury => 'إصابة';

  @override
  String get supportOptionOther => 'أخرى';

  @override
  String get supportAssetSimCard => 'شريحة اتصال';

  @override
  String get supportAssetFuelCard => 'بطاقة وقود';

  @override
  String get supportAssetFuelLimitChange => 'تعديل حد الوقود';

  @override
  String get supportAssetRaincoat => 'معطف مطر';

  @override
  String get supportAssetDeliveryBag => 'حقيبة توصيل';

  @override
  String get supportAssetReflectiveVest => 'سترة عاكسة';

  @override
  String get supportAssetWinterJacket => 'جاكيت شتوي';

  @override
  String get supportAssetDeliveryAttire => 'زي التوصيل';

  @override
  String get supportAssetDeliveryPants => 'بنطال التوصيل';

  @override
  String get supportAssetNewBike => 'دراجة جديدة';

  @override
  String get supportAssetHelmet => 'خوذة';

  @override
  String get supportAssetDeliveryBox => 'صندوق التوصيل';

  @override
  String get supportAssetFuelChip => 'شريحة وقود';

  @override
  String get supportAssetPhone => 'هاتف';

  @override
  String get supportAssetMobileHolder => 'حامل الهاتف';

  @override
  String get supportDocTypeCivilIdCopy => 'نسخة البطاقة المدنية';

  @override
  String get supportDocTypeLicenseCopy => 'نسخة رخصة القيادة';

  @override
  String get supportDocTypeWorkPermitCopy => 'نسخة إذن العمل';

  @override
  String get supportDocTypeRegistrationCopy => 'نسخة دفتر المركبة';

  @override
  String get supportDocTypeVehicleDocumentCopy => 'نسخة مستندات المركبة';

  @override
  String get supportDocTypeSalaryCertification => 'شهادة راتب';

  @override
  String get supportRequestModeRenewal => 'تجديد';

  @override
  String get supportRequestModeFirstTime => 'لأول مرة';

  @override
  String get supportAssetStatusLost => 'مفقودة';

  @override
  String get supportAssetStatusDamaged => 'تالفة';

  @override
  String get supportDeliveryMethodEmail => 'بريد إلكتروني';

  @override
  String get supportDeliveryMethodPickup => 'استلام شخصي';

  @override
  String get supportSeverityLow => 'منخفضة';

  @override
  String get supportSeverityMedium => 'متوسطة';

  @override
  String get supportSeverityHigh => 'عالية';

  @override
  String get supportFieldLeaveType => 'نوع الإجازة';

  @override
  String get supportFieldFrom => 'من';

  @override
  String get supportFieldTo => 'إلى';

  @override
  String get supportFieldCommentOptional => 'ملاحظة (اختياري)';

  @override
  String get supportFieldComment => 'ملاحظة';

  @override
  String get supportHintMentionHere => 'اكتب هنا';

  @override
  String get supportFieldJustificationRequired => 'المبرر *';

  @override
  String supportFieldRequiredNamed(String field) {
    return '$field مطلوب';
  }

  @override
  String supportErrorAttachmentsMin(int count) {
    return 'أرفق $count ملف على الأقل';
  }

  @override
  String get supportAttachmentRequired => 'مرفق *';

  @override
  String get supportRequestTypeUnknown => 'نوع الطلب هذا غير متاح.';

  @override
  String get supportRequestTypeNoFields =>
      'لا يوجد نموذج لهذا النوع بعد. يرجى المحاولة لاحقًا.';

  @override
  String get supportAttachmentOptional => 'مرفق (اختياري)';

  @override
  String supportFilesSelected(int count) {
    return 'تم اختيار $count ملف';
  }

  @override
  String get supportFieldSymptomsRequired => 'الأعراض / التفاصيل *';

  @override
  String get supportUploadMedicalCertificate => 'ارفع التقرير الطبي *';

  @override
  String get supportFieldAmountKwdRequired => 'المبلغ (د.ك) *';

  @override
  String get supportLoanTenureUnavailable =>
      'لم يتم إعداد خيارات السداد بعد. طلبات القروض غير متاحة مؤقتاً.';

  @override
  String get supportFieldTenureRequired => 'مدة السداد *';

  @override
  String get supportFieldNeededBy => 'مطلوب بحلول';

  @override
  String get supportFieldReasonRequired => 'السبب *';

  @override
  String get supportFieldAssetType => 'نوع العهدة';

  @override
  String get supportFieldQuantity => 'الكمية';

  @override
  String get supportFieldPeriodMonth => 'الفترة (الشهر)';

  @override
  String get supportFieldDistanceKm => 'المسافة (كم)';

  @override
  String get supportUploadFuelReceipts => 'ارفع إيصالات الوقود *';

  @override
  String get supportFieldDocumentType => 'نوع المستند';

  @override
  String get supportComplaintCategoriesUnavailable =>
      'لم يتم إعداد فئات الشكاوى بعد. الشكاوى غير متاحة مؤقتاً.';

  @override
  String get supportFieldCategoryRequired => 'الفئة *';

  @override
  String get supportFieldSubjectRequired => 'الموضوع *';

  @override
  String get supportFieldDescriptionRequired => 'الوصف *';

  @override
  String get supportFieldSalaryMonth => 'شهر الراتب';

  @override
  String get supportFieldExpectedAmountRequired => 'المبلغ المتوقع *';

  @override
  String get supportFieldReceivedAmountRequired => 'المبلغ المستلم *';

  @override
  String get supportSupportingDocument => 'مستند داعم';

  @override
  String get supportPhotoOptional => 'صورة (اختياري)';

  @override
  String get supportAttachPayslipOptional => 'إرفاق كشف الراتب (اختياري)';

  @override
  String get supportDeclarationLeave =>
      'إقرار: ألتزم بالعودة في الموعد المحدد، وإلا يحق للشركة تطبيق قائمة الجزاءات في حال التأخر عن العودة.';

  @override
  String get supportDeclarationLoan =>
      'إقرار: ألتزم بسداد كامل المبلغ للشركة أو أن تقوم الشركة بخصمه على أقساط من راتبي.';

  @override
  String get supportDeclarationAsset =>
      'إقرار: في حال استبدال عهدة مفقودة أو تالفة، أتحمل أي رسوم تفرضها الشركة للحصول على بديل.';

  @override
  String get supportTemporarilyUnavailable => 'غير متاح مؤقتاً';

  @override
  String get supportSubmitRequest => 'إرسال الطلب';

  @override
  String get supportChooseFromGallery => 'الاختيار من المعرض';

  @override
  String get supportTakeAPhoto => 'التقاط صورة';

  @override
  String get supportResponseSubmitted => 'تم إرسال الرد';

  @override
  String get supportAskQuestion => 'طرح سؤال';

  @override
  String get supportAskQuestionBody =>
      'أرسل ملاحظة إلى فريق العمليات بخصوص هذا الطلب، وسيتم الرد عليك هنا.';

  @override
  String get supportAskQuestionHint =>
      'مثال: أي وجه من البطاقة المدنية تحتاجون؟';

  @override
  String get supportSendQuestion => 'إرسال السؤال';

  @override
  String get supportAttachDocumentFirst => 'يرجى إرفاق المستند المطلوب أولاً';

  @override
  String get supportRequestDetailsTitle => 'تفاصيل الطلب';

  @override
  String get supportFromManagement => 'من الإدارة';

  @override
  String get supportApprovalProgress => 'مسار الموافقة';

  @override
  String get supportUploadRequestedDocument => 'ارفع المستند المطلوب';

  @override
  String get supportUploadHintChooseOrCapture =>
      'اختر صورة أو التقط إثبات التوصيل';

  @override
  String get supportYourResponse => 'ردك';

  @override
  String get supportSubmitResponse => 'إرسال الرد';

  @override
  String get supportNoteOptional => 'ملاحظة (اختياري)';

  @override
  String get supportAddNote => 'إضافة ملاحظة';

  @override
  String get supportUploadDocuments => 'رفع المستندات';

  @override
  String get supportAcknowledge => 'إقرار بالاطلاع';

  @override
  String get supportAttachedFile => 'ملف مرفق';

  @override
  String get supportNoneAttached => 'لا يوجد مرفق';

  @override
  String get supportFieldRequested => 'المبلغ المطلوب';

  @override
  String get supportFieldInstallments => 'الأقساط';

  @override
  String supportMonthsCount(String count) {
    return '$count شهراً';
  }

  @override
  String get supportFieldPurpose => 'الغرض';

  @override
  String get supportFieldAsset => 'العهدة';

  @override
  String supportAssetWithSize(String asset, String size) {
    return '$asset ($size)';
  }

  @override
  String get supportFieldCondition => 'الحالة';

  @override
  String get supportFieldEvidence => 'الإثبات';

  @override
  String get supportFieldDates => 'التواريخ';

  @override
  String get supportFieldDuration => 'المدة';

  @override
  String supportDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوماً',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get supportFieldAttachment => 'المرفق';

  @override
  String get supportStepInReview => 'قيد المراجعة';

  @override
  String supportStepSince(String word, String date) {
    return '$word منذ $date';
  }

  @override
  String supportStepDecidedAt(String word, String dateTime) {
    return '$word · $dateTime';
  }

  @override
  String get supportReason => 'السبب';

  @override
  String get supportAdminResponse => 'رد الإدارة';

  @override
  String get supportCommentFromAdmin => 'تعليق الإدارة';

  @override
  String get supportFieldRequestedAmount => 'المبلغ المطلوب';

  @override
  String get supportFieldApprovedAmount => 'المبلغ المعتمد';

  @override
  String get supportFieldDeductionStarts => 'بداية الخصم';

  @override
  String get supportFieldApprovedBy => 'تمت الموافقة بواسطة';

  @override
  String get supportFieldPenaltyAmount => 'مبلغ الغرامة';

  @override
  String get supportFieldRequestedBy => 'الطلب من';

  @override
  String get supportStatusOnHold => 'معلّق';

  @override
  String get supportFieldRequired => 'المطلوب';

  @override
  String get supportNotSpecified => 'غير محدد';

  @override
  String get supportBadgeAmountChanged => 'تم تعديل المبلغ';

  @override
  String get supportBadgeUpdate => 'تحديث';

  @override
  String get supportBadgePenaltyApplied => 'تم تطبيق غرامة';

  @override
  String get supportBadgeReviewRequired => 'يتطلب مراجعة';

  @override
  String get supportBadgeDocumentsRequired => 'مستندات مطلوبة';

  @override
  String supportFilesReady(int count) {
    return '$count ملف جاهز';
  }

  @override
  String get supportUpload => 'رفع';

  @override
  String get supportCapture => 'التقاط';

  @override
  String get supportSubmittedTitle => 'تم الإرسال';

  @override
  String get supportRequestSubmitted => 'تم إرسال الطلب';

  @override
  String get supportRequestSubmittedBody =>
      'استلمنا طلبك وسنراجعه قريباً. يمكنك متابعة حالته في أي وقت.';

  @override
  String get supportFieldRequestId => 'رقم الطلب';

  @override
  String get supportFieldType => 'النوع';

  @override
  String get supportTrackRequest => 'متابعة الطلب';

  @override
  String get supportBackToSupport => 'العودة إلى الدعم';

  @override
  String get supportAcknowledgedTitle => 'تم الإقرار';

  @override
  String get supportResponseAcknowledged => 'تم الإقرار بالرد';

  @override
  String get supportResponseAcknowledgedBody =>
      'شكراً لك. أبلغنا الإدارة بأنك اطلعت على ردهم ووافقت عليه.';

  @override
  String supportCodeWithType(String code, String type) {
    return '$code · $type';
  }

  @override
  String get supportBackToMyRequests => 'العودة إلى طلباتي';

  @override
  String get weekdayInitialSun => 'ح';

  @override
  String get weekdayInitialMon => 'ن';

  @override
  String get weekdayInitialTue => 'ث';

  @override
  String get weekdayInitialWed => 'ر';

  @override
  String get weekdayInitialThu => 'خ';

  @override
  String get weekdayInitialFri => 'ج';

  @override
  String get weekdayInitialSat => 'س';

  @override
  String get visitCentralTower => 'البرج المركزي';

  @override
  String get visitStepReason => 'سبب الزيارة';

  @override
  String get visitStepSelectDate => 'اختيار التاريخ';

  @override
  String get visitStepReviewConfirm => 'المراجعة والتأكيد';

  @override
  String get visitBooking => 'جارٍ الحجز…';

  @override
  String get visitConfirmBooking => 'تأكيد الحجز';

  @override
  String get visitDefaultBranchName => 'برج مسلم المركزي';

  @override
  String get visitHeadOfficeSubtitle => 'المكتب الرئيسي - خدمات السائقين';

  @override
  String get visitFieldLocation => 'الموقع';

  @override
  String get visitFieldWorkingHours => 'ساعات العمل';

  @override
  String get visitFieldContact => 'التواصل';

  @override
  String get visitBookASlot => 'احجز موعداً';

  @override
  String get visitSkipQueueHint =>
      'حجز موعد يساعدك على تجنب الانتظار وإنجاز معاملتك أسرع.';

  @override
  String get visitSelectDepartment => 'اختر القسم';

  @override
  String get visitAddNoteOptional => 'أضف ملاحظة (اختياري)';

  @override
  String get visitNoteHint => 'صف مشكلتك باختصار';

  @override
  String get visitChange => 'تغيير';

  @override
  String get visitNoSlotsForDate => 'لا توجد مواعيد متاحة في هذا التاريخ.';

  @override
  String get visitSectionMorning => 'الفترة الصباحية';

  @override
  String get visitSectionAfternoon => 'الفترة المسائية';

  @override
  String get visitLunchBreak => 'استراحة الغداء';

  @override
  String get visitSlotFull => 'مكتمل';

  @override
  String visitSlotRemaining(int count) {
    return 'متبقٍ $count';
  }

  @override
  String visitSlotRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String get visitFieldDepartment => 'القسم';

  @override
  String get visitFieldDate => 'التاريخ';

  @override
  String get visitFieldTime => 'الوقت';

  @override
  String get visitFieldNote => 'ملاحظة';

  @override
  String get visitArriveEarlyHint =>
      'يرجى الحضور قبل الموعد بعشر دقائق مع إحضار بطاقة السائق.';

  @override
  String get visitBookedTitle => 'تم حجز الزيارة';

  @override
  String get visitBookedBody =>
      'تم تأكيد زيارتك. اعرض هذه البطاقة في استقبال البرج المركزي.';

  @override
  String get visitTicketHeader => 'زيارة البرج المركزي';

  @override
  String get visitScanAtReception => 'امسح الرمز في الاستقبال';

  @override
  String visitBookingTokenHint(String code) {
    return 'رمز الحجز $code. احتفظ به جاهزاً عند الوصول.';
  }

  @override
  String get visitViewMyVisits => 'عرض زياراتي';

  @override
  String get visitTabUpcoming => 'القادمة';

  @override
  String get visitTabPast => 'السابقة';

  @override
  String get visitNoUpcoming => 'لا توجد زيارات قادمة';

  @override
  String get visitNoPast => 'لا توجد زيارات سابقة';

  @override
  String get visitRescheduleTitle => 'إعادة جدولة الزيارة؟';

  @override
  String visitRescheduleBody(String code) {
    return 'هل تريد إلغاء $code وحجز موعد جديد؟';
  }

  @override
  String get visitKeep => 'الإبقاء عليها';

  @override
  String get visitReschedule => 'إعادة الجدولة';

  @override
  String get visitStatusConfirmed => 'مؤكدة';

  @override
  String get visitStatusCheckedIn => 'تم تسجيل الحضور';

  @override
  String get visitMonthJanUpper => 'يناير';

  @override
  String get visitMonthFebUpper => 'فبراير';

  @override
  String get visitMonthMarUpper => 'مارس';

  @override
  String get visitMonthAprUpper => 'أبريل';

  @override
  String get visitMonthMayUpper => 'مايو';

  @override
  String get visitMonthJunUpper => 'يونيو';

  @override
  String get visitMonthJulUpper => 'يوليو';

  @override
  String get visitMonthAugUpper => 'أغسطس';

  @override
  String get visitMonthSepUpper => 'سبتمبر';

  @override
  String get visitMonthOctUpper => 'أكتوبر';

  @override
  String get visitMonthNovUpper => 'نوفمبر';

  @override
  String get visitMonthDecUpper => 'ديسمبر';

  @override
  String get esignNoDocumentsToSign => 'لا توجد مستندات للتوقيع';

  @override
  String get esignSectionPending => 'قيد الانتظار';

  @override
  String get esignSectionSigned => 'موقّعة';

  @override
  String get esignSectionDeclined => 'مرفوضة';

  @override
  String esignDueOn(String date) {
    return 'الاستحقاق $date';
  }

  @override
  String esignSignedOn(String date) {
    return 'تم التوقيع $date';
  }

  @override
  String get esignDeclineDocument => 'رفض المستند';

  @override
  String get esignDeclineBody =>
      'أبلغ الإدارة بسبب عدم تمكنك من توقيع هذا المستند.';

  @override
  String get esignDeclineReasonHint => 'السبب (اختياري)';

  @override
  String get esignDocumentDeclined => 'تم رفض المستند';

  @override
  String get esignDocumentTitle => 'المستند';

  @override
  String get esignReviewDocument => 'مراجعة المستند';

  @override
  String get esignNoDocumentAttached => 'لا يوجد مستند مرفق.';

  @override
  String get esignPreviewLoadFailed => 'تعذّر تحميل معاينة المستند.';

  @override
  String get esignPreviewUnavailable =>
      'المعاينة غير متاحة — افتح المستند خارجياً.';

  @override
  String get esignPdfDocument => 'مستند PDF';

  @override
  String get esignTapToOpen => 'اضغط للفتح';

  @override
  String get esignOpenFullDocument => 'فتح المستند كاملاً';

  @override
  String get esignFromAdmin => 'من الإدارة';

  @override
  String esignMetaLine(String code, String category, String source) {
    return '$code$category · $source';
  }

  @override
  String get esignDecline => 'رفض';

  @override
  String get esignSignDocument => 'توقيع المستند';

  @override
  String get esignAddYourSignature => 'أضف توقيعك';

  @override
  String get esignDrawSignatureHint => 'ارسم توقيعك في المربع أدناه';

  @override
  String get esignClear => 'مسح';

  @override
  String get esignLegalDeclaration =>
      'أقر بأن هذا توقيعي الإلكتروني المعتمد قانوناً.';

  @override
  String get esignPleaseDrawSignature => 'يرجى رسم توقيعك';

  @override
  String get esignCapturedWith => 'تم تسجيل التوقيع مع البيانات التالية:';

  @override
  String get esignSignerYou => 'أنت';

  @override
  String get esignSubmitting => 'جارٍ الإرسال…';

  @override
  String get esignConfirmSignature => 'تأكيد التوقيع';

  @override
  String get esignSignedTitle => 'موقّع';

  @override
  String get esignDocumentSigned => 'تم توقيع المستند';

  @override
  String get esignDocumentSignedBody =>
      'تم إرسال توقيعك إلى الإدارة وحفظه في سجلاتك.';

  @override
  String get esignSignatureProof => 'إثبات التوقيع';

  @override
  String get esignFieldSignedBy => 'وقّع بواسطة';

  @override
  String get esignFieldDateTime => 'التاريخ والوقت';

  @override
  String get esignFieldIpAddress => 'عنوان IP';

  @override
  String get esignNotCaptured => 'غير مسجّل';

  @override
  String get esignFieldDevice => 'الجهاز';

  @override
  String get esignDownloadSignedCopy => 'تنزيل النسخة الموقّعة';

  @override
  String get esignDownloadDocument => 'تنزيل المستند';

  @override
  String get esignNoDocumentToDownload => 'لا يوجد مستند متاح للتنزيل';

  @override
  String get esignSignedCopyReady =>
      'تم ختم توقيعك في الصفحة الأخيرة من هذه النسخة.';

  @override
  String get esignSignedCopyPending =>
      'يجري تجهيز نسختك الموقّعة — هذه هي النسخة الأصلية حتى تصبح جاهزة. أعد فتح هذه الشاشة بعد قليل.';

  @override
  String get esignSignedCopyUnavailable =>
      'النسخة الموقّعة غير متاحة، لذا هذه هي النسخة الأصلية المرسلة إليك. توقيعك محفوظ مع الطلب.';

  @override
  String get esignBackToDocuments => 'العودة إلى المستندات';

  @override
  String get visitDefaultWorkingHours =>
      'الأحد - الخميس، 9:00 صباحاً - 5:00 مساءً';

  @override
  String get esignScreenshotsRestricted => 'لقطات الشاشة معطّلة لهذا المستند';

  @override
  String get esignContentHidden => 'المحتوى مخفي';

  @override
  String get apptNoneScheduled => 'لا توجد مواعيد مجدولة';

  @override
  String get apptRequestTitle => 'طلب موعد';

  @override
  String get apptNotFound => 'الموعد غير موجود';

  @override
  String apptFromRequester(String code, String name) {
    return '$code · من $name';
  }

  @override
  String get apptRequesterAdmin => 'الإدارة';

  @override
  String get apptDetails => 'التفاصيل';

  @override
  String get apptFieldPurpose => 'الغرض';

  @override
  String get apptFieldProposedDateTime => 'التاريخ والوقت المقترحان';

  @override
  String get apptFieldLocation => 'الموقع';

  @override
  String get apptFieldNote => 'ملاحظة';

  @override
  String get apptFieldYourProposedTime => 'الوقت الذي اقترحته';

  @override
  String get apptFieldYourNote => 'ملاحظتك';

  @override
  String get apptNoticeAccepted =>
      'لقد قبلت هذا الموعد. يرجى الحضور في الوقت المحدد إلى الاستقبال.';

  @override
  String get apptNoticeRejected => 'لقد رفضت هذا الموعد.';

  @override
  String get apptNoticeRescheduleRequested =>
      'لقد اقترحت وقتاً جديداً. في انتظار تأكيد الإدارة.';

  @override
  String get apptNoticeScheduled =>
      'تم جدولة موعدك. يرجى الحضور في الوقت المحدد إلى الاستقبال.';

  @override
  String get apptReject => 'رفض';

  @override
  String get apptProposeTime => 'اقتراح وقت';

  @override
  String get apptAcceptAppointment => 'قبول الموعد';

  @override
  String get apptRejectAppointment => 'رفض الموعد';

  @override
  String get apptRejectBody => 'أبلغ الإدارة بسبب عدم تمكنك من الحضور.';

  @override
  String get supportReasonOptionalHint => 'السبب (اختياري)';

  @override
  String get apptRejected => 'تم رفض الموعد';

  @override
  String get apptProposeNewTime => 'اقتراح وقت جديد';

  @override
  String get apptNoteForAdminHint => 'ملاحظة للإدارة (اختياري)';

  @override
  String get apptSendProposedTime => 'إرسال الوقت المقترح';

  @override
  String get apptProposedTimeSent => 'تم إرسال الوقت المقترح إلى الإدارة';

  @override
  String get apptConfirmedTitle => 'تم تأكيد الموعد';

  @override
  String get apptConfirmedBody => 'تمت إضافته إلى جدولك. سنذكّرك قبل موعده.';

  @override
  String get apptDone => 'تم';

  @override
  String get apptViewInCalendar => 'عرض في التقويم';

  @override
  String apptTitleWithTime(String title, String time) {
    return '$title · $time';
  }

  @override
  String get supportStatusRescheduled => 'أُعيد تحديد الموعد';

  @override
  String get supportStatusResponded => 'تم الرد';

  @override
  String get supportStatusClosed => 'مُغلق';

  @override
  String get supportActionRescheduleProposed => 'مواعيد جديدة مقترحة';

  @override
  String get supportRescheduleProposedTitle => 'مواعيد جديدة مقترحة';

  @override
  String get supportRescheduleNewStart => 'تاريخ البداية الجديد';

  @override
  String get supportRescheduleNewEnd => 'تاريخ النهاية الجديد';

  @override
  String get supportRescheduleProposedBy => 'مقترح من';

  @override
  String get supportRescheduleAccept => 'قبول المواعيد';

  @override
  String get supportRescheduleDecline => 'رفض';

  @override
  String get supportRescheduleAccepted =>
      'تم قبول المواعيد. طلبك قيد المراجعة مرة أخرى.';

  @override
  String get supportRescheduleDeclined =>
      'تم رفض المواعيد. طلبك قيد المراجعة مرة أخرى.';
}
