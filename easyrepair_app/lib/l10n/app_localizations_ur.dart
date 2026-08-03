// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get languageSectionTitle => 'ترجیحات';

  @override
  String get languageRowLabel => 'زبان';

  @override
  String get languageSheetTitle => 'اپنی زبان منتخب کریں';

  @override
  String get authRoleQuestion => 'HandyGo پر آپ کیا کرنا چاہتے ہیں؟';

  @override
  String get authRoleClientTitle => 'مجھے گھر کے کام کے لیے استاد چاہیے';

  @override
  String get authRoleClientSubtitle =>
      'تصدیق شدہ استاد بک کریں اور اپنا کام آسانی سے کروائیں۔';

  @override
  String get authRoleWorkerTitle => 'میں استاد ہوں اور کام حاصل کرنا چاہتا ہوں';

  @override
  String get authRoleWorkerSubtitle =>
      'HandyGo جوائن کریں اور اپنی مہارت کے مطابق کام حاصل کریں۔';

  @override
  String get authWorkerTypeQuestion => 'کیا آپ پہلے سے HandyGo\nاستاد ہیں؟';

  @override
  String get authWorkerTypeNewTitle => 'میں نیا استاد ہوں';

  @override
  String get authWorkerTypeNewSubtitle => 'HandyGo پر اپنا نیا اکاؤنٹ بنائیں۔';

  @override
  String get authWorkerTypeExistingTitle => 'میرا اکاؤنٹ پہلے سے بنا ہوا ہے';

  @override
  String get authWorkerTypeExistingSubtitle =>
      'OTP یا پاس ورڈ سے اپنے اکاؤنٹ میں لاگ اِن کریں۔';

  @override
  String authWelcomeToastTitle(String name) {
    return 'خوش آمدید، $name!';
  }

  @override
  String get authWelcomeToastSubtitle => 'آپ کا اکاؤنٹ تیار ہے۔';

  @override
  String get authOtpExpired => 'کوڈ ختم ہو گیا ہے۔ نیا کوڈ منگوائیں۔';

  @override
  String authOtpExpiresIn(String time) {
    return 'کوڈ $time میں ختم ہوگا';
  }

  @override
  String authOtpResendCooldown(int seconds) {
    return 'کوڈ دوبارہ بھیجیں (${seconds}s)';
  }

  @override
  String get authOtpResend => 'کوڈ دوبارہ بھیجیں';

  @override
  String get authFieldFullName => 'آپ کا پورا نام';

  @override
  String get authFieldFullNameShort => 'پورا نام';

  @override
  String get authHintFullName => 'اپنا پورا نام لکھیں';

  @override
  String get authFieldMobileNumber => 'موبائل نمبر';

  @override
  String get authFieldMobileNumberTitle => 'موبائل نمبر';

  @override
  String get authFieldPassword => 'پاس ورڈ';

  @override
  String get authFieldConfirmPassword => 'پاس ورڈ دوبارہ لکھیں';

  @override
  String get authValidationNameRequired => 'اپنا نام لکھیں۔';

  @override
  String get authValidationPhoneRequired => 'موبائل نمبر لکھیں۔';

  @override
  String get authValidationPhoneInvalid => 'درست پاکستانی موبائل نمبر لکھیں۔';

  @override
  String get authValidationPasswordRequired => 'پاس ورڈ لکھیں۔';

  @override
  String get authValidationPasswordTooShort =>
      'پاس ورڈ کم از کم 8 حروف کا ہونا چاہیے۔';

  @override
  String get authValidationConfirmPasswordRequired => 'پاس ورڈ دوبارہ لکھیں۔';

  @override
  String get authValidationPasswordsDoNotMatch => 'پاس ورڈ آپس میں نہیں ملتے۔';

  @override
  String get authClientLoginTitle => 'استاد بک کرنے کے لیے\nلاگ اِن کریں';

  @override
  String get authClientOtpSubtitle =>
      'اپنا نام اور موبائل نمبر لکھیں۔ ہم ویریفیکیشن کوڈ بھیجیں گے۔';

  @override
  String get authClientPasswordSubtitle =>
      'اپنے موبائل نمبر اور پاس ورڈ سے آگے بڑھیں۔';

  @override
  String get authOtpWillBeSentNotice =>
      'اس نمبر پر ویریفیکیشن کوڈ بھیجا جائے گا۔';

  @override
  String get authButtonSendCode => 'کوڈ بھیجیں';

  @override
  String get authButtonVerifyAndContinue => 'ویریفائی کر کے آگے بڑھیں';

  @override
  String get authButtonLogIn => 'لاگ اِن کریں';

  @override
  String get authButtonCreateAccount => 'اکاؤنٹ بنائیں';

  @override
  String get authButtonForgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get authButtonContinueWithOtp => 'OTP سے آگے بڑھیں';

  @override
  String get authButtonContinueWithPassword => 'پاس ورڈ سے آگے بڑھیں';

  @override
  String get authButtonUstaadLogin => 'استاد لاگ اِن';

  @override
  String get authErrorGeneric => 'کچھ غلط ہو گیا۔';

  @override
  String get authErrorOtpSendFailed =>
      'OTP فی الحال نہیں بھیجا جا سکا۔ پاس ورڈ سے آگے بڑھیں یا تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get commonCancel => 'منسوخ کریں';

  @override
  String get commonSave => 'محفوظ کریں';

  @override
  String get commonDelete => 'ڈیلیٹ کریں';

  @override
  String get commonRetry => 'دوبارہ کوشش کریں';

  @override
  String get commonUser => 'صارف';

  @override
  String get commonYesterday => 'کل';

  @override
  String get commonUploading => 'اپ لوڈ ہو رہا ہے...';

  @override
  String get chatTitleFallback => 'چیٹ';

  @override
  String get chatListTitle => 'پیغامات';

  @override
  String get chatSearchHint => 'چیٹ ڈھونڈیں یا ”support“ لکھیں';

  @override
  String get chatEmptyTitle => 'ابھی کوئی گفتگو نہیں';

  @override
  String get chatEmptySubtitle => 'پیغامات یہاں نظر آئیں گے';

  @override
  String get chatNoResultsTitle => 'کوئی چیٹ نہیں ملی';

  @override
  String get chatNoResultsSubtitle =>
      'کوئی اور نام آزمائیں، یا ”support“ لکھیں';

  @override
  String get chatNoMessagesYet => 'ابھی کوئی پیغام نہیں۔ سلام کریں!';

  @override
  String get chatSupportBanner =>
      'اپنا مسئلہ یا سوال یہاں لکھیں۔ HandyGo Support آپ کی مدد کرے گا۔';

  @override
  String get chatEditMessage => 'پیغام میں تبدیلی';

  @override
  String get chatEditHint => 'اپنا پیغام تبدیل کریں...';

  @override
  String get chatDeleteMessage => 'پیغام ڈیلیٹ کریں';

  @override
  String get chatDeleteConfirm =>
      'یہ پیغام چیٹ میں سب کے لیے ڈیلیٹ ہو جائے گا۔';

  @override
  String get chatMicPermissionRequired =>
      'وائس میسج بھیجنے کے لیے مائیکروفون کی اجازت درکار ہے۔';

  @override
  String get chatLocationPermissionDenied => 'لوکیشن کی اجازت نہیں دی گئی';

  @override
  String get chatLocationPermissionPermanentlyDenied =>
      'لوکیشن کی اجازت مستقل بند ہے — سیٹنگز میں جا کر آن کریں';

  @override
  String chatLocationFailed(String error) {
    return 'آپ کی لوکیشن حاصل نہیں ہو سکی: $error';
  }

  @override
  String get weekdayMon => 'پیر';

  @override
  String get weekdayTue => 'منگل';

  @override
  String get weekdayWed => 'بدھ';

  @override
  String get weekdayThu => 'جمعرات';

  @override
  String get weekdayFri => 'جمعہ';

  @override
  String get weekdaySat => 'ہفتہ';

  @override
  String get weekdaySun => 'اتوار';

  @override
  String get commonContinue => 'آگے بڑھیں';

  @override
  String get commonNotNow => 'ابھی نہیں';

  @override
  String get commonToday => 'آج';

  @override
  String get commonOpenSettings => 'سیٹنگز کھولیں';

  @override
  String get permissionsTitle => 'اجازتیں دیں';

  @override
  String get permissionsRationale =>
      'HandyGo کو کیمرہ، مائیکروفون اور لوکیشن کی اجازت چاہیے تاکہ آپ تصاویر اور ویڈیو بھیج سکیں، وائس نوٹ بھیج سکیں، اور کام کی لوکیشن شیئر یا ٹریک کر سکیں۔';

  @override
  String get permissionsBlockedTitle => 'اجازتیں بند ہیں';

  @override
  String get permissionsBlockedBody =>
      'کچھ اجازتیں مستقل طور پر بند کر دی گئی ہیں۔ انہیں دوبارہ آن کرنے کے لیے سیٹنگز کھولیں۔';

  @override
  String get generalInfoTitle => 'جنرل';

  @override
  String get generalAccountSection => 'اکاؤنٹ کی معلومات';

  @override
  String get generalFirstName => 'پہلا نام';

  @override
  String get generalLastName => 'آخری نام';

  @override
  String get generalPhoneNumber => 'فون نمبر';

  @override
  String get generalNamePhoneLocked =>
      'نام اور فون نمبر آپ کے اکاؤنٹ سے منسلک ہیں اور یہاں سے تبدیل نہیں کیے جا سکتے۔';

  @override
  String get generalSecuritySection => 'سیکیورٹی';

  @override
  String get generalChangePassword => 'پاس ورڈ تبدیل کریں';

  @override
  String get generalCurrentPassword => 'موجودہ پاس ورڈ';

  @override
  String get generalNewPassword => 'نیا پاس ورڈ';

  @override
  String get generalConfirmNewPassword => 'نیا پاس ورڈ دوبارہ لکھیں';

  @override
  String get generalChangePasswordComingSoon =>
      'ایپ میں پاس ورڈ تبدیل کرنے کی سہولت جلد آ رہی ہے۔ فوری مدد کے لیے سپورٹ سے رابطہ کریں۔';

  @override
  String get generalUpdatePassword => 'پاس ورڈ اپ ڈیٹ کریں';

  @override
  String get distanceAtYourLocation => 'بالکل آپ کی جگہ پر';

  @override
  String distanceMetersAway(int meters) {
    return '$meters میٹر دور';
  }

  @override
  String distanceKmAway(String km) {
    return '$km کلومیٹر دور';
  }

  @override
  String get distanceUnderOneKm => '1 کلومیٹر سے کم';

  @override
  String get notificationsTitle => 'اطلاعات';

  @override
  String get notificationsMarkAllRead => 'سب پڑھا ہوا نشان زد کریں';

  @override
  String get notificationsEmptyTitle => 'ابھی کوئی اطلاع نہیں';

  @override
  String get notificationsEmptySubtitle =>
      'کام کی اپ ڈیٹس، ریویوز اور مزید کی اطلاع آپ کو دی جائے گی۔';

  @override
  String get timeJustNow => 'ابھی ابھی';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes منٹ پہلے';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours گھنٹے پہلے';
  }

  @override
  String get workerRatingNew => 'نیا استاد';

  @override
  String get workerRatingNone => 'کوئی ریٹنگ نہیں';

  @override
  String workerRatingWithJobs(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کام',
      one: '$count کام',
    );
    return '$rating ($_temp0)';
  }

  @override
  String get chatSeen => 'دیکھ لیا';

  @override
  String get chatMessageDeleted => 'یہ پیغام ڈیلیٹ کر دیا گیا';

  @override
  String get chatEdited => 'تبدیل شدہ';

  @override
  String get chatCouldNotOpenMaps => 'نقشہ نہیں کھل سکا';

  @override
  String get chatSharedLocation => 'لوکیشن بھیجی گئی';

  @override
  String get chatComposerHint => 'پیغام لکھیں...';

  @override
  String get chatAttachPhoto => 'تصویر';

  @override
  String get chatAttachVideo => 'ویڈیو';

  @override
  String get chatAttachVoice => 'وائس';

  @override
  String get chatAttachLocation => 'لوکیشن';

  @override
  String get chatTakePhoto => 'تصویر لیں';

  @override
  String get chatRecordVideo => 'ویڈیو بنائیں';

  @override
  String get monthJan => 'جنوری';

  @override
  String get monthFeb => 'فروری';

  @override
  String get monthMar => 'مارچ';

  @override
  String get monthApr => 'اپریل';

  @override
  String get monthMay => 'مئی';

  @override
  String get monthJun => 'جون';

  @override
  String get monthJul => 'جولائی';

  @override
  String get monthAug => 'اگست';

  @override
  String get monthSep => 'ستمبر';

  @override
  String get monthOct => 'اکتوبر';

  @override
  String get monthNov => 'نومبر';

  @override
  String get monthDec => 'دسمبر';

  @override
  String dateDayMonthYear(int day, String month, int year) {
    return '$day $month $year';
  }

  @override
  String get authPasswordResetSuccess =>
      'آپ کا پاس ورڈ کامیابی سے تبدیل ہو گیا ہے۔';

  @override
  String get authForgotPasswordPrompt => 'اپنا رجسٹرڈ موبائل نمبر لکھیں';

  @override
  String get authSendOtp => 'OTP بھیجیں';

  @override
  String get authNewPasswordRequired => 'نیا پاس ورڈ لکھیں۔';

  @override
  String get authOr => 'یا';

  @override
  String get authLoginWithPassword => 'پاس ورڈ سے لاگ اِن کریں';

  @override
  String get authWorkerRegisterTitle => 'نیا استاد اکاؤنٹ\nبنائیں';

  @override
  String get authCnicNameHint =>
      'اپنا پورا نام بالکل ویسے لکھیں جیسے آپ کے شناختی کارڈ پر ہے';

  @override
  String get authCreatePasswordLabel => 'پاس ورڈ بنائیں';

  @override
  String get authSelectSkill => 'اپنی مہارت منتخب کریں';

  @override
  String get authSkillsLoadFailed =>
      'مہارتیں لوڈ نہیں ہو سکیں۔ دوبارہ کوشش کریں۔';

  @override
  String get authSkillRequired => 'کوئی مہارت منتخب کریں۔';

  @override
  String get authConfirmNewPasswordButton => 'نیا پاس ورڈ کنفرم کریں';

  @override
  String get postJobOffersSoon =>
      'چند ہی منٹ میں آپ کو استادوں کی آفرز ملنا شروع ہو جائیں گی۔';

  @override
  String get postJobSelectDateTimeFirst =>
      'آگے بڑھنے کے لیے تاریخ اور وقت منتخب کریں۔';

  @override
  String postJobGoesLiveAt(String time, String date) {
    return 'کام $date کو $time بجے لائیو ہوگا — استاد کے پہنچنے کے وقت سے ایک گھنٹہ پہلے۔';
  }

  @override
  String get postJobAddPhotoVideo => 'تصویر یا ویڈیو شامل کریں';

  @override
  String get postJobChoosePhoto => 'تصویر منتخب کریں';

  @override
  String get postJobChooseVideo => 'ویڈیو منتخب کریں - 30 سیکنڈ';

  @override
  String get postJobCamera => 'کیمرہ';

  @override
  String get postJobRecordVideo30 => 'ویڈیو بنائیں - 30 سیکنڈ';

  @override
  String get errorNoInternet => 'انٹرنیٹ کنکشن نہیں ہے۔ اپنا نیٹ ورک چیک کریں۔';

  @override
  String get postJobSaveFailed => 'بکنگ محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get postJobBookingUpdatedTitle => 'بکنگ اپ ڈیٹ ہو گئی!';

  @override
  String get postJobBookingUpdatedBody =>
      'آپ کی بکنگ کی تفصیلات کامیابی سے اپ ڈیٹ ہو گئی ہیں۔';

  @override
  String get postJobViewBooking => 'بکنگ دیکھیں';

  @override
  String get postJobSelectService => 'سروس منتخب کریں';

  @override
  String get postJobServicesLoadFailed =>
      'سروسز لوڈ نہیں ہو سکیں۔ ایپ دوبارہ کھولیں۔';

  @override
  String get postJobBookingType => 'بکنگ کی قسم';

  @override
  String get postJobNormal => 'عام';

  @override
  String get postJobUrgent => 'فوری';

  @override
  String get postJobDateTime => 'تاریخ اور وقت';

  @override
  String get postJobArrivalTime => 'پہنچنے کا وقت';

  @override
  String get postJobWhatNeedsFixing => 'کیا ٹھیک کرانا ہے؟';

  @override
  String get postJobIssueHint =>
      'مثلاً اے سی ٹھنڈا نہیں کر رہا، پانی لیک ہو رہا ہے، سوئچ کام نہیں کر رہا';

  @override
  String get postJobDescription => 'تفصیل';

  @override
  String get postJobDescriptionHint => 'مسئلہ بیان کریں (اختیاری)';

  @override
  String get postJobServiceAddress => 'سروس کا پتہ';

  @override
  String get postJobAddressHint =>
      'مثلاً مکان 12، گلی 5، ڈی ایچ اے فیز 6، کراچی';

  @override
  String get postJobAddLocationFirst =>
      'آگے بڑھنے کے لیے اپنی لوکیشن شامل کریں۔';

  @override
  String get postJobVoiceAndPhotos => 'وائس نوٹ اور تصاویر';

  @override
  String get postJobVoiceAttached => 'وائس نوٹ لگا دیا گیا';

  @override
  String postJobAttachmentCount(int count) {
    return '4 میں سے $count · تصاویر یا 30 سیکنڈ کی ویڈیو';
  }

  @override
  String postJobAttachmentsWillBeRemoved(int count) {
    return 'محفوظ کرنے پر $count پرانی فائلیں ہٹا دی جائیں گی۔';
  }

  @override
  String get postJobTapToRecord =>
      'ریکارڈ کرنے کے لیے دبائیں — مسئلہ اپنے الفاظ میں بتائیں';

  @override
  String get postJobService => 'سروس';

  @override
  String get postJobWhatDoYouNeed => 'آپ کو کیا چاہیے؟';

  @override
  String get postJobChooseOneOption => 'ایک آپشن چنیں';

  @override
  String get postJobUnderstandingIsOurJob =>
      'مسئلہ سمجھنا ہمارا کام ہے — آپ کا نہیں۔';

  @override
  String get postJobStandardWork => 'اسٹینڈرڈ کام';

  @override
  String get postJobStandardWorkSubtitle => 'کام اور قیمت پہلے سے واضح۔';

  @override
  String get postJobOr => 'یا';

  @override
  String get postJobIKnowThePart => 'مجھے پرزہ بالکل معلوم ہے';

  @override
  String get postJobIKnowThePartSubtitle => 'استاد اپنا ریٹ بھیجیں گے، آپ چنیں';

  @override
  String get postJobIKnowThePartWarning =>
      'یہ صرف اسی صورت میں چنیں جب پرزے کا پورا یقین ہو۔ غلط نکلا تو استاد کا چکر ضائع جائے گا اور نیا ریٹ لگے گا۔';

  @override
  String get postJobSomethingIsBroken => 'کچھ خراب ہے';

  @override
  String get postJobDontKnowIssue => 'مسئلہ کیا ہے، یہ معلوم نہیں';

  @override
  String get postJobInspectionFeeTitle => 'انسپیکشن فیس';

  @override
  String get postJobNothingOpensBeforeRate =>
      'ریٹ بتانے سے پہلے کچھ نہیں کھلتا — جو کہا، وہی لیا۔';

  @override
  String get postJobChooseStandardService => 'اسٹینڈرڈ سروس منتخب کریں';

  @override
  String get postJobServicesUnavailable =>
      'سروسز لوڈ نہیں ہو سکیں۔ واپس جا کر دوبارہ کوشش کریں۔';

  @override
  String get postJobSelectCategoryFirst => 'پہلے سروس کیٹیگری منتخب کریں۔';

  @override
  String get postJobStandardServicesUnavailable =>
      'اسٹینڈرڈ سروسز لوڈ نہیں ہو سکیں۔';

  @override
  String get postJobNoStandardServices =>
      'اس سروس کے لیے ابھی کوئی اسٹینڈرڈ سروس دستیاب نہیں۔ اوپر سے کوئی اور آپشن منتخب کریں۔';

  @override
  String get postJobMultiSelectHint => 'آپ ایک سے زیادہ سروسز چن سکتے ہیں۔';

  @override
  String get postJobTotal => 'کل';

  @override
  String get postJobInspectionFeeLower => 'انسپیکشن فیس';

  @override
  String get postJobInspectionFeeLoadFailed => 'انسپیکشن فیس لوڈ نہیں ہو سکی۔';

  @override
  String get postJobHowInspectionWorks => 'انسپیکشن کیسے ہوتی ہے';

  @override
  String get postJobWhatDoYouSee => 'آپ کو کیا نظر آ رہا ہے؟ (اختیاری)';

  @override
  String get postJobWhatDoYouSeeHint =>
      'مثلاً اے سی چلتا ہے مگر کمرہ گرم رہتا ہے…';

  @override
  String get postJobBack => 'پیچھے';

  @override
  String get postJobNext => 'آگے';

  @override
  String get postJobStepAddress => 'پتہ';

  @override
  String get postJobStepDetails => 'تفصیلات';

  @override
  String get postJobStepTimeSelection => 'وقت کا انتخاب';

  @override
  String postJobStepIndicator(int current, int total, String title) {
    return 'مرحلہ $total میں سے $current  ·  $title';
  }

  @override
  String get clientHomeYourArea => 'آپ کا علاقہ';

  @override
  String get clientHomeSectionRepairs => 'مرمت';

  @override
  String get clientHomeSectionCleaning => 'صفائی';

  @override
  String get clientHomeSectionPainting => 'پینٹنگ';

  @override
  String get clientHomeSectionOutdoorVehicle => 'باہر اور گاڑی';

  @override
  String get serviceAcTechnician => 'اے سی ٹیکنیشن';

  @override
  String get serviceElectrician => 'الیکٹریشن';

  @override
  String get servicePlumber => 'پلمبر';

  @override
  String get serviceCarpenter => 'کارپینٹر';

  @override
  String get serviceDeepCleaning => 'گہری صفائی';

  @override
  String get servicePestControl => 'کیڑے مار سروس';

  @override
  String get servicePainter => 'پینٹر';

  @override
  String get serviceGardening => 'باغبانی';

  @override
  String get serviceCarWash => 'کار واش';

  @override
  String get serviceMoversPackers => 'مووَرز اینڈ پیکرز';

  @override
  String get clientHomeNoServicesFound => 'کوئی سروس نہیں ملی';

  @override
  String get clientHomeSearchResults => 'تلاش کے نتائج';

  @override
  String get clientHomeBookUrgently => 'فوری بک کریں';

  @override
  String get clientHomeChooseServiceHelp =>
      'فوری مدد کے لیے کوئی سروس منتخب کریں۔';

  @override
  String clientHomeGreeting(String name) {
    return 'سلام $name 👋';
  }

  @override
  String get clientHomeBeatTheHeat => 'کراچی کی گرمی کا مقابلہ کریں ☀️';

  @override
  String get clientHomeAcServiceBanner =>
      'اپنا اے سی سروس کروائیں\nاس سے پہلے کہ خرابی بڑھ جائے۔';

  @override
  String get clientHomeBookAcTechnician => 'اے سی ٹیکنیشن بک کریں';

  @override
  String get clientHomeNeedHelpNow => 'ابھی مدد چاہیے؟';

  @override
  String get clientHomeUrgentSubtitle => 'فوری مسائل کے لیے ابھی بک کریں۔';

  @override
  String get clientHome247Service => '24/7 سروس';

  @override
  String get clientHomeRecent => 'حالیہ';

  @override
  String get clientHomeSeeAll => 'سب دیکھیں';

  @override
  String get timeNow => 'ابھی';

  @override
  String timeMinutesShort(int minutes) {
    return '$minutes منٹ';
  }

  @override
  String timeHoursShort(int hours) {
    return '$hours گھنٹے';
  }

  @override
  String get clientProfileTitle => 'پروفائل';

  @override
  String get clientProfileAvatarLocalOnly =>
      'پروفائل تصویر اسی ڈیوائس پر محفوظ ہے۔ کلاؤڈ سِنک ابھی دستیاب نہیں۔';

  @override
  String get settingsSectionAccount => 'اکاؤنٹ';

  @override
  String get settingsSectionLegal => 'قانونی';

  @override
  String get settingsSectionDangerZone => 'خطرناک زون';

  @override
  String get settingsPrivacyPolicy => 'پرائیویسی پالیسی';

  @override
  String get settingsTermsConditions => 'شرائط و ضوابط';

  @override
  String get profilePhotoTitle => 'پروفائل تصویر';

  @override
  String get commonGallery => 'گیلری';

  @override
  String get commonRemove => 'ہٹائیں';

  @override
  String get deleteAccountConfirmTitle => 'اکاؤنٹ ڈیلیٹ کریں؟';

  @override
  String get deleteAccountConfirmBody =>
      'اس سے آپ کا HandyGo اکاؤنٹ ڈیلیٹ ہو جائے گا اور آپ سائن آؤٹ ہو جائیں گے۔ یہ عمل شاید واپس نہ ہو سکے۔';

  @override
  String get deleteAccountTitle => 'اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get deleteAccountRequestByEmail =>
      'ای میل کے ذریعے ڈیلیٹ کی درخواست دیں';

  @override
  String get commonLogout => 'لاگ آؤٹ';

  @override
  String get clientJobsTitle => 'میرے کام';

  @override
  String get clientJobsEmpty => '📋  ابھی کوئی کام نہیں';

  @override
  String get locationSelected => 'منتخب کردہ لوکیشن';

  @override
  String get locationSearchHint => 'علاقہ یا کوئی نشانی تلاش کریں…';

  @override
  String get locationGettingAddress => 'پتہ حاصل کیا جا رہا ہے…';

  @override
  String get locationUseThis => 'یہی لوکیشن استعمال کریں';

  @override
  String get serviceComingSoon => 'جلد آ رہا ہے';

  @override
  String get clientHomeSearchHint => 'سروسز تلاش کریں...';

  @override
  String get profileDeleteFailed => 'اکاؤنٹ ڈیلیٹ نہیں ہو سکا۔';

  @override
  String get serviceBookNow => 'ابھی بک کریں';

  @override
  String get serviceSelectedTick => 'منتخب ✓';

  @override
  String get locationMoveMapHint => 'نقشہ ہلائیں یا لوکیشن چننے کے لیے دبائیں';

  @override
  String get slotMorning => 'صبح';

  @override
  String get slotAfternoon => 'دوپہر';

  @override
  String get slotEvening => 'شام';

  @override
  String get slotNight => 'رات';

  @override
  String get slotMorningRange => 'صبح 9 – دوپہر 12';

  @override
  String get slotAfternoonRange => 'دوپہر 12 – شام 4';

  @override
  String get slotEveningRange => 'شام 4 – رات 8';

  @override
  String get slotNightRange => 'رات 8 – رات 11';

  @override
  String get postJobSelectDate => 'تاریخ منتخب کریں';

  @override
  String get postJobLocationAdded => 'لوکیشن شامل کر دی گئی';

  @override
  String get postJobCurrentLocation => 'موجودہ لوکیشن';

  @override
  String get postJobMapLocationAdded => 'نقشے سے لوکیشن شامل کر دی گئی';

  @override
  String get postJobPickOnMap => 'نقشے پر منتخب کریں';

  @override
  String postJobMapPrefix(String address) {
    return 'نقشہ: $address';
  }

  @override
  String postJobGpsPrefix(String coordinates) {
    return 'جی پی ایس: $coordinates';
  }

  @override
  String get postJobBookService => 'سروس بک کریں';

  @override
  String get postJobSaveChanges => 'تبدیلیاں محفوظ کریں';

  @override
  String get postJobBookAService => 'سروس بک کریں';

  @override
  String get postJobEditBooking => 'بکنگ میں تبدیلی';

  @override
  String get postJobNotAvailable => 'دستیاب نہیں';

  @override
  String get bookingLoadFailed => 'بکنگ لوڈ نہیں ہو سکی۔';

  @override
  String get bookingServiceDetails => 'سروس کی تفصیلات';

  @override
  String get bookingIssue => 'مسئلہ';

  @override
  String get bookingUrgency => 'فوری ضرورت';

  @override
  String get bookingTiming => 'وقت';

  @override
  String get bookingNotScheduledYet => 'ابھی وقت طے نہیں ہوا';

  @override
  String get bookingTimeWindow => 'وقت کا دورانیہ';

  @override
  String get bookingScheduledDate => 'طے شدہ تاریخ';

  @override
  String get bookingCreated => 'بنائی گئی';

  @override
  String get bookingCancellationReason => 'منسوخی کی وجہ';

  @override
  String get bookingInspectionCompletedBy => 'انسپیکشن مکمل کرنے والے';

  @override
  String get bookingWorkBeingCompletedBy => 'کام مکمل کرنے والے';

  @override
  String get bookingInspectionAndRepairBy => 'انسپیکشن اور مرمت کرنے والے';

  @override
  String get bookingAssignedWorker => 'مقرر کردہ استاد';

  @override
  String get bookingDetailsTitle => 'بکنگ کی تفصیلات';

  @override
  String get bookingNoAddressProvided => 'کوئی پتہ نہیں دیا گیا';

  @override
  String get bookingAttachments => 'منسلک فائلیں';

  @override
  String bookingPhotosCount(int count) {
    return 'تصاویر ($count)';
  }

  @override
  String bookingVideosCount(int count) {
    return 'ویڈیوز ($count)';
  }

  @override
  String get bookingVoiceNote => 'وائس نوٹ';

  @override
  String get bookingPricing => 'قیمت';

  @override
  String get bookingEstimatedPrice => 'تخمینی قیمت';

  @override
  String get bookingInspectionCharges => 'انسپیکشن چارجز';

  @override
  String get bookingWorkCharges => 'کام کے چارجز';

  @override
  String get bookingFinalPrice => 'حتمی قیمت';

  @override
  String get bookingJobLocation => 'کام کی جگہ';

  @override
  String get bookingLiveLocation => 'لائیو لوکیشن';

  @override
  String bookingTrackingWorker(String name) {
    return '$name کو ٹریک کیا جا رہا ہے';
  }

  @override
  String get bookingWaitingForWorkerLocation =>
      'استاد کے لوکیشن شیئر کرنے کا انتظار ہے';

  @override
  String get bookingLiveLocationNotAvailable => 'لائیو لوکیشن ابھی دستیاب نہیں';

  @override
  String get bookingLocationPending => 'لوکیشن کا انتظار ہے';

  @override
  String get bookingMapPreviewUnavailable => 'نقشہ دکھایا نہیں جا سکا';

  @override
  String get bookingMapImageLoadFailed => 'نقشے کی تصویر لوڈ نہیں ہو سکی';

  @override
  String get bookingAppearsWhenEnRoute => 'استاد کے روانہ ہوتے ہی نظر آئے گا';

  @override
  String get bookingWorkerNearlyThere => 'استاد تقریباً پہنچ چکے ہیں';

  @override
  String get bookingWorkerOnTheWay => 'استاد راستے میں ہیں';

  @override
  String get bookingLiveUpdatedNow => 'لائیو · ابھی اپ ڈیٹ ہوا';

  @override
  String get bookingStatusTimeline => 'کام کی صورتحال کی ٹائم لائن';

  @override
  String get bookingJobExpired => 'یہ کام ختم ہو گیا';

  @override
  String get bookingExpiredExplanation =>
      '72 گھنٹوں میں کوئی استاد ہائر نہیں ہوا۔ تلاش جاری رکھنے کے لیے اسے دوبارہ لائیو کریں۔';

  @override
  String get bookingMakeLiveFailed => 'کام دوبارہ لائیو نہیں ہو سکا۔';

  @override
  String get bookingMakeLiveAgain => 'دوبارہ لائیو کریں';

  @override
  String bookingPreviousUstaadCancelledNamed(String name) {
    return 'پچھلے استاد نے منسوخ کر دیا: $name';
  }

  @override
  String get bookingPreviousUstaadCancelled => 'پچھلے استاد نے منسوخ کر دیا';

  @override
  String get bookingUstaadCancelledJob => 'استاد نے یہ کام منسوخ کر دیا';

  @override
  String bookingReasonPrefix(String reason) {
    return 'وجہ: $reason';
  }

  @override
  String get bookingFindAnotherUstaadFailed => 'دوسرا استاد تلاش نہیں ہو سکا۔';

  @override
  String get bookingFindAnotherUstaad => 'دوسرا استاد تلاش کریں';

  @override
  String get bookingSelectedServices => 'منتخب سروسز';

  @override
  String bookingServiceQuantity(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String get bookingChooseUstaad => 'استاد منتخب کریں';

  @override
  String get bookingSeeWorkerBids => 'استادوں کی بولیاں دیکھیں';

  @override
  String get bookingTrackWorker => 'استاد کو ٹریک کریں';

  @override
  String get bookingReviewWorker => 'استاد کو ریویو دیں';

  @override
  String get bookingYourReview => 'آپ کا ریویو';

  @override
  String get bookingCallWorker => 'استاد کو کال کریں';

  @override
  String get bookingCancelBooking => 'بکنگ منسوخ کریں';

  @override
  String get bookingCancelFailed => 'بکنگ منسوخ نہیں ہو سکی۔';

  @override
  String get bookingChatWithWorker => 'استاد سے چیٹ کریں';

  @override
  String get bookingLoadFailedShort => 'بکنگ لوڈ نہیں ہو سکی';

  @override
  String get workerLevelMaster => 'ماسٹر';

  @override
  String get workerLevelElite => 'ایلیٹ';

  @override
  String get workerLevelProUstaad => 'پرو استاد';

  @override
  String get workerLevelPro => 'پرو';

  @override
  String get workerLevelStandard => 'اسٹینڈرڈ';

  @override
  String get trackLoadFailed => 'ٹریکنگ ڈیٹا لوڈ نہیں ہو سکا۔';

  @override
  String get trackTitleUstaad => 'استاد کو ٹریک کریں';

  @override
  String get trackNoLocationForBooking => 'اس بکنگ کے لیے لوکیشن دستیاب نہیں۔';

  @override
  String get trackUstaadLocationUnavailable =>
      'استاد کی لوکیشن ابھی دستیاب نہیں ہے۔';

  @override
  String get trackJobCompleted => 'کام مکمل ✓';

  @override
  String get trackQuoteAcceptedRepairInProgress => 'کوٹ منظور — مرمت جاری ہے';

  @override
  String get trackReportSubmitted => 'رپورٹ جمع کرا دی گئی';

  @override
  String get trackInspectionInProgress => 'انسپیکشن جاری ہے';

  @override
  String get trackReviewReportAndDecide =>
      'نیچے رپورٹ دیکھیں اور فیصلہ کریں کہ آگے کیا کرنا ہے';

  @override
  String get trackWorkerLabel => 'استاد';

  @override
  String trackHiredAt(String price) {
    return '$price پر ہائر کیا گیا';
  }

  @override
  String get trackPhoneUnavailable => 'فون نمبر دستیاب نہیں';

  @override
  String get trackDialerFailed => 'فون ڈائلر نہیں کھل سکا';

  @override
  String get trackAssignedWorkerCaps => 'مقرر کردہ استاد';

  @override
  String get trackCall => 'کال';

  @override
  String get trackLocationUnavailable => 'لوکیشن دستیاب نہیں';

  @override
  String trackArrivingIn(int count) {
    return 'تقریباً $count منٹ میں پہنچ رہے ہیں';
  }

  @override
  String get trackEtaUnavailable => 'پہنچنے کا وقت معلوم نہیں';

  @override
  String get trackStepHired => 'ہائر ہو گئے';

  @override
  String get trackStepUstaadOnTheWay => 'استاد راستے میں';

  @override
  String get trackStepInspectionInProgress => 'انسپیکشن جاری';

  @override
  String get trackStepReportSubmitted => 'رپورٹ جمع';

  @override
  String get trackStepClosedAfterInspection => 'انسپیکشن کے بعد بند';

  @override
  String get trackStepQuoteAccepted => 'کوٹ منظور';

  @override
  String get trackStepReviewed => 'ریویو ہو گیا';

  @override
  String get trackStepWorkInProgress => 'کام جاری';

  @override
  String get trackStepReviewPending => 'ریویو باقی';

  @override
  String get trackJobProgress => 'کام کی پیش رفت';

  @override
  String get trackLoadFailedShort => 'ٹریکنگ لوڈ نہیں ہو سکی';

  @override
  String get discoveryJobLocation => 'کام کی جگہ';

  @override
  String get discoveryJobLocationUnavailable => 'کام کی جگہ دستیاب نہیں';

  @override
  String get discoveryLiveWorkerOffers => 'استادوں کی لائیو آفرز';

  @override
  String get discoveryRefresh => 'ریفریش';

  @override
  String get discoveryBidsLoadFailed => 'بولیاں لوڈ نہیں ہو سکیں۔';

  @override
  String get discoveryNoBidsYet => 'ابھی کوئی بولی نہیں';

  @override
  String discoveryPendingCount(int count) {
    return '$count زیرِ التوا';
  }

  @override
  String get discoveryHire => 'ہائر کریں';

  @override
  String get discoveryHiring => 'ہائر کیا جا رہا ہے…';

  @override
  String discoveryHireNamed(String name) {
    return '$name کو ہائر کریں؟';
  }

  @override
  String discoveryAcceptBid(String name, String price) {
    return '$name کی $price کی بولی منظور کریں؟';
  }

  @override
  String get discoveryInspectionFeeSeparate =>
      'انسپیکشن کرنے والے استاد کی انسپیکشن فیس الگ سے دینی ہوگی۔ نیا استاد اپنی آفر کے مطابق کام کی پوری رقم لے گا، اور انسپیکشن فیس اس میں ایڈجسٹ نہیں ہوگی۔';

  @override
  String get discoveryWorkerHired => 'استاد کامیابی سے ہائر ہو گئے';

  @override
  String get discoveryHireFailed => 'استاد ہائر نہیں ہو سکے۔';

  @override
  String get discoveryInspectedThisJob => 'اس کام کی انسپیکشن کی';

  @override
  String get discoveryTheirQuote => 'ان کا کوٹ';

  @override
  String get discoveryInspectionCompletedByThis =>
      'انسپیکشن اسی استاد نے مکمل کی۔';

  @override
  String get discoveryViewInspectionReport => 'انسپیکشن رپورٹ دیکھیں';

  @override
  String get discoveryHireAgain => 'دوبارہ ہائر کریں';

  @override
  String discoveryHireAgainNamed(String name) {
    return '$name کو دوبارہ ہائر کریں؟';
  }

  @override
  String get discoveryOriginalQuoteContinues =>
      'وہ اپنے اصل انسپیکشن کوٹ پر ہی کام جاری رکھیں گے۔';

  @override
  String get discoveryWorkersWillAppear =>
      'درخواست دینے والے استاد یہاں نظر آئیں گے۔\nتھوڑی دیر بعد دوبارہ دیکھیں۔';

  @override
  String get discoveryTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get inspectionReportTitle => 'انسپیکشن رپورٹ';

  @override
  String get inspectionReportNotAvailable => 'رپورٹ ابھی دستیاب نہیں۔';

  @override
  String get inspectionUstaadVoiceNote => 'استاد کا وائس نوٹ';

  @override
  String get inspectionPhotos => 'تصاویر';

  @override
  String get inspectionParts => 'پرزے';

  @override
  String get inspectionRepairQuoteTotal => 'مرمت کے کوٹ کا کل';

  @override
  String get inspectionAcceptQuoteContinue =>
      'کوٹ منظور کریں اور مرمت جاری رکھیں';

  @override
  String get inspectionFindOtherUstaad => 'دوسرا استاد تلاش کریں';

  @override
  String get inspectionCloseAfterInspection => 'انسپیکشن کے بعد بند کریں';

  @override
  String get inspectionAcceptQuoteConfirmTitle =>
      'کوٹ منظور کر کے مرمت جاری رکھیں؟';

  @override
  String get inspectionCloseConfirmTitle => 'انسپیکشن کے بعد بند کریں؟';

  @override
  String get inspectionAcceptQuoteConfirmBody =>
      'یہی استاد مرمت جاری رکھیں گے۔ انسپیکشن فیس معاف ہے — آپ صرف مرمت کا کوٹ ادا کریں گے۔';

  @override
  String get inspectionCloseConfirmBody =>
      'آپ سے صرف انسپیکشن فیس لی جائے گی۔ کام مکمل شدہ نشان زد ہو جائے گا۔';

  @override
  String get inspectionClosedAfterInspection =>
      'انسپیکشن کے بعد بند کر دیا گیا۔';

  @override
  String get inspectionQuoteAcceptedRepairInProgress =>
      'کوٹ منظور — مرمت جاری ہے۔';

  @override
  String get inspectionActionFailed => 'کارروائی ناکام۔ دوبارہ کوشش کریں۔';

  @override
  String get inspectionFindAnotherConfirmTitle => 'دوسرا استاد تلاش کریں؟';

  @override
  String get inspectionFindAnotherConfirmBody =>
      'تصدیق کرنے پر انسپیکشن مکمل ہو جائے گی اور انسپیکشن فیس لی جائے گی۔ آپ کا کام دوبارہ لائیو ہو جائے گا تاکہ دوسرے استاد اپنے ریٹ بھیج سکیں۔';

  @override
  String get inspectionBadge => 'انسپیکشن';

  @override
  String get chooseHireConfirmTitle => 'اس استاد کو ہائر کریں؟';

  @override
  String chooseHireConfirmBody(String name) {
    return 'کیا $name کو یہ کام دیں؟ اس کے بعد آپ دوسرا استاد منتخب نہیں کر سکیں گے۔';
  }

  @override
  String get chooseAssignFailed =>
      'یہ استاد مقرر نہیں ہو سکے۔ دوبارہ کوشش کریں۔';

  @override
  String chooseServiceTotal(String price) {
    return 'سروس کا کل $price';
  }

  @override
  String chooseInspectionFeeAmount(String price) {
    return 'انسپیکشن فیس $price';
  }

  @override
  String get chooseFindingUstaads =>
      'آپ کے قریب تصدیق شدہ استاد تلاش کیے جا رہے ہیں…';

  @override
  String get chooseLoadFailed => 'اس وقت دستیاب استاد لوڈ نہیں ہو سکے۔';

  @override
  String get chooseNoUstaadAvailable =>
      'اس وقت کوئی تصدیق شدہ استاد دستیاب نہیں۔';

  @override
  String get chooseAutoRefreshNote =>
      'فہرست ہر 45 سیکنڈ بعد خود بخود ریفریش ہوتی ہے۔';

  @override
  String get chooseRefreshOrWait =>
      'آپ ریفریش کر سکتے ہیں یا تھوڑا انتظار کریں — دستیاب استاد دیکھے جا رہے ہیں…';

  @override
  String get chooseNewBadge => 'نیا';

  @override
  String get chooseSelect => 'منتخب کریں';

  @override
  String get chooseRecommended => 'تجویز کردہ';

  @override
  String get chooseSkills => 'مہارتیں';

  @override
  String get myBookingsLoadFailed =>
      'آپ کی بکنگز لوڈ نہیں ہو سکیں۔ دوبارہ کوشش کریں۔';

  @override
  String get myBookingsTitle => 'میری بکنگز';

  @override
  String get myBookingsEmptyTitle => 'ابھی کوئی بکنگ نہیں';

  @override
  String get myBookingsNoResults => 'کوئی نتیجہ نہیں ملا';

  @override
  String get myBookingsAdjustFilters =>
      'اپنے فلٹر یا تلاش کا لفظ بدل کر دیکھیں';

  @override
  String get myBookingsBookFirst => 'شروع کرنے کے لیے اپنی پہلی سروس بک کریں';

  @override
  String get myBookingsRefreshFailed =>
      'ریفریش نہیں ہو سکا۔ دوبارہ کوشش کے لیے کھینچیں۔';

  @override
  String get myBookingsSomethingWrong => 'کچھ غلط ہو گیا';

  @override
  String cardTodayAt(String time) {
    return 'آج، $time';
  }

  @override
  String get cardGoesLiveBefore => 'وقت سے ایک گھنٹہ پہلے لائیو ہوگا';

  @override
  String get cardWorkersNotified => 'استادوں کو فوراً اطلاع دی جاتی ہے';

  @override
  String get cardSearchingWorkers => 'استاد تلاش کیے جا رہے ہیں...';

  @override
  String get cardNoWorkerYet => 'ابھی کوئی استاد نہیں';

  @override
  String get cardEstimatePrefix => 'تخمینہ';

  @override
  String get cardFindWorkers => 'استاد تلاش کریں';

  @override
  String get cardEdit => 'تبدیلی';

  @override
  String get filterTitle => 'بکنگز فلٹر کریں';

  @override
  String get filterReset => 'ری سیٹ';

  @override
  String get filterAll => 'سب';

  @override
  String get filterUrgentOption => '⚡ فوری';

  @override
  String get filterNormalOption => '🗓 عام';

  @override
  String get filterSortByDate => 'تاریخ کے حساب سے ترتیب';

  @override
  String get filterNewestFirst => 'نئی پہلے';

  @override
  String get filterOldestFirst => 'پرانی پہلے';

  @override
  String get filterApply => 'فلٹر لگائیں';

  @override
  String get searchBookingsHint => 'بکنگز، سروسز تلاش کریں...';

  @override
  String get cancelReasonTitle => 'بکنگ منسوخ کرنے کی وجہ';

  @override
  String get cancelReasonRequired => 'براہِ کرم وجہ بتائیں۔';

  @override
  String get cancelReasonSelect => 'وجہ منتخب کریں';

  @override
  String get cancelReasonWriteOwn => 'اپنی وجہ لکھیں';

  @override
  String get reviewSubmitFailed => 'ریویو جمع نہیں ہو سکا۔';

  @override
  String get reviewPromptBeforeContinuing =>
      'آگے بڑھنے سے پہلے اپنے استاد کو ریویو دیں۔';

  @override
  String get reviewHowWasWork => 'کام کیسا رہا؟';

  @override
  String get reviewCommentHint => 'تبصرہ لکھیں (اختیاری)...';

  @override
  String get reviewSubmit => 'ریویو جمع کریں';

  @override
  String get reviewLater => 'بعد میں';

  @override
  String get chatOpenFailed => 'چیٹ نہیں کھل سکی۔';

  @override
  String get mediaTapToPlay => 'چلانے کے لیے دبائیں';

  @override
  String get inspectionConfirm => 'تصدیق کریں';

  @override
  String trackSubtextCompleted(String name) {
    return '$name نے کام مکمل کر دیا';
  }

  @override
  String trackSubtextContinuingRepair(String name) {
    return '$name مرمت جاری رکھے ہوئے ہیں';
  }

  @override
  String trackSubtextOnTheWay(String name) {
    return '$name آپ کی لوکیشن کی طرف آ رہے ہیں';
  }

  @override
  String trackSubtextArrived(String name) {
    return '$name آپ کی لوکیشن پر پہنچ گئے ہیں';
  }

  @override
  String trackSubtextInspecting(String name) {
    return '$name مسئلہ دیکھ رہے ہیں';
  }

  @override
  String trackSubtextHiredForInspection(String name) {
    return '$name کو اس انسپیکشن کے لیے ہائر کیا گیا ہے';
  }

  @override
  String trackSubtextWorking(String name) {
    return '$name آپ کے کام پر لگے ہوئے ہیں';
  }

  @override
  String trackSubtextHiredForJob(String name) {
    return '$name کو اس کام کے لیے ہائر کیا گیا ہے';
  }

  @override
  String get urgentWithin1Hour => 'ایک گھنٹے کے اندر';

  @override
  String get urgentWithin2Hours => 'دو گھنٹوں کے اندر';

  @override
  String get urgentWithin4Hours => 'چار گھنٹوں کے اندر';

  @override
  String get inspectionFeePaid => 'انسپیکشن فیس ادا ہو گئی';

  @override
  String get inspectionFeeNotPaid => 'انسپیکشن فیس ادا نہیں ہوئی';

  @override
  String chooseWithinRadius(String km) {
    return '$km کلومیٹر کے اندر';
  }

  @override
  String chooseHireConfirmBodyFull(String name) {
    return 'کیا $name کو یہ کام دیں؟ اس کے بعد آپ دوسرا استاد منتخب نہیں کر سکیں گے۔';
  }

  @override
  String get trackHeadlineUstaadOnTheWay => 'استاد راستے میں';

  @override
  String get trackHeadlineUstaadArrived => 'استاد پہنچ گئے';

  @override
  String get trackHeadlineWorkInProgress => 'کام جاری ہے';

  @override
  String get trackHeadlineHired => 'ہائر ہو گئے ✓';

  @override
  String trackRatingOutOfFive(String rating) {
    return '$rating / 5.0';
  }

  @override
  String get discoveryLoadingBids => 'بولیاں لوڈ ہو رہی ہیں...';

  @override
  String get discoveryBidsLoadFailedShort => 'بولیاں لوڈ نہیں ہو سکیں';

  @override
  String bookingWorkersAvailableNearby(int count) {
    return 'قریب $count استاد دستیاب';
  }

  @override
  String bookingIdShort(String code) {
    return '#ER-$code';
  }

  @override
  String inspectionPartWithWarranty(
    String name,
    int quantity,
    String warranty,
  ) {
    return '$name x$quantity · $warranty';
  }

  @override
  String discoveryPendingBidsSorted(int count) {
    return '$count زیرِ التوا بولیاں · قیمت کے حساب سے ترتیب';
  }

  @override
  String get workerOffline => 'آف لائن';

  @override
  String get workerOnline => 'آن لائن';

  @override
  String get workerBusy => 'مصروف';

  @override
  String get workerOfflineHelper => 'آپ کلائنٹس کو نظر نہیں آ رہے';

  @override
  String get workerOnlineHelper =>
      'آپ کے قریب موجود کلائنٹس آپ کو دیکھ سکتے ہیں';

  @override
  String get workerBusyHelper => 'آپ اس وقت ایک کام پر مصروف ہیں';

  @override
  String get workerStatusOnTheWay => 'راستے میں';

  @override
  String get workerActionOnMyWay => 'میں روانہ ہوں';

  @override
  String get workerActionArrived => 'پہنچ گیا';

  @override
  String get workerActionStartJob => 'کام شروع کریں';

  @override
  String get workerActionCompleteJob => 'کام مکمل کریں';

  @override
  String get workerActionStartInspection => 'انسپیکشن شروع کریں';

  @override
  String get workerActionStartWork => 'کام شروع کریں';

  @override
  String get workerActionFillReport => 'انسپیکشن رپورٹ بھریں';

  @override
  String get workerActionWaitingForClient => 'کلائنٹ کے فیصلے کا انتظار';

  @override
  String get workerSuccessOnTheWay =>
      'آپ روانہ ہیں — کلائنٹ کو اطلاع دے دی گئی۔';

  @override
  String get workerSuccessArrived => 'پہنچنے کا نشان لگا دیا گیا۔';

  @override
  String get workerSuccessJobStarted => 'کام شروع ہو گیا۔';

  @override
  String get workerSuccessJobCompleted => 'کام مکمل شدہ نشان زد ہو گیا۔';

  @override
  String get workerSuccessInspectionStarted => 'انسپیکشن شروع ہو گئی۔';

  @override
  String get workerSuccessWorkStarted => 'کام شروع ہو گیا۔';

  @override
  String get workerSkillNotSelected => 'مہارت منتخب نہیں کی گئی';

  @override
  String get workerLocating => 'لوکیشن معلوم کی جا رہی ہے…';

  @override
  String get workerTapToRetry => 'دوبارہ کوشش کے لیے دبائیں';

  @override
  String get workerTapForLocation => 'لوکیشن کے لیے دبائیں';

  @override
  String get workerOnActiveJob => 'کام جاری ہے';

  @override
  String get workerConnecting => 'کنیکٹ ہو رہا ہے...';

  @override
  String get workerGoingOffline => 'آف لائن ہو رہے ہیں...';

  @override
  String get workerGoOffline => 'آف لائن ہو جائیں';

  @override
  String get workerGoOnline => 'آن لائن ہو جائیں';

  @override
  String get workerTodaysEarnings => 'آج کی کمائی';

  @override
  String get workerRating => 'ریٹنگ';

  @override
  String get workerActive => 'فعال';

  @override
  String get workerGoOfflineConfirmTitle => 'آف لائن ہو جائیں؟';

  @override
  String get workerGoOfflineConfirmBody =>
      'آپ قریبی کلائنٹس کو نظر آنا بند ہو جائیں گے۔';

  @override
  String get workerGoOfflineConfirmYes => 'ہاں، آف لائن کریں';

  @override
  String get workerFindNewWork => 'نیا کام ڈھونڈیں';

  @override
  String get workerViewNewJobs => 'نئے کام دیکھیں';

  @override
  String get workerActiveJobCaps => 'جاری کام';

  @override
  String get workerMap => 'نقشہ';

  @override
  String get workerViewDetails => 'تفصیلات دیکھیں ←';

  @override
  String get workerNoActiveJob => 'اس وقت کوئی کام جاری نہیں';

  @override
  String get workerStayOnlineHint => 'قریبی کام تلاش کرنے کے لیے آن لائن رہیں۔';

  @override
  String get workerReady => 'تیار';

  @override
  String get workerPerformance => 'کارکردگی';

  @override
  String get workerJobsDone => 'مکمل کام';

  @override
  String get workerCancelRate => 'منسوخی کی شرح';

  @override
  String workerPercentValue(String value) {
    return '$value%';
  }

  @override
  String get workerResponse => 'جواب';

  @override
  String get workerReviews => 'ریویوز';

  @override
  String get workerSeeAll => 'سب دیکھیں ←';

  @override
  String get workerNoReviewsYet => 'ابھی کوئی ریویو نہیں';

  @override
  String get workerReviewsAppearHint =>
      'آپ کے مکمل کاموں کے بعد کلائنٹس کے ریویوز یہاں نظر آئیں گے۔';

  @override
  String get workerSelectMainSkill => 'اپنی بنیادی مہارت منتخب کریں';

  @override
  String get workerSelectMainSkillHint =>
      'کام ملنا شروع کرنے کے لیے اپنی بنیادی مہارت منتخب کریں';

  @override
  String workerCategoriesLoadFailed(String error) {
    return 'کیٹیگریز لوڈ نہیں ہو سکیں: $error';
  }

  @override
  String get workerSkillsSaveFailed =>
      'مہارتیں محفوظ نہیں ہو سکیں۔ دوبارہ کوشش کریں۔';

  @override
  String get workerSaveAndGoOnline => 'محفوظ کریں اور آن لائن ہوں';

  @override
  String get workerDashboardLoadFailed => 'ڈیش بورڈ لوڈ نہیں ہو سکا';

  @override
  String get workerNewJobsTitle => 'نئے کام';

  @override
  String get workerNewJobsSubtitle => 'آپ کی مہارت کے مطابق کام';

  @override
  String get workerCompleteProfileForNewJobs =>
      'اپنی پروفائل مکمل کریں۔ منظوری کے بعد آپ کو نئے کام نظر آنے لگیں گے۔';

  @override
  String get workerNewJobsLoadFailed => 'نئے کام لوڈ نہیں ہو سکے۔';

  @override
  String workerOfferCount(int count) {
    return '$count آفرز';
  }

  @override
  String get workerDirectHireNote =>
      'کلائنٹ آپ کو براہِ راست ہائر کر سکتا ہے۔ آفر بھیجنے کی ضرورت نہیں۔';

  @override
  String get workerListedJob => 'درج شدہ کام';

  @override
  String get workerOfferSent => 'آفر بھیج دی';

  @override
  String get workerNoNewJobs => 'اس وقت کوئی نیا کام نہیں';

  @override
  String get workerNoNewJobsHint =>
      'آپ کی مہارت کے مطابق نئے کام یہاں نظر آئیں گے۔ ریفریش کرنے کے لیے نیچے کھینچیں۔';

  @override
  String get workerCompleteProfileForJobs =>
      'اپنی پروفائل مکمل کریں۔ منظوری کے بعد آپ اپنے کام سنبھال سکیں گے۔';

  @override
  String get workerJobsLoadFailed => 'کام لوڈ نہیں ہو سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get workerClientCancelledBooking => 'کلائنٹ نے یہ بکنگ منسوخ کر دی';

  @override
  String get workerOnlyInspectionCompleted => 'صرف انسپیکشن مکمل ہوئی';

  @override
  String get workerComplete => 'مکمل کریں';

  @override
  String get workerCompleting => 'مکمل کیا جا رہا ہے...';

  @override
  String get workerMarkCompletedTitle => 'مکمل شدہ نشان زد کریں؟';

  @override
  String get workerMarkCompletedBody =>
      'اس سے کام بند ہو جائے گا اور کلائنٹ کو اطلاع مل جائے گی۔';

  @override
  String get workerNoActiveJobs => 'کوئی جاری کام نہیں';

  @override
  String get workerNoCompletedJobs => 'ابھی کوئی مکمل کام نہیں';

  @override
  String get workerNoCancelledJobs => 'کوئی منسوخ کام نہیں';

  @override
  String get workerNoJobsAssigned => 'ابھی کوئی کام نہیں ملا';

  @override
  String get workerNewRequestsHere => 'نئی درخواستیں یہاں نظر آئیں گی';

  @override
  String get workerCompletedJobsHere => 'مکمل کام یہاں نظر آئیں گے';

  @override
  String get workerCancelledJobsHere => 'منسوخ کام یہاں نظر آئیں گے';

  @override
  String get workerAcceptToGetStarted => 'شروع کرنے کے لیے کوئی بکنگ قبول کریں';

  @override
  String get workerFilterCancelled => 'منسوخ';

  @override
  String get workerFilterAllWork => 'سارا کام';

  @override
  String get workerFilterMyOffers => 'میری آفرز';

  @override
  String get workerFilterNoOfferSent => 'آفر نہیں بھیجی';

  @override
  String get bidPlaceABid => 'بولی لگائیں';

  @override
  String get bidChatWithClient => 'کلائنٹ سے چیٹ کریں';

  @override
  String get bidLiveBids => 'لائیو بولیاں';

  @override
  String get bidAreaNotAvailable => 'علاقہ دستیاب نہیں';

  @override
  String get bidExactAddressAfterAccept =>
      'کلائنٹ کے آپ کی بولی قبول کرنے پر مکمل پتہ بھیج دیا جاتا ہے۔';

  @override
  String get bidStatusAccepted => 'منظور';

  @override
  String get bidStatusRejected => 'مسترد';

  @override
  String get bidStatusPending => 'زیرِ التوا';

  @override
  String get bidYourCurrentBid => 'آپ کی موجودہ بولی';

  @override
  String get bidSubmit => 'بولی بھیجیں';

  @override
  String get bidUpdate => 'بولی اپ ڈیٹ کریں';

  @override
  String get bidPlaceYourBid => 'اپنی بولی لگائیں';

  @override
  String get bidUpdateYourBid => 'اپنی بولی اپ ڈیٹ کریں';

  @override
  String bidCanUpdateIn(String seconds) {
    return 'آپ $seconds سیکنڈ بعد بولی اپ ڈیٹ کر سکتے ہیں۔';
  }

  @override
  String get bidCanUpdateNow => 'آپ ابھی اپنی بولی اپ ڈیٹ کر سکتے ہیں۔';

  @override
  String get bidAmountLabel => 'بولی کی رقم (PKR) *';

  @override
  String get bidAmountHint => 'مثلاً 2500';

  @override
  String bidLabelWithCountdown(String label, String seconds) {
    return '$label (${seconds}s)';
  }

  @override
  String bidJobCount(int count) {
    return '$count کام';
  }

  @override
  String get bidBeFirstToBid => 'اس کام پر سب سے پہلے بولی لگائیں';

  @override
  String get earningBidding => 'بولی';

  @override
  String get earningHistoryTitle => 'کمائی کی تفصیل';

  @override
  String get earningNoneYet => 'ابھی کوئی کمائی نہیں';

  @override
  String get earningNoneHint =>
      'مکمل کام یہاں آپ کی روزانہ کمائی کے ساتھ نظر آئیں گے۔';

  @override
  String get reviewsMyReviews => 'میرے ریویوز';

  @override
  String reviewsCount(int count) {
    return '$count ریویوز';
  }

  @override
  String get reviewsSubtitle => 'آپ کے مکمل کیے گئے کاموں پر کلائنٹس کے ریویوز';

  @override
  String get reviewsAvg => 'اوسط';

  @override
  String get reviewsMax => 'زیادہ سے زیادہ';

  @override
  String get reviewsMin => 'کم سے کم';

  @override
  String get reviewsEmptyHint =>
      'جب کلائنٹس آپ کے مکمل کاموں پر ریویو دیں گے،\nوہ یہاں نظر آئیں گے۔';

  @override
  String reviewsRatingSummary(String rating, int count) {
    return '$rating · $count ریویوز';
  }

  @override
  String reviewsHighestLowest(String max, String min) {
    return 'زیادہ سے زیادہ: $max ★  ·  کم سے کم: $min ★';
  }

  @override
  String get inspFormChooseFromGallery => 'گیلری سے منتخب کریں';

  @override
  String get inspFormSubmitted =>
      'رپورٹ جمع ہو گئی۔ کلائنٹ کے فیصلے کا انتظار ہے۔';

  @override
  String get inspFormSubmitFailed => 'رپورٹ جمع نہیں ہو سکی۔';

  @override
  String get inspFormWhatWasIssue => 'مسئلہ کیا نکلا؟';

  @override
  String get inspFormWhatWasIssueRequired => 'مسئلہ کیا نکلا؟ *';

  @override
  String get inspFormRecommendedRepair => 'تجویز کردہ مرمت';

  @override
  String get inspFormRecommendedRepairRequired => 'تجویز کردہ مرمت *';

  @override
  String get inspFormWhatWorkNeeded => 'کیا کام کرنا ہوگا';

  @override
  String get inspFormWriteOrRecord =>
      'براہِ کرم رپورٹ لکھیں یا وائس نوٹ ریکارڈ کریں۔';

  @override
  String get inspFormPartsRequired => 'پرزے درکار ہیں؟';

  @override
  String get inspFormAddPart => 'پرزہ شامل کریں';

  @override
  String get inspFormUstaadNotes => 'استاد کے نوٹس';

  @override
  String get inspFormSubmitReport => 'رپورٹ جمع کریں';

  @override
  String inspFormIssuePhotos(int max) {
    return 'مسئلے کی تصاویر — اختیاری، زیادہ سے زیادہ $max';
  }

  @override
  String get inspFormVoiceNote => 'وائس نوٹ';

  @override
  String get inspFormVoiceNoteHint =>
      'اگر لکھنا مشکل ہو تو وائس نوٹ ریکارڈ کر دیں۔';

  @override
  String inspFormRecording(String duration) {
    return 'ریکارڈنگ  $duration';
  }

  @override
  String get inspFormStop => 'روکیں';

  @override
  String get inspFormStartRecording => 'ریکارڈنگ شروع کریں';

  @override
  String get inspFormPartNameHint => 'مثلاً استعمال ہونے والا پرزہ یا سامان';

  @override
  String get inspFormWarrantyHint => 'مثلاً 7 دن';

  @override
  String get inspFormRemovePart => 'پرزہ ہٹائیں';

  @override
  String get inspFormTotalAmount => 'کام کی پوری رقم';

  @override
  String get inspFormFeeWaivedNote =>
      'اگر کسٹمر مرمت جاری رکھواتا ہے تو انسپیکشن فیس نہیں لی جائے گی۔';

  @override
  String get inspHintElectrical => 'مثلاً سوئچ خراب ہے، تار شارٹ ہے...';

  @override
  String get inspHintPlumbing => 'مثلاً پائپ لیک ہے، ڈرین بلاک ہے...';

  @override
  String get inspHintAc => 'مثلاً اے سی ٹھنڈا نہیں کر رہا، گیس لیک ہے...';

  @override
  String get inspHintCarpentry =>
      'مثلاً دروازہ ٹھیک سے بند نہیں ہوتا، قبضہ ٹوٹ گیا...';

  @override
  String get workerCompleteProfile => 'پروفائل مکمل کریں';

  @override
  String get workerApprovalRequired =>
      'کام ملنے سے پہلے پروفائل کی منظوری ضروری ہے۔';

  @override
  String get workerCompleteProfileDetails =>
      'اپنی پروفائل کی تفصیلات مکمل کریں۔';

  @override
  String get workerCompleteProfileWhy =>
      'پروفائل مکمل ہونے کے بعد ہی آپ کاموں کے لیے اپلائی یا ہائر ہو سکیں گے۔';

  @override
  String earningJobsCompleted(int count) {
    return '$count کام مکمل';
  }

  @override
  String get bookingStatusLive => 'جاری';

  @override
  String get bookingStatusAssigned => 'مقرر';

  @override
  String get bookingStatusCompleted => 'مکمل';

  @override
  String get bookingStatusExpired => 'ختم';

  @override
  String get jobStatusEnRoute => 'راستے میں';

  @override
  String get jobStatusInProgress => 'کام جاری';

  @override
  String get l10nFallbackProbe => 'English fallback works';

  @override
  String get workerJobDetailsTitle => 'کام کی تفصیل';

  @override
  String get workerJobLoadFailed => 'کام لوڈ نہیں ہو سکا۔';

  @override
  String get workerStandardDirectHireNote =>
      'یہ ایک اسٹینڈرڈ کام ہے۔ کلائنٹ آپ کو براہِ راست ہائر کر سکتا ہے — آفر بھیجنے کی ضرورت نہیں۔';

  @override
  String get workerBidNow => 'ابھی بولی لگائیں';

  @override
  String get workerReportSubmittedWaiting =>
      'رپورٹ بھیج دی گئی۔ کلائنٹ کے کوٹ قبول کرنے یا انسپیکشن کے بعد کام بند کرنے کا انتظار ہے۔';

  @override
  String get workerClientSection => 'کلائنٹ';

  @override
  String get workerPostedBy => 'کام دینے والا';

  @override
  String get workerCategoryLabel => 'کیٹیگری';

  @override
  String get workerTitleLabel => 'عنوان';

  @override
  String get workerTimeSlotLabel => 'وقت کا سلاٹ';

  @override
  String get workerTimelineSection => 'ٹائم لائن';

  @override
  String get workerTimelineScheduled => 'طے شدہ';

  @override
  String get workerTimelineStarted => 'شروع ہوا';

  @override
  String get workerEstimatedLabel => 'تخمینہ';

  @override
  String get workerFeeStatusLabel => 'اسٹیٹس';

  @override
  String get workerCancelJob => 'کام منسوخ کریں';

  @override
  String get workerCancelJobTitle => 'یہ کام منسوخ کریں؟';

  @override
  String get workerCancelJobBody =>
      'براہِ کرم کلائنٹ کو بتائیں کہ آپ کیوں منسوخ کر رہے ہیں۔';

  @override
  String get workerCancelOwnReasonHint => 'اپنی وجہ لکھیں (لازمی)';

  @override
  String get workerKeepJob => 'کام رکھیں';

  @override
  String get workerYesCancel => 'جی ہاں، منسوخ کریں';

  @override
  String get workerCancelReasonEmergency => 'ایمرجنسی آ گئی';

  @override
  String get workerCancelReasonTooFar => 'جگہ بہت دور ہے';

  @override
  String get workerCancelReasonNoTools => 'ضروری اوزار یا پرزے دستیاب نہیں';

  @override
  String get workerCancelReasonSchedule => 'وقت یا شیڈول کا مسئلہ';

  @override
  String get workerCancelReasonCustomer => 'کسٹمر یا جگہ سے متعلق مسئلہ';

  @override
  String get workerCancelReasonOther => 'دیگر';

  @override
  String get workerAttachmentsVideos => 'ویڈیوز';

  @override
  String get workerAttachmentsVoiceNotes => 'وائس نوٹس';

  @override
  String get workerStatusHistory => 'اسٹیٹس کی تاریخ';

  @override
  String get workerMarkAsCompleted => 'مکمل شدہ نشان زد کریں';

  @override
  String get workerClientReview => 'کلائنٹ کا ریویو';

  @override
  String workerReviewRatingOutOfFive(int rating) {
    return '$rating/5';
  }

  @override
  String workerApproximateArea(String city) {
    return 'تخمینی علاقہ: $city';
  }

  @override
  String get workerApproximateAreaUnavailable => 'تخمینی علاقہ دستیاب نہیں';

  @override
  String workerDistanceLabel(String distance) {
    return 'فاصلہ: $distance';
  }

  @override
  String get workerExactAddressAfterHire =>
      'اس کام کے لیے ہائر ہونے کے بعد ہی صحیح پتہ اور نقشہ نظر آئے گا۔';

  @override
  String get workerRoadRouteNotConfigured =>
      'روڈ روٹ ابھی سیٹ نہیں ہوا۔ راستے کے لیے گوگل میپس کھولا جا رہا ہے۔';

  @override
  String get workerLocationPermissionDenied => 'لوکیشن کی اجازت نہیں دی گئی۔';

  @override
  String get workerDirectionsLocationFailed =>
      'راستے کے لیے آپ کی لوکیشن نہیں مل سکی۔';

  @override
  String get workerArrivedAtJobLocation => 'آپ کام کی جگہ پہنچ گئے ہیں۔';

  @override
  String get workerYourLocation => 'آپ کی لوکیشن';

  @override
  String get workerCityLabel => 'شہر';

  @override
  String get workerClientAddress => 'کلائنٹ کا پتہ';

  @override
  String get workerPinnedJobLocation => 'نقشے پر لگی کام کی جگہ';

  @override
  String get workerPinnedOnMap => 'نقشے پر لگا ہوا';

  @override
  String get workerGettingLocation => 'لوکیشن لی جا رہی ہے...';

  @override
  String get workerDirections => 'راستہ';

  @override
  String get workerOpenInMaps => 'میپس میں کھولیں';

  @override
  String get workerDirectionsActive => 'راستہ چل رہا ہے';

  @override
  String get workerUploadFailed => 'اپ لوڈ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get workerCompleteHighlightedFields =>
      'براہِ کرم نیچے نشان زد خانے مکمل کریں۔';

  @override
  String get workerProfileSaveFailed =>
      'پروفائل محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get workerProfileSubmitted => 'پروفائل منظوری کے لیے بھیج دی گئی۔';

  @override
  String get workerCompleteAllRequired =>
      'بھیجنے سے پہلے تمام ضروری خانے مکمل کریں۔';

  @override
  String get workerProfileLoadFailed => 'پروفائل لوڈ نہیں ہو سکی۔';

  @override
  String get workerFullLegalName => 'مکمل قانونی نام';

  @override
  String get workerLegalNameHint => 'جیسا آپ کے شناختی کارڈ پر لکھا ہے';

  @override
  String get workerLegalNameRequired => 'مکمل قانونی نام ضروری ہے۔';

  @override
  String get workerCnicNumber => 'شناختی کارڈ نمبر';

  @override
  String get workerCnicInvalid => 'شناختی کارڈ اس طرح لکھیں: 12345-1234567-1';

  @override
  String get workerMainSkill => 'بنیادی ہنر';

  @override
  String get workerMainSkillNotSelected => 'منتخب نہیں کیا گیا';

  @override
  String get workerChangeSkill => 'تبدیل کریں';

  @override
  String get workerMainSkillRequired => 'براہِ کرم اپنا بنیادی ہنر منتخب کریں۔';

  @override
  String get workerExperienceYears => 'تجربہ (سالوں میں)';

  @override
  String get workerExperienceHint => 'مثلاً 3';

  @override
  String get workerExperienceInvalid =>
      'سالوں کی درست تعداد لکھیں (0 یا اس سے زیادہ)۔';

  @override
  String get workerResidentialAddress => 'رہائشی پتہ';

  @override
  String get workerResidentialAddressHint => 'مکان نمبر، گلی، علاقہ، شہر';

  @override
  String get workerResidentialAddressRequired => 'رہائشی پتہ ضروری ہے۔';

  @override
  String get workerIdentityDocuments => 'شناختی دستاویزات';

  @override
  String get workerCnicFront => 'شناختی کارڈ کا اگلا رخ';

  @override
  String get workerCnicBack => 'شناختی کارڈ کا پچھلا رخ';

  @override
  String get workerLiveSelfie => 'لائیو سیلفی';

  @override
  String get workerDocumentRequired => 'ضروری ہے';

  @override
  String get workerAgreements => 'معاہدے';

  @override
  String get workerConfirmLegalName =>
      'میں تصدیق کرتا ہوں کہ میرا قانونی نام میرے شناختی کارڈ کے مطابق ہے۔';

  @override
  String get workerViewAgreement => 'معاہدہ دیکھیں';

  @override
  String get workerConfirmationRequired => 'یہ تصدیق ضروری ہے۔';

  @override
  String get workerSubmitForApproval => 'منظوری کے لیے بھیجیں';

  @override
  String workerAgreementVersion(String version) {
    return 'ورژن $version';
  }

  @override
  String get workerOnboardingSubmitted => 'جائزے کے لیے بھیج دی گئی';

  @override
  String get workerOnboardingChangesRequired => 'تبدیلیاں درکار ہیں';

  @override
  String get workerOnboardingApproved => 'منظور شدہ';

  @override
  String get workerOnboardingDraft => 'مسودہ';

  @override
  String get workerRoleBadge => 'استاد';

  @override
  String workerMainSkillWithName(String skill) {
    return 'بنیادی ہنر: $skill';
  }

  @override
  String get workerNoMainSkillYet => 'ابھی کوئی بنیادی ہنر منتخب نہیں کیا گیا';

  @override
  String get workerProfileApproval => 'پروفائل کی منظوری';

  @override
  String get inspHintFallback => 'مثلاً بتائیں آپ کو کیا ملا';

  @override
  String get bidAmountRequired => 'براہِ کرم بولی کی رقم لکھیں۔';

  @override
  String get bidAmountRange =>
      'بولی کی رقم 100 سے 500,000 کے درمیان ہونی چاہیے۔';

  @override
  String get bidSubmitted => 'بولی بھیج دی گئی!';

  @override
  String get bidSubmitFailed => 'بولی نہیں بھیجی جا سکی۔';

  @override
  String get workerViewJobDetails => 'تفصیل دیکھیں';

  @override
  String get workerSendOffer => 'آفر بھیجیں';

  @override
  String get workerChangeOffer => 'آفر بدلیں';

  @override
  String get workerOnboardingSubmittedBody =>
      'آپ کی پروفائل ایڈمن کے جائزے میں ہے۔';

  @override
  String get workerOnboardingChangesRequiredBody =>
      'آپ کی پروفائل میں تبدیلی درکار ہے — تفصیل دیکھیں۔';

  @override
  String get workerOnboardingRejectedBody =>
      'آپ کی پروفائل مسترد ہو گئی — وجہ دیکھیں۔';

  @override
  String get workerProfileIncomplete => 'پروفائل نامکمل';

  @override
  String get inspFormLabourCostRequired => 'مزدوری کی لاگت *';

  @override
  String get inspFormNotesOptional => 'نوٹس (اختیاری)';

  @override
  String get inspFormPartName => 'پرزے کا نام';

  @override
  String get inspFormQty => 'تعداد';

  @override
  String get inspFormUnitPrice => 'فی عدد قیمت';

  @override
  String get inspFormWarrantyOptional => 'وارنٹی / گارنٹی (اختیاری)';

  @override
  String get inspFormPartsTotal => 'پرزوں کی کل رقم';

  @override
  String get inspFormLabour => 'مزدوری';

  @override
  String get inspFormMicPermanentlyDenied =>
      'مائیکروفون کی اجازت مستقل بند ہے۔ اسے سیٹنگز میں آن کریں۔';

  @override
  String get inspFormMicDenied => 'مائیکروفون کی اجازت نہیں دی گئی۔';

  @override
  String get errorTimeout => 'کنکشن کا وقت ختم ہو گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get errorRequestCancelled => 'درخواست منسوخ کر دی گئی۔';

  @override
  String get errorInvalidRequest =>
      'کچھ تفصیلات درست نہیں ہیں۔ انہیں دیکھ کر دوبارہ کوشش کریں۔';

  @override
  String get errorSessionExpired =>
      'آپ کا سیشن ختم ہو گیا ہے۔ دوبارہ لاگ اِن کریں۔';

  @override
  String get errorForbidden => 'آپ کو اس کام کی اجازت نہیں ہے۔';

  @override
  String get errorNotFound => 'یہ اب دستیاب نہیں ہے۔';

  @override
  String get errorConflict =>
      'یہ پہلے ہی اپ ڈیٹ ہو چکا ہے۔ ریفریش کر کے دوبارہ کوشش کریں۔';

  @override
  String get errorTooManyRequests =>
      'بہت زیادہ کوششیں ہو گئی ہیں۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get errorServer => 'سرور میں مسئلہ ہے۔ کچھ دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get errorSmsSendFailed =>
      'ایس ایم ایس نہیں بھیجا جا سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get errorInspectorBusy =>
      'معائنہ کرنے والا استاد ابھی دوسرے کام میں مصروف ہے۔ نیچے سے کوئی اور استاد منتخب کریں۔';

  @override
  String get errorPhoneIsWorker =>
      'یہ موبائل نمبر پہلے سے استاد اکاؤنٹ کے ساتھ رجسٹرڈ ہے۔';

  @override
  String get errorPhoneIsClient =>
      'یہ موبائل نمبر پہلے سے کلائنٹ اکاؤنٹ کے ساتھ رجسٹرڈ ہے۔';

  @override
  String get errorUnknown => 'کچھ گڑبڑ ہو گئی۔ دوبارہ کوشش کریں۔';

  @override
  String get authForgotPasswordTitle => 'پاس ورڈ بھول\nگئے؟';

  @override
  String get authSetNewPasswordTitle => 'نیا پاس ورڈ\nسیٹ کریں';

  @override
  String get authEnterCodeSentToNumber =>
      'اپنے نمبر پر بھیجا گیا کوڈ درج کریں۔';

  @override
  String get authForgotPasswordClientOnly =>
      'صرف کلائنٹ اکاؤنٹ کے لیے۔ رجسٹرڈ نمبر پر کوڈ بھیجا جائے گا۔';

  @override
  String get authForgotPasswordWorkerOnly =>
      'صرف استاد اکاؤنٹ کے لیے۔ رجسٹرڈ نمبر پر کوڈ بھیجا جائے گا۔';

  @override
  String get authErrorCodeSendFailed => 'کوڈ نہیں بھیجا جا سکا۔';

  @override
  String get authErrorPasswordChangeFailed => 'پاس ورڈ تبدیل نہیں ہو سکا۔';

  @override
  String get authErrorLoginFailed => 'لاگ اِن نہیں ہو سکا۔';

  @override
  String get authErrorRegisterFailed => 'اکاؤنٹ نہیں بن سکا۔';

  @override
  String get authLoginWithOtp => 'او ٹی پی سے لاگ اِن کریں';

  @override
  String get authHintExampleFullName => 'محمد علی خان';

  @override
  String get notificationsBannerFallbackTitle => 'اطلاع';

  @override
  String get legalEnglishOnlyNotice =>
      'یہ قانونی دستاویز فی الحال صرف انگریزی میں دستیاب ہے۔';

  @override
  String myBookingsTotalCount(int count) {
    return 'کل $count';
  }

  @override
  String get workerBidJobFallbackTitle => 'کام';

  @override
  String get navHome => 'ہوم';

  @override
  String get navBookings => 'بکنگز';

  @override
  String get navChats => 'چیٹس';

  @override
  String get inspectionRowIssueFound => 'جو مسئلہ ملا';

  @override
  String get inspectionRowNotes => 'نوٹس';

  @override
  String get inspectionBadgeAwaitingDecision =>
      'رپورٹ جمع ہو گئی — فیصلے کا انتظار';

  @override
  String get inspectionBadgeQuoteAccepted => 'قیمت منظور — مرمت جاری ہے';

  @override
  String get inspectionBadgeFindingAnother =>
      'دوسرا استاد تلاش کیا جا رہا ہے — بولی کے لیے کھلا';

  @override
  String inspStripClosedFeeOnlyWithAmount(String fee) {
    return 'معائنے کے بعد بند — کلائنٹ صرف معائنہ فیس دے گا: $fee';
  }

  @override
  String get inspStripClosedFeeOnly =>
      'معائنے کے بعد بند — کلائنٹ صرف معائنہ فیس دے گا۔';

  @override
  String get inspStripRepairCompletedFeeWaived =>
      'مرمت مکمل — معائنہ فیس معاف۔';

  @override
  String get inspStripQuoteAcceptedFeeWaived =>
      'قیمت منظور — معائنہ فیس معاف۔ مرمت جاری ہے۔';

  @override
  String get inspStripReportSubmitted =>
      'معائنہ رپورٹ جمع ہو گئی — مرمت جاری رکھنے کے لیے قیمت دیکھیں یا معائنے کے بعد بند کریں۔';

  @override
  String get inspStripUstaadHired => 'استاد ہائر ہو گیا';

  @override
  String get inspStripBookedChooseUstaad =>
      'معائنہ بک ہو گیا — استاد منتخب کریں';

  @override
  String chooseChipCancelRate(int rate) {
    return '$rate% منسوخی';
  }

  @override
  String get locationCurrentFailed => 'موجودہ لوکیشن حاصل نہیں ہو سکی۔';

  @override
  String get locationResolveFailed => 'منتخب لوکیشن معلوم نہیں ہو سکی۔';

  @override
  String get locationOutsideKarachi =>
      'یہ لوکیشن کراچی کے سروس ایریا سے باہر ہے۔';

  @override
  String postJobVideoTooLong(int seconds) {
    return 'ویڈیو $seconds سیکنڈ یا اس سے کم ہونی چاہیے۔';
  }

  @override
  String get postJobLocationRetrieveFailed =>
      'لوکیشن حاصل نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get postJobSelectOption => 'جاری رکھنے کے لیے ایک آپشن منتخب کریں۔';

  @override
  String get postJobDescribeIssue => 'براہ کرم بتائیں کہ کیا ٹھیک کروانا ہے۔';

  @override
  String get postJobSelectStandardService =>
      'کم از کم ایک اسٹینڈرڈ سروس منتخب کریں۔';

  @override
  String get postJobSelectArrivalWindow => 'براہ کرم آمد کا وقت منتخب کریں۔';

  @override
  String get postJobSelectUrgencyWindow => 'براہ کرم فوری وقت منتخب کریں۔';

  @override
  String get postJobEnterAddress => 'اپنا پتہ درج کریں۔';

  @override
  String get postJobAddAddressToContinue =>
      'جاری رکھنے کے لیے اپنا سروس پتہ شامل کریں۔';

  @override
  String get postJobNearbyNotifiedNow =>
      'قریبی استادوں کو فوراً اطلاع دی جاتی ہے۔';

  @override
  String get postJobInspectionNotAvailable =>
      'اس سروس کے لیے معائنہ دستیاب نہیں ہے۔';

  @override
  String get postJobInspectionHeroStep1 => 'استاد آ کر خود چیک کرے گا';

  @override
  String get postJobInspectionHeroStep2 =>
      'کام شروع کرنے سے پہلے ریٹ طے ہو جائے گا۔';

  @override
  String get postJobInspectionHeroStep3 =>
      'پسند آئے تو کام کروا لیں، ورنہ صرف معائنہ فیس دیں۔';

  @override
  String get postJobStandardTotalFinal =>
      'کل رقم حتمی ہے — کوئی بولی نہیں۔ اگلے مرحلے میں آپ استاد منتخب کریں گے۔';

  @override
  String get postJobHowInspectionStep1 => 'معائنہ فیس مقرر ہے۔';

  @override
  String get postJobHowInspectionStep2 =>
      'استاد آتا ہے، مسئلہ معلوم کرتا ہے، اور ایپ میں مرمت کی مقررہ قیمت دیتا ہے۔';

  @override
  String get postJobHowInspectionStep3 =>
      'اس کی قیمت قبول کر کے جاری رکھیں، یا دوسرے استادوں سے بولیاں لیں — آپ کی مرضی۔';

  @override
  String get cancelReasonNoLongerNeeded => 'اب سروس کی ضرورت نہیں';

  @override
  String get cancelReasonBookedByMistake => 'بکنگ غلطی سے ہو گئی';

  @override
  String get cancelReasonProblemSolved => 'مسئلہ خود حل ہو گیا';

  @override
  String get cancelReasonTimingNotSuitable => 'وقت یا تاریخ مناسب نہیں';

  @override
  String get cancelReasonPriceNotSuitable => 'قیمت یا بجٹ مناسب نہیں';

  @override
  String get cancelReasonCannotReachUstaad => 'استاد سے رابطہ نہیں ہو رہا';

  @override
  String get cancelReasonUstaadRunningLate => 'استاد بہت دیر کر رہا ہے';

  @override
  String get cancelReasonOther => 'دوسری وجہ';

  @override
  String get bookingAgreedPrice => 'طے شدہ قیمت';

  @override
  String get inspRepairHintElectrical =>
      'مثلاً ایم سی بی بدلیں اور ساکٹ کی وائرنگ دوبارہ کریں';

  @override
  String get inspRepairHintPlumbing =>
      'مثلاً لیک ہوتا پائپ بدلیں اور نیا والو لگائیں';

  @override
  String get inspRepairHintAc => 'مثلاً گیس بھروائیں اور کیپیسیٹر بدلیں';

  @override
  String get inspRepairHintCarpentry =>
      'مثلاً قبضے بدلیں اور دروازے کا فریم سیدھا کریں';

  @override
  String get inspRepairHintPainting =>
      'مثلاً پٹی اور پرائمر لگائیں، پھر ایملشن کے دو کوٹ';

  @override
  String get inspRepairHintFallback =>
      'مثلاً اسے ٹھیک کرنے کے لیے کیا کام درکار ہے';

  @override
  String get inspPartHintElectrical => 'مثلاً ایم سی بی، سوئچ، ساکٹ';

  @override
  String get inspPartHintPlumbing => 'مثلاً پائپ، والو، ٹونٹی';

  @override
  String get inspPartHintAc => 'مثلاً گیس ری فل، کیپیسیٹر، کمپریسر';

  @override
  String get inspPartHintCarpentry => 'مثلاً قبضے، پلائی ووڈ، دروازے کا فریم';

  @override
  String get inspPartHintPainting => 'مثلاً پرائمر، پٹی، ایملشن';

  @override
  String get inspHintPainting => 'مثلاً پینٹ اکھڑ رہا ہے، دیوار پر سیلن...';

  @override
  String get agreementViewerTitle => 'معاہدہ';

  @override
  String get agreementLoadFailed =>
      'معاہدہ لوڈ نہیں ہو سکا۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get agreementUnavailableForTrade =>
      'آپ کے منتخب کام کے لیے ابھی کوئی منظور شدہ معاہدہ دستیاب نہیں۔ براہِ کرم HandyGo سپورٹ سے رابطہ کریں۔';

  @override
  String agreementLanguageChip(String language) {
    return 'معاہدے کی زبان: $language';
  }

  @override
  String agreementTradeChip(String trade) {
    return 'کام: $trade';
  }

  @override
  String get agreementLanguageNotice =>
      'یہ منظور شدہ قانونی معاہدہ فی الحال صرف رومن اردو میں دستیاب ہے۔';

  @override
  String get agreementLanguageRomanUrdu => 'رومن اردو';

  @override
  String get agreementLanguageEnglish => 'انگریزی';

  @override
  String get agreementLanguageUrdu => 'اردو';

  @override
  String get agreementAcceptCheckbox =>
      'میں نے یہ معاہدہ پڑھ لیا ہے اور اسے قبول کرتا ہوں۔';

  @override
  String get agreementViewBeforeAccepting =>
      'قبول کرنے سے پہلے معاہدہ کھول کر پڑھیں۔';

  @override
  String get agreementAcceptRequired => 'یہ معاہدہ قبول کرنا لازمی ہے۔';

  @override
  String get agreementTradeChangedReopen =>
      'آپ کا مرکزی کام تبدیل ہو گیا ہے۔ کام سے متعلق معاہدہ دوبارہ کھول کر قبول کریں۔';

  @override
  String get agreementsLoadFailed => 'معاہدے لوڈ نہیں ہو سکے۔';

  @override
  String get agreementsAllThreeRequired =>
      'جمع کرانے سے پہلے تینوں معاہدے کھول کر قبول کریں۔';

  @override
  String get workerFatherName => 'والد کا نام';

  @override
  String get workerFatherNameRequired => 'والد کا نام لازمی ہے۔';

  @override
  String get workerDateOfBirth => 'تاریخِ پیدائش';

  @override
  String get workerDateOfBirthHint => 'اپنی تاریخِ پیدائش منتخب کریں';

  @override
  String get workerDateOfBirthRequired => 'تاریخِ پیدائش لازمی ہے۔';

  @override
  String get workerEmergencyContact => 'ہنگامی رابطہ (اختیاری)';

  @override
  String get workerEmergencyContactHint => 'نام اور فون نمبر';

  @override
  String get workerAcceptedAgreementsTitle => 'میرے معاہدے';

  @override
  String get workerAcceptedAgreementsEmpty =>
      'آپ نے ابھی تک کوئی معاہدہ قبول نہیں کیا۔';

  @override
  String agreementAcceptedOn(String date) {
    return 'قبول کیا گیا: $date';
  }

  @override
  String agreementAcceptanceId(String id) {
    return 'ایکسیپٹنس آئی ڈی: $id';
  }

  @override
  String get agreementDownload => 'ڈاؤن لوڈ';

  @override
  String get agreementDownloadInProgress => 'معاہدہ ڈاؤن لوڈ ہو رہا ہے...';

  @override
  String agreementDownloadSaved(String path) {
    return 'معاہدہ محفوظ ہو گیا: $path';
  }

  @override
  String get agreementDownloadFailed =>
      'معاہدہ ڈاؤن لوڈ نہیں ہو سکا۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get workerSubmittedDetails => 'جمع کرائی گئی تفصیلات';

  @override
  String get workerViewSubmittedDetails => 'جمع کرائی گئی تفصیلات دیکھیں';

  @override
  String get workerDetailsReadOnlyNotice =>
      'آپ کی پروفائل منظور ہو چکی ہے۔ یہ تفصیلات مقفل ہیں اور تبدیل نہیں کی جا سکتیں۔';

  @override
  String get workerVerificationStatus => 'تصدیق کی حالت';

  @override
  String get workerMainTrade => 'مرکزی ہنر';
}

/// The translations for Urdu, using the Latin script (`ur_Latn`).
class AppLocalizationsUrLatn extends AppLocalizationsUr {
  AppLocalizationsUrLatn() : super('ur_Latn');

  @override
  String get languageSectionTitle => 'Settings';

  @override
  String get languageRowLabel => 'Zaban';

  @override
  String get languageSheetTitle => 'Apni zaban chunein';

  @override
  String get authRoleQuestion => 'HandyGo par aap kya karna chahte hain?';

  @override
  String get authRoleClientTitle => 'Mujhe ghar ke kaam ke liye Ustaad chahiye';

  @override
  String get authRoleClientSubtitle =>
      'Verified Ustaad book karein aur apna kaam asaani se karwayein.';

  @override
  String get authRoleWorkerTitle =>
      'Main Ustaad hoon aur kaam hasil karna chahta hoon';

  @override
  String get authRoleWorkerSubtitle =>
      'HandyGo join karein aur apni skill ke mutabiq kaam hasil karein.';

  @override
  String get authWorkerTypeQuestion => 'Aap pehle se HandyGo\nUstaad hain?';

  @override
  String get authWorkerTypeNewTitle => 'Main naya Ustaad hoon';

  @override
  String get authWorkerTypeNewSubtitle =>
      'HandyGo par apna naya account banayein.';

  @override
  String get authWorkerTypeExistingTitle =>
      'Mera account pehle se bana hua hai';

  @override
  String get authWorkerTypeExistingSubtitle =>
      'OTP ya password se apne account mein login karein.';

  @override
  String authWelcomeToastTitle(String name) {
    return 'Khush aamdeed, $name!';
  }

  @override
  String get authWelcomeToastSubtitle => 'Aap ka account tayyar hai.';

  @override
  String get authOtpExpired => 'Code expire ho gaya hai. Naya code mangwayein.';

  @override
  String authOtpExpiresIn(String time) {
    return 'Code $time mein expire hoga';
  }

  @override
  String authOtpResendCooldown(int seconds) {
    return 'Code dobara bhejein (${seconds}s)';
  }

  @override
  String get authOtpResend => 'Code dobara bhejein';

  @override
  String get authFieldFullName => 'Aap ka poora naam';

  @override
  String get authFieldFullNameShort => 'Pura Naam';

  @override
  String get authHintFullName => 'Apna poora naam likhein';

  @override
  String get authFieldMobileNumber => 'Mobile number';

  @override
  String get authFieldMobileNumberTitle => 'Mobile Number';

  @override
  String get authFieldPassword => 'Password';

  @override
  String get authFieldConfirmPassword => 'Password Dobara Likhein';

  @override
  String get authValidationNameRequired => 'Poora naam likhein.';

  @override
  String get authValidationPhoneRequired => 'Mobile number likhein.';

  @override
  String get authValidationPhoneInvalid =>
      'Sahi Pakistani mobile number likhein.';

  @override
  String get authValidationPasswordRequired => 'Password likhein.';

  @override
  String get authValidationPasswordTooShort =>
      'Password kam az kam 8 characters ka hona chahiye.';

  @override
  String get authValidationConfirmPasswordRequired =>
      'Password dobara likhein.';

  @override
  String get authValidationPasswordsDoNotMatch => 'Passwords match nahi karte.';

  @override
  String get authClientLoginTitle => 'Ustaad book karne ke liye\nlogin karein';

  @override
  String get authClientOtpSubtitle =>
      'Apna naam aur mobile number dalain. Hum verification code bhejein ge.';

  @override
  String get authClientPasswordSubtitle =>
      'Apna mobile number aur password se continue karein.';

  @override
  String get authOtpWillBeSentNotice =>
      'Is number par verification code bheja jayega.';

  @override
  String get authButtonSendCode => 'Code Bhejein';

  @override
  String get authButtonVerifyAndContinue => 'Verify Karke Aage Barhein';

  @override
  String get authButtonLogIn => 'Login Karein';

  @override
  String get authButtonCreateAccount => 'Account Banayein';

  @override
  String get authButtonForgotPassword => 'Password Bhool Gaye?';

  @override
  String get authButtonContinueWithOtp => 'OTP se Continue';

  @override
  String get authButtonContinueWithPassword => 'Password se Continue';

  @override
  String get authButtonUstaadLogin => 'Ustaad Login';

  @override
  String get authErrorGeneric => 'Kuch ghalat ho gaya.';

  @override
  String get authErrorOtpSendFailed =>
      'OTP filhal send nahi ho saka. Password se continue karein ya thori dair baad dobara koshish karein.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Dobara koshish karein';

  @override
  String get commonUser => 'User';

  @override
  String get commonYesterday => 'Kal';

  @override
  String get commonUploading => 'Upload ho raha hai...';

  @override
  String get chatTitleFallback => 'Chat';

  @override
  String get chatListTitle => 'Messages';

  @override
  String get chatSearchHint => 'Chat dhoondein ya “support” likhein';

  @override
  String get chatEmptyTitle => 'Abhi koi baat cheet nahi';

  @override
  String get chatEmptySubtitle => 'Messages yahan nazar aayenge';

  @override
  String get chatNoResultsTitle => 'Koi chat nahi mili';

  @override
  String get chatNoResultsSubtitle =>
      'Koi aur naam try karein, ya “support” likhein';

  @override
  String get chatNoMessagesYet => 'Abhi koi message nahi. Salam karein!';

  @override
  String get chatSupportBanner =>
      'Apna masla ya sawal yahan likhein. HandyGo Support aapki madad karega.';

  @override
  String get chatEditMessage => 'Message edit karein';

  @override
  String get chatEditHint => 'Apna message edit karein...';

  @override
  String get chatDeleteMessage => 'Message delete karein';

  @override
  String get chatDeleteConfirm =>
      'Ye message chat mein sab ke liye delete ho jayega.';

  @override
  String get chatMicPermissionRequired =>
      'Voice message bhejne ke liye microphone ki ijazat chahiye.';

  @override
  String get chatLocationPermissionDenied => 'Location ki ijazat nahi di gayi';

  @override
  String get chatLocationPermissionPermanentlyDenied =>
      'Location ki ijazat permanently band hai — Settings mein jaa kar on karein';

  @override
  String chatLocationFailed(String error) {
    return 'Aap ki location nahi mil saki: $error';
  }

  @override
  String get weekdayMon => 'Peer';

  @override
  String get weekdayTue => 'Mangal';

  @override
  String get weekdayWed => 'Budh';

  @override
  String get weekdayThu => 'Jumeraat';

  @override
  String get weekdayFri => 'Juma';

  @override
  String get weekdaySat => 'Hafta';

  @override
  String get weekdaySun => 'Itwar';

  @override
  String get commonContinue => 'Aage Barhein';

  @override
  String get commonNotNow => 'Abhi nahi';

  @override
  String get commonToday => 'Aaj';

  @override
  String get commonOpenSettings => 'Settings kholein';

  @override
  String get permissionsTitle => 'Ijazat dein';

  @override
  String get permissionsRationale =>
      'HandyGo ko camera, microphone aur location ki ijazat chahiye taake aap photos aur videos bhej sakein, voice note bhej sakein, aur kaam ki location share ya track kar sakein.';

  @override
  String get permissionsBlockedTitle => 'Ijazat band hai';

  @override
  String get permissionsBlockedBody =>
      'Kuch ijazat permanently band kar di gayi hain. Unhein dobara on karne ke liye Settings kholein.';

  @override
  String get generalInfoTitle => 'General';

  @override
  String get generalAccountSection => 'Account ki maloomat';

  @override
  String get generalFirstName => 'Pehla Naam';

  @override
  String get generalLastName => 'Aakhri Naam';

  @override
  String get generalPhoneNumber => 'Phone Number';

  @override
  String get generalNamePhoneLocked =>
      'Naam aur phone number aap ke account se juday hain aur yahan se change nahi ho sakte.';

  @override
  String get generalSecuritySection => 'Security';

  @override
  String get generalChangePassword => 'Password Change Karein';

  @override
  String get generalCurrentPassword => 'Mojooda Password';

  @override
  String get generalNewPassword => 'Naya Password';

  @override
  String get generalConfirmNewPassword => 'Naya Password Dobara Likhein';

  @override
  String get generalChangePasswordComingSoon =>
      'App mein password change karne ki sahulat jald aa rahi hai. Foran madad ke liye support se raabta karein.';

  @override
  String get generalUpdatePassword => 'Password Update Karein';

  @override
  String get distanceAtYourLocation => 'Bilkul aap ki jagah par';

  @override
  String distanceMetersAway(int meters) {
    return '$meters m door';
  }

  @override
  String distanceKmAway(String km) {
    return '$km km door';
  }

  @override
  String get distanceUnderOneKm => '1 km se kam';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Sab read mark karein';

  @override
  String get notificationsEmptyTitle => 'Abhi koi notification nahi';

  @override
  String get notificationsEmptySubtitle =>
      'Kaam ki updates, reviews aur mazeed ki ittila aap ko di jayegi.';

  @override
  String get timeJustNow => 'Abhi abhi';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m pehle';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h pehle';
  }

  @override
  String get workerRatingNew => 'Naya Ustaad';

  @override
  String get workerRatingNone => 'Koi rating nahi';

  @override
  String workerRatingWithJobs(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kaam',
      one: '$count kaam',
    );
    return '$rating ($_temp0)';
  }

  @override
  String get chatSeen => 'Dekh liya';

  @override
  String get chatMessageDeleted => 'Ye message delete kar diya gaya';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatCouldNotOpenMaps => 'Map nahi khul saka';

  @override
  String get chatSharedLocation => 'Location bheji gayi';

  @override
  String get chatComposerHint => 'Message likhein...';

  @override
  String get chatAttachPhoto => 'Photo';

  @override
  String get chatAttachVideo => 'Video';

  @override
  String get chatAttachVoice => 'Voice';

  @override
  String get chatAttachLocation => 'Location';

  @override
  String get chatTakePhoto => 'Photo lein';

  @override
  String get chatRecordVideo => 'Video banayein';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

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
  String dateDayMonthYear(int day, String month, int year) {
    return '$day $month $year';
  }

  @override
  String get authPasswordResetSuccess =>
      'Aap ka password kamyabi se badal diya gaya hai.';

  @override
  String get authForgotPasswordPrompt => 'Apna registered mobile number dalain';

  @override
  String get authSendOtp => 'OTP Bhejein';

  @override
  String get authNewPasswordRequired => 'Naya password likhein.';

  @override
  String get authOr => 'Ya phir';

  @override
  String get authLoginWithPassword => 'Password Se Login Karein';

  @override
  String get authWorkerRegisterTitle => 'Naya Ustaad account\nbanayein';

  @override
  String get authCnicNameHint => 'Apne CNIC wala poora naam dalain';

  @override
  String get authCreatePasswordLabel => 'Password banayein';

  @override
  String get authSelectSkill => 'Apni skill select karein';

  @override
  String get authSkillsLoadFailed =>
      'Skills load nahi ho sakin. Dobara koshish karein.';

  @override
  String get authSkillRequired => 'Skill select karein.';

  @override
  String get authConfirmNewPasswordButton => 'Naya Password Confirm Karein';

  @override
  String get postJobOffersSoon =>
      'Chand hi minute mein aap ko Ustaad ki offers milna shuru ho jayengi.';

  @override
  String get postJobSelectDateTimeFirst =>
      'Aage barhne ke liye date aur time chunain.';

  @override
  String postJobGoesLiveAt(String time, String date) {
    return 'Kaam $date ko $time baje live hoga — Ustaad ke pohanchne ke waqt se ek ghanta pehle.';
  }

  @override
  String get postJobAddPhotoVideo => 'Photo/Video shamil karein';

  @override
  String get postJobChoosePhoto => 'Photo chunain';

  @override
  String get postJobChooseVideo => 'Video chunain - 30 sec';

  @override
  String get postJobCamera => 'Camera';

  @override
  String get postJobRecordVideo30 => 'Video banayein - 30 sec';

  @override
  String get errorNoInternet =>
      'Internet connection nahi hai. Apna network check karein.';

  @override
  String get postJobSaveFailed =>
      'Booking save nahi ho saki. Dobara koshish karein.';

  @override
  String get postJobBookingUpdatedTitle => 'Booking update ho gayi!';

  @override
  String get postJobBookingUpdatedBody =>
      'Aap ki booking ki tafseelat kamyabi se update ho gayi hain.';

  @override
  String get postJobViewBooking => 'Booking dekhein';

  @override
  String get postJobSelectService => 'Service chunain';

  @override
  String get postJobServicesLoadFailed =>
      'Services load nahi ho sakin. App dobara kholein.';

  @override
  String get postJobBookingType => 'Booking ki qism';

  @override
  String get postJobNormal => 'Normal';

  @override
  String get postJobUrgent => 'Urgent';

  @override
  String get postJobDateTime => 'Date aur Time';

  @override
  String get postJobArrivalTime => 'Pohanchne ka waqt';

  @override
  String get postJobWhatNeedsFixing => 'Kya theek karana hai?';

  @override
  String get postJobIssueHint =>
      'Maslan AC thanda nahi kar raha, paani leak ho raha hai, switch kaam nahi kar raha';

  @override
  String get postJobDescription => 'Tafseel';

  @override
  String get postJobDescriptionHint => 'Masla bayan karein (optional)';

  @override
  String get postJobServiceAddress => 'Service ka pata';

  @override
  String get postJobAddressHint =>
      'Maslan House 12, Street 5, DHA Phase 6, Karachi';

  @override
  String get postJobAddLocationFirst =>
      'Aage barhne ke liye apni location shamil karein.';

  @override
  String get postJobVoiceAndPhotos => 'Voice note aur photos';

  @override
  String get postJobVoiceAttached => 'Voice note laga diya gaya';

  @override
  String postJobAttachmentCount(int count) {
    return '4 mein se $count · Photos ya 30-sec video';
  }

  @override
  String postJobAttachmentsWillBeRemoved(int count) {
    return 'Save karne par $count purani files hata di jayengi.';
  }

  @override
  String get postJobTapToRecord =>
      'Record karne ke liye dabayein — masla apne alfaz mein batayein';

  @override
  String get postJobService => 'Service';

  @override
  String get postJobWhatDoYouNeed => 'Aap ko kya chahiye?';

  @override
  String get postJobChooseOneOption => 'Ek option chunain';

  @override
  String get postJobUnderstandingIsOurJob =>
      'Masla samajhna hamara kaam hai — aapka nahi.';

  @override
  String get postJobStandardWork => 'Standard kaam';

  @override
  String get postJobStandardWorkSubtitle => 'Kaam aur qeemat pehle se clear.';

  @override
  String get postJobOr => 'YA PHIR';

  @override
  String get postJobIKnowThePart => 'Mujhe exact part pata hai';

  @override
  String get postJobIKnowThePartSubtitle => 'Ustaad rate bhejenge, aap chunain';

  @override
  String get postJobIKnowThePartWarning =>
      'Sirf tab chunain jab part ka poora yaqeen ho. Ghalat nikla to Ustaad ka chakkar zaya jayega aur naya rate lagega.';

  @override
  String get postJobSomethingIsBroken => 'Kuch kharab hai';

  @override
  String get postJobDontKnowIssue => 'Masla kya hai, ye pata nahi';

  @override
  String get postJobInspectionFeeTitle => 'Inspection Fee';

  @override
  String get postJobNothingOpensBeforeRate =>
      'Rate batane se pehle kuch nahi khulta — jo kaha, wohi liya.';

  @override
  String get postJobChooseStandardService => 'Standard service chunain';

  @override
  String get postJobServicesUnavailable =>
      'Services load nahi ho sakin. Wapas jaa kar dobara koshish karein.';

  @override
  String get postJobSelectCategoryFirst => 'Pehle service category chunain.';

  @override
  String get postJobStandardServicesUnavailable =>
      'Standard services load nahi ho sakin.';

  @override
  String get postJobNoStandardServices =>
      'Is service ke liye abhi koi standard service available nahi. Ooper se koi aur option chunain.';

  @override
  String get postJobMultiSelectHint =>
      'Aap ek se zyada services chun sakte hain.';

  @override
  String get postJobTotal => 'Total';

  @override
  String get postJobInspectionFeeLower => 'Inspection fee';

  @override
  String get postJobInspectionFeeLoadFailed =>
      'Inspection fee load nahi ho saki.';

  @override
  String get postJobHowInspectionWorks => 'Inspection kaise hoti hai';

  @override
  String get postJobWhatDoYouSee => 'Aap ko kya nazar aa raha hai? (optional)';

  @override
  String get postJobWhatDoYouSeeHint =>
      'Maslan AC chalta hai magar kamra garam rehta hai…';

  @override
  String get postJobBack => 'Wapas';

  @override
  String get postJobNext => 'Aage';

  @override
  String get postJobStepAddress => 'Pata';

  @override
  String get postJobStepDetails => 'Tafseelat';

  @override
  String get postJobStepTimeSelection => 'Time ka intekhab';

  @override
  String postJobStepIndicator(int current, int total, String title) {
    return 'Step $total mein se $current  ·  $title';
  }

  @override
  String get clientHomeYourArea => 'Aap ka ilaqa';

  @override
  String get clientHomeSectionRepairs => 'Marammat';

  @override
  String get clientHomeSectionCleaning => 'Safai';

  @override
  String get clientHomeSectionPainting => 'Painting';

  @override
  String get clientHomeSectionOutdoorVehicle => 'Bahar aur Gaari';

  @override
  String get serviceAcTechnician => 'AC Technician';

  @override
  String get serviceElectrician => 'Electrician';

  @override
  String get servicePlumber => 'Plumber';

  @override
  String get serviceCarpenter => 'Carpenter';

  @override
  String get serviceDeepCleaning => 'Deep Cleaning';

  @override
  String get servicePestControl => 'Pest Control';

  @override
  String get servicePainter => 'Painter';

  @override
  String get serviceGardening => 'Gardening';

  @override
  String get serviceCarWash => 'Car Wash';

  @override
  String get serviceMoversPackers => 'Movers & Packers';

  @override
  String get clientHomeNoServicesFound => 'Koi service nahi mili';

  @override
  String get clientHomeSearchResults => 'Search ke nataij';

  @override
  String get clientHomeBookUrgently => 'Foran book karein';

  @override
  String get clientHomeChooseServiceHelp =>
      'Foran madad ke liye koi service chunain.';

  @override
  String clientHomeGreeting(String name) {
    return 'Hi $name 👋';
  }

  @override
  String get clientHomeBeatTheHeat => 'Karachi ki garmi ka muqabla karein ☀️';

  @override
  String get clientHomeAcServiceBanner =>
      'Apna AC service karwayein\nis se pehle ke kharabi barh jaye.';

  @override
  String get clientHomeBookAcTechnician => 'AC Technician book karein';

  @override
  String get clientHomeNeedHelpNow => 'Abhi madad chahiye?';

  @override
  String get clientHomeUrgentSubtitle =>
      'Foran maslon ke liye abhi book karein.';

  @override
  String get clientHome247Service => '24/7 Service';

  @override
  String get clientHomeRecent => 'Recent';

  @override
  String get clientHomeSeeAll => 'Sab dekhein';

  @override
  String get timeNow => 'Abhi';

  @override
  String timeMinutesShort(int minutes) {
    return '${minutes}m';
  }

  @override
  String timeHoursShort(int hours) {
    return '${hours}h';
  }

  @override
  String get clientProfileTitle => 'Profile';

  @override
  String get clientProfileAvatarLocalOnly =>
      'Profile picture isi device par save hai. Cloud sync abhi available nahi.';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsSectionDangerZone => 'Danger Zone';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsConditions => 'Terms & Conditions';

  @override
  String get profilePhotoTitle => 'Profile Photo';

  @override
  String get commonGallery => 'Gallery';

  @override
  String get commonRemove => 'Hatayein';

  @override
  String get deleteAccountConfirmTitle => 'Account delete karein?';

  @override
  String get deleteAccountConfirmBody =>
      'Is se aap ka HandyGo account delete ho jayega aur aap sign out ho jayenge. Ye kaam shayad wapas na ho sake.';

  @override
  String get deleteAccountTitle => 'Account Delete Karein';

  @override
  String get deleteAccountRequestByEmail =>
      'Email ke zariye deletion ki request dein';

  @override
  String get commonLogout => 'Logout';

  @override
  String get clientJobsTitle => 'Mere Kaam';

  @override
  String get clientJobsEmpty => '📋  Abhi koi kaam nahi';

  @override
  String get locationSelected => 'Muntakhab location';

  @override
  String get locationSearchHint => 'Ilaqa ya koi nishani dhoondein…';

  @override
  String get locationGettingAddress => 'Pata hasil kiya ja raha hai…';

  @override
  String get locationUseThis => 'Yehi location use karein';

  @override
  String get serviceComingSoon => 'Jald aa raha hai';

  @override
  String get clientHomeSearchHint => 'Services dhoondein...';

  @override
  String get profileDeleteFailed => 'Account delete nahi ho saka.';

  @override
  String get serviceBookNow => 'Abhi book karein';

  @override
  String get serviceSelectedTick => 'Selected ✓';

  @override
  String get locationMoveMapHint =>
      'Map hilayein ya location chunne ke liye dabayein';

  @override
  String get slotMorning => 'Subah';

  @override
  String get slotAfternoon => 'Dopehar';

  @override
  String get slotEvening => 'Shaam';

  @override
  String get slotNight => 'Raat';

  @override
  String get slotMorningRange => '9 AM – 12 PM';

  @override
  String get slotAfternoonRange => '12 PM – 4 PM';

  @override
  String get slotEveningRange => '4 PM – 8 PM';

  @override
  String get slotNightRange => '8 PM – 11 PM';

  @override
  String get postJobSelectDate => 'Date chunain';

  @override
  String get postJobLocationAdded => 'Location shamil kar di gayi';

  @override
  String get postJobCurrentLocation => 'Mojooda Location';

  @override
  String get postJobMapLocationAdded => 'Map se location shamil kar di gayi';

  @override
  String get postJobPickOnMap => 'Map par chunain';

  @override
  String postJobMapPrefix(String address) {
    return 'Map: $address';
  }

  @override
  String postJobGpsPrefix(String coordinates) {
    return 'GPS: $coordinates';
  }

  @override
  String get postJobBookService => 'Service book karein';

  @override
  String get postJobSaveChanges => 'Tabdeeliyan save karein';

  @override
  String get postJobBookAService => 'Ek service book karein';

  @override
  String get postJobEditBooking => 'Booking edit karein';

  @override
  String get postJobNotAvailable => 'Available nahi';

  @override
  String get bookingLoadFailed => 'Booking load nahi ho saki.';

  @override
  String get bookingServiceDetails => 'Service ki tafseelat';

  @override
  String get bookingIssue => 'Masla';

  @override
  String get bookingUrgency => 'Urgency';

  @override
  String get bookingTiming => 'Timing';

  @override
  String get bookingNotScheduledYet => 'Abhi time tay nahi hua';

  @override
  String get bookingTimeWindow => 'Time Window';

  @override
  String get bookingScheduledDate => 'Tay shuda date';

  @override
  String get bookingCreated => 'Banayi gayi';

  @override
  String get bookingCancellationReason => 'Cancel karne ki wajah';

  @override
  String get bookingInspectionCompletedBy => 'Inspection mukammal karne wale';

  @override
  String get bookingWorkBeingCompletedBy => 'Kaam mukammal karne wale';

  @override
  String get bookingInspectionAndRepairBy =>
      'Inspection aur marammat karne wale';

  @override
  String get bookingAssignedWorker => 'Assign kiya gaya Ustaad';

  @override
  String get bookingDetailsTitle => 'Booking ki tafseelat';

  @override
  String get bookingNoAddressProvided => 'Koi pata nahi diya gaya';

  @override
  String get bookingAttachments => 'Attachments';

  @override
  String bookingPhotosCount(int count) {
    return 'Photos ($count)';
  }

  @override
  String bookingVideosCount(int count) {
    return 'Videos ($count)';
  }

  @override
  String get bookingVoiceNote => 'Voice Note';

  @override
  String get bookingPricing => 'Qeemat';

  @override
  String get bookingEstimatedPrice => 'Andazan qeemat';

  @override
  String get bookingInspectionCharges => 'Inspection charges';

  @override
  String get bookingWorkCharges => 'Kaam ke charges';

  @override
  String get bookingFinalPrice => 'Final qeemat';

  @override
  String get bookingJobLocation => 'Kaam ki jagah';

  @override
  String get bookingLiveLocation => 'Live Location';

  @override
  String bookingTrackingWorker(String name) {
    return '$name ko track kiya ja raha hai';
  }

  @override
  String get bookingWaitingForWorkerLocation =>
      'Ustaad ke location share karne ka intezar hai';

  @override
  String get bookingLiveLocationNotAvailable =>
      'Live location abhi available nahi';

  @override
  String get bookingLocationPending => 'Location ka intezar hai';

  @override
  String get bookingMapPreviewUnavailable => 'Map preview available nahi';

  @override
  String get bookingMapImageLoadFailed => 'Map ki image load nahi ho saki';

  @override
  String get bookingAppearsWhenEnRoute =>
      'Ustaad ke rawana hote hi nazar aayega';

  @override
  String get bookingWorkerNearlyThere => 'Ustaad taqreeban pohanch chuke hain';

  @override
  String get bookingWorkerOnTheWay => 'Ustaad raaste mein hain';

  @override
  String get bookingLiveUpdatedNow => 'Live · Abhi update hua';

  @override
  String get bookingStatusTimeline => 'Kaam ki status timeline';

  @override
  String get bookingJobExpired => 'Ye kaam khatam ho gaya';

  @override
  String get bookingExpiredExplanation =>
      '72 ghanton mein koi Ustaad hire nahi hua. Talash jari rakhne ke liye ise dobara live karein.';

  @override
  String get bookingMakeLiveFailed => 'Kaam dobara live nahi ho saka.';

  @override
  String get bookingMakeLiveAgain => 'Dobara live karein';

  @override
  String bookingPreviousUstaadCancelledNamed(String name) {
    return 'Pichle Ustaad ne cancel kar diya: $name';
  }

  @override
  String get bookingPreviousUstaadCancelled =>
      'Pichle Ustaad ne cancel kar diya';

  @override
  String get bookingUstaadCancelledJob => 'Ustaad ne job cancel kar di';

  @override
  String bookingReasonPrefix(String reason) {
    return 'Wajah: $reason';
  }

  @override
  String get bookingFindAnotherUstaadFailed =>
      'Doosra Ustaad talash nahi ho saka.';

  @override
  String get bookingFindAnotherUstaad => 'Doosra Ustaad dhoondein';

  @override
  String get bookingSelectedServices => 'Muntakhab services';

  @override
  String bookingServiceQuantity(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String get bookingChooseUstaad => 'Ustaad chunain';

  @override
  String get bookingSeeWorkerBids => 'Ustaad ki bids dekhein';

  @override
  String get bookingTrackWorker => 'Ustaad ko track karein';

  @override
  String get bookingReviewWorker => 'Ustaad ko review dein';

  @override
  String get bookingYourReview => 'Aap ka review';

  @override
  String get bookingCallWorker => 'Ustaad ko call karein';

  @override
  String get bookingCancelBooking => 'Booking cancel karein';

  @override
  String get bookingCancelFailed => 'Booking cancel nahi ho saki.';

  @override
  String get bookingChatWithWorker => 'Ustaad se chat karein';

  @override
  String get bookingLoadFailedShort => 'Booking load nahi ho saki';

  @override
  String get workerLevelMaster => 'Master';

  @override
  String get workerLevelElite => 'Elite';

  @override
  String get workerLevelProUstaad => 'Pro Ustaad';

  @override
  String get workerLevelPro => 'Pro';

  @override
  String get workerLevelStandard => 'Standard';

  @override
  String get trackLoadFailed => 'Tracking data load nahi ho saka.';

  @override
  String get trackTitleUstaad => 'Ustaad ko track karein';

  @override
  String get trackNoLocationForBooking =>
      'Is booking ke liye location available nahi.';

  @override
  String get trackUstaadLocationUnavailable =>
      'Ustaad ki location abhi available nahi hai.';

  @override
  String get trackJobCompleted => 'Kaam mukammal ✓';

  @override
  String get trackQuoteAcceptedRepairInProgress =>
      'Quote accept — marammat jari hai';

  @override
  String get trackReportSubmitted => 'Report jama kara di gayi';

  @override
  String get trackInspectionInProgress => 'Inspection jari hai';

  @override
  String get trackReviewReportAndDecide =>
      'Neeche report dekhein aur faisla karein ke aage kya karna hai';

  @override
  String get trackWorkerLabel => 'Ustaad';

  @override
  String trackHiredAt(String price) {
    return '$price par hire kiya gaya';
  }

  @override
  String get trackPhoneUnavailable => 'Phone number available nahi';

  @override
  String get trackDialerFailed => 'Phone dialer nahi khul saka';

  @override
  String get trackAssignedWorkerCaps => 'ASSIGN KIYA GAYA USTAAD';

  @override
  String get trackCall => 'Call';

  @override
  String get trackLocationUnavailable => 'Location available nahi';

  @override
  String trackArrivingIn(int count) {
    return 'Taqreeban $count minute mein pohanch rahe hain';
  }

  @override
  String get trackEtaUnavailable => 'ETA available nahi';

  @override
  String get trackStepHired => 'Hire ho gaye';

  @override
  String get trackStepUstaadOnTheWay => 'Ustaad raaste mein';

  @override
  String get trackStepInspectionInProgress => 'Inspection jari';

  @override
  String get trackStepReportSubmitted => 'Report jama';

  @override
  String get trackStepClosedAfterInspection => 'Inspection ke baad band';

  @override
  String get trackStepQuoteAccepted => 'Quote accept';

  @override
  String get trackStepReviewed => 'Review ho gaya';

  @override
  String get trackStepWorkInProgress => 'Kaam jari';

  @override
  String get trackStepReviewPending => 'Review baqi';

  @override
  String get trackJobProgress => 'Kaam ki pesh raft';

  @override
  String get trackLoadFailedShort => 'Tracking load nahi ho saki';

  @override
  String get discoveryJobLocation => 'Kaam ki jagah';

  @override
  String get discoveryJobLocationUnavailable => 'Kaam ki jagah available nahi';

  @override
  String get discoveryLiveWorkerOffers => 'Ustaad ki live offers';

  @override
  String get discoveryRefresh => 'Refresh';

  @override
  String get discoveryBidsLoadFailed => 'Bids load nahi ho sakin.';

  @override
  String get discoveryNoBidsYet => 'Abhi koi bid nahi';

  @override
  String discoveryPendingCount(int count) {
    return '$count pending';
  }

  @override
  String get discoveryHire => 'Hire karein';

  @override
  String get discoveryHiring => 'Hire kiya ja raha hai…';

  @override
  String discoveryHireNamed(String name) {
    return '$name ko hire karein?';
  }

  @override
  String discoveryAcceptBid(String name, String price) {
    return '$name ki $price ki bid accept karein?';
  }

  @override
  String get discoveryInspectionFeeSeparate =>
      'Inspection karne wale Ustaad ko inspection fee alag deni hogi. Naya Ustaad apne offer ke mutabiq kaam ki puri raqam charge karega. Inspection fee uske offer mein adjust nahi hogi.';

  @override
  String get discoveryWorkerHired => 'Ustaad kamyabi se hire ho gaye';

  @override
  String get discoveryHireFailed => 'Ustaad hire nahi ho sake.';

  @override
  String get discoveryInspectedThisJob => 'IS KAAM KI INSPECTION KI';

  @override
  String get discoveryTheirQuote => 'un ka quote';

  @override
  String get discoveryInspectionCompletedByThis =>
      'Inspection isi Ustaad ne mukammal ki.';

  @override
  String get discoveryViewInspectionReport => 'Inspection Report Dekhein';

  @override
  String get discoveryHireAgain => 'Dobara Hire Karein';

  @override
  String discoveryHireAgainNamed(String name) {
    return '$name ko dobara hire karein?';
  }

  @override
  String get discoveryOriginalQuoteContinues =>
      'Wo apne asal inspection quote par hi kaam jari rakhenge.';

  @override
  String get discoveryWorkersWillAppear =>
      'Apply karne wale Ustaad yahan nazar aayenge.\nThori dair baad dobara dekhein.';

  @override
  String get discoveryTryAgain => 'Dobara koshish karein';

  @override
  String get inspectionReportTitle => 'Inspection Report';

  @override
  String get inspectionReportNotAvailable => 'Report abhi available nahi.';

  @override
  String get inspectionUstaadVoiceNote => 'Ustaad ka voice note';

  @override
  String get inspectionPhotos => 'Photos';

  @override
  String get inspectionParts => 'Parts';

  @override
  String get inspectionRepairQuoteTotal => 'Marammat ke quote ka total';

  @override
  String get inspectionAcceptQuoteContinue =>
      'Quote accept karein aur marammat jari rakhein';

  @override
  String get inspectionFindOtherUstaad => 'Doosra Ustaad dhoondein';

  @override
  String get inspectionCloseAfterInspection => 'Inspection ke baad band karein';

  @override
  String get inspectionAcceptQuoteConfirmTitle =>
      'Quote accept kar ke marammat jari rakhein?';

  @override
  String get inspectionCloseConfirmTitle => 'Inspection ke baad band karein?';

  @override
  String get inspectionAcceptQuoteConfirmBody =>
      'Yehi Ustaad marammat jari rakhenge. Inspection fee maaf hai — aap sirf marammat ka quote den ge.';

  @override
  String get inspectionCloseConfirmBody =>
      'Aap se sirf inspection fee li jayegi. Kaam mukammal mark ho jayega.';

  @override
  String get inspectionClosedAfterInspection =>
      'Inspection ke baad band kar diya gaya.';

  @override
  String get inspectionQuoteAcceptedRepairInProgress =>
      'Quote accept — marammat jari hai.';

  @override
  String get inspectionActionFailed => 'Kaam nahi hua. Dobara koshish karein.';

  @override
  String get inspectionFindAnotherConfirmTitle => 'Doosra Ustaad dhoondein?';

  @override
  String get inspectionFindAnotherConfirmBody =>
      'Confirm karne par inspection mukammal ho jayegi aur inspection fee li jayegi. Aap ka kaam dobara live ho jayega taake doosre Ustaad apne rate bhej sakein.';

  @override
  String get inspectionBadge => 'Inspection';

  @override
  String get chooseHireConfirmTitle => 'Is Ustaad ko hire karein?';

  @override
  String chooseHireConfirmBody(String name) {
    return '$name ko ye kaam dein? Is ke baad aap doosra Ustaad nahi chun sakenge.';
  }

  @override
  String get chooseAssignFailed =>
      'Ye Ustaad assign nahi ho sake. Dobara koshish karein.';

  @override
  String chooseServiceTotal(String price) {
    return 'Service Total $price';
  }

  @override
  String chooseInspectionFeeAmount(String price) {
    return 'Inspection fee $price';
  }

  @override
  String get chooseFindingUstaads =>
      'Aap ke qareeb verified Ustaad dhoonde ja rahe hain…';

  @override
  String get chooseLoadFailed => 'Is waqt available Ustaad load nahi ho sake.';

  @override
  String get chooseNoUstaadAvailable =>
      'Is waqt koi verified Ustaad available nahi.';

  @override
  String get chooseAutoRefreshNote =>
      'List har 45 seconds mein khud-ba-khud refresh hoti hai.';

  @override
  String get chooseRefreshOrWait =>
      'Aap refresh kar sakte hain ya thora intezar karein — available Ustaad check ho rahe hain…';

  @override
  String get chooseNewBadge => 'Naya';

  @override
  String get chooseSelect => 'Chunain';

  @override
  String get chooseRecommended => 'Recommended';

  @override
  String get chooseSkills => 'Skills';

  @override
  String get myBookingsLoadFailed =>
      'Aap ki bookings load nahi ho sakin. Dobara koshish karein.';

  @override
  String get myBookingsTitle => 'Meri Bookings';

  @override
  String get myBookingsEmptyTitle => 'Abhi koi booking nahi';

  @override
  String get myBookingsNoResults => 'Koi nateeja nahi mila';

  @override
  String get myBookingsAdjustFilters =>
      'Apne filter ya search word badal kar dekhein';

  @override
  String get myBookingsBookFirst =>
      'Shuru karne ke liye apni pehli service book karein';

  @override
  String get myBookingsRefreshFailed =>
      'Refresh nahi hua. Dobara koshish ke liye kheenchein.';

  @override
  String get myBookingsSomethingWrong => 'Kuch ghalat ho gaya';

  @override
  String cardTodayAt(String time) {
    return 'Aaj, $time';
  }

  @override
  String get cardGoesLiveBefore => 'Window se 1 ghanta pehle live hoga';

  @override
  String get cardWorkersNotified => 'Ustaad ko foran ittila di jati hai';

  @override
  String get cardSearchingWorkers => 'Ustaad dhoonde ja rahe hain...';

  @override
  String get cardNoWorkerYet => 'Abhi koi Ustaad nahi';

  @override
  String get cardEstimatePrefix => 'est.';

  @override
  String get cardFindWorkers => 'Ustaad dhoondein';

  @override
  String get cardEdit => 'Edit';

  @override
  String get filterTitle => 'Bookings filter karein';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterAll => 'Sab';

  @override
  String get filterUrgentOption => '⚡ Urgent';

  @override
  String get filterNormalOption => '🗓 Normal';

  @override
  String get filterSortByDate => 'Date ke hisab se sort';

  @override
  String get filterNewestFirst => 'Nayi pehle';

  @override
  String get filterOldestFirst => 'Purani pehle';

  @override
  String get filterApply => 'Filter lagayein';

  @override
  String get searchBookingsHint => 'Bookings, services dhoondein...';

  @override
  String get cancelReasonTitle => 'Booking Cancel Karne Ki Wajah';

  @override
  String get cancelReasonRequired => 'Barah-e-karam wajah batayein.';

  @override
  String get cancelReasonSelect => 'Wajah select karein';

  @override
  String get cancelReasonWriteOwn => 'Apni wajah likhein';

  @override
  String get reviewSubmitFailed => 'Review submit nahi ho saka.';

  @override
  String get reviewPromptBeforeContinuing =>
      'Aage barhne se pehle apne Ustaad ko review dein.';

  @override
  String get reviewHowWasWork => 'Kaam kaisa raha?';

  @override
  String get reviewCommentHint => 'Comment likhein (optional)...';

  @override
  String get reviewSubmit => 'Review Submit Karein';

  @override
  String get reviewLater => 'Baad Mein';

  @override
  String get chatOpenFailed => 'Chat nahi khul saki.';

  @override
  String get mediaTapToPlay => 'Chalane ke liye dabayein';

  @override
  String get inspectionConfirm => 'Confirm karein';

  @override
  String trackSubtextCompleted(String name) {
    return '$name ne kaam mukammal kar diya';
  }

  @override
  String trackSubtextContinuingRepair(String name) {
    return '$name marammat jari rakhe hue hain';
  }

  @override
  String trackSubtextOnTheWay(String name) {
    return '$name aap ki location ki taraf aa rahe hain';
  }

  @override
  String trackSubtextArrived(String name) {
    return '$name aap ki location par pohanch gaye hain';
  }

  @override
  String trackSubtextInspecting(String name) {
    return '$name masla dekh rahe hain';
  }

  @override
  String trackSubtextHiredForInspection(String name) {
    return '$name ko is inspection ke liye hire kiya gaya hai';
  }

  @override
  String trackSubtextWorking(String name) {
    return '$name aap ke kaam par lage hue hain';
  }

  @override
  String trackSubtextHiredForJob(String name) {
    return '$name ko is kaam ke liye hire kiya gaya hai';
  }

  @override
  String get urgentWithin1Hour => 'Ek ghante ke andar';

  @override
  String get urgentWithin2Hours => 'Do ghanton ke andar';

  @override
  String get urgentWithin4Hours => 'Chaar ghanton ke andar';

  @override
  String get inspectionFeePaid => 'Inspection fee paid';

  @override
  String get inspectionFeeNotPaid => 'Inspection fee paid nahi';

  @override
  String chooseWithinRadius(String km) {
    return '$km km ke andar';
  }

  @override
  String chooseHireConfirmBodyFull(String name) {
    return '$name ko ye kaam dein? Is ke baad aap doosra Ustaad nahi chun sakenge.';
  }

  @override
  String get trackHeadlineUstaadOnTheWay => 'Ustaad On The Way';

  @override
  String get trackHeadlineUstaadArrived => 'Ustaad Arrived';

  @override
  String get trackHeadlineWorkInProgress => 'Work In Progress';

  @override
  String get trackHeadlineHired => 'Hire ho gaye ✓';

  @override
  String trackRatingOutOfFive(String rating) {
    return '$rating / 5.0';
  }

  @override
  String get discoveryLoadingBids => 'Bids load ho rahi hain...';

  @override
  String get discoveryBidsLoadFailedShort => 'Bids load nahi ho sakin';

  @override
  String bookingWorkersAvailableNearby(int count) {
    return 'Qareeb $count Ustaad available';
  }

  @override
  String bookingIdShort(String code) {
    return '#ER-$code';
  }

  @override
  String inspectionPartWithWarranty(
    String name,
    int quantity,
    String warranty,
  ) {
    return '$name x$quantity · $warranty';
  }

  @override
  String discoveryPendingBidsSorted(int count) {
    return '$count pending bids · qeemat ke hisab se sorted';
  }

  @override
  String get workerOffline => 'Offline';

  @override
  String get workerOnline => 'Online';

  @override
  String get workerBusy => 'Busy';

  @override
  String get workerOfflineHelper => 'Aap clients ko nazar nahi aa rahe';

  @override
  String get workerOnlineHelper =>
      'Aap ke qareeb ke clients aap ko dekh sakte hain';

  @override
  String get workerBusyHelper => 'Aap is waqt ek kaam par masroof hain';

  @override
  String get workerStatusOnTheWay => 'Raaste mein';

  @override
  String get workerActionOnMyWay => 'Main rawana hoon';

  @override
  String get workerActionArrived => 'Pohanch gaya';

  @override
  String get workerActionStartJob => 'Kaam shuru karein';

  @override
  String get workerActionCompleteJob => 'Kaam mukammal karein';

  @override
  String get workerActionStartInspection => 'Inspection shuru karein';

  @override
  String get workerActionStartWork => 'Kaam shuru karein';

  @override
  String get workerActionFillReport => 'Inspection report bharein';

  @override
  String get workerActionWaitingForClient => 'Client ke faisle ka intezar';

  @override
  String get workerSuccessOnTheWay =>
      'Aap rawana hain — client ko ittila de di gayi.';

  @override
  String get workerSuccessArrived => 'Pohanchne ka nishan laga diya gaya.';

  @override
  String get workerSuccessJobStarted => 'Kaam shuru ho gaya.';

  @override
  String get workerSuccessJobCompleted => 'Kaam mukammal mark ho gaya.';

  @override
  String get workerSuccessInspectionStarted => 'Inspection shuru ho gayi.';

  @override
  String get workerSuccessWorkStarted => 'Kaam shuru ho gaya.';

  @override
  String get workerSkillNotSelected => 'Skill select nahi ki gayi';

  @override
  String get workerLocating => 'Location maloom ki ja rahi hai…';

  @override
  String get workerTapToRetry => 'Dobara koshish ke liye dabayein';

  @override
  String get workerTapForLocation => 'Location ke liye dabayein';

  @override
  String get workerOnActiveJob => 'Kaam jari hai';

  @override
  String get workerConnecting => 'Connect ho raha hai...';

  @override
  String get workerGoingOffline => 'Offline ho rahe hain...';

  @override
  String get workerGoOffline => 'Offline ho jayein';

  @override
  String get workerGoOnline => 'Online ho jayein';

  @override
  String get workerTodaysEarnings => 'Aaj ki Kamai';

  @override
  String get workerRating => 'Rating';

  @override
  String get workerActive => 'Active';

  @override
  String get workerGoOfflineConfirmTitle => 'Offline ho jayein?';

  @override
  String get workerGoOfflineConfirmBody =>
      'Aap qareebi clients ko nazar aana band ho jayenge.';

  @override
  String get workerGoOfflineConfirmYes => 'Haan, offline karein';

  @override
  String get workerFindNewWork => 'Naya Kaam Dhondain';

  @override
  String get workerViewNewJobs => 'Naye kaam dekhein';

  @override
  String get workerActiveJobCaps => 'JARI KAAM';

  @override
  String get workerMap => 'Map';

  @override
  String get workerViewDetails => 'Tafseelat dekhein →';

  @override
  String get workerNoActiveJob => 'Is waqt koi kaam jari nahi';

  @override
  String get workerStayOnlineHint =>
      'Online rahein, nazdeek ka kaam dhondne ke liye.';

  @override
  String get workerReady => 'Tayyar';

  @override
  String get workerPerformance => 'Performance';

  @override
  String get workerJobsDone => 'Jobs Done';

  @override
  String get workerCancelRate => 'Cancel Rate';

  @override
  String workerPercentValue(String value) {
    return '$value%';
  }

  @override
  String get workerResponse => 'Response';

  @override
  String get workerReviews => 'Reviews';

  @override
  String get workerSeeAll => 'Sab dekhein →';

  @override
  String get workerNoReviewsYet => 'Abhi koi review nahi';

  @override
  String get workerReviewsAppearHint =>
      'Aap ke mukammal kaamon ke baad clients ke reviews yahan nazar aayenge.';

  @override
  String get workerSelectMainSkill => 'Apni main skill chunain';

  @override
  String get workerSelectMainSkillHint =>
      'Kaam milna shuru karne ke liye apni main skill chunain';

  @override
  String workerCategoriesLoadFailed(String error) {
    return 'Categories load nahi ho sakin: $error';
  }

  @override
  String get workerSkillsSaveFailed =>
      'Skills save nahi ho sakin. Dobara koshish karein.';

  @override
  String get workerSaveAndGoOnline => 'Save karein aur online hon';

  @override
  String get workerDashboardLoadFailed => 'Dashboard load nahi ho saka';

  @override
  String get workerNewJobsTitle => 'Naye Kaam';

  @override
  String get workerNewJobsSubtitle => 'Aapke hunar ke hisaab se kaam';

  @override
  String get workerCompleteProfileForNewJobs =>
      'Apni profile complete karain. Approval ke baad aapko naye kaam nazar ayenge.';

  @override
  String get workerNewJobsLoadFailed => 'Naye kaam load nahi ho sake.';

  @override
  String workerOfferCount(int count) {
    return '$count offers';
  }

  @override
  String get workerDirectHireNote =>
      'Client aap ko seedha hire kar sakta hai. Koi offer bhejne ki zaroorat nahi.';

  @override
  String get workerListedJob => 'Listed Job';

  @override
  String get workerOfferSent => 'Offer bhej di';

  @override
  String get workerNoNewJobs => 'Is waqt koi naya kaam nahi';

  @override
  String get workerNoNewJobsHint =>
      'Aap ki skill ke mutabiq naye kaam yahan nazar aayenge. Refresh ke liye neeche kheenchein.';

  @override
  String get workerCompleteProfileForJobs =>
      'Apni profile complete karain. Approval ke baad aap apni jobs manage kar sakenge.';

  @override
  String get workerJobsLoadFailed =>
      'Jobs load nahi ho sake. Dobara koshish karein.';

  @override
  String get workerClientCancelledBooking =>
      'Client ne ye booking cancel kar di';

  @override
  String get workerOnlyInspectionCompleted => 'Sirf Inspection Mukammal Hui';

  @override
  String get workerComplete => 'Complete';

  @override
  String get workerCompleting => 'Complete ho raha hai...';

  @override
  String get workerMarkCompletedTitle => 'Mukammal mark karein?';

  @override
  String get workerMarkCompletedBody =>
      'Is se kaam band ho jayega aur client ko ittila mil jayegi.';

  @override
  String get workerNoActiveJobs => 'Koi jari kaam nahi';

  @override
  String get workerNoCompletedJobs => 'Abhi koi mukammal kaam nahi';

  @override
  String get workerNoCancelledJobs => 'Koi cancel kaam nahi';

  @override
  String get workerNoJobsAssigned => 'Abhi koi kaam nahi mila';

  @override
  String get workerNewRequestsHere => 'Nayi requests yahan nazar aayengi';

  @override
  String get workerCompletedJobsHere => 'Mukammal kaam yahan nazar aayenge';

  @override
  String get workerCancelledJobsHere => 'Cancel kaam yahan nazar aayenge';

  @override
  String get workerAcceptToGetStarted =>
      'Shuru karne ke liye koi booking accept karein';

  @override
  String get workerFilterCancelled => 'Cancel';

  @override
  String get workerFilterAllWork => 'Sab Kaam';

  @override
  String get workerFilterMyOffers => 'Meri Offers';

  @override
  String get workerFilterNoOfferSent => 'Offer nahi bheji';

  @override
  String get bidPlaceABid => 'Bid lagayein';

  @override
  String get bidChatWithClient => 'Client se chat karein';

  @override
  String get bidLiveBids => 'Live Bids';

  @override
  String get bidAreaNotAvailable => 'Ilaqa available nahi';

  @override
  String get bidExactAddressAfterAccept =>
      'Client ke aap ki bid accept karne par poora pata bhej diya jata hai.';

  @override
  String get bidStatusAccepted => 'Accept';

  @override
  String get bidStatusRejected => 'Reject';

  @override
  String get bidStatusPending => 'Pending';

  @override
  String get bidYourCurrentBid => 'Aap ki mojooda bid';

  @override
  String get bidSubmit => 'Bid bhejein';

  @override
  String get bidUpdate => 'Bid update karein';

  @override
  String get bidPlaceYourBid => 'Apni bid lagayein';

  @override
  String get bidUpdateYourBid => 'Apni bid update karein';

  @override
  String bidCanUpdateIn(String seconds) {
    return 'Aap ${seconds}s baad bid update kar sakte hain.';
  }

  @override
  String get bidCanUpdateNow => 'Aap abhi apni bid update kar sakte hain.';

  @override
  String get bidAmountLabel => 'Bid Amount (PKR) *';

  @override
  String get bidAmountHint => 'Maslan 2500';

  @override
  String bidLabelWithCountdown(String label, String seconds) {
    return '$label (${seconds}s)';
  }

  @override
  String bidJobCount(int count) {
    return '$count jobs';
  }

  @override
  String get bidBeFirstToBid => 'Is kaam par sab se pehle bid lagayein';

  @override
  String get earningBidding => 'Bidding';

  @override
  String get earningHistoryTitle => 'Earning History';

  @override
  String get earningNoneYet => 'Abhi koi kamai nahi';

  @override
  String get earningNoneHint =>
      'Mukammal kaam yahan aap ki rozana kamai ke sath nazar aayenge.';

  @override
  String get reviewsMyReviews => 'Mere Reviews';

  @override
  String reviewsCount(int count) {
    return '$count reviews';
  }

  @override
  String get reviewsSubtitle => 'Aap ke mukammal kaamon par clients ke reviews';

  @override
  String get reviewsAvg => 'Avg';

  @override
  String get reviewsMax => 'Max';

  @override
  String get reviewsMin => 'Min';

  @override
  String get reviewsEmptyHint =>
      'Jab clients aap ke mukammal kaamon par review denge,\nwo yahan nazar aayenge.';

  @override
  String reviewsRatingSummary(String rating, int count) {
    return '$rating · $count reviews';
  }

  @override
  String reviewsHighestLowest(String max, String min) {
    return 'Highest: $max ★  ·  Lowest: $min ★';
  }

  @override
  String get inspFormChooseFromGallery => 'Gallery se chunain';

  @override
  String get inspFormSubmitted =>
      'Report jama ho gayi. Client ke faisle ka intezar hai.';

  @override
  String get inspFormSubmitFailed => 'Report jama nahi ho saki.';

  @override
  String get inspFormWhatWasIssue => 'Masla kya nikla?';

  @override
  String get inspFormWhatWasIssueRequired => 'Masla kya nikla? *';

  @override
  String get inspFormRecommendedRepair => 'Recommended repair';

  @override
  String get inspFormRecommendedRepairRequired => 'Recommended repair *';

  @override
  String get inspFormWhatWorkNeeded => 'Kya kaam karna hoga';

  @override
  String get inspFormWriteOrRecord =>
      'Barah-e-karam report likhein ya voice note record karein.';

  @override
  String get inspFormPartsRequired => 'Parts chahiye?';

  @override
  String get inspFormAddPart => 'Part shamil karein';

  @override
  String get inspFormUstaadNotes => 'Ustaad ke notes';

  @override
  String get inspFormSubmitReport => 'Report submit karain';

  @override
  String inspFormIssuePhotos(int max) {
    return 'Masle ki photos — optional, max $max';
  }

  @override
  String get inspFormVoiceNote => 'Voice note';

  @override
  String get inspFormVoiceNoteHint =>
      'Agar likhna mushkil ho, voice note record kar dein.';

  @override
  String inspFormRecording(String duration) {
    return 'Recording  $duration';
  }

  @override
  String get inspFormStop => 'Stop';

  @override
  String get inspFormStartRecording => 'Recording shuru karein';

  @override
  String get inspFormPartNameHint => 'Maslan istemal hone wala purza ya saman';

  @override
  String get inspFormWarrantyHint => 'Maslan 7 din';

  @override
  String get inspFormRemovePart => 'Part hatayein';

  @override
  String get inspFormTotalAmount => 'Kam ki puri raqam';

  @override
  String get inspFormFeeWaivedNote =>
      'Agar customer repair continue karwata hai to inspection fee nhi deni hogi.';

  @override
  String get inspHintElectrical =>
      'Misal: switch kharab hai, wire short hai...';

  @override
  String get inspHintPlumbing => 'Misal: pipe leak hai, drain block hai...';

  @override
  String get inspHintAc => 'Misal: AC cooling nahi kar raha, gas leak hai...';

  @override
  String get inspHintCarpentry =>
      'Misal: darwaza theek se band nahi hota, hinge toot gaya...';

  @override
  String get workerCompleteProfile => 'Profile mukammal karein';

  @override
  String get workerApprovalRequired =>
      'Kaam milne se pehle profile ki manzoori zaroori hai.';

  @override
  String get workerCompleteProfileDetails =>
      'Apni profile ki details complete karain.';

  @override
  String get workerCompleteProfileWhy =>
      'Profile complete honay ke baad hi aap jobs ke liye apply ya hire ho sakenge.';

  @override
  String earningJobsCompleted(int count) {
    return '$count jobs completed';
  }

  @override
  String get bookingStatusLive => 'Jaari';

  @override
  String get bookingStatusAssigned => 'Assign';

  @override
  String get bookingStatusCompleted => 'Mukammal';

  @override
  String get bookingStatusExpired => 'Khatam';

  @override
  String get jobStatusEnRoute => 'Raaste Mein';

  @override
  String get jobStatusInProgress => 'Kaam Jaari';

  @override
  String get workerJobDetailsTitle => 'Kaam Ki Tafseel';

  @override
  String get workerJobLoadFailed => 'Kaam load nahi ho saka.';

  @override
  String get workerStandardDirectHireNote =>
      'Yeh ek Standard kaam hai. Client aap ko seedha hire kar sakta hai — offer bhejne ki zaroorat nahi.';

  @override
  String get workerBidNow => 'Abhi Bid Lagayein';

  @override
  String get workerReportSubmittedWaiting =>
      'Report bhej di gayi. Client ke quote accept karne ya inspection ke baad kaam band karne ka intezaar hai.';

  @override
  String get workerClientSection => 'Client';

  @override
  String get workerPostedBy => 'Kaam dene wala';

  @override
  String get workerCategoryLabel => 'Category';

  @override
  String get workerTitleLabel => 'Unwan';

  @override
  String get workerTimeSlotLabel => 'Waqt ka slot';

  @override
  String get workerTimelineSection => 'Timeline';

  @override
  String get workerTimelineScheduled => 'Tay shuda';

  @override
  String get workerTimelineStarted => 'Shuru hua';

  @override
  String get workerEstimatedLabel => 'Takhmeena';

  @override
  String get workerFeeStatusLabel => 'Status';

  @override
  String get workerCancelJob => 'Kaam cancel karein';

  @override
  String get workerCancelJobTitle => 'Ye kaam cancel karein?';

  @override
  String get workerCancelJobBody =>
      'Baraye meherbani client ko batayein ke aap kyun cancel kar rahe hain.';

  @override
  String get workerCancelOwnReasonHint => 'Apni wajah likhein (zaroori)';

  @override
  String get workerKeepJob => 'Kaam rakhein';

  @override
  String get workerYesCancel => 'Ji haan, cancel karein';

  @override
  String get workerCancelReasonEmergency => 'Emergency aa gayi';

  @override
  String get workerCancelReasonTooFar => 'Location bohat door hai';

  @override
  String get workerCancelReasonNoTools =>
      'Zaroori tools ya parts available nahi';

  @override
  String get workerCancelReasonSchedule => 'Waqt ya schedule ka issue';

  @override
  String get workerCancelReasonCustomer => 'Customer ya site se mutaliq issue';

  @override
  String get workerCancelReasonOther => 'Deegar';

  @override
  String get workerAttachmentsVideos => 'Videos';

  @override
  String get workerAttachmentsVoiceNotes => 'Voice notes';

  @override
  String get workerStatusHistory => 'Status ki history';

  @override
  String get workerMarkAsCompleted => 'Mukammal mark karein';

  @override
  String get workerClientReview => 'Client ka review';

  @override
  String workerReviewRatingOutOfFive(int rating) {
    return '$rating/5';
  }

  @override
  String workerApproximateArea(String city) {
    return 'Takhmeeni ilaqa: $city';
  }

  @override
  String get workerApproximateAreaUnavailable =>
      'Takhmeeni ilaqa available nahi';

  @override
  String workerDistanceLabel(String distance) {
    return 'Faasla: $distance';
  }

  @override
  String get workerExactAddressAfterHire =>
      'Is kaam ke liye hire hone ke baad hi sahi address aur map nazar aayega.';

  @override
  String get workerRoadRouteNotConfigured =>
      'Road route abhi set nahi hua. Raaste ke liye Google Maps khola ja raha hai.';

  @override
  String get workerLocationPermissionDenied =>
      'Location ki ijazat nahi di gayi.';

  @override
  String get workerDirectionsLocationFailed =>
      'Raaste ke liye aap ki location nahi mil saki.';

  @override
  String get workerArrivedAtJobLocation =>
      'Aap kaam ki jagah pahunch gaye hain.';

  @override
  String get workerYourLocation => 'Aap ki location';

  @override
  String get workerCityLabel => 'Sheher';

  @override
  String get workerClientAddress => 'Client ka address';

  @override
  String get workerPinnedJobLocation => 'Map par lagi kaam ki jagah';

  @override
  String get workerPinnedOnMap => 'Map par laga hua';

  @override
  String get workerGettingLocation => 'Location li ja rahi hai...';

  @override
  String get workerDirections => 'Raasta';

  @override
  String get workerOpenInMaps => 'Maps mein kholein';

  @override
  String get workerDirectionsActive => 'Raasta chal raha hai';

  @override
  String get workerUploadFailed =>
      'Upload nahi ho saka. Dobara koshish karein.';

  @override
  String get workerCompleteHighlightedFields =>
      'Baraye meherbani neeche nishan zad khane mukammal karein.';

  @override
  String get workerProfileSaveFailed =>
      'Profile save nahi ho saki. Dobara koshish karein.';

  @override
  String get workerProfileSubmitted => 'Profile manzoori ke liye bhej di gayi.';

  @override
  String get workerCompleteAllRequired =>
      'Bhejne se pehle tamam zaroori khane mukammal karein.';

  @override
  String get workerProfileLoadFailed => 'Profile load nahi ho saki.';

  @override
  String get workerFullLegalName => 'Mukammal qanooni naam';

  @override
  String get workerLegalNameHint => 'Jaisa aap ke CNIC par likha hai';

  @override
  String get workerLegalNameRequired => 'Mukammal qanooni naam zaroori hai.';

  @override
  String get workerCnicNumber => 'CNIC number';

  @override
  String get workerCnicInvalid => 'CNIC is tarah likhein: 12345-1234567-1';

  @override
  String get workerMainSkill => 'Buniyadi hunar';

  @override
  String get workerMainSkillNotSelected => 'Muntakhab nahi kiya gaya';

  @override
  String get workerChangeSkill => 'Tabdeel karein';

  @override
  String get workerMainSkillRequired =>
      'Baraye meherbani apna buniyadi hunar muntakhab karein.';

  @override
  String get workerExperienceYears => 'Tajurba (saalon mein)';

  @override
  String get workerExperienceHint => 'misal ke taur par 3';

  @override
  String get workerExperienceInvalid =>
      'Saalon ki durust tadaad likhein (0 ya us se ziyada).';

  @override
  String get workerResidentialAddress => 'Rihaishi address';

  @override
  String get workerResidentialAddressHint =>
      'Makan number, gali, ilaqa, sheher';

  @override
  String get workerResidentialAddressRequired =>
      'Rihaishi address zaroori hai.';

  @override
  String get workerIdentityDocuments => 'Shanakhti dastawezat';

  @override
  String get workerCnicFront => 'CNIC ka agla rukh';

  @override
  String get workerCnicBack => 'CNIC ka pichla rukh';

  @override
  String get workerLiveSelfie => 'Live selfie';

  @override
  String get workerDocumentRequired => 'Zaroori hai';

  @override
  String get workerAgreements => 'Muahiday';

  @override
  String get workerConfirmLegalName =>
      'Main tasdeeq karta hoon ke mera qanooni naam mere CNIC ke mutabiq hai.';

  @override
  String get workerViewAgreement => 'Muahida dekhein';

  @override
  String get workerConfirmationRequired => 'Ye tasdeeq zaroori hai.';

  @override
  String get workerSubmitForApproval => 'Manzoori ke liye bhejein';

  @override
  String workerAgreementVersion(String version) {
    return 'Version $version';
  }

  @override
  String get workerOnboardingSubmitted => 'Jaizey ke liye bhej di gayi';

  @override
  String get workerOnboardingChangesRequired => 'Tabdeeliyan darkar hain';

  @override
  String get workerOnboardingApproved => 'Manzoor shuda';

  @override
  String get workerOnboardingDraft => 'Draft';

  @override
  String get workerRoleBadge => 'Ustaad';

  @override
  String workerMainSkillWithName(String skill) {
    return 'Buniyadi hunar: $skill';
  }

  @override
  String get workerNoMainSkillYet =>
      'Abhi koi buniyadi hunar muntakhab nahi kiya gaya';

  @override
  String get workerProfileApproval => 'Profile ki manzoori';

  @override
  String get inspHintFallback => 'Maslan batayein aap ko kya mila';

  @override
  String get bidAmountRequired => 'Baraye meherbani bid ki raqam likhein.';

  @override
  String get bidAmountRange =>
      'Bid ki raqam 100 se 500,000 ke darmiyan honi chahiye.';

  @override
  String get bidSubmitted => 'Bid bhej di gayi!';

  @override
  String get bidSubmitFailed => 'Bid nahi bheji ja saki.';

  @override
  String get workerViewJobDetails => 'Tafseel dekhein';

  @override
  String get workerSendOffer => 'Offer bhejein';

  @override
  String get workerChangeOffer => 'Offer badlein';

  @override
  String get workerOnboardingSubmittedBody =>
      'Aap ki profile admin ke jaizey mein hai.';

  @override
  String get workerOnboardingChangesRequiredBody =>
      'Aap ki profile mein tabdeeli darkar hai — tafseel dekhein.';

  @override
  String get workerOnboardingRejectedBody =>
      'Aap ki profile mustarad ho gayi — wajah dekhein.';

  @override
  String get workerProfileIncomplete => 'Profile namukammal';

  @override
  String get inspFormLabourCostRequired => 'Mazdoori ki laagat *';

  @override
  String get inspFormNotesOptional => 'Notes (ikhtiyari)';

  @override
  String get inspFormPartName => 'Purze ka naam';

  @override
  String get inspFormQty => 'Tadaad';

  @override
  String get inspFormUnitPrice => 'Fi adad qeemat';

  @override
  String get inspFormWarrantyOptional => 'Warranty / guarantee (ikhtiyari)';

  @override
  String get inspFormPartsTotal => 'Purzon ki kul raqam';

  @override
  String get inspFormLabour => 'Mazdoori';

  @override
  String get inspFormMicPermanentlyDenied =>
      'Microphone ki ijazat mustaqil band hai. Ise Settings mein on karein.';

  @override
  String get inspFormMicDenied => 'Microphone ki ijazat nahi di gayi.';

  @override
  String get errorTimeout =>
      'Connection ka waqt khatam ho gaya. Dobara koshish karein.';

  @override
  String get errorRequestCancelled => 'Request cancel kar di gayi.';

  @override
  String get errorInvalidRequest =>
      'Kuch tafseelat theek nahi hain. Inhein check kar ke dobara koshish karein.';

  @override
  String get errorSessionExpired =>
      'Aap ka session khatam ho gaya hai. Dobara login karein.';

  @override
  String get errorForbidden => 'Aap ko is kaam ki ijazat nahi hai.';

  @override
  String get errorNotFound => 'Yeh ab available nahi hai.';

  @override
  String get errorConflict =>
      'Yeh pehle hi update ho chuka hai. Refresh kar ke dobara koshish karein.';

  @override
  String get errorTooManyRequests =>
      'Bohot zyada koshishein ho gayi hain. Thori dair baad dobara koshish karein.';

  @override
  String get errorServer =>
      'Server mein masla hai. Kuch dair baad dobara koshish karein.';

  @override
  String get errorSmsSendFailed =>
      'SMS bhejne mein masla hua. Dobara koshish karein.';

  @override
  String get errorInspectorBusy =>
      'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. Neeche se koi aur Ustaad choose karein.';

  @override
  String get errorPhoneIsWorker =>
      'Ye mobile number Ustaad account ke saath registered hai.';

  @override
  String get errorPhoneIsClient =>
      'Ye number Client account ke saath registered hai.';

  @override
  String get errorUnknown => 'Kuch masla ho gaya. Dobara koshish karein.';

  @override
  String get authForgotPasswordTitle => 'Password bhool\ngaye?';

  @override
  String get authSetNewPasswordTitle => 'Naya password\nset karein';

  @override
  String get authEnterCodeSentToNumber =>
      'Apne number par bheja gaya code darj karein.';

  @override
  String get authForgotPasswordClientOnly =>
      'Sirf Client account ke liye. Registered number par code bheja jayega.';

  @override
  String get authForgotPasswordWorkerOnly =>
      'Sirf Ustaad account ke liye. Registered number par code bheja jayega.';

  @override
  String get authErrorCodeSendFailed => 'Code bhejne mein masla hua.';

  @override
  String get authErrorPasswordChangeFailed => 'Password badal nahi saka.';

  @override
  String get authErrorLoginFailed => 'Login nahi ho saka.';

  @override
  String get authErrorRegisterFailed => 'Account nahi ban saka.';

  @override
  String get authLoginWithOtp => 'OTP se login karein';

  @override
  String get authHintExampleFullName => 'Muhammad Ali Khan';

  @override
  String get notificationsBannerFallbackTitle => 'Notification';

  @override
  String get legalEnglishOnlyNotice =>
      'Yeh qanooni document filhal sirf English mein available hai.';

  @override
  String myBookingsTotalCount(int count) {
    return 'Kul $count';
  }

  @override
  String get workerBidJobFallbackTitle => 'Kaam';

  @override
  String get navHome => 'Home';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navChats => 'Chats';

  @override
  String get inspectionRowIssueFound => 'Jo masla mila';

  @override
  String get inspectionRowNotes => 'Notes';

  @override
  String get inspectionBadgeAwaitingDecision =>
      'Report jama ho gayi — faisle ka intezar';

  @override
  String get inspectionBadgeQuoteAccepted =>
      'Quote manzoor — marammat jari hai';

  @override
  String get inspectionBadgeFindingAnother =>
      'Doosra Ustaad talash kiya ja raha hai — bidding ke liye khula';

  @override
  String inspStripClosedFeeOnlyWithAmount(String fee) {
    return 'Inspection ke baad band — client sirf inspection fee dega: $fee';
  }

  @override
  String get inspStripClosedFeeOnly =>
      'Inspection ke baad band — client sirf inspection fee dega.';

  @override
  String get inspStripRepairCompletedFeeWaived =>
      'Marammat mukammal — inspection fee maaf.';

  @override
  String get inspStripQuoteAcceptedFeeWaived =>
      'Quote manzoor — inspection fee maaf. Marammat jari hai.';

  @override
  String get inspStripReportSubmitted =>
      'Inspection report jama ho gayi — marammat jari rakhne ke liye quote dekhein ya inspection ke baad band karein.';

  @override
  String get inspStripUstaadHired => 'Ustaad hire ho gaya';

  @override
  String get inspStripBookedChooseUstaad =>
      'Inspection book ho gaya — Ustaad chunein';

  @override
  String chooseChipCancelRate(int rate) {
    return '$rate% cancel';
  }

  @override
  String get locationCurrentFailed => 'Maujooda location hasil nahi ho saki.';

  @override
  String get locationResolveFailed => 'Muntakhib location maloom nahi ho saki.';

  @override
  String get locationOutsideKarachi =>
      'Yeh location Karachi ke service area se bahar hai.';

  @override
  String postJobVideoTooLong(int seconds) {
    return 'Video $seconds second ya us se kam honi chahiye.';
  }

  @override
  String get postJobLocationRetrieveFailed =>
      'Location hasil nahi ho saki. Dobara koshish karein.';

  @override
  String get postJobSelectOption => 'Jari rakhne ke liye ek option chunein.';

  @override
  String get postJobDescribeIssue =>
      'Baraye meherbani batayein ke kya theek karwana hai.';

  @override
  String get postJobSelectStandardService =>
      'Kam az kam ek standard service chunein.';

  @override
  String get postJobSelectArrivalWindow =>
      'Baraye meherbani aane ka waqt chunein.';

  @override
  String get postJobSelectUrgencyWindow =>
      'Baraye meherbani foran ka waqt chunein.';

  @override
  String get postJobEnterAddress => 'Apna pata darj karein.';

  @override
  String get postJobAddAddressToContinue =>
      'Jari rakhne ke liye apna service pata shamil karein.';

  @override
  String get postJobNearbyNotifiedNow =>
      'Qareebi Ustaadon ko foran ittila di jati hai.';

  @override
  String get postJobInspectionNotAvailable =>
      'Is service ke liye inspection available nahi hai.';

  @override
  String get postJobInspectionHeroStep1 => 'Ustaad aa kar khud check karega';

  @override
  String get postJobInspectionHeroStep2 =>
      'Kaam shuru karne se pehle rate clear hoga.';

  @override
  String get postJobInspectionHeroStep3 =>
      'Pasand aaye to kaam karwa lein, warna sirf inspection fee dein.';

  @override
  String get postJobStandardTotalFinal =>
      'Total amount final hai — koi bidding nahi. Aap next step par Ustaad choose karenge.';

  @override
  String get postJobHowInspectionStep1 => 'Inspection fee fixed hai.';

  @override
  String get postJobHowInspectionStep2 =>
      'Ustaad aata hai, masla maloom karta hai, aur app mein marammat ka fixed quote deta hai.';

  @override
  String get postJobHowInspectionStep3 =>
      'Uska quote accept kar ke jari rakhein, ya doosre Ustaadon se bids lein — aap ki marzi.';

  @override
  String get cancelReasonNoLongerNeeded => 'Ab service ki zarurat nahi';

  @override
  String get cancelReasonBookedByMistake => 'Booking ghalti se ho gayi';

  @override
  String get cancelReasonProblemSolved => 'Masla khud hal ho gaya';

  @override
  String get cancelReasonTimingNotSuitable => 'Waqt ya tareekh munasib nahi';

  @override
  String get cancelReasonPriceNotSuitable => 'Qeemat ya budget munasib nahi';

  @override
  String get cancelReasonCannotReachUstaad => 'Ustaad se rabta nahi ho raha';

  @override
  String get cancelReasonUstaadRunningLate => 'Ustaad bohat dair kar raha hai';

  @override
  String get cancelReasonOther => 'Dusri wajah';

  @override
  String get bookingAgreedPrice => 'Tay shuda qeemat';

  @override
  String get inspRepairHintElectrical =>
      'Maslan MCB badlein aur socket ki wiring dobara karein';

  @override
  String get inspRepairHintPlumbing =>
      'Maslan leak hota pipe badlein aur naya valve lagayein';

  @override
  String get inspRepairHintAc => 'Maslan gas bharwayein aur capacitor badlein';

  @override
  String get inspRepairHintCarpentry =>
      'Maslan qabzay badlein aur darwazay ka frame seedha karein';

  @override
  String get inspRepairHintPainting =>
      'Maslan putty aur primer lagayein, phir emulsion ke do coat';

  @override
  String get inspRepairHintFallback =>
      'Maslan ise theek karne ke liye kya kaam darkar hai';

  @override
  String get inspPartHintElectrical => 'Maslan MCB, switch, socket';

  @override
  String get inspPartHintPlumbing => 'Maslan pipe, valve, tonti';

  @override
  String get inspPartHintAc => 'Maslan gas refill, capacitor, compressor';

  @override
  String get inspPartHintCarpentry =>
      'Maslan qabzay, plywood, darwazay ka frame';

  @override
  String get inspPartHintPainting => 'Maslan primer, putty, emulsion';

  @override
  String get inspHintPainting =>
      'Maslan paint ukhar raha hai, deewar par seelan...';

  @override
  String get agreementViewerTitle => 'Muahida';

  @override
  String get agreementLoadFailed =>
      'Muahida load nahi ho saka. Dobara koshish karein.';

  @override
  String get agreementUnavailableForTrade =>
      'Aap ke muntakhab kaam ke liye abhi koi manzoor shuda muahida mojood nahi hai. Bara-e-karam HandyGo support se rabta karein.';

  @override
  String agreementLanguageChip(String language) {
    return 'Muahide ki zubaan: $language';
  }

  @override
  String agreementTradeChip(String trade) {
    return 'Kaam: $trade';
  }

  @override
  String get agreementLanguageNotice =>
      'Yeh manzoor shuda legal muahida filhaal sirf Roman Urdu mein mojood hai.';

  @override
  String get agreementLanguageRomanUrdu => 'Roman Urdu';

  @override
  String get agreementLanguageEnglish => 'English';

  @override
  String get agreementLanguageUrdu => 'Urdu';

  @override
  String get agreementAcceptCheckbox =>
      'Main ne yeh muahida parh liya hai aur ise qabool karta hoon.';

  @override
  String get agreementViewBeforeAccepting =>
      'Qabool karne se pehle muahida khol kar parhein.';

  @override
  String get agreementAcceptRequired => 'Yeh muahida qabool karna lazmi hai.';

  @override
  String get agreementTradeChangedReopen =>
      'Aap ka main kaam tabdeel ho gaya hai. Trade wala muahida dobara khol kar qabool karein.';

  @override
  String get agreementsLoadFailed => 'Muahide load nahi ho sake.';

  @override
  String get agreementsAllThreeRequired =>
      'Submit karne se pehle teenon muahide khol kar qabool karein.';

  @override
  String get workerFatherName => 'Walid ka naam';

  @override
  String get workerFatherNameRequired => 'Walid ka naam lazmi hai.';

  @override
  String get workerDateOfBirth => 'Tareekh-e-Paidaish';

  @override
  String get workerDateOfBirthHint =>
      'Apni tareekh-e-paidaish muntakhab karein';

  @override
  String get workerDateOfBirthRequired => 'Tareekh-e-paidaish lazmi hai.';

  @override
  String get workerEmergencyContact => 'Emergency Contact (ikhtiyari)';

  @override
  String get workerEmergencyContactHint => 'Naam aur phone number';

  @override
  String get workerAcceptedAgreementsTitle => 'Mere Muahide';

  @override
  String get workerAcceptedAgreementsEmpty =>
      'Aap ne abhi tak koi muahida qabool nahi kiya.';

  @override
  String agreementAcceptedOn(String date) {
    return 'Qabool kiya gaya: $date';
  }

  @override
  String agreementAcceptanceId(String id) {
    return 'Acceptance ID: $id';
  }

  @override
  String get agreementDownload => 'Download';

  @override
  String get agreementDownloadInProgress => 'Muahida download ho raha hai...';

  @override
  String agreementDownloadSaved(String path) {
    return 'Muahida save ho gaya: $path';
  }

  @override
  String get agreementDownloadFailed =>
      'Muahida download nahi ho saka. Dobara koshish karein.';

  @override
  String get workerSubmittedDetails => 'Jama karai gayi tafseelat';

  @override
  String get workerViewSubmittedDetails => 'Jama karai gayi tafseelat dekhein';

  @override
  String get workerDetailsReadOnlyNotice =>
      'Aap ki profile manzoor ho chuki hai. Yeh tafseelat lock hain aur tabdeel nahi ki ja sakti.';

  @override
  String get workerVerificationStatus => 'Tasdeeq ki haalat';

  @override
  String get workerMainTrade => 'Markazi hunar';
}
