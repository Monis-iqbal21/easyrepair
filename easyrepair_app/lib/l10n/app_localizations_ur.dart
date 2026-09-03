// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get languageSectionTitle => 'سیٹنگز';

  @override
  String get languageRowLabel => 'زبان';

  @override
  String get languageSheetTitle => 'اپنی زبان منتخب کریں';

  @override
  String get languageOnboardingTitle => 'زبان منتخب کریں';

  @override
  String get languageOnboardingSubtitle =>
      'آپ کس زبان میں ایپ استعمال کرنا چاہتے ہیں؟';

  @override
  String get languageOptionRomanUrduSubtitle => 'آسان الفاظ، سمجھنے میں آسان';

  @override
  String get languageOptionEnglishSubtitle => 'پوری ایپ انگریزی میں';

  @override
  String get authRoleQuestion => 'آپ کیا کرنا چاہتے ہیں؟';

  @override
  String get authRoleSubtitle => 'اپنا آپشن منتخب کریں';

  @override
  String get authRoleClientTitle => 'گھر کا کام کروانا ہے';

  @override
  String get authRoleClientSubtitle =>
      'مرمت، سروس یا انسٹالیشن کے لیے استاد بک کریں۔';

  @override
  String get authRoleWorkerTitle => 'میں استاد ہوں';

  @override
  String get authRoleWorkerSubtitle => 'کام لینے کے لیے رجسٹر کریں۔';

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
      'اپنا نام اور موبائل نمبر لکھیں۔ ہم تصدیقی کوڈ بھیجیں گے۔';

  @override
  String get authClientPasswordSubtitle =>
      'اپنے موبائل نمبر اور پاس ورڈ سے آگے بڑھیں۔';

  @override
  String get authOtpWillBeSentNotice => 'اس نمبر پر تصدیقی کوڈ بھیجا جائے گا۔';

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
  String get authClientLoginHeading => 'خوش آمدید';

  @override
  String get authClientLoginSubtitle =>
      'موبائل نمبر اور پاس ورڈ سے لاگ ان کریں۔';

  @override
  String get authClientPasswordShow => 'دکھائیں';

  @override
  String get authClientPasswordHide => 'چھپائیں';

  @override
  String get authClientForgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get authClientLoginButton => 'لاگ ان';

  @override
  String get authClientLoginAction => 'لاگ ان کریں';

  @override
  String get authClientOtpLoginButton => 'OTP سے لاگ ان کریں';

  @override
  String get authClientLoginWithPassword => 'پاس ورڈ سے لاگ ان کریں';

  @override
  String get authClientNoAccountFound =>
      'اس نمبر کا کلائنٹ اکاؤنٹ نہیں ملا۔ اکاؤنٹ بنائیں۔';

  @override
  String get ustaadLoginBrandSubtitle => 'HandyGo کے ساتھ کام کریں';

  @override
  String get ustaadLoginSubtitle => 'کام لینے کے لیے اپنے نمبر سے لاگ ان کریں۔';

  @override
  String get ustaadLoginInfoBox =>
      'ہر استاد کا شناختی کارڈ تصدیق ہوتا ہے۔ رجسٹریشن کے بعد 24 گھنٹے میں منظوری۔';

  @override
  String get ustaadLoginNewPrompt => 'نئے استاد ہیں؟';

  @override
  String get ustaadLoginRegisterAction => 'رجسٹر کریں';

  @override
  String get ustaadRegisterHeader => 'استاد رجسٹریشن';

  @override
  String ustaadStepIndicator(int current, int total) {
    return 'مرحلہ $current / $total';
  }

  @override
  String get ustaadStep1Heading => 'اپنی تفصیلات دیں';

  @override
  String get ustaadFullNameLabel => 'پورا نام · شناختی کارڈ کے مطابق';

  @override
  String get ustaadFullNameHint => 'مثلاً: کامران شیخ';

  @override
  String get ustaadCnicLabel => 'شناختی کارڈ نمبر';

  @override
  String get ustaadCreatePasswordLabel => 'پاس ورڈ بنائیں';

  @override
  String get ustaadSendOtpButton => 'OTP بھیجیں';

  @override
  String get ustaadVerificationHeader => 'تصدیق';

  @override
  String get ustaadStep2Heading => 'اپنا نمبر تصدیق کریں';

  @override
  String ustaadStep2Subtitle(String phone) {
    return 'کوڈ +92 $phone پر بھیجا گیا · مرحلہ 2 / 4';
  }

  @override
  String get ustaadVerifyButton => 'تصدیق کریں';

  @override
  String get ustaadStep3Heading => 'پروفائل اور کام';

  @override
  String get ustaadPhotoTitle => 'اپنی تصویر لگائیں';

  @override
  String get ustaadPhotoSubtitle => 'گاہک کو یہی تصویر دکھتی ہے';

  @override
  String get ustaadPhotoPlaceholder => 'تصویر';

  @override
  String get ustaadPhotoUpload => 'اپ لوڈ';

  @override
  String get ustaadSkillsTitle => 'آپ کیا کام کرتے ہیں؟';

  @override
  String get ustaadExperienceTitle => 'کتنے سال کا تجربہ؟';

  @override
  String get ustaadAddressTitle => 'گھر کا پتہ';

  @override
  String get ustaadAddressSubtitle =>
      'جہاں آپ رہتے ہیں — تصدیق کے لیے۔ گاہک کو یہ کبھی نہیں دکھتا۔';

  @override
  String get ustaadAreaLabel => 'علاقہ';

  @override
  String get ustaadAreaHint => 'مثلاً: صدر';

  @override
  String get ustaadStreetLabel => 'گلی';

  @override
  String get ustaadHouseLabel => 'گھر / فلیٹ نمبر';

  @override
  String get ustaadLandmarkLabel => 'نشانی · اختیاری';

  @override
  String get ustaadLandmarkHint => 'مسجد کے سامنے';

  @override
  String get ustaadStep4Heading => 'شناختی کارڈ کی تصدیق';

  @override
  String get ustaadStep4Subtitle => 'مرحلہ 4 / 4 · یہ گاہک کو کبھی نہیں دکھتا';

  @override
  String get ustaadCnicFrontTitle => 'شناختی کارڈ سامنے';

  @override
  String get ustaadCnicFrontSubtitle => 'صاف تصویر، پورا کارڈ';

  @override
  String get ustaadCnicBackTitle => 'شناختی کارڈ پیچھے';

  @override
  String get ustaadCnicBackSubtitle => 'پیچھے کا رخ';

  @override
  String get ustaadUploadAction => 'اپ لوڈ';

  @override
  String get ustaadPendingBadge => 'باقی ہے';

  @override
  String get ustaadUploadedBadge => 'لگ گیا';

  @override
  String get ustaadAgreementsLabel => 'معاہدے';

  @override
  String get ustaadReadAction => 'پڑھیں ←';

  @override
  String get ustaadSubmitButton => 'تصدیق کے لیے بھیجیں';

  @override
  String get workerPendingReviewTitle => 'پروفائل جائزے میں ہے';

  @override
  String get workerPendingReviewBody =>
      'آپ کی تفصیلات تصدیق کے لیے بھیج دی گئی ہیں۔ منظوری کے بعد آپ کام لینا شروع کر سکتے ہیں۔';

  @override
  String get ustaadForgotHeading => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get ustaadForgotSubtitle => 'اپنا رجسٹرڈ موبائل نمبر لکھیں۔';

  @override
  String get ustaadForgotOtpHeading => 'کوڈ کی تصدیق کریں';

  @override
  String ustaadForgotOtpBody(String phone) {
    return 'کوڈ +92 $phone پر بھیجا گیا۔';
  }

  @override
  String get ustaadForgotNewPasswordHeading => 'نیا پاس ورڈ بنائیں';

  @override
  String get ustaadConfirmPasswordLabel => 'پاس ورڈ کی تصدیق کریں';

  @override
  String get ustaadChangePasswordButton => 'پاس ورڈ تبدیل کریں';

  @override
  String get ustaadResetSuccessTitle => 'پاس ورڈ تبدیل ہو گیا';

  @override
  String get ustaadResetSuccessBody => 'اب اپنے نئے پاس ورڈ سے لاگ ان کریں۔';

  @override
  String get ustaadGoToLoginButton => 'لاگ ان پر جائیں';

  @override
  String get ustaadNewPasswordLabel => 'نیا پاس ورڈ';

  @override
  String get ustaadAgreementGeneralSummary =>
      'کام کا طریقہ، وقت کی پابندی، یونیفارم اور شناخت، اور ریٹ کے اصول۔';

  @override
  String get ustaadAgreementTradeSummary =>
      'آپ کے کام کے مطابق — پرزے، گریڈ اور حفاظت کے اصول۔';

  @override
  String get ustaadAgreementBackgroundSummary =>
      'شناختی کارڈ، پولیس ویریفیکیشن اور حوالہ جات کی جانچ کی اجازت۔';

  @override
  String get authClientOtpHelp =>
      'OTP آپ کے رجسٹرڈ موبائل نمبر پر بھیجا جائے گا۔';

  @override
  String get authClientNewHere => 'نئے ہیں؟';

  @override
  String get authClientRegisterSubtitle =>
      'صرف ایک بار۔ اس کے بعد موبائل نمبر اور پاس ورڈ سے لاگ ان کریں۔';

  @override
  String get authClientCreatePasswordLabel => 'پاس ورڈ بنائیں';

  @override
  String get authClientPasswordHint => 'کم از کم 8 حروف';

  @override
  String get authClientConfirmPasswordLabel => 'پاس ورڈ کی تصدیق کریں';

  @override
  String get authClientConfirmPasswordHint => 'پاس ورڈ دوبارہ لکھیں';

  @override
  String get authClientAddressNotice =>
      'ابھی پتہ درکار نہیں۔ پہلی بکنگ کے وقت پوچھیں گے۔';

  @override
  String get authClientHaveAccount => 'پہلے سے اکاؤنٹ ہے؟';

  @override
  String get authClientVerifyHeading => 'موبائل نمبر کی تصدیق کریں';

  @override
  String get authClientResendPrompt => 'کوڈ نہیں ملا؟';

  @override
  String get authClientResendAction => 'دوبارہ بھیجیں';

  @override
  String get authClientVerifyButton => 'تصدیق کرکے اکاؤنٹ بنائیں';

  @override
  String get authClientReadyHeading => 'اکاؤنٹ تیار ہے';

  @override
  String get authClientReadySubtitle =>
      'HandyGo میں خوش آمدید۔ اب آپ سروس بک کر سکتے ہیں۔';

  @override
  String get authClientAccountCardLabel => 'آپ کا اکاؤنٹ';

  @override
  String get authClientRoleCustomer => 'کسٹمر';

  @override
  String authClientVerifySentTo(int count, String phone) {
    return '$count ہندسوں کا کوڈ +92 $phone پر بھیجا گیا۔';
  }

  @override
  String get authClientCreateAccountTitle => 'اکاؤنٹ بنائیں';

  @override
  String get authClientFullNameLabel => 'پورا نام';

  @override
  String get authClientSendOtpButton => 'OTP بھیجیں';

  @override
  String get authClientGoHome => 'ہوم پر جائیں';

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
  String chatNewMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نئے پیغامات',
      one: '1 نیا پیغام',
    );
    return '$_temp0';
  }

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
      'کام کی اپ ڈیٹس، ریویوز اور دیگر معلومات یہاں نظر آئیں گی۔';

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
  String get chatCouldNotOpenDialer => 'فون ڈائلر نہیں کھل سکا';

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
  String get authOr => 'یا پھر';

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
  String get postJobAddPhotoVideo => 'تصویر/ویڈیو';

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
      'عمارت/مکان، اپارٹمنٹ/فلیٹ، منزل/یونٹ، علاقہ، کراچی';

  @override
  String get postJobAddLocationFirst =>
      'آگے بڑھنے کے لیے اپنی لوکیشن شامل کریں۔';

  @override
  String get postJobVoiceAndPhotos => 'وائس نوٹ اور تصاویر';

  @override
  String get postJobVoiceAttached => 'وائس نوٹ لگا دیا گیا';

  @override
  String get postJobAttachmentHelper =>
      'تصاویر یا 30 سیکنڈ تک کی ویڈیو شامل کریں۔ زیادہ سے زیادہ 4 اٹیچمنٹس۔';

  @override
  String postJobAttachmentCount(int count) {
    return '$count/4 اٹیچمنٹس شامل کی گئی ہیں';
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
  String get postJobInspectionFeeTitle => 'معائنہ فیس';

  @override
  String get postJobInspectionDetailsPageTitle => 'مسئلہ بتائیں';

  @override
  String postJobInspectionDetailsStepIndicator(String service) {
    return 'مرحلہ 3 / 4 · $service';
  }

  @override
  String get postJobInspectionDetailsFeeLabel => 'معائنہ فیس';

  @override
  String get postJobInspectionDetailsFeeWaiver =>
      'مرمت منظور کرنے پر یہ فیس معاف ہے — آپ صرف مرمت کی قیمت ادا کریں گے';

  @override
  String get postJobInspectionProblemHeading =>
      'آپ کو کیا نظر آ رہا ہے؟ · ضروری';

  @override
  String get postJobInspectionVoiceHeading => 'وائس نوٹ · اختیاری';

  @override
  String get postJobInspectionRecordPrompt =>
      'دبائیں اور اپنے الفاظ میں بتائیں';

  @override
  String get postJobInspectionAddPhoto => 'تصویر شامل کریں';

  @override
  String postJobInspectionAttachmentCount(int count) {
    return '$count / 4 اٹیچمنٹس';
  }

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
  String get postJobInspectionFeeLower => 'معائنہ فیس';

  @override
  String get postJobInspectionFeeLoadFailed => 'معائنہ فیس لوڈ نہیں ہو سکی۔';

  @override
  String get postJobHowInspectionWorks => 'معائنہ کیسے ہوتا ہے';

  @override
  String get postJobWhatDoYouSee => 'آپ کو کیا مسئلہ نظر آ رہا ہے؟ (ضروری)';

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
  String get postJobStepLaneSelection => 'قسم منتخب کریں';

  @override
  String get postJobStepDetails => 'تفصیلات';

  @override
  String get postJobStepTimeSelection => 'وقت کا انتخاب';

  @override
  String postJobStepIndicator(int current, int total, String title) {
    return 'مرحلہ $total میں سے $current  ·  $title';
  }

  @override
  String get postJobProgressBarTime => 'وقت';

  @override
  String get postJobRecommendedBadge => 'بہتر';

  @override
  String get trackLiveBadge => 'لائیو';

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
  String get serviceAppliancesRepair => 'گھریلو آلات کی مرمت';

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
  String clientHomeHello(String name) {
    return 'ہیلو، $name';
  }

  @override
  String get clientHomeGuest => 'دوست';

  @override
  String get clientHomeLocating => 'مقام تلاش کیا جا رہا ہے…';

  @override
  String get clientHomeUrgentTitle => 'ابھی مدد چاہیے؟';

  @override
  String get clientHomeUrgentPromise =>
      'فوراً استاد بھیجتے ہیں — وہی ریٹ، کوئی اضافی چارج نہیں';

  @override
  String get clientHomeWhatNeedsDoing => 'کیا کروانا ہے؟';

  @override
  String get clientHomeTrustMessage =>
      'ہر استاد کا شناختی کارڈ تصدیق شدہ · ریٹ پہلے طے ہوتا ہے';

  @override
  String get clientHomeSupportUnavailable =>
      'HandyGo سپورٹ ابھی دستیاب نہیں۔ دوبارہ کوشش کریں۔';

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
  String get locationSearchHint => 'جگہ، علاقہ یا نشانی تلاش کریں…';

  @override
  String get locationNoSuggestions =>
      'کوئی ملتی جگہ نہیں ملی۔ قریبی نشانی یا علاقے کا نام لکھیں۔';

  @override
  String get locationSearchFailed =>
      'فی الحال جگہ کی تجاویز دستیاب نہیں۔ آپ پن خود منتقل کر سکتے ہیں۔';

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
  String get postJobGpsPrefix => 'لوکیشن پن کر دی گئی';

  @override
  String get postJobBookService => 'بک کریں';

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
  String get bookingInspectionCompletedBy => 'معائنہ مکمل کرنے والے';

  @override
  String get bookingWorkBeingCompletedBy => 'کام مکمل کرنے والے';

  @override
  String get bookingInspectionAndRepairBy => 'معائنہ اور مرمت کرنے والے';

  @override
  String get bookingAssignedWorker => 'مقرر کردہ استاد';

  @override
  String get bookingDetailsTitle => 'بکنگ کی تفصیلات';

  @override
  String get bookingNoAddressProvided => 'کوئی پتہ نہیں دیا گیا';

  @override
  String get bookingAttachments => 'ویڈیوز اور تصاویر';

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
  String get bookingInspectionCharges => 'معائنہ چارجز';

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
  String get bookingSeeWorkerBids => 'استادوں کی آفرز دیکھیں';

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
  String get trackInspectionInProgress => 'معائنہ جاری ہے';

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
  String get trackStepInspectionInProgress => 'معائنہ جاری';

  @override
  String get trackStepReportSubmitted => 'رپورٹ جمع';

  @override
  String get trackStepClosedAfterInspection => 'معائنے کے بعد بند';

  @override
  String get trackStepQuoteAccepted => 'کوٹ منظور';

  @override
  String get trackStepReviewed => 'ریویو ہو گیا';

  @override
  String get trackStepWorkInProgress => 'کام جاری';

  @override
  String get trackStepReviewPending => 'ریویو باقی';

  @override
  String get trackJobProgress => 'کام کہاں تک پہنچا';

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
  String get discoveryBidsLoadFailed => 'آفرز لوڈ نہیں ہو سکیں۔';

  @override
  String get discoveryNoBidsYet => 'ابھی کوئی آفر نہیں';

  @override
  String discoveryPendingCount(int count) {
    return '$count باقی';
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
    return '$name کی $price کی آفر منظور کریں؟';
  }

  @override
  String get discoveryInspectionFeeSeparate =>
      'معائنہ فیس الگ ادا کی جاتی ہے۔\nنئے اُستاد کا آفر الگ چارج ہوگا۔';

  @override
  String get discoveryBidLabourOnlyNote =>
      'یہ بولی صرف مزدوری کے اخراجات کے لیے ہے۔ پرزے اور سامان آپ کی منظوری سے الگ خریدے یا چارج کیے جائیں گے۔';

  @override
  String get discoveryBidInspectionBasedNote =>
      'یہ بولی انسپیکشن رپورٹ کے مطابق ہے اور اس میں مزدوری اور رپورٹ کیے گئے کام کے لیے درکار پرزے یا سامان شامل ہیں۔';

  @override
  String get discoveryWorkerHired => 'استاد کامیابی سے ہائر ہو گئے';

  @override
  String get discoveryHireFailed => 'استاد ہائر نہیں ہو سکے۔';

  @override
  String get discoveryInspectedThisJob => 'اس کام کا معائنہ کیا';

  @override
  String get discoveryTheirQuote => 'ان کا کوٹ';

  @override
  String get discoveryInspectionCompletedByThis =>
      'معائنہ اسی استاد نے مکمل کیا۔';

  @override
  String get discoveryViewInspectionReport => 'معائنہ رپورٹ دیکھیں';

  @override
  String get discoveryHireAgain => 'دوبارہ ہائر کریں';

  @override
  String discoveryHireAgainNamed(String name) {
    return '$name کو دوبارہ ہائر کریں؟';
  }

  @override
  String get discoveryOriginalQuoteContinues =>
      'وہ اپنے اصل معائنہ کوٹ پر ہی کام جاری رکھیں گے۔';

  @override
  String get discoveryWorkersWillAppear =>
      'درخواست دینے والے استاد یہاں نظر آئیں گے۔\nتھوڑی دیر بعد دوبارہ دیکھیں۔';

  @override
  String get discoveryTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get postJobInspectionReportSectionTitle => 'انسپکشن رپورٹ (اختیاری)';

  @override
  String get postJobAttachInspectionReport => 'پچھلی انسپکشن رپورٹ منسلک کریں';

  @override
  String get postJobAttachInspectionHint =>
      'پہلے کی تشخیص شیئر کر کے بولی دینے والوں کو کام سمجھنے میں مدد دیں۔';

  @override
  String get postJobChangeInspectionReport => 'رپورٹ تبدیل کریں';

  @override
  String get postJobSelectInspectionReport => 'انسپکشن رپورٹ منتخب کریں';

  @override
  String get postJobNoInspectionReports =>
      'اس سروس کے لیے کوئی پچھلی انسپکشن رپورٹ دستیاب نہیں۔';

  @override
  String get postJobInspectionReportsFailed =>
      'آپ کی انسپکشن رپورٹس لوڈ نہیں ہو سکیں۔';

  @override
  String get postJobInspectionReportCleared =>
      'سروس تبدیل ہونے کی وجہ سے منسلک انسپکشن رپورٹ ہٹا دی گئی۔';

  @override
  String get inspectionReportTitle => 'معائنہ رپورٹ';

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
  String get inspectionCloseAfterInspection => 'معائنے کے بعد بند کریں';

  @override
  String get inspectionAcceptQuoteConfirmTitle =>
      'کوٹ منظور کر کے مرمت جاری رکھیں؟';

  @override
  String get inspectionCloseConfirmTitle => 'معائنے کے بعد بند کریں؟';

  @override
  String get inspectionAcceptQuoteConfirmBody =>
      'یہی استاد مرمت جاری رکھیں گے۔ معائنہ فیس معاف ہے — آپ صرف مرمت کا کوٹ ادا کریں گے۔';

  @override
  String get inspectionCloseConfirmBody =>
      'آپ سے صرف معائنہ فیس لی جائے گی۔ کام مکمل شدہ نشان زد ہو جائے گا۔';

  @override
  String get inspectionClosedAfterInspection => 'معائنے کے بعد بند کر دیا گیا۔';

  @override
  String get inspectionQuoteAcceptedRepairInProgress =>
      'کوٹ منظور — مرمت جاری ہے۔';

  @override
  String get inspectionActionFailed => 'کارروائی ناکام۔ دوبارہ کوشش کریں۔';

  @override
  String get inspectionFindAnotherConfirmTitle => 'دوسرا استاد تلاش کریں؟';

  @override
  String get inspectionFindAnotherConfirmBody =>
      'تصدیق کرنے پر معائنہ مکمل ہو جائے گا اور معائنہ فیس لی جائے گی۔ آپ کا کام دوبارہ لائیو ہو جائے گا تاکہ دوسرے استاد اپنے ریٹ بھیج سکیں۔';

  @override
  String get inspectionBadge => 'معائنہ';

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
    return 'معائنہ فیس $price';
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
  String get chooseNearestFirst => 'قریب والے پہلے';

  @override
  String chooseAvailableCount(int count) {
    return '$count دستیاب';
  }

  @override
  String get chooseViewProfile => 'پروفائل دیکھیں';

  @override
  String get chooseNoReviews => 'کوئی ریویو دستیاب نہیں';

  @override
  String get chooseCnicVerified => 'شناختی کارڈ تصدیق شدہ';

  @override
  String get chooseCnicVerifiedUstaad => 'شناختی کارڈ تصدیق شدہ استاد';

  @override
  String chooseExperienceYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years سال تجربہ',
      one: '$years سال تجربہ',
    );
    return '$_temp0';
  }

  @override
  String get choosePhoneLabel => 'فون نمبر';

  @override
  String get chooseProfileLoadFailed => 'اس استاد کی پروفائل لوڈ نہیں ہو سکی۔';

  @override
  String get myBookingsLoadFailed =>
      'آپ کی بکنگز لوڈ نہیں ہو سکیں۔ دوبارہ کوشش کریں۔';

  @override
  String get myBookingsTitle => 'بکنگز';

  @override
  String get myBookingsSubtitle => 'تمام بکنگز ایک جگہ';

  @override
  String get myBookingsEmptyActiveTitle => 'کوئی کام جاری نہیں';

  @override
  String get myBookingsEmptyCompletedTitle => 'ابھی کوئی کام مکمل نہیں ہوا';

  @override
  String get myBookingsEmptyCancelledTitle => 'کوئی منسوخ بکنگ نہیں';

  @override
  String get myBookingsEmptyActiveHelper =>
      'نیا کام بک کریں تو یہاں لائیو اسٹیٹس ملے گا۔';

  @override
  String get myBookingsEmptyHistoryHelper =>
      'آپ جب بھی کام کروائیں گے، مکمل ریکارڈ یہاں رہے گا۔';

  @override
  String get myBookingsEmptyCta => 'نیا کام بک کریں';

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
  String get bookingCardLaneBidding => 'بولی';

  @override
  String get bookingCardDetails => 'تفصیل ←';

  @override
  String get bookingCardPaymentAfterWork => 'نقد — کام کے بعد';

  @override
  String get bookingCardPaymentPending => 'ادائیگی باقی ہے';

  @override
  String get bookingCardNothingPaid => 'کچھ ادا نہیں کیا';

  @override
  String bookingCardPartialPayment(String received, String remaining) {
    return '$received ادا · $remaining باقی';
  }

  @override
  String get bookingCardNoPaymentTaken => 'کوئی ادائیگی نہیں لی گئی';

  @override
  String get bookingCardStatusOnTheWay => 'راستے میں';

  @override
  String get bookingCardStatusWaitingQuote => 'قیمت کا انتظار';

  @override
  String get bookingCardRomanActiveFilter => 'کام جاری';

  @override
  String get bookingCardRomanAssigned => 'استاد مقرر ہو گیا';

  @override
  String get bookingCardRomanWorkInProgress => 'کام جاری ہے';

  @override
  String get bookingCardRomanRejected => 'بکنگ مسترد';

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
  String get reviewSelectRating => 'پہلے ستارے منتخب کریں۔';

  @override
  String get reviewSubmitSuccess => 'شکریہ! آپ کا ریویو جمع ہو گیا۔';

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
    return '$name کو اس معائنے کے لیے ہائر کیا گیا ہے';
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
  String get inspectionFeePaid => 'معائنہ فیس ادا ہو گئی';

  @override
  String inspectionFeePaidAmount(Object amount) {
    return 'معائنہ فیس ادا ہو گئی: $amount';
  }

  @override
  String get inspectionFeeWaivedOff => 'معائنہ فیس معاف کر دی گئی';

  @override
  String get inspectionFeeNotPaid => 'معائنہ فیس ادا نہیں ہوئی';

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
  String get discoveryLoadingBids => 'آفرز لوڈ ہو رہی ہیں...';

  @override
  String get discoveryBidsLoadFailedShort => 'آفرز لوڈ نہیں ہو سکیں';

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
    return '$count باقی آفرز · قیمت کے حساب سے ترتیب';
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
  String get workerActionStartInspection => 'معائنہ شروع کریں';

  @override
  String get workerActionStartWork => 'کام شروع کریں';

  @override
  String get workerActionFillReport => 'معائنہ رپورٹ بھریں';

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
  String get workerSuccessInspectionStarted => 'معائنہ شروع ہو گیا۔';

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
  String workerHelloName(String name) {
    return 'ہیلو $name';
  }

  @override
  String get workerTodaysEarnings => 'کمائی';

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
  String get workerFindNewWork => 'نئی شکایات';

  @override
  String get workerViewNewJobs => 'دیکھیں';

  @override
  String workerNewComplaintsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نئی',
      one: '1 نئی',
    );
    return '$_temp0';
  }

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
  String get workerOnlyInspectionCompleted => 'صرف معائنہ مکمل ہوا';

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
  String get workerNoAppliedJobs => 'ابھی کوئی درخواست نہیں دی';

  @override
  String get workerNewRequestsHere => 'نئی درخواستیں یہاں نظر آئیں گی';

  @override
  String get workerCompletedJobsHere => 'مکمل کام یہاں نظر آئیں گے';

  @override
  String get workerCancelledJobsHere => 'منسوخ کام یہاں نظر آئیں گے';

  @override
  String get workerAppliedJobsHere =>
      'جن کاموں پر آپ نے آفر بھیجی ہے وہ یہاں نظر آئیں گے';

  @override
  String get workerAcceptToGetStarted => 'شروع کرنے کے لیے کوئی بکنگ قبول کریں';

  @override
  String get workerFilterCancelled => 'منسوخ';

  @override
  String get workerFilterAllWork => 'نئے کام';

  @override
  String get workerFilterMyOffers => 'میری آفرز';

  @override
  String get workerFilterNoOfferSent => 'آفر نہیں بھیجی';

  @override
  String get bidPlaceABid => 'آفر بھیجیں';

  @override
  String get bidChatWithClient => 'کلائنٹ سے چیٹ کریں';

  @override
  String get bidLiveBids => 'لائیو آفرز';

  @override
  String get bidAreaNotAvailable => 'علاقہ دستیاب نہیں';

  @override
  String get bidExactAddressAfterAccept =>
      'کلائنٹ کے آپ کی آفر قبول کرنے پر مکمل پتہ بھیج دیا جاتا ہے۔';

  @override
  String get bidStatusAccepted => 'منظور';

  @override
  String get bidStatusRejected => 'مسترد';

  @override
  String get bidStatusPending => 'باقی';

  @override
  String get bidYourCurrentBid => 'آپ کی موجودہ آفر';

  @override
  String get bidSubmit => 'آفر جمع کریں';

  @override
  String get bidUpdate => 'آفر اپ ڈیٹ کریں';

  @override
  String get bidPlaceYourBid => 'اپنی آفر بھیجیں';

  @override
  String get bidUpdateYourBid => 'اپنی آفر اپ ڈیٹ کریں';

  @override
  String bidCanUpdateIn(String seconds) {
    return 'آپ $seconds سیکنڈ بعد آفر اپ ڈیٹ کر سکتے ہیں۔';
  }

  @override
  String get bidCanUpdateNow => 'آپ ابھی اپنی آفر اپ ڈیٹ کر سکتے ہیں۔';

  @override
  String get bidAmountLabel => 'آفر کی رقم (PKR) *';

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
  String get bidBeFirstToBid => 'اس کام پر سب سے پہلے آفر بھیجیں';

  @override
  String get earningBidding => 'آفرز';

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
  String get inspFormRecommendedRepair => 'بہتر طریقہ';

  @override
  String get inspFormRecommendedRepairRequired => 'بہتر طریقہ *';

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
      'اگر کسٹمر مرمت جاری رکھواتا ہے تو معائنہ فیس نہیں لی جائے گی۔';

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
  String get workerReportSubmittedWaiting =>
      'رپورٹ بھیج دی گئی۔ کلائنٹ کے کوٹ قبول کرنے یا معائنے کے بعد کام بند کرنے کا انتظار ہے۔';

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
  String get workerIdentityDocuments => 'شناختی کاغذات';

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
  String get bidAmountRequired => 'براہِ کرم آفر کی رقم لکھیں۔';

  @override
  String get bidAmountRange =>
      'آفر کی رقم 100 سے 500,000 کے درمیان ہونی چاہیے۔';

  @override
  String get bidSubmitted => 'آفر بھیج دی گئی!';

  @override
  String get bidSubmitFailed => 'آفر نہیں بھیجی جا سکی۔';

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
  String get errorOtpResendTooSoon =>
      'دوبارہ او ٹی پی منگوانے سے پہلے تھوڑی دیر انتظار کریں۔';

  @override
  String get errorInspectorBusy =>
      'معائنہ کرنے والا استاد ابھی دوسرے کام میں مصروف ہے۔ نیچے سے کوئی اور استاد منتخب کریں۔';

  @override
  String get errorPhoneNotRegistered => 'یہ نمبر رجسٹرڈ نہیں ہے۔';

  @override
  String get errorPhoneAlreadyRegistered => 'یہ نمبر پہلے سے رجسٹرڈ ہے۔';

  @override
  String get errorUnknown => 'کچھ گڑبڑ ہو گئی۔ دوبارہ کوشش کریں۔';

  @override
  String get errorOfflineActionBlocked =>
      'انٹرنیٹ کنکشن موجود نہیں ہے۔ جاری رکھنے کے لیے انٹرنیٹ سے منسلک ہوں۔';

  @override
  String get offlineCachedDataBanner =>
      'آف لائن — محفوظ شدہ معلومات دکھائی جا رہی ہیں';

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
      'دوسرا استاد تلاش کیا جا رہا ہے — آفرز کے لیے کھلا';

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
      'یہ قیمت حتمی ہے۔ دروازے پر نہیں بدلے گی۔';

  @override
  String get postJobHowInspectionStep1 => 'معائنہ فیس مقرر ہے۔';

  @override
  String get postJobHowInspectionStep2 =>
      'استاد آتا ہے، مسئلہ معلوم کرتا ہے، اور ایپ میں مرمت کی مقررہ قیمت دیتا ہے۔';

  @override
  String get postJobHowInspectionStep3 =>
      'اس کی قیمت قبول کر کے جاری رکھیں، یا دوسرے استادوں سے آفرز لیں — آپ کی مرضی۔';

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
    return 'تصدیقی نمبر: $id';
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
  String get customerAgreementTitle =>
      'کسٹمر شرائط، بکنگ قواعد اور پرائیویسی نوٹس';

  @override
  String get customerAgreementCheckboxLabel =>
      'میں نے یہ شرائط اور پرائیویسی نوٹس پڑھ لیے ہیں اور ان سے رضامند ہوں۔';

  @override
  String get customerAgreementIAgree => 'میں رضامند ہوں';

  @override
  String get customerAgreementViewDownloadPdf =>
      'پی ڈی ایف دیکھیں/ڈاؤن لوڈ کریں';

  @override
  String get customerAgreementSaveFailed =>
      'منظوری محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get customerAgreementEffectiveDateNote =>
      'یہ آپ کی نیچے دی گئی منظوری کی تاریخ سے مؤثر ہے۔';

  @override
  String get customerAgreementHistoryTitle => 'منظور شدہ معاہدے';

  @override
  String get customerAgreementHistoryEmptyTitle =>
      'ابھی کوئی معاہدہ منظور نہیں کیا';

  @override
  String get customerAgreementHistoryEmptyHelper =>
      'آپ کے منظور کیے ہوئے کسٹمر معاہدے یہاں نظر آئیں گے۔';

  @override
  String get clientStateLoading => 'لوڈ ہو رہا ہے…';

  @override
  String get clientStateErrorTitle => 'یہ لوڈ نہیں ہو سکا';

  @override
  String get trackLoading => 'لائیو ٹریکنگ لوڈ ہو رہی ہے…';

  @override
  String get reportCheckingExisting => 'پہلے سے موجود رپورٹ چیک ہو رہی ہے…';

  @override
  String get postJobInspectionReportsEmptyTitle =>
      'ابھی کوئی انسپکشن رپورٹ نہیں';

  @override
  String get postJobInspectionReportsErrorTitle => 'انسپکشن رپورٹس دستیاب نہیں';

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

  @override
  String get workerSuspendedMessage =>
      'آپ کا HandyGo اکاؤنٹ معطل کر دیا گیا ہے۔ مزید معلومات کے لیے سپورٹ سے رابطہ کریں۔';

  @override
  String get workerSuspendedContactSupport => 'سپورٹ سے رابطہ کریں';

  @override
  String get earningGrossEarnings => 'مزدوری';

  @override
  String get earningCommissionLabel => 'HandyGo کمیشن (18%)';

  @override
  String get earningUstaadEarnings => 'منافع';

  @override
  String get earningCommissionStatusLabel => 'کمیشن اسٹیٹس';

  @override
  String get earningStatusPaid => 'ادا شدہ';

  @override
  String get notificationsPermissionOffMessage =>
      'نوٹیفکیشن بند ہیں۔ بکنگ اور جاب اپ ڈیٹس حاصل کرنے کے لیے نوٹیفکیشن کی اجازت دیں۔';

  @override
  String get notificationsAllowAction => 'نوٹیفکیشن کی اجازت دیں';

  @override
  String get locationPermissionRequiredMessage => 'لوکیشن کی اجازت ضروری ہے۔';

  @override
  String get locationAllowAction => 'لوکیشن کی اجازت دیں';

  @override
  String get locationPermanentlyDeniedMessage =>
      'لوکیشن کی اجازت سیٹنگز سے فعال کریں۔';

  @override
  String get locationGpsOffMessage =>
      'آپ کے فون کی لوکیشن/GPS بند ہے۔ جاری رکھنے کے لیے اسے آن کریں۔';

  @override
  String get locationTurnOnAction => 'لوکیشن آن کریں';

  @override
  String get locationUnavailableRetryMessage =>
      'لوکیشن حاصل نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get locationStaleMessage =>
      'آپ کی موجودہ لوکیشن ضروری ہے۔ براہ کرم اپنی لوکیشن اپ ڈیٹ کریں۔';

  @override
  String get cameraPermissionDeniedMessage =>
      'جاری رکھنے کے لیے کیمرہ کی اجازت دیں۔';

  @override
  String get galleryPermissionDeniedMessage =>
      'تصاویر منتخب کرنے کے لیے اجازت دیں۔';

  @override
  String get unsupportedFileMessage =>
      'یہ فائل سپورٹڈ نہیں ہے۔ دوسری فائل منتخب کریں۔';

  @override
  String get fileTooLargeMessage =>
      'فائل کا سائز زیادہ ہے۔ چھوٹی فائل منتخب کریں۔';

  @override
  String get commonChooseAgain => 'دوبارہ منتخب کریں';

  @override
  String get pageNotAvailableTitle => 'صفحہ دستیاب نہیں ہے';

  @override
  String get pageNotAvailableBody => 'یہ صفحہ اب دستیاب نہیں ہے۔';

  @override
  String get commonGoHome => 'ہوم پر جائیں';

  @override
  String get resourceBookingUnavailable => 'یہ بکنگ اب دستیاب نہیں ہے۔';

  @override
  String get resourceJobUnavailable => 'یہ جاب اب آپ کو اسائن نہیں ہے۔';

  @override
  String get resourceConversationUnavailable => 'یہ چیٹ اب دستیاب نہیں ہے۔';

  @override
  String get goToMyBookingsAction => 'میری بکنگز پر جائیں';

  @override
  String get goToMyJobsAction => 'میری جابز پر جائیں';

  @override
  String get goToChatsAction => 'چیٹس پر جائیں';

  @override
  String get settingsSupportTitle => 'سپورٹ';

  @override
  String get settingsAboutTitle => 'HandyGo کے بارے میں';

  @override
  String get settingsAppVersionTitle => 'ایپ ورژن';

  @override
  String get aboutAppDescription =>
      'HandyGo کلائنٹس کو قریبی تصدیق شدہ اُستادوں سے گھر کی مرمت اور دیکھ بھال کی خدمات سے جوڑتا ہے۔';

  @override
  String get aboutWebsiteLabel => 'ویب سائٹ';

  @override
  String get cashPaymentLater => 'بعد میں';

  @override
  String get cashPaymentTitle => 'نقد ادائیگی کی تصدیق کریں';

  @override
  String get cashPaymentQuestion => 'آپ نے کتنی نقد ادائیگی کی؟';

  @override
  String cashPaymentExpected(Object amount) {
    return 'بکنگ کی متوقع رقم: $amount';
  }

  @override
  String get cashPaymentInputLabel => 'ادا کی گئی نقد رقم (PKR)';

  @override
  String get cashPaymentInputHint => 'پورے روپے لکھیں، 0 بھی لکھ سکتے ہیں';

  @override
  String get cashPaymentRequired => 'اصل ادا کی گئی نقد رقم لکھیں۔';

  @override
  String get cashPaymentWholeRupees => 'اعشاریہ کے بغیر پوری PKR رقم لکھیں۔';

  @override
  String get cashPaymentNegative => 'رقم منفی نہیں ہو سکتی۔';

  @override
  String get cashPaymentExceedsBookingPrice =>
      'رقم بکنگ کی قیمت سے زیادہ نہیں ہو سکتی۔';

  @override
  String get cashPaymentConfirmedTitle => 'نقد ادائیگی کی تصدیق ہو گئی';

  @override
  String cashPaymentPaid(Object amount) {
    return 'ادا کی گئی نقد رقم: $amount';
  }

  @override
  String cashPaymentExpectedReceipt(Object amount) {
    return 'متوقع رقم: $amount';
  }

  @override
  String cashPaymentShortfall(Object amount) {
    return 'باقی رقم: $amount';
  }

  @override
  String cashPaymentReference(Object reference) {
    return 'تصدیقی حوالہ: $reference';
  }

  @override
  String get cashPaymentContinueReview => 'جائزہ دیں';

  @override
  String get cashPaymentConflict =>
      'ادائیگی پہلے کسی دوسری رقم کے ساتھ تصدیق ہو چکی ہے۔ درستگی کے لیے HandyGo سپورٹ سے رابطہ کریں۔';

  @override
  String get cashPaymentFailed =>
      'نقد ادائیگی کی تصدیق نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get cashPaymentReviewBlocked =>
      'استاد کو جائزہ دینے سے پہلے نقد ادائیگی کی تصدیق کریں۔';

  @override
  String get postJobSelectBookingTypeFirst => 'پہلے عام یا فوری منتخب کریں۔';

  @override
  String get postJobInspectionDescriptionRequired =>
      'آگے بڑھنے سے پہلے نظر آنے والا مسئلہ لکھیں۔';

  @override
  String get postJobCustomVoiceRequired =>
      'کسٹم کام کے لیے آگے بڑھنے سے پہلے وائس نوٹ شامل کریں۔';

  @override
  String get postJobCompleteAddressBeforeSaving =>
      'محفوظ کرنے سے پہلے مکمل پتہ اور نقشے کا پن لگائیں۔';

  @override
  String get postJobDay => 'دن';

  @override
  String get postJobTomorrow => 'کل';

  @override
  String get postJobCustomVoiceAndPhotos =>
      'وائس نوٹ (ضروری) اور تصاویر/ویڈیو (اختیاری)';

  @override
  String get postJobInspectionVoiceAndPhotos =>
      'وائس نوٹ اور تصاویر/ویڈیو (اختیاری)';

  @override
  String get postJobInspectionRateNote =>
      'ابھی صرف آنے کی فیس دیں۔ مرمت کا نرخ کام شروع ہونے سے پہلے ایپ میں آئے گا۔';

  @override
  String get postJobBiddingRateNote =>
      'استاد مکمل مرمت کا نرخ بھیجیں گے۔ آپ کا قبول کردہ نرخ حتمی ہے اور دروازے پر تبدیل نہیں ہوگا۔';

  @override
  String get savedAddresses => 'محفوظ پتے';

  @override
  String get savedAddressForNextTime => 'یہ پتہ اگلی بار کے لیے محفوظ کریں';

  @override
  String get savedAddressOffice => 'دفتر';

  @override
  String get savedAddressName => 'محفوظ پتے کا نام';

  @override
  String get savedAddressNameRequired => 'نام درج کریں۔';

  @override
  String get savedAddressCustomNameTitle => 'اس محفوظ پتے کا نام رکھیں';

  @override
  String get savedAddressRenameTitle => 'محفوظ پتے کا نام بدلیں';

  @override
  String get savedAddressRenameConflict =>
      'یہ نام پہلے سے استعمال ہو رہا ہے۔ کوئی دوسرا نام منتخب کریں۔';

  @override
  String get savedAddressSaved => 'پتہ محفوظ ہو گیا۔';

  @override
  String get savedAddressUse => 'پتہ استعمال کریں';

  @override
  String get savedAddressUpdateWithCurrent =>
      'موجودہ پتے اور پن سے اپ ڈیٹ کریں';

  @override
  String get savedAddressRename => 'نام بدلیں';

  @override
  String get savedAddressDeleteTitle => 'محفوظ پتہ حذف کریں؟';

  @override
  String savedAddressDeleteBody(String name) {
    return '$name کو محفوظ پتوں سے حذف کریں؟';
  }

  @override
  String savedAddressUpdateTitle(String name) {
    return '$name اپ ڈیٹ کریں؟';
  }

  @override
  String savedAddressUpdateBody(String name) {
    return '$name پہلے سے محفوظ ہے۔ اس پتے سے اپ ڈیٹ کریں؟';
  }

  @override
  String get savedAddressUpdateAction => 'پتہ اپ ڈیٹ کریں';

  @override
  String get postJobAddressIntro =>
      'پہلی بکنگ ہے — پتہ ایک بار لکھ دیں۔ اگلی بار کے لیے محفوظ کیا جا سکتا ہے۔';

  @override
  String get postJobCompleteAddressLabel => 'سروس کا مکمل پتہ لکھیں';

  @override
  String get postJobAddressLandmarkHelper =>
      'عمارت/مکان، اپارٹمنٹ/فلیٹ، منزل/یونٹ اور قریبی نشانی لکھیں۔';

  @override
  String get postJobAddressResolving => 'اس پتے کو نقشے پر تلاش کیا جا رہا ہے…';

  @override
  String get postJobAddressUnresolved =>
      'یہ پتہ نہیں ملا۔ مزید تفصیل لکھیں یا نقشے پر منتخب کریں۔';

  @override
  String get postJobAddressRequired => 'آگے بڑھنے سے پہلے پتہ درج کریں۔';

  @override
  String get postJobMapPreviewEmpty => 'نقشہ — پن لگانے کے لیے دبائیں';

  @override
  String get postJobLanePageTitle => 'بکنگ کا آپشن منتخب کریں';

  @override
  String postJobLaneStepIndicator(String service) {
    return 'مرحلہ 2 / 4 · $service';
  }

  @override
  String get postJobLaneFixedTitle => 'مقررہ قیمت کی سروسز';

  @override
  String get postJobLaneFixedSubtitle => 'سروس اور قیمت پہلے سے مقرر ہیں';

  @override
  String get postJobLaneFixedBody => 'بکنگ سے پہلے حتمی قیمت دیکھیں۔';

  @override
  String get postJobLaneFixedAction => 'سروسز اور قیمتیں دیکھیں ←';

  @override
  String get postJobLaneFixedCta => 'سروسز اور قیمتیں دیکھیں';

  @override
  String get postJobFixedPricePageTitle => 'مقررہ قیمت کی سروسز';

  @override
  String postJobFixedPriceStepIndicator(String service) {
    return 'مرحلہ 3 / 4 · $service';
  }

  @override
  String get postJobLaneInspectionTitle => 'معائنہ';

  @override
  String get postJobLaneInspectionSubtitle => 'مسئلہ سمجھ نہیں آ رہا؟';

  @override
  String postJobLaneInspectionFeeBody(String fee) {
    return '$fee معائنہ فیس — ابھی نہیں، معائنے کے بعد۔';
  }

  @override
  String get postJobLaneInspectionReportBody =>
      'استاد مسئلہ چیک کر کے رپورٹ اور حتمی نرخ ایپ میں بھیجے گا۔';

  @override
  String postJobLaneInspectionWaiverBody(String fee) {
    return 'کام کروا لیا تو $fee معائنہ فیس معاف ہوگی اور صرف مرمت کی قیمت دینی ہوگی۔';
  }

  @override
  String get postJobLaneInspectionAction => 'معائنہ بک کریں ←';

  @override
  String get postJobLaneInspectionCta => 'معائنہ بک کریں';

  @override
  String get postJobLaneCustomTitle => 'کسٹم کام';

  @override
  String get postJobLaneCustomBody =>
      'چھوٹی مرمت، فٹنگ یا تبدیلی کی تفصیل اور تصاویر بھیجیں۔';

  @override
  String get postJobLaneCustomRatesBody => 'قریبی استاد اپنی قیمتیں بھیجیں گے۔';

  @override
  String get postJobLaneCustomAction => 'کام کی تفصیل دیں ←';

  @override
  String get postJobLaneCustomCta => 'کام کی تفصیل دیں';

  @override
  String get postJobLanePriceNote =>
      'قیمت صرف ایپ میں نیا نرخ بھیجنے کے بعد بدل سکتی ہے — گھر پہنچنے کے بعد نہیں۔';

  @override
  String get postJobLaneChooseCta => 'بکنگ کا آپشن منتخب کریں';

  @override
  String get postJobCustomRequestTitle => 'آپ کی درخواست';

  @override
  String postJobCustomRequestStepIndicator(String service) {
    return 'مرحلہ 3 / 4 · $service';
  }

  @override
  String get postJobCustomWorkTitleLabel => 'کیا کام کروانا ہے؟';

  @override
  String get postJobCustomRequired => 'ضروری';

  @override
  String get postJobCustomWorkTitleHint => 'مثلاً سیلنگ فین لگوانا ہے';

  @override
  String get postJobCustomDetailsLabel => 'تفصیل سے بتائیں';

  @override
  String get postJobCustomOptional => 'اختیاری';

  @override
  String get postJobCustomDetailsHint => 'کوئی اور مددگار بات شامل کریں';

  @override
  String get postJobCustomVoiceLabel => 'وائس نوٹ';

  @override
  String get postJobCustomAddPhotos => 'تصاویر شامل کریں';

  @override
  String postJobCustomMediaAttached(int count) {
    return '$count / 4 تصاویر · وائس نوٹ منسلک ہے';
  }

  @override
  String postJobCustomMediaPending(int count) {
    return '$count / 4 تصاویر · وائس نوٹ منسلک نہیں';
  }

  @override
  String get postJobCustomHelperNote =>
      'تصاویر اور وائس نوٹ سے استاد کو کام سب سے بہتر سمجھ آتا ہے۔ تکنیکی تفصیل کی ضرورت نہیں۔';

  @override
  String get postJobCustomReportLabel => 'پچھلی انسپکشن رپورٹ';

  @override
  String get postJobCustomAttachReport => 'رپورٹ منسلک کریں';

  @override
  String get postJobInspectionReportAttached => 'رپورٹ منسلک ہے';

  @override
  String aboutVersionValue(String version, String build) {
    return 'ورژن $version ($build)';
  }

  @override
  String get reportProblemTitle => 'مسئلہ رپورٹ کریں';

  @override
  String get reportProblemHelper => 'جو مسئلہ ہوا ہے اسے منتخب کریں۔';

  @override
  String get reportProblemAction => 'مسئلہ رپورٹ کریں';

  @override
  String get reportIssueWorkQuality => 'کام کا معیار درست نہیں تھا';

  @override
  String get reportIssuePricePayment => 'قیمت یا ادائیگی کا مسئلہ';

  @override
  String get reportIssueUstaadBehaviour => 'استاد کا رویہ';

  @override
  String get reportIssueDamage => 'کسی چیز کو نقصان پہنچا';

  @override
  String get reportIssuePartMaterial => 'پرزے یا مواد کا مسئلہ';

  @override
  String get reportIssueWarrantyRework => 'وارنٹی یا دوبارہ کام درکار ہے';

  @override
  String get reportIssueOther => 'کچھ اور';

  @override
  String get reportOtherLabel => 'بتائیں کیا ہوا';

  @override
  String get reportSubmit => 'رپورٹ جمع کریں';

  @override
  String get reportSelectAtLeastOneError => 'کم از کم ایک مسئلہ منتخب کریں۔';

  @override
  String get reportOtherRequiredError => 'دوسرے مسئلے کی تفصیل بتائیں۔';

  @override
  String get reportSubmittedTitle => 'رپورٹ جمع ہو گئی';

  @override
  String get reportSubmittedBody => 'HandyGo ٹیم اس کا جائزہ لے گی۔';

  @override
  String get reportYourReportTitle => 'آپ کی رپورٹ';

  @override
  String get reportSubmittedAtLabel => 'جمع کرائی گئی';

  @override
  String get reportReferenceLabel => 'حوالہ';

  @override
  String get reportLookupFailed => 'رپورٹ ابھی لوڈ نہیں ہو سکی۔';

  @override
  String get reportActionFailed => 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get reportTalkToSupport => 'سپورٹ سے بات کریں';

  @override
  String get reportHumanRequestedConfirmation =>
      'سپورٹ ٹیم کو اطلاع دے دی گئی ہے۔';

  @override
  String get reportStatusPending => 'زیرِ التوا';

  @override
  String get reportStatusInReview => 'زیرِ جائزہ';

  @override
  String get reportStatusResolved => 'حل شدہ';

  @override
  String get reportAlreadyExists => 'اس بکنگ کے لیے رپورٹ پہلے سے موجود ہے۔';

  @override
  String get reportBackToBooking => 'بکنگ پر واپس';

  @override
  String get bookingSchedule => 'شیڈول';

  @override
  String get bookingPrice => 'قیمت';

  @override
  String get bookingPaymentTitle => 'ادائیگی';

  @override
  String get bookingPaymentUnpaid => 'ادائیگی باقی';

  @override
  String get bookingPaymentPartial => 'کچھ ادا شدہ';

  @override
  String get bookingStatusSectionLabel => 'بکنگ';

  @override
  String get bookingHireNewUstaad => 'نیا استاد منتخب کریں';

  @override
  String get bookingJobClosedTitle => 'کام مکمل ہو گیا';

  @override
  String get bookingJobClosedBody =>
      'یہ کام بند ہو چکا ہے۔ آپ اب بھی استاد کو ریویو دے سکتے ہیں یا مسئلہ رپورٹ کر سکتے ہیں۔';

  @override
  String get bookingReportLabel => 'رپورٹ';

  @override
  String get bookingPaymentReceived => 'وصول شدہ رقم';

  @override
  String get bookingPaymentRemaining => 'باقی';

  @override
  String get bookingPaymentExpected => 'متوقع رقم';

  @override
  String get timelineStepWorkConfirmed => 'کام کنفرم ہو گیا';

  @override
  String get timelineStepInspectionConfirmed => 'انسپیکشن کنفرم ہو گئی';

  @override
  String get timelineStepUstaadHired => 'استاد ہائر ہو گیا';

  @override
  String get timelineStepWorkStarted => 'کام شروع';

  @override
  String get timelineStepInspectionStarted => 'انسپیکشن شروع';

  @override
  String get timelineStepWorkCompleted => 'کام مکمل';

  @override
  String get timelineStepInspectionCompleted => 'انسپیکشن مکمل';

  @override
  String get timelineWaitingForUstaadTitle => 'استاد کا انتظار';

  @override
  String get timelineWaitingForUstaadBody =>
      'جیسے ہی آپ اس کام کے لیے استاد ہائر کریں گے، کام شروع ہو جائے گا۔';

  @override
  String get ustaadIdentityTitle => 'شناختی تفصیلات';

  @override
  String get ustaadLiveSelfieSubtitle => 'ابھی لیں — چہرہ صاف نظر آنا چاہیے';

  @override
  String get reportDetailsHelper =>
      'مختصر تفصیل سے ہماری ٹیم آپ کی شکایت پر جلد کارروائی کر سکتی ہے۔';

  @override
  String get reportDetailsRequiredError =>
      'براہِ کرم مسئلہ کم از کم 10 حروف میں بیان کریں۔';

  @override
  String get workerPaymentPartsLabel => 'پرزہ جات کی رقم';

  @override
  String get workerPaymentLabourLabel => 'مزدوری موصول';

  @override
  String get workerPaymentAwaitingTitle => 'ادائیگی ابھی درج نہیں ہوئی';

  @override
  String get workerPaymentAwaitingBody =>
      'رقم درج ہوتے ہی آپ کو معلوم ہو جائے گا کہ کتنی رقم موصول ہوئی۔';

  @override
  String get workerReportPaymentAction => 'کم پیسہ ملا؟';

  @override
  String get workerReportPaymentTitle => 'آپ کو اصل میں کتنی رقم ملی؟';

  @override
  String get workerReportPaymentHelper =>
      'جو نقد رقم گاہک نے دی وہ لکھیں۔ باقی حساب HandyGo خود کرے گا۔';

  @override
  String get workerReportPaymentFieldLabel => 'موصول شدہ رقم';

  @override
  String get workerReportPaymentInvalidError =>
      'صفر یا اس سے زیادہ مکمل روپے کی رقم لکھیں۔';

  @override
  String get workerReportPaymentSubmit => 'ادائیگی درج کریں';

  @override
  String get workerReportPaymentSuccess =>
      'ادائیگی درج ہو گئی۔ باقی رقم کے لیے HandyGo رابطہ کرے گا۔';

  @override
  String get workerReportPaymentFailed =>
      'ادائیگی درج نہیں ہو سکی۔ دوبارہ کوشش کریں۔';
}

/// The translations for Urdu, using the Latin script (`ur_Latn`).
class AppLocalizationsUrLatn extends AppLocalizationsUr {
  AppLocalizationsUrLatn() : super('ur_Latn');

  @override
  String get languageSectionTitle => 'Settings';

  @override
  String get languageRowLabel => 'Language';

  @override
  String get languageSheetTitle => 'Apni zaban chunein';

  @override
  String get languageOnboardingTitle => 'Zabaan chunein';

  @override
  String get languageOnboardingSubtitle => 'App kis zabaan mein chalayein?';

  @override
  String get languageOptionRomanUrduSubtitle => 'Aasan alfaaz mein';

  @override
  String get languageOptionEnglishSubtitle => 'Sab kuch English mein';

  @override
  String get authRoleQuestion => 'Aap kya karna chahte hain?';

  @override
  String get authRoleSubtitle => 'Aik chunein';

  @override
  String get authRoleClientTitle => 'Ghar ka kaam karwana hai';

  @override
  String get authRoleClientSubtitle =>
      'Repair, safai ya nayi cheez lagwane ke liye Ustaad bulwayein.';

  @override
  String get authRoleWorkerTitle => 'Main Ustaad hoon';

  @override
  String get authRoleWorkerSubtitle =>
      'Kaam dhoondne ke liye account banayein.';

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
  String get authHintFullName => 'Aap ka poora naam';

  @override
  String get authFieldMobileNumber => 'Mobile number';

  @override
  String get authFieldMobileNumberTitle => 'Mobile number';

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
      'Password kam az kam 8 harf ka ho.';

  @override
  String get authValidationConfirmPasswordRequired =>
      'Password dobara likhein.';

  @override
  String get authValidationPasswordsDoNotMatch =>
      'Dono password aik jaise nahi.';

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
      'Code filhal nahi bheja ja saka. Password se aage barhein ya thori dair baad koshish karein.';

  @override
  String get authClientLoginHeading => 'Khush aamdeed';

  @override
  String get authClientLoginSubtitle => 'Apna number aur password daalein.';

  @override
  String get authClientPasswordShow => 'Dikhayein';

  @override
  String get authClientPasswordHide => 'Chupayein';

  @override
  String get authClientForgotPassword => 'Password bhool gaye?';

  @override
  String get authClientLoginButton => 'Login';

  @override
  String get authClientLoginAction => 'Login karein';

  @override
  String get authClientOtpLoginButton => 'Code se login karein';

  @override
  String get authClientLoginWithPassword => 'Password se login karein';

  @override
  String get authClientNoAccountFound =>
      'Is number ka Client account nahi mila. Account banayein.';

  @override
  String get ustaadLoginBrandSubtitle => 'HandyGo par kaam lein';

  @override
  String get ustaadLoginSubtitle =>
      'Kaam lene ke liye apne number se Login karein.';

  @override
  String get ustaadLoginInfoBox =>
      'Har Ustaad ka CNIC verify hota hai. Registration ke baad 24 ghante mein approval.';

  @override
  String get ustaadLoginNewPrompt => 'Naye Ustaad hain?';

  @override
  String get ustaadLoginRegisterAction => 'Register karein';

  @override
  String get ustaadRegisterHeader => 'Ustaad registration';

  @override
  String ustaadStepIndicator(int current, int total) {
    return 'Step $current / $total';
  }

  @override
  String get ustaadStep1Heading => 'Apni details dein';

  @override
  String get ustaadFullNameLabel => 'Poora Naam · CNIC ke mutabiq';

  @override
  String get ustaadFullNameHint => 'Maslan: Kamran Sheikh';

  @override
  String get ustaadCnicLabel => 'CNIC Number';

  @override
  String get ustaadCreatePasswordLabel => 'Password banayein';

  @override
  String get ustaadSendOtpButton => 'OTP bhejein';

  @override
  String get ustaadVerificationHeader => 'Verification';

  @override
  String get ustaadStep2Heading => 'Number verify karein';

  @override
  String ustaadStep2Subtitle(String phone) {
    return '+92 $phone par code bheja · Step 2 / 4';
  }

  @override
  String get ustaadVerifyButton => 'Verify karein';

  @override
  String get ustaadStep3Heading => 'Profile aur kaam';

  @override
  String get ustaadPhotoTitle => 'Apni photo lagayein';

  @override
  String get ustaadPhotoSubtitle => 'Customer ko yehi photo dikhti hai';

  @override
  String get ustaadPhotoPlaceholder => 'PHOTO';

  @override
  String get ustaadPhotoUpload => 'Upload';

  @override
  String get ustaadSkillsTitle => 'Aap kya kaam karte hain?';

  @override
  String get ustaadExperienceTitle => 'Kitne saal ka tajurba?';

  @override
  String get ustaadAddressTitle => 'Ghar ka address';

  @override
  String get ustaadAddressSubtitle =>
      'Jahan aap rehte hain — verification ke liye. Customer ko ye kabhi nahi dikhta.';

  @override
  String get ustaadAreaLabel => 'Area';

  @override
  String get ustaadAreaHint => 'Maslan: Saddar';

  @override
  String get ustaadStreetLabel => 'Street';

  @override
  String get ustaadHouseLabel => 'Ghar / Flat number';

  @override
  String get ustaadLandmarkLabel => 'Nishani · optional';

  @override
  String get ustaadLandmarkHint => 'Masjid ke saamne';

  @override
  String get ustaadStep4Heading => 'CNIC verification';

  @override
  String get ustaadStep4Subtitle =>
      'Step 4 / 4 · ye customer ko kabhi nahi dikhta';

  @override
  String get ustaadCnicFrontTitle => 'CNIC front';

  @override
  String get ustaadCnicFrontSubtitle => 'Saaf tasveer, poora card';

  @override
  String get ustaadCnicBackTitle => 'CNIC back';

  @override
  String get ustaadCnicBackSubtitle => 'Peechay ka rukh';

  @override
  String get ustaadUploadAction => 'UPLOAD';

  @override
  String get ustaadPendingBadge => 'Baqi hai';

  @override
  String get ustaadUploadedBadge => 'Lag gaya';

  @override
  String get ustaadAgreementsLabel => 'AGREEMENTS';

  @override
  String get ustaadReadAction => 'Parhein →';

  @override
  String get ustaadSubmitButton => 'Verification ke liye bhejein';

  @override
  String get workerPendingReviewTitle => 'Profile review mein hai';

  @override
  String get workerPendingReviewBody =>
      'Aap ki details verification ke liye bhej di gayi hain. Approval ke baad aap jobs lena shuru kar sakte hain.';

  @override
  String get ustaadForgotHeading => 'Password reset karein';

  @override
  String get ustaadForgotSubtitle => 'Apna registered mobile number likhein.';

  @override
  String get ustaadForgotOtpHeading => 'Code verify karein';

  @override
  String ustaadForgotOtpBody(String phone) {
    return '+92 $phone par code bheja gaya.';
  }

  @override
  String get ustaadForgotNewPasswordHeading => 'Naya password banayein';

  @override
  String get ustaadConfirmPasswordLabel => 'Confirm password';

  @override
  String get ustaadChangePasswordButton => 'Password change karein';

  @override
  String get ustaadResetSuccessTitle => 'Password change ho gaya';

  @override
  String get ustaadResetSuccessBody => 'Ab apne naye password se Login karein.';

  @override
  String get ustaadGoToLoginButton => 'Login par jayein';

  @override
  String get ustaadNewPasswordLabel => 'New password';

  @override
  String get ustaadAgreementGeneralSummary =>
      'Kaam ka tareeqa, waqt ki pabandi, uniform aur ID, aur rate ke usool.';

  @override
  String get ustaadAgreementTradeSummary =>
      'Aap ke kaam ke mutabiq — parts, grade aur safety ke usool.';

  @override
  String get ustaadAgreementBackgroundSummary =>
      'CNIC, police verification aur reference check ki ijazat.';

  @override
  String get authClientOtpHelp => 'Code aap ke number par SMS aa jayega.';

  @override
  String get authClientNewHere => 'Naye hain?';

  @override
  String get authClientRegisterSubtitle =>
      'Sirf aik dafa. Aage se number aur password kaafi.';

  @override
  String get authClientCreatePasswordLabel => 'Password banayein';

  @override
  String get authClientPasswordHint => 'Kam az kam 8 harf';

  @override
  String get authClientConfirmPasswordLabel => 'Password dobara';

  @override
  String get authClientConfirmPasswordHint => 'Password dobara likhein';

  @override
  String get authClientAddressNotice =>
      'Pata abhi nahi chahiye. Pehli booking par poochenge.';

  @override
  String get authClientHaveAccount => 'Pehle se account hai?';

  @override
  String get authClientVerifyHeading => 'Number verify karein';

  @override
  String get authClientResendPrompt => 'Code nahi mila?';

  @override
  String get authClientResendAction => 'Dobara bhejein';

  @override
  String get authClientVerifyButton => 'Verify kar ke account banayein';

  @override
  String get authClientReadyHeading => 'Account ready hai';

  @override
  String get authClientReadySubtitle =>
      'Welcome to HandyGo. Ab aap service book kar sakte hain.';

  @override
  String get authClientAccountCardLabel => 'AAP KA ACCOUNT';

  @override
  String get authClientRoleCustomer => 'Customer';

  @override
  String authClientVerifySentTo(int count, String phone) {
    return '$count-digit code +92 $phone par bheja gaya.';
  }

  @override
  String get authClientCreateAccountTitle => 'Account banayein';

  @override
  String get authClientFullNameLabel => 'Poora naam';

  @override
  String get authClientSendOtpButton => 'Code bhejein';

  @override
  String get authClientGoHome => 'Home par jayein';

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
  String chatNewMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count naye messages',
      one: '1 naya message',
    );
    return '$_temp0';
  }

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
  String get commonContinue => 'Aage barhein';

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
  String get generalPhoneNumber => 'Phone number';

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
  String get generalNewPassword => 'Naya password';

  @override
  String get generalConfirmNewPassword => 'Naya password dobara';

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
  String get notificationsMarkAllRead => 'Sab read kar dein';

  @override
  String get notificationsEmptyTitle => 'Abhi koi notification nahi';

  @override
  String get notificationsEmptySubtitle =>
      'Kaam ki updates aur reviews aap ko bhejte rahenge.';

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
  String get chatCouldNotOpenDialer => 'Phone dialer nahi khul saka';

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
  String get authForgotPasswordPrompt => 'Apna mobile number likhein';

  @override
  String get authSendOtp => 'Code bhejein';

  @override
  String get authNewPasswordRequired => 'Naya password likhein.';

  @override
  String get authOr => 'ya';

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
      'Aage barhne ke liye date aur time chunein.';

  @override
  String postJobGoesLiveAt(String time, String date) {
    return 'Kaam $date ko $time baje live hoga — Ustaad ke pohanchne ke waqt se ek ghanta pehle.';
  }

  @override
  String get postJobAddPhotoVideo => 'Photo/Video';

  @override
  String get postJobChoosePhoto => 'Photo chunein';

  @override
  String get postJobChooseVideo => 'Video chunein - 30 sec';

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
      'Aap ki booking ki details kamyabi se update ho gayi hain.';

  @override
  String get postJobViewBooking => 'Booking dekhein';

  @override
  String get postJobSelectService => 'Service chunein';

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
      'Building/ghar, apartment/flat, floor/unit, ilaqa, Karachi';

  @override
  String get postJobAddLocationFirst =>
      'Aage barhne ke liye apni location shamil karein.';

  @override
  String get postJobVoiceAndPhotos => 'Voice note aur photos';

  @override
  String get postJobVoiceAttached => 'Voice note laga diya gaya';

  @override
  String get postJobAttachmentHelper =>
      'Photos ya 30 sec ki video dalain. Zyada se zyada 4 attachments.';

  @override
  String postJobAttachmentCount(int count) {
    return '$count/4 attachments add ki gayi hain';
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
  String get postJobChooseOneOption => 'Ek option chunein';

  @override
  String get postJobUnderstandingIsOurJob =>
      'Masla samajhna hamara kaam hai — aapka nahi.';

  @override
  String get postJobStandardWork => 'Standard kaam';

  @override
  String get postJobStandardWorkSubtitle => 'Kaam aur qeemat pehle se clear.';

  @override
  String get postJobIKnowThePart => 'Mujhe exact part pata hai';

  @override
  String get postJobIKnowThePartSubtitle => 'Ustaad rate bhejenge, aap chunein';

  @override
  String get postJobIKnowThePartWarning =>
      'Sirf tab chunein jab part ka poora yaqeen ho. Ghalat nikla to Ustaad ka chakkar zaya jayega aur naya rate lagega.';

  @override
  String get postJobSomethingIsBroken => 'Kuch kharab hai';

  @override
  String get postJobDontKnowIssue => 'Masla kya hai, ye pata nahi';

  @override
  String get postJobInspectionFeeTitle => 'Inspection fee';

  @override
  String get postJobInspectionDetailsPageTitle => 'Masla bataein';

  @override
  String postJobInspectionDetailsStepIndicator(String service) {
    return 'Step 3 / 4 · $service';
  }

  @override
  String get postJobInspectionDetailsFeeLabel => 'INSPECTION FEE';

  @override
  String get postJobInspectionDetailsFeeWaiver =>
      'Repair approve kiya to ye fees maaf — sirf kaam ka rate';

  @override
  String get postJobInspectionProblemHeading =>
      'Aap ko kya nazar aa raha hai? · zaroori';

  @override
  String get postJobInspectionVoiceHeading => 'Bol kar bataein · marzi se';

  @override
  String get postJobInspectionRecordPrompt =>
      'Dabayein aur apne alfaz mein bolein';

  @override
  String get postJobInspectionAddPhoto => 'Photo daalein';

  @override
  String postJobInspectionAttachmentCount(int count) {
    return '$count / 4 attachments';
  }

  @override
  String get postJobChooseStandardService => 'Standard service chunein';

  @override
  String get postJobServicesUnavailable =>
      'Services load nahi ho sakin. Wapas jaa kar dobara koshish karein.';

  @override
  String get postJobSelectCategoryFirst => 'Pehle service category chunein.';

  @override
  String get postJobStandardServicesUnavailable =>
      'Standard services load nahi ho sakin.';

  @override
  String get postJobNoStandardServices =>
      'Is service ke liye abhi koi standard service available nahi. Ooper se koi aur option chunein.';

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
  String get postJobHowInspectionWorks => 'Inspection kaise hota hai';

  @override
  String get postJobWhatDoYouSee =>
      'Aap ko kya masla nazar aa raha hai? (zaroori)';

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
  String get postJobStepLaneSelection => 'Qism chunein';

  @override
  String get postJobStepDetails => 'Details';

  @override
  String get postJobStepTimeSelection => 'Time chunein';

  @override
  String postJobStepIndicator(int current, int total, String title) {
    return 'Step $current / $total  ·  $title';
  }

  @override
  String get postJobProgressBarTime => 'Time';

  @override
  String get postJobRecommendedBadge => 'Behtar';

  @override
  String get trackLiveBadge => 'Live';

  @override
  String get clientHomeYourArea => 'Aap ka ilaqa';

  @override
  String get clientHomeSectionRepairs => 'Repair';

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
  String get serviceAppliancesRepair => 'Appliances Repair';

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
      'Foran madad ke liye koi service chunein.';

  @override
  String clientHomeHello(String name) {
    return 'Hello, $name';
  }

  @override
  String get clientHomeGuest => 'dost';

  @override
  String get clientHomeLocating => 'Location dhoond rahe hain…';

  @override
  String get clientHomeUrgentTitle => 'Abhi madad chahiye?';

  @override
  String get clientHomeUrgentPromise =>
      'Foran Ustaad bhejte hain — rate wahi, koi extra charge nahi';

  @override
  String get clientHomeWhatNeedsDoing => 'Service select karein';

  @override
  String get clientHomeTrustMessage =>
      'Har Ustaad CNIC verified · Rate pehle tay hota hai';

  @override
  String get clientHomeSupportUnavailable =>
      'HandyGo Support abhi available nahi. Dobara koshish karein.';

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
  String get settingsSectionDangerZone => 'Danger zone';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsConditions => 'Terms & Conditions';

  @override
  String get profilePhotoTitle => 'Profile photo';

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
  String get locationSearchHint => 'Jagah, ilaqa ya nishani dhoondein…';

  @override
  String get locationNoSuggestions =>
      'Koi milti jagah nahi mili. Qareebi nishani ya ilaqay ka naam likhein.';

  @override
  String get locationSearchFailed =>
      'Abhi jagah ki suggestions nahi mil rahin. Aap pin khud move kar sakte hain.';

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
  String get postJobSelectDate => 'Date chunein';

  @override
  String get postJobLocationAdded => 'Location shamil kar di gayi';

  @override
  String get postJobCurrentLocation => 'Current location';

  @override
  String get postJobMapLocationAdded => 'Map se location shamil kar di gayi';

  @override
  String get postJobPickOnMap => 'Map par lagayein';

  @override
  String postJobMapPrefix(String address) {
    return 'Map: $address';
  }

  @override
  String get postJobGpsPrefix => 'Pin Location';

  @override
  String get postJobBookService => 'Book karein';

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
  String get bookingServiceDetails => 'Service ki details';

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
  String get bookingInspectionAndRepairBy => 'Inspection aur repair karne wale';

  @override
  String get bookingAssignedWorker => 'Assign kiya gaya Ustaad';

  @override
  String get bookingDetailsTitle => 'Booking ki details';

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
  String get bookingVoiceNote => 'Voice note';

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
  String get bookingSelectedServices => 'Selected services';

  @override
  String bookingServiceQuantity(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String get bookingChooseUstaad => 'Ustaad chunein';

  @override
  String get bookingSeeWorkerBids => 'Ustaad ki offers dekhein';

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
      'Quote accept — repair jari hai';

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
  String get trackAssignedWorkerCaps => 'AAP KA USTAAD';

  @override
  String get trackCall => 'Call';

  @override
  String get trackLocationUnavailable => 'Location available nahi';

  @override
  String trackArrivingIn(int count) {
    return 'Taqreeban $count minute mein pohanch rahe hain';
  }

  @override
  String get trackEtaUnavailable => 'Pohanchne ka waqt maloom nahi';

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
  String get trackJobProgress => 'Kaam ka progress';

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
  String get discoveryBidsLoadFailed => 'Offers load nahi ho sakin.';

  @override
  String get discoveryNoBidsYet => 'Abhi koi offer nahi';

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
    return '$name ki $price ki offer accept karein?';
  }

  @override
  String get discoveryInspectionFeeSeparate =>
      'Inspection fee alag ada ki jati hai.\nNaye Ustaad ka offer alag charge hoga.';

  @override
  String get discoveryBidLabourOnlyNote =>
      'Yeh bid sirf labour charges ke liye hai. Parts aur material aap ki approval se alag khareede ya charge kiye jayenge.';

  @override
  String get discoveryBidInspectionBasedNote =>
      'Yeh bid inspection report ke mutabiq hai aur is mein labour aur report ke kaam ke liye zaroori parts ya material shamil hain.';

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
      'Inspection isi Ustaad ne mukammal kiya.';

  @override
  String get discoveryViewInspectionReport => 'Inspection report dekhein';

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
  String get postJobInspectionReportSectionTitle =>
      'Inspection Report (Optional)';

  @override
  String get postJobAttachInspectionReport =>
      'Pichli inspection report attach karein';

  @override
  String get postJobAttachInspectionHint =>
      'Pehle ki diagnosis share kar ke bid dene walon ko kaam samajhne mein madad dein.';

  @override
  String get postJobChangeInspectionReport => 'Report tabdeel karein';

  @override
  String get postJobSelectInspectionReport =>
      'Inspection report muntakhib karein';

  @override
  String get postJobNoInspectionReports =>
      'Is service ke liye koi pichli inspection report dastyab nahi.';

  @override
  String get postJobInspectionReportsFailed =>
      'Aap ki inspection reports load nahi ho sakein.';

  @override
  String get postJobInspectionReportCleared =>
      'Service tabdeel hone ki wajah se attached inspection report hata di gayi.';

  @override
  String get inspectionReportTitle => 'Inspection report';

  @override
  String get inspectionReportNotAvailable => 'Report abhi available nahi.';

  @override
  String get inspectionUstaadVoiceNote => 'Ustaad ka voice note';

  @override
  String get inspectionPhotos => 'Photos';

  @override
  String get inspectionParts => 'Parts';

  @override
  String get inspectionRepairQuoteTotal => 'Repair ke quote ka total';

  @override
  String get inspectionAcceptQuoteContinue =>
      'Quote accept karein aur repair jari rakhein';

  @override
  String get inspectionFindOtherUstaad => 'Doosra Ustaad dhoondein';

  @override
  String get inspectionCloseAfterInspection => 'Inspection ke baad band karein';

  @override
  String get inspectionAcceptQuoteConfirmTitle =>
      'Quote accept kar ke repair jari rakhein?';

  @override
  String get inspectionCloseConfirmTitle => 'Inspection ke baad band karein?';

  @override
  String get inspectionAcceptQuoteConfirmBody =>
      'Yehi Ustaad repair jari rakhenge. Inspection fee maaf hai — aap sirf repair ka quote den ge.';

  @override
  String get inspectionCloseConfirmBody =>
      'Aap se sirf inspection fee li jayegi. Kaam mukammal mark ho jayega.';

  @override
  String get inspectionClosedAfterInspection =>
      'Inspection ke baad band kar diya gaya.';

  @override
  String get inspectionQuoteAcceptedRepairInProgress =>
      'Quote accept — repair jari hai.';

  @override
  String get inspectionActionFailed => 'Kaam nahi hua. Dobara koshish karein.';

  @override
  String get inspectionFindAnotherConfirmTitle => 'Doosra Ustaad dhoondein?';

  @override
  String get inspectionFindAnotherConfirmBody =>
      'Confirm karne par inspection mukammal ho jayega aur inspection fee li jayegi. Aap ka kaam dobara live ho jayega taake doosre Ustaad apne rate bhej sakein.';

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
  String get chooseSelect => 'Chunein';

  @override
  String get chooseRecommended => 'Recommended';

  @override
  String get chooseSkills => 'Skills';

  @override
  String get chooseNearestFirst => 'Qareeb wale pehle';

  @override
  String chooseAvailableCount(int count) {
    return '$count mojood';
  }

  @override
  String get chooseViewProfile => 'Profile dekhein';

  @override
  String get chooseNoReviews => 'Koi review mojood nahi';

  @override
  String get chooseCnicVerified => 'CNIC verified';

  @override
  String get chooseCnicVerifiedUstaad => 'CNIC Verified Ustaad';

  @override
  String chooseExperienceYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years saal tajurba',
      one: '$years saal tajurba',
    );
    return '$_temp0';
  }

  @override
  String get choosePhoneLabel => 'Phone number';

  @override
  String get chooseProfileLoadFailed =>
      'Is Ustaad ki profile load nahi ho saki.';

  @override
  String get myBookingsLoadFailed =>
      'Aap ki bookings load nahi ho sakin. Dobara koshish karein.';

  @override
  String get myBookingsTitle => 'Bookings';

  @override
  String get myBookingsSubtitle => 'Sab booking aik jagah';

  @override
  String get myBookingsEmptyActiveTitle => 'Koi kaam chal nahi raha';

  @override
  String get myBookingsEmptyCompletedTitle => 'Abhi koi kaam complete nahi hua';

  @override
  String get myBookingsEmptyCancelledTitle => 'Koi cancel booking nahi';

  @override
  String get myBookingsEmptyActiveHelper =>
      'Naya kaam book karein to yahan live status milega.';

  @override
  String get myBookingsEmptyHistoryHelper =>
      'Jab bhi kaam karwayenge, poora record yahan rahega.';

  @override
  String get myBookingsEmptyCta => 'Naya kaam book karein';

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
  String get cardWorkersNotified => 'Ustaad ko foran bata diya jata hai';

  @override
  String get cardSearchingWorkers => 'Ustaad dhoonde ja rahe hain...';

  @override
  String get cardNoWorkerYet => 'Abhi koi Ustaad nahi';

  @override
  String get cardEstimatePrefix => 'Taqreeban';

  @override
  String get cardFindWorkers => 'Ustaad dhoondein';

  @override
  String get cardEdit => 'Edit';

  @override
  String get bookingCardLaneBidding => 'Bidding';

  @override
  String get bookingCardDetails => 'Details →';

  @override
  String get bookingCardPaymentAfterWork => 'Cash — kaam ke baad';

  @override
  String get bookingCardPaymentPending => 'Payment baqi';

  @override
  String get bookingCardNothingPaid => 'Kuch nahi diya';

  @override
  String bookingCardPartialPayment(String received, String remaining) {
    return '$received diya · $remaining baqi';
  }

  @override
  String get bookingCardNoPaymentTaken => 'Kuch nahi liya gaya';

  @override
  String get bookingCardStatusOnTheWay => 'Raaste mein';

  @override
  String get bookingCardStatusWaitingQuote => 'Quote ka intezar';

  @override
  String get bookingCardRomanActiveFilter => 'Chal raha';

  @override
  String get bookingCardRomanAssigned => 'Assign hua';

  @override
  String get bookingCardRomanWorkInProgress => 'Kaam chal raha';

  @override
  String get bookingCardRomanRejected => 'Reject hua';

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
  String get reviewSelectRating => 'Barah-e-karam pehle rating select karein.';

  @override
  String get reviewSubmitSuccess => 'Shukriya! Aap ka review submit ho gaya.';

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
    return '$name repair jari rakhe hue hain';
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
  String inspectionFeePaidAmount(Object amount) {
    return 'Inspection fee paid: $amount';
  }

  @override
  String get inspectionFeeWaivedOff => 'Inspection fee waived off';

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
  String get trackHeadlineWorkInProgress => 'Kaam chal raha hai';

  @override
  String get trackHeadlineHired => 'Hire ho gaye ✓';

  @override
  String trackRatingOutOfFive(String rating) {
    return '$rating / 5.0';
  }

  @override
  String get discoveryLoadingBids => 'Offers load ho rahi hain...';

  @override
  String get discoveryBidsLoadFailedShort => 'Offers load nahi ho sakin';

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
    return '$count pending offers · qeemat ke hisab se sorted';
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
      'Aap rawana hain — client ko bata diya gaya.';

  @override
  String get workerSuccessArrived => 'Pohanchne ka nishan laga diya gaya.';

  @override
  String get workerSuccessJobStarted => 'Kaam shuru ho gaya.';

  @override
  String get workerSuccessJobCompleted => 'Kaam mukammal mark ho gaya.';

  @override
  String get workerSuccessInspectionStarted => 'Inspection shuru ho gaya.';

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
  String workerHelloName(String name) {
    return 'Hello $name';
  }

  @override
  String get workerTodaysEarnings => 'Kamai';

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
  String get workerFindNewWork => 'Nayi Shikayat';

  @override
  String get workerViewNewJobs => 'Dekhein';

  @override
  String workerNewComplaintsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nayi',
      one: '1 nayi',
    );
    return '$_temp0';
  }

  @override
  String get workerActiveJobCaps => 'JARI KAAM';

  @override
  String get workerMap => 'Map';

  @override
  String get workerViewDetails => 'Details dekhein →';

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
  String get workerSelectMainSkill => 'Apni main skill chunein';

  @override
  String get workerSelectMainSkillHint =>
      'Kaam milna shuru karne ke liye apni main skill chunein';

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
      'Apni profile complete karein. Approval ke baad aapko naye kaam nazar ayenge.';

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
      'Apni profile complete karein. Approval ke baad aap apni jobs manage kar sakenge.';

  @override
  String get workerJobsLoadFailed =>
      'Jobs load nahi ho sake. Dobara koshish karein.';

  @override
  String get workerClientCancelledBooking =>
      'Client ne ye booking cancel kar di';

  @override
  String get workerOnlyInspectionCompleted => 'Sirf inspection mukammal hua';

  @override
  String get workerComplete => 'Complete';

  @override
  String get workerCompleting => 'Complete ho raha hai...';

  @override
  String get workerMarkCompletedTitle => 'Mukammal mark karein?';

  @override
  String get workerMarkCompletedBody =>
      'Is se kaam band ho jayega aur client ko pata chal jayega.';

  @override
  String get workerNoActiveJobs => 'Koi jari kaam nahi';

  @override
  String get workerNoCompletedJobs => 'Abhi koi mukammal kaam nahi';

  @override
  String get workerNoCancelledJobs => 'Koi cancel kaam nahi';

  @override
  String get workerNoJobsAssigned => 'Abhi koi kaam nahi mila';

  @override
  String get workerNoAppliedJobs => 'Abhi koi offer nahi bheji';

  @override
  String get workerNewRequestsHere => 'Nayi requests yahan nazar aayengi';

  @override
  String get workerCompletedJobsHere => 'Mukammal kaam yahan nazar aayenge';

  @override
  String get workerCancelledJobsHere => 'Cancel kaam yahan nazar aayenge';

  @override
  String get workerAppliedJobsHere =>
      'Jin kaamon par aapne offer bheji hai woh yahan nazar aayenge';

  @override
  String get workerAcceptToGetStarted =>
      'Shuru karne ke liye koi booking accept karein';

  @override
  String get workerFilterCancelled => 'Cancel';

  @override
  String get workerFilterAllWork => 'Naye Kaam';

  @override
  String get workerFilterMyOffers => 'Meri Offers';

  @override
  String get workerFilterNoOfferSent => 'Offer nahi bheji';

  @override
  String get bidPlaceABid => 'Offer bhejein';

  @override
  String get bidChatWithClient => 'Client se chat karein';

  @override
  String get bidLiveBids => 'Live Offers';

  @override
  String get bidAreaNotAvailable => 'Ilaqa available nahi';

  @override
  String get bidExactAddressAfterAccept =>
      'Client ke aap ki offer accept karne par poora pata bhej diya jata hai.';

  @override
  String get bidStatusAccepted => 'Accept';

  @override
  String get bidStatusRejected => 'Reject';

  @override
  String get bidStatusPending => 'Pending';

  @override
  String get bidYourCurrentBid => 'Aap ki mojooda offer';

  @override
  String get bidSubmit => 'Offer submit karein';

  @override
  String get bidUpdate => 'Offer update karein';

  @override
  String get bidPlaceYourBid => 'Apni offer bhejein';

  @override
  String get bidUpdateYourBid => 'Apni offer update karein';

  @override
  String bidCanUpdateIn(String seconds) {
    return 'Aap ${seconds}s baad offer update kar sakte hain.';
  }

  @override
  String get bidCanUpdateNow => 'Aap abhi apni offer update kar sakte hain.';

  @override
  String get bidAmountLabel => 'Offer Amount (PKR) *';

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
  String get bidBeFirstToBid => 'Is kaam par sab se pehle offer bhejein';

  @override
  String get earningBidding => 'Offers';

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
  String get inspFormChooseFromGallery => 'Gallery se chunein';

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
  String get inspFormRecommendedRepair => 'Behtar Tareeqa';

  @override
  String get inspFormRecommendedRepairRequired => 'Behtar Tareeqa *';

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
  String get inspFormSubmitReport => 'Report submit karein';

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
      'Apni profile ki details complete karein.';

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
  String get workerAgreements => 'Agreements';

  @override
  String get workerConfirmLegalName =>
      'Main tasdeeq karta hoon ke mera qanooni naam mere CNIC ke mutabiq hai.';

  @override
  String get workerViewAgreement => 'Agreement dekhein';

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
  String get bidAmountRequired => 'Baraye meherbani offer ki raqam likhein.';

  @override
  String get bidAmountRange =>
      'Offer ki raqam 100 se 500,000 ke darmiyan honi chahiye.';

  @override
  String get bidSubmitted => 'Offer bhej di gayi!';

  @override
  String get bidSubmitFailed => 'Offer nahi bheji ja saki.';

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
  String get inspFormNotesOptional => 'Notes (optional)';

  @override
  String get inspFormPartName => 'Purze ka naam';

  @override
  String get inspFormQty => 'Tadaad';

  @override
  String get inspFormUnitPrice => 'Fi adad qeemat';

  @override
  String get inspFormWarrantyOptional => 'Warranty / guarantee (optional)';

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
      'Kuch details theek nahi hain. Inhein check kar ke dobara koshish karein.';

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
  String get errorOtpResendTooSoon =>
      'OTP dobara mangwane se pehle thori dair intezar karein.';

  @override
  String get errorInspectorBusy =>
      'Inspection karne wala Ustaad abhi doosre kaam mein masroof hai. Neeche se koi aur Ustaad choose karein.';

  @override
  String get errorPhoneNotRegistered => 'Ye number registered nahi hai.';

  @override
  String get errorPhoneAlreadyRegistered =>
      'Ye number pehle se registered hai.';

  @override
  String get errorUnknown => 'Kuch masla ho gaya. Dobara koshish karein.';

  @override
  String get errorOfflineActionBlocked =>
      'Internet connection nahi hai. Yeh action karne ke liye internet se connect karein.';

  @override
  String get offlineCachedDataBanner =>
      'Offline — saved data dikhaya ja raha hai';

  @override
  String get authForgotPasswordTitle => 'Password bhool\ngaye?';

  @override
  String get authSetNewPasswordTitle => 'Naya password\nbanayein';

  @override
  String get authEnterCodeSentToNumber => 'Number par aaya code likhein.';

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
  String get inspectionRowIssueFound => 'Jo masla mila';

  @override
  String get inspectionRowNotes => 'Notes';

  @override
  String get inspectionBadgeAwaitingDecision =>
      'Report jama ho gayi — faisle ka intezar';

  @override
  String get inspectionBadgeQuoteAccepted => 'Quote manzoor — repair jari hai';

  @override
  String get inspectionBadgeFindingAnother =>
      'Doosra Ustaad talash kiya ja raha hai — offers ke liye khula';

  @override
  String inspStripClosedFeeOnlyWithAmount(String fee) {
    return 'Inspection ke baad band — client sirf inspection fee dega: $fee';
  }

  @override
  String get inspStripClosedFeeOnly =>
      'Inspection ke baad band — client sirf inspection fee dega.';

  @override
  String get inspStripRepairCompletedFeeWaived =>
      'Repair mukammal — inspection fee maaf.';

  @override
  String get inspStripQuoteAcceptedFeeWaived =>
      'Quote manzoor — inspection fee maaf. Repair jari hai.';

  @override
  String get inspStripReportSubmitted =>
      'Inspection report jama ho gayi — repair jari rakhne ke liye quote dekhein ya inspection ke baad band karein.';

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
      'Qareebi Ustaadon ko foran bata diya jata hai.';

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
      'Ye rate final hai. Darwazay par nahi badlega.';

  @override
  String get postJobHowInspectionStep1 => 'Inspection fee fixed hai.';

  @override
  String get postJobHowInspectionStep2 =>
      'Ustaad aata hai, masla maloom karta hai, aur app mein repair ka fixed quote deta hai.';

  @override
  String get postJobHowInspectionStep3 =>
      'Uska quote accept kar ke jari rakhein, ya doosre Ustaadon se offers lein — aap ki marzi.';

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
  String get agreementViewerTitle => 'Agreement';

  @override
  String get agreementLoadFailed =>
      'Agreement load nahi ho saka. Dobara koshish karein.';

  @override
  String get agreementUnavailableForTrade =>
      'Aap ke muntakhab kaam ke liye abhi koi manzoor shuda agreement mojood nahi hai. Bara-e-karam HandyGo support se rabta karein.';

  @override
  String agreementLanguageChip(String language) {
    return 'Agreement ki zabaan: $language';
  }

  @override
  String agreementTradeChip(String trade) {
    return 'Kaam: $trade';
  }

  @override
  String get agreementLanguageNotice =>
      'Yeh manzoor shuda legal agreement filhaal sirf Roman Urdu mein mojood hai.';

  @override
  String get agreementLanguageRomanUrdu => 'Roman Urdu';

  @override
  String get agreementLanguageEnglish => 'English';

  @override
  String get agreementLanguageUrdu => 'Urdu';

  @override
  String get agreementAcceptCheckbox =>
      'Main ne yeh agreement parh liya hai aur ise qabool karta hoon.';

  @override
  String get agreementViewBeforeAccepting =>
      'Qabool karne se pehle agreement khol kar parhein.';

  @override
  String get agreementAcceptRequired => 'Yeh agreement qabool karna lazmi hai.';

  @override
  String get agreementTradeChangedReopen =>
      'Aap ka main kaam tabdeel ho gaya hai. Trade wala agreement dobara khol kar qabool karein.';

  @override
  String get agreementsLoadFailed => 'Agreements load nahi ho sake.';

  @override
  String get agreementsAllThreeRequired =>
      'Submit karne se pehle teenon agreements khol kar qabool karein.';

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
  String get workerAcceptedAgreementsTitle => 'Mere agreements';

  @override
  String get workerAcceptedAgreementsEmpty =>
      'Aap ne abhi tak koi agreement qabool nahi kiya.';

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
  String get agreementDownloadInProgress => 'Agreement download ho raha hai...';

  @override
  String agreementDownloadSaved(String path) {
    return 'Agreement save ho gaya: $path';
  }

  @override
  String get agreementDownloadFailed =>
      'Agreement download nahi ho saka. Dobara koshish karein.';

  @override
  String get customerAgreementTitle =>
      'Customer Terms, Booking Rules aur Privacy Notice';

  @override
  String get customerAgreementCheckboxLabel =>
      'Main ne ye Terms aur Privacy Notice parh liye hain aur in se razamand hoon.';

  @override
  String get customerAgreementIAgree => 'Main Razamand Hoon';

  @override
  String get customerAgreementViewDownloadPdf => 'PDF Dekhein/Download Karein';

  @override
  String get customerAgreementSaveFailed =>
      'Acceptance save nahi ho saki. Dobara koshish karein.';

  @override
  String get customerAgreementEffectiveDateNote =>
      'Yeh aap ki neeche di gayi acceptance ki tareekh se effective hai.';

  @override
  String get customerAgreementHistoryTitle => 'Aap ke agreements';

  @override
  String get customerAgreementHistoryEmptyTitle =>
      'Abhi koi agreement manzoor nahi kiya';

  @override
  String get customerAgreementHistoryEmptyHelper =>
      'Aap ke manzoor kiye hue customer agreements yahan nazar aayenge.';

  @override
  String get clientStateLoading => 'Load ho raha hai…';

  @override
  String get clientStateErrorTitle => 'Yeh load nahi ho saka';

  @override
  String get trackLoading => 'Live tracking load ho rahi hai…';

  @override
  String get reportCheckingExisting =>
      'Pehle se maujood report check ho rahi hai…';

  @override
  String get postJobInspectionReportsEmptyTitle =>
      'Abhi koi inspection report nahi';

  @override
  String get postJobInspectionReportsErrorTitle =>
      'Inspection reports dastyab nahi';

  @override
  String get workerSubmittedDetails => 'Jama karai gayi details';

  @override
  String get workerViewSubmittedDetails => 'Jama karai gayi details dekhein';

  @override
  String get workerDetailsReadOnlyNotice =>
      'Aap ki profile manzoor ho chuki hai. Yeh details lock hain aur tabdeel nahi ki ja sakti.';

  @override
  String get workerVerificationStatus => 'Tasdeeq ki haalat';

  @override
  String get workerMainTrade => 'Markazi hunar';

  @override
  String get workerSuspendedMessage =>
      'Aapka HandyGo account suspend kar diya gaya hai. Mazeed maloomat ke liye Support se rabta karein.';

  @override
  String get workerSuspendedContactSupport => 'Support se Rabta Karein';

  @override
  String get earningGrossEarnings => 'Mazdoori';

  @override
  String get earningCommissionLabel => 'HandyGo Commission (18%)';

  @override
  String get earningUstaadEarnings => 'Munafa';

  @override
  String get earningCommissionStatusLabel => 'Commission Status';

  @override
  String get earningStatusPaid => 'Paid';

  @override
  String get notificationsPermissionOffMessage =>
      'Notifications band hain. Booking aur job updates hasil karne ke liye notifications allow karein.';

  @override
  String get notificationsAllowAction => 'Notifications Allow Karein';

  @override
  String get locationPermissionRequiredMessage =>
      'Location ki permission zaroori hai.';

  @override
  String get locationAllowAction => 'Location Allow Karein';

  @override
  String get locationPermanentlyDeniedMessage =>
      'Location permission Settings se allow karein.';

  @override
  String get locationGpsOffMessage =>
      'Phone ki Location/GPS band hai. Location on karein.';

  @override
  String get locationTurnOnAction => 'Location On Karein';

  @override
  String get locationUnavailableRetryMessage =>
      'Location hasil nahi ho saki. Dobara koshish karein.';

  @override
  String get locationStaleMessage =>
      'Aapki maujooda location zaroori hai. Location update karein.';

  @override
  String get cameraPermissionDeniedMessage =>
      'Camera use karne ke liye permission allow karein.';

  @override
  String get galleryPermissionDeniedMessage =>
      'Photos select karne ke liye permission allow karein.';

  @override
  String get unsupportedFileMessage =>
      'Ye file supported nahi hai. Doosri file select karein.';

  @override
  String get fileTooLargeMessage =>
      'File size zyada hai. Choti file select karein.';

  @override
  String get commonChooseAgain => 'Dobara Chunein';

  @override
  String get pageNotAvailableTitle => 'Page Available Nahi Hai';

  @override
  String get pageNotAvailableBody => 'Ye page ab available nahi hai.';

  @override
  String get commonGoHome => 'Home Par Jayein';

  @override
  String get resourceBookingUnavailable => 'Ye booking ab available nahi hai.';

  @override
  String get resourceJobUnavailable => 'Ye job ab aapko assigned nahi hai.';

  @override
  String get resourceConversationUnavailable =>
      'Ye chat ab available nahi hai.';

  @override
  String get goToMyBookingsAction => 'My Bookings Par Jayein';

  @override
  String get goToMyJobsAction => 'My Jobs Par Jayein';

  @override
  String get goToChatsAction => 'Chats Par Jayein';

  @override
  String get settingsSupportTitle => 'Support';

  @override
  String get settingsAboutTitle => 'HandyGo Ke Baare Mein';

  @override
  String get settingsAppVersionTitle => 'App version';

  @override
  String get aboutAppDescription =>
      'HandyGo clients ko nearby verified Ustaadon se ghar ki repair aur maintenance ki khidmat ke liye jorta hai.';

  @override
  String get aboutWebsiteLabel => 'Website';

  @override
  String get cashPaymentLater => 'Baad mein';

  @override
  String get cashPaymentTitle => 'Cash payment confirm karein';

  @override
  String get cashPaymentQuestion => 'Aap ne kitni cash payment ki?';

  @override
  String cashPaymentExpected(Object amount) {
    return 'Booking ki expected amount: $amount';
  }

  @override
  String get cashPaymentInputLabel => 'Ada ki gayi cash (PKR)';

  @override
  String get cashPaymentInputHint =>
      'Poore rupay likhein, 0 bhi likh sakte hain';

  @override
  String get cashPaymentRequired => 'Asal ada ki gayi cash amount likhein.';

  @override
  String get cashPaymentWholeRupees =>
      'Decimal ke baghair poori PKR amount likhein.';

  @override
  String get cashPaymentNegative => 'Raqam negative nahi ho sakti.';

  @override
  String get cashPaymentExceedsBookingPrice =>
      'Raqam booking price se zyada nahi ho sakti.';

  @override
  String get cashPaymentConfirmedTitle => 'Cash payment confirm ho gayi';

  @override
  String cashPaymentPaid(Object amount) {
    return 'Ada ki gayi cash: $amount';
  }

  @override
  String cashPaymentExpectedReceipt(Object amount) {
    return 'Expected amount: $amount';
  }

  @override
  String cashPaymentShortfall(Object amount) {
    return 'Baqi amount: $amount';
  }

  @override
  String cashPaymentReference(Object reference) {
    return 'Confirmation reference: $reference';
  }

  @override
  String get cashPaymentContinueReview => 'Review dein';

  @override
  String get cashPaymentConflict =>
      'Payment pehle kisi doosri amount ke sath confirm ho chuki hai. Correction ke liye HandyGo Support se rabta karein.';

  @override
  String get cashPaymentFailed =>
      'Cash payment confirm nahi ho saki. Dobara koshish karein.';

  @override
  String get cashPaymentReviewBlocked =>
      'Ustaad ko review dene se pehle cash payment confirm karein.';

  @override
  String get postJobSelectBookingTypeFirst =>
      'Pehle Normal ya Urgent choose karein.';

  @override
  String get postJobInspectionDescriptionRequired =>
      'Aage barhne se pehle nazar aane wala masla likhein.';

  @override
  String get postJobCustomVoiceRequired =>
      'Custom kaam ke liye aage barhne se pehle voice note lagayein.';

  @override
  String get postJobCompleteAddressBeforeSaving =>
      'Save karne se pehle poora address aur map pin lagayen.';

  @override
  String get postJobDay => 'Din';

  @override
  String get postJobTomorrow => 'Kal';

  @override
  String get postJobCustomVoiceAndPhotos =>
      'Voice note (zaroori) aur photos/video (marzi se)';

  @override
  String get postJobInspectionVoiceAndPhotos =>
      'Voice note aur photos/video (marzi se)';

  @override
  String get postJobInspectionRateNote =>
      'Abhi sirf aane ki fee dein. Repair ka quote kaam shuru hone se pehle app mein aayega.';

  @override
  String get postJobBiddingRateNote =>
      'Ustaads poore repair ka quote bhejenge. Jo quote aap accept karein woh final hai aur darwaze par nahi badlega.';

  @override
  String get savedAddresses => 'Save kiye hue addresses';

  @override
  String get savedAddressForNextTime =>
      'Yeh address agli baar ke liye save karein';

  @override
  String get savedAddressOffice => 'Office';

  @override
  String get savedAddressName => 'Saved address ka naam';

  @override
  String get savedAddressNameRequired => 'Naam likhein.';

  @override
  String get savedAddressCustomNameTitle => 'Is address ka naam rakhein';

  @override
  String get savedAddressRenameTitle => 'Saved address ka naam badlein';

  @override
  String get savedAddressRenameConflict =>
      'Yeh naam pehle se use ho raha hai. Koi aur naam choose karein.';

  @override
  String get savedAddressSaved => 'Address save ho gaya.';

  @override
  String get savedAddressUse => 'Address use karein';

  @override
  String get savedAddressUpdateWithCurrent =>
      'Maujooda address aur pin se update karein';

  @override
  String get savedAddressRename => 'Naam badlein';

  @override
  String get savedAddressDeleteTitle => 'Saved address delete karein?';

  @override
  String savedAddressDeleteBody(String name) {
    return '$name ko saved addresses se delete karein?';
  }

  @override
  String savedAddressUpdateTitle(String name) {
    return '$name update karein?';
  }

  @override
  String savedAddressUpdateBody(String name) {
    return '$name pehle se saved hai. Is address se update karein?';
  }

  @override
  String get savedAddressUpdateAction => 'Address update karein';

  @override
  String get postJobAddressIntro =>
      'Pehli booking hai — pata aik dafa likh dein. Aage se save ho sakta hai.';

  @override
  String get postJobCompleteAddressLabel => 'Poora pata likhein';

  @override
  String get postJobAddressLandmarkHelper =>
      'Building/ghar, apartment/flat, floor/unit aur qareebi nishani likhein.';

  @override
  String get postJobAddressResolving =>
      'Is address ko map par dhoonda ja raha hai…';

  @override
  String get postJobAddressUnresolved =>
      'Yeh address nahi mila. Mazeed tafseel likhein ya map par chunein.';

  @override
  String get postJobAddressRequired => 'Aage barhne se pehle address likhein.';

  @override
  String get postJobMapPreviewEmpty => 'Map — pin lagane ke liye tap karein';

  @override
  String get postJobLanePageTitle => 'Kaam kaise karwana hai?';

  @override
  String postJobLaneStepIndicator(String service) {
    return 'Step 2 / 4 · $service';
  }

  @override
  String get postJobLaneFixedTitle => 'Fixed price';

  @override
  String get postJobLaneFixedSubtitle => 'Service aur price pehle se fixed';

  @override
  String get postJobLaneFixedBody => 'Booking se pehle final price dekhein.';

  @override
  String get postJobLaneFixedAction => 'Services aur prices dekhein →';

  @override
  String get postJobLaneFixedCta => 'Services aur prices dekhein';

  @override
  String get postJobFixedPricePageTitle => 'Fixed price services';

  @override
  String postJobFixedPriceStepIndicator(String service) {
    return 'Step 3 / 4 · $service';
  }

  @override
  String get postJobLaneInspectionTitle => 'Inspection';

  @override
  String get postJobLaneInspectionSubtitle => 'Masla samajh nahi aa raha?';

  @override
  String postJobLaneInspectionFeeBody(String fee) {
    return '$fee inspection fee — abhi nahi, inspection ke baad.';
  }

  @override
  String get postJobLaneInspectionReportBody =>
      'Ustaad masla check karke report aur final quote app mein bhejega.';

  @override
  String postJobLaneInspectionWaiverBody(String fee) {
    return 'Kaam karwa liya to ye $fee maaf — sirf repair ka rate dena hai.';
  }

  @override
  String get postJobLaneInspectionAction => 'Inspection book karein →';

  @override
  String get postJobLaneInspectionCta => 'Inspection book karein';

  @override
  String get postJobLaneCustomTitle => 'Custom kaam';

  @override
  String get postJobLaneCustomBody =>
      'Chhote repair, fitting ya replacement ki details aur photos bhejein.';

  @override
  String get postJobLaneCustomRatesBody =>
      'Qareebi Ustaads apne rates bhejenge.';

  @override
  String get postJobLaneCustomAction => 'Kaam ki details dein →';

  @override
  String get postJobLaneCustomCta => 'Kaam ki details dein';

  @override
  String get postJobLanePriceNote =>
      'Price sirf app mein naya quote bhejne ke baad badal sakta hai — ghar pohanch kar nahi.';

  @override
  String get postJobLaneChooseCta => 'Booking option choose karein';

  @override
  String get postJobCustomRequestTitle => 'Aap ki request';

  @override
  String postJobCustomRequestStepIndicator(String service) {
    return 'Step 3 / 4 · $service';
  }

  @override
  String get postJobCustomWorkTitleLabel => 'KYA KARWANA HAI?';

  @override
  String get postJobCustomRequired => 'zaroori';

  @override
  String get postJobCustomWorkTitleHint => 'Maslan ceiling fan lagwana hai';

  @override
  String get postJobCustomDetailsLabel => 'Details se batayein';

  @override
  String get postJobCustomOptional => 'marzi se';

  @override
  String get postJobCustomDetailsHint => 'Agar koi aur baat madad kare';

  @override
  String get postJobCustomVoiceLabel => 'Voice note';

  @override
  String get postJobCustomAddPhotos => 'Photo dalain';

  @override
  String postJobCustomMediaAttached(int count) {
    return '$count / 4 photos · Voice note laga hua';
  }

  @override
  String postJobCustomMediaPending(int count) {
    return '$count / 4 photos · Voice note nahi laga';
  }

  @override
  String get postJobCustomHelperNote =>
      'Ustaad ko photo aur awaz se sab se zyada samajh aata hai. Technical details ki zaroorat nahi.';

  @override
  String get postJobCustomReportLabel => 'Pichli inspection report';

  @override
  String get postJobCustomAttachReport => 'Report lagayen';

  @override
  String get postJobInspectionReportAttached => 'Report laga hua';

  @override
  String aboutVersionValue(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get reportProblemTitle => 'Masla report karein';

  @override
  String get reportProblemHelper => 'Jo masla hua hai select karein.';

  @override
  String get reportProblemAction => 'Masla report karein';

  @override
  String get reportIssueWorkQuality => 'Kaam theek nahi hua';

  @override
  String get reportIssuePricePayment => 'Price / payment ka masla';

  @override
  String get reportIssueUstaadBehaviour => 'Ustaad ka behaviour';

  @override
  String get reportIssueDamage => 'Damage hua';

  @override
  String get reportIssuePartMaterial => 'Part / material ka masla';

  @override
  String get reportIssueWarrantyRework => 'Warranty / dobara kaam chahiye';

  @override
  String get reportIssueOther => 'Kuch aur';

  @override
  String get reportOtherLabel => 'Masla bataein';

  @override
  String get reportSubmit => 'Report submit karein';

  @override
  String get reportSelectAtLeastOneError =>
      'Kam az kam aik masla select karein.';

  @override
  String get reportOtherRequiredError => 'Kuch aur ka masla bataein.';

  @override
  String get reportSubmittedTitle => 'Report submit ho gaya';

  @override
  String get reportSubmittedBody => 'HandyGo team isay review karegi.';

  @override
  String get reportYourReportTitle => 'Aap ka report';

  @override
  String get reportSubmittedAtLabel => 'Submit hua';

  @override
  String get reportReferenceLabel => 'Reference';

  @override
  String get reportLookupFailed => 'Report abhi load nahi ho saka.';

  @override
  String get reportActionFailed =>
      'Kuch ghalat ho gaya. Dobara koshish karein.';

  @override
  String get reportTalkToSupport => 'Support se baat karein';

  @override
  String get reportHumanRequestedConfirmation =>
      'Support team ko bata diya gaya hai.';

  @override
  String get reportStatusPending => 'Pending';

  @override
  String get reportStatusInReview => 'Review mein';

  @override
  String get reportStatusResolved => 'Resolved';

  @override
  String get reportAlreadyExists => 'Is booking ka report pehle se mojood hai.';

  @override
  String get reportBackToBooking => 'Booking par wapas';

  @override
  String get bookingSchedule => 'Schedule';

  @override
  String get bookingPrice => 'Qeemat';

  @override
  String get bookingPaymentTitle => 'Payment';

  @override
  String get bookingPaymentUnpaid => 'Payment baqi';

  @override
  String get bookingPaymentPartial => 'Thora diya';

  @override
  String get bookingStatusSectionLabel => 'Booking';

  @override
  String get bookingHireNewUstaad => 'Naya Ustaad hire karein';

  @override
  String get bookingJobClosedTitle => 'Kaam mukammal ho gaya';

  @override
  String get bookingJobClosedBody =>
      'Ye kaam band ho chuka hai. Aap ab bhi Ustaad ko review de sakte hain ya masla report kar sakte hain.';

  @override
  String get bookingReportLabel => 'Report';

  @override
  String get bookingPaymentReceived => 'Cash mila';

  @override
  String get bookingPaymentRemaining => 'Baqi';

  @override
  String get bookingPaymentExpected => 'Expected';

  @override
  String get timelineStepWorkConfirmed => 'Kaam confirm hua';

  @override
  String get timelineStepInspectionConfirmed => 'Inspection confirm hui';

  @override
  String get timelineStepUstaadHired => 'Ustaad hire hua';

  @override
  String get timelineStepWorkStarted => 'Kaam shuru';

  @override
  String get timelineStepInspectionStarted => 'Inspection shuru';

  @override
  String get timelineStepWorkCompleted => 'Kaam complete';

  @override
  String get timelineStepInspectionCompleted => 'Inspection complete';

  @override
  String get timelineWaitingForUstaadTitle => 'Ustaad ka intezaar';

  @override
  String get timelineWaitingForUstaadBody =>
      'Jaise hi aap is kaam ke liye Ustaad hire karenge, kaam shuru ho jayega.';

  @override
  String get ustaadIdentityTitle => 'Shanakhti details';

  @override
  String get ustaadLiveSelfieSubtitle =>
      'Abhi lein — chehra saaf nazar aana chahiye';

  @override
  String get reportDetailsHelper =>
      'Thori si detail se hamari team aap ki shikayat par jald action le sakti hai.';

  @override
  String get reportDetailsRequiredError =>
      'Barae meherbani masla kam az kam 10 harf mein bayan karein.';

  @override
  String get workerPaymentPartsLabel => 'Purza jaat ki raqam';

  @override
  String get workerPaymentLabourLabel => 'Mazdoori wasool';

  @override
  String get workerPaymentAwaitingTitle => 'Adaigi abhi darj nahi hui';

  @override
  String get workerPaymentAwaitingBody =>
      'Raqam darj hotay hi aap ko maloom ho jaye ga kitni raqam wasool hui.';

  @override
  String get workerReportPaymentAction => 'Kam paisa mila?';

  @override
  String get workerReportPaymentTitle => 'Aap ko asal mein kitni raqam mili?';

  @override
  String get workerReportPaymentHelper =>
      'Jo cash customer ne diya wo likhein. Baqi hisaab HandyGo khud kare ga.';

  @override
  String get workerReportPaymentFieldLabel => 'Wasool shuda raqam';

  @override
  String get workerReportPaymentInvalidError =>
      'Sifar ya us se zyada poore rupay ki raqam likhein.';

  @override
  String get workerReportPaymentSubmit => 'Adaigi darj karein';

  @override
  String get workerReportPaymentSuccess =>
      'Adaigi darj ho gayi. Baqi raqam ke liye HandyGo rabta kare ga.';

  @override
  String get workerReportPaymentFailed =>
      'Adaigi darj nahi ho saki. Dobara koshish karein.';
}
