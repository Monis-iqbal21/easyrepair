// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSectionTitle => 'Settings';

  @override
  String get languageRowLabel => 'Language';

  @override
  String get languageSheetTitle => 'Choose your language';

  @override
  String get languageOnboardingTitle => 'Choose Language';

  @override
  String get languageOnboardingSubtitle =>
      'Which language would you like to use the app in?';

  @override
  String get languageOptionRomanUrduSubtitle =>
      'Simple words, easy to understand';

  @override
  String get languageOptionEnglishSubtitle => 'Full application in English';

  @override
  String get authRoleQuestion => 'What would you like to do?';

  @override
  String get authRoleSubtitle => 'Choose an option';

  @override
  String get authRoleClientTitle => 'I need a home service';

  @override
  String get authRoleClientSubtitle =>
      'Book an Ustaad for repair, service, or installation.';

  @override
  String get authRoleWorkerTitle => 'I am an Ustaad';

  @override
  String get authRoleWorkerSubtitle => 'Register to find and accept jobs.';

  @override
  String get authWorkerTypeQuestion => 'Are you already a HandyGo\nUstaad?';

  @override
  String get authWorkerTypeNewTitle => 'I am a new Ustaad';

  @override
  String get authWorkerTypeNewSubtitle => 'Create your new account on HandyGo.';

  @override
  String get authWorkerTypeExistingTitle => 'I already have an account';

  @override
  String get authWorkerTypeExistingSubtitle =>
      'Log in to your account with OTP or password.';

  @override
  String authWelcomeToastTitle(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get authWelcomeToastSubtitle => 'Your account is ready to go.';

  @override
  String get authOtpExpired => 'The code has expired. Request a new one.';

  @override
  String authOtpExpiresIn(String time) {
    return 'Code expires in $time';
  }

  @override
  String authOtpResendCooldown(int seconds) {
    return 'Resend code (${seconds}s)';
  }

  @override
  String get authOtpResend => 'Resend code';

  @override
  String get authFieldFullName => 'Your full name';

  @override
  String get authFieldFullNameShort => 'Full name';

  @override
  String get authHintFullName => 'Enter your full name';

  @override
  String get authFieldMobileNumber => 'Mobile number';

  @override
  String get authFieldMobileNumberTitle => 'Mobile Number';

  @override
  String get authFieldPassword => 'Password';

  @override
  String get authFieldConfirmPassword => 'Re-enter password';

  @override
  String get authValidationNameRequired => 'Please enter your name.';

  @override
  String get authValidationPhoneRequired => 'Please enter a mobile number.';

  @override
  String get authValidationPhoneInvalid =>
      'Please enter a valid Pakistani mobile number.';

  @override
  String get authValidationPasswordRequired => 'Please enter a password.';

  @override
  String get authValidationPasswordTooShort =>
      'Password must be at least 8 characters.';

  @override
  String get authValidationConfirmPasswordRequired =>
      'Please re-enter your password.';

  @override
  String get authValidationPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get authClientLoginTitle => 'Log in to book\nan Ustaad';

  @override
  String get authClientOtpSubtitle =>
      'Enter your name and mobile number. We will send a verification code.';

  @override
  String get authClientPasswordSubtitle =>
      'Continue with your mobile number and password.';

  @override
  String get authOtpWillBeSentNotice =>
      'A verification code will be sent to this number.';

  @override
  String get authButtonSendCode => 'Send Code';

  @override
  String get authButtonVerifyAndContinue => 'Verify and Continue';

  @override
  String get authButtonLogIn => 'Log In';

  @override
  String get authButtonCreateAccount => 'Create Account';

  @override
  String get authButtonForgotPassword => 'Forgot password?';

  @override
  String get authButtonContinueWithOtp => 'Continue with OTP';

  @override
  String get authButtonContinueWithPassword => 'Continue with password';

  @override
  String get authButtonUstaadLogin => 'Ustaad Login';

  @override
  String get authErrorGeneric => 'Something went wrong.';

  @override
  String get authErrorOtpSendFailed =>
      'The OTP could not be sent right now. Continue with your password, or try again shortly.';

  @override
  String get authClientLoginHeading => 'Welcome Back';

  @override
  String get authClientLoginSubtitle =>
      'Login with your mobile number and password.';

  @override
  String get authClientPasswordShow => 'Show';

  @override
  String get authClientPasswordHide => 'Hide';

  @override
  String get authClientForgotPassword => 'Forgot Password?';

  @override
  String get authClientLoginButton => 'Login';

  @override
  String get authClientLoginAction => 'Login';

  @override
  String get authClientOtpLoginButton => 'Login with OTP';

  @override
  String get authClientLoginWithPassword => 'Login with Password';

  @override
  String get authClientNoAccountFound =>
      'No Client account was found for this number. Create an account.';

  @override
  String get ustaadLoginBrandSubtitle => 'Work with HandyGo';

  @override
  String get ustaadLoginSubtitle =>
      'Login with your mobile number to find work.';

  @override
  String get ustaadLoginInfoBox =>
      'Every Ustaad\'s CNIC is verified. Approval is usually completed within 24 hours after registration.';

  @override
  String get ustaadLoginNewPrompt => 'New Ustaad?';

  @override
  String get ustaadLoginRegisterAction => 'Register';

  @override
  String get ustaadRegisterHeader => 'Ustaad registration';

  @override
  String ustaadStepIndicator(int current, int total) {
    return 'Step $current / $total';
  }

  @override
  String get ustaadStep1Heading => 'Enter your details';

  @override
  String get ustaadFullNameLabel => 'Full Name · As shown on CNIC';

  @override
  String get ustaadFullNameHint => 'For example: Kamran Sheikh';

  @override
  String get ustaadCnicLabel => 'CNIC Number';

  @override
  String get ustaadCreatePasswordLabel => 'Create Password';

  @override
  String get ustaadSendOtpButton => 'Send OTP';

  @override
  String get ustaadVerificationHeader => 'Verification';

  @override
  String get ustaadStep2Heading => 'Verify your number';

  @override
  String ustaadStep2Subtitle(String phone) {
    return 'Code sent to +92 $phone · Step 2 / 4';
  }

  @override
  String get ustaadVerifyButton => 'Verify';

  @override
  String get ustaadStep3Heading => 'Profile and work';

  @override
  String get ustaadPhotoTitle => 'Add your photo';

  @override
  String get ustaadPhotoSubtitle => 'This is the photo customers see';

  @override
  String get ustaadPhotoPlaceholder => 'PHOTO';

  @override
  String get ustaadPhotoUpload => 'Upload';

  @override
  String get ustaadSkillsTitle => 'What work do you do?';

  @override
  String get ustaadExperienceTitle => 'How many years of experience?';

  @override
  String get ustaadAddressTitle => 'Home address';

  @override
  String get ustaadAddressSubtitle =>
      'Where you live — for verification. Customers never see this.';

  @override
  String get ustaadAreaLabel => 'Area';

  @override
  String get ustaadAreaHint => 'For example: Saddar';

  @override
  String get ustaadStreetLabel => 'Street';

  @override
  String get ustaadHouseLabel => 'House / Flat number';

  @override
  String get ustaadLandmarkLabel => 'Landmark · optional';

  @override
  String get ustaadLandmarkHint => 'Opposite the mosque';

  @override
  String get ustaadStep4Heading => 'CNIC verification';

  @override
  String get ustaadStep4Subtitle => 'Step 4 / 4 · customers never see this';

  @override
  String get ustaadCnicFrontTitle => 'CNIC front';

  @override
  String get ustaadCnicFrontSubtitle => 'Clear photo, whole card';

  @override
  String get ustaadCnicBackTitle => 'CNIC back';

  @override
  String get ustaadCnicBackSubtitle => 'The back side';

  @override
  String get ustaadUploadAction => 'UPLOAD';

  @override
  String get ustaadPendingBadge => 'Pending';

  @override
  String get ustaadUploadedBadge => 'Added';

  @override
  String get ustaadAgreementsLabel => 'AGREEMENTS';

  @override
  String get ustaadReadAction => 'Read →';

  @override
  String get ustaadSubmitButton => 'Submit for Verification';

  @override
  String get workerPendingReviewTitle => 'Profile under review';

  @override
  String get workerPendingReviewBody =>
      'Your details have been submitted for verification. You can start receiving jobs after approval.';

  @override
  String get ustaadForgotHeading => 'Reset Password';

  @override
  String get ustaadForgotSubtitle => 'Enter your registered mobile number.';

  @override
  String get ustaadForgotOtpHeading => 'Verify Code';

  @override
  String ustaadForgotOtpBody(String phone) {
    return 'A code was sent to +92 $phone.';
  }

  @override
  String get ustaadForgotNewPasswordHeading => 'Create a New Password';

  @override
  String get ustaadConfirmPasswordLabel => 'Confirm Password';

  @override
  String get ustaadChangePasswordButton => 'Change Password';

  @override
  String get ustaadResetSuccessTitle => 'Password changed';

  @override
  String get ustaadResetSuccessBody =>
      'You can now login with your new password.';

  @override
  String get ustaadGoToLoginButton => 'Go to Login';

  @override
  String get ustaadNewPasswordLabel => 'New Password';

  @override
  String get ustaadAgreementGeneralSummary =>
      'How work is done, punctuality, uniform and ID, and the rate rules.';

  @override
  String get ustaadAgreementTradeSummary =>
      'Matched to your trade — parts, grade and safety rules.';

  @override
  String get ustaadAgreementBackgroundSummary =>
      'Permission for CNIC, police verification and reference checks.';

  @override
  String get authClientOtpHelp =>
      'An OTP will be sent to your registered mobile number.';

  @override
  String get authClientNewHere => 'New here?';

  @override
  String get authClientRegisterSubtitle =>
      'Create your account once. After that, login with your mobile number and password.';

  @override
  String get authClientCreatePasswordLabel => 'Create password';

  @override
  String get authClientPasswordHint => 'At least 8 characters';

  @override
  String get authClientConfirmPasswordLabel => 'Confirm password';

  @override
  String get authClientConfirmPasswordHint => 'Enter your password again';

  @override
  String get authClientAddressNotice =>
      'We do not need your address yet. We will ask for it when you make your first booking.';

  @override
  String get authClientHaveAccount => 'Already have an account?';

  @override
  String get authClientVerifyHeading => 'Verify Mobile Number';

  @override
  String get authClientResendPrompt => 'Didn\'t receive the code?';

  @override
  String get authClientResendAction => 'Resend';

  @override
  String get authClientVerifyButton => 'Verify & Create Account';

  @override
  String get authClientReadyHeading => 'Your account is ready';

  @override
  String get authClientReadySubtitle =>
      'Welcome to HandyGo. You can now book a service.';

  @override
  String get authClientAccountCardLabel => 'YOUR ACCOUNT';

  @override
  String get authClientRoleCustomer => 'Customer';

  @override
  String authClientVerifySentTo(int count, String phone) {
    return 'A $count-digit code was sent to +92 $phone.';
  }

  @override
  String get authClientCreateAccountTitle => 'Create Account';

  @override
  String get authClientFullNameLabel => 'Full name';

  @override
  String get authClientSendOtpButton => 'Send OTP';

  @override
  String get authClientGoHome => 'Go to Home';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonUser => 'User';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonUploading => 'Uploading...';

  @override
  String get chatTitleFallback => 'Chat';

  @override
  String get chatListTitle => 'Messages';

  @override
  String get chatSearchHint => 'Search chats or type “support”';

  @override
  String get chatEmptyTitle => 'No conversations yet';

  @override
  String get chatEmptySubtitle => 'Messages will appear here';

  @override
  String get chatNoResultsTitle => 'No chats found';

  @override
  String get chatNoResultsSubtitle =>
      'Try a different name, or search “support”';

  @override
  String get chatNoMessagesYet => 'No messages yet. Say hello!';

  @override
  String get chatSupportBanner =>
      'Write your problem or question here. HandyGo Support will help you.';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get chatEditHint => 'Edit your message...';

  @override
  String get chatDeleteMessage => 'Delete message';

  @override
  String get chatDeleteConfirm =>
      'This message will be deleted for everyone in the chat.';

  @override
  String get chatMicPermissionRequired =>
      'Microphone permission is needed to send a voice message.';

  @override
  String get chatLocationPermissionDenied => 'Location permission denied';

  @override
  String get chatLocationPermissionPermanentlyDenied =>
      'Location permission permanently denied — enable it in Settings';

  @override
  String chatLocationFailed(String error) {
    return 'Could not get your location: $error';
  }

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
  String get commonContinue => 'Continue';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonToday => 'Today';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get permissionsTitle => 'Allow permissions';

  @override
  String get permissionsRationale =>
      'HandyGo needs camera, microphone, and location permissions so you can upload photos and videos, send voice notes, and share or track job location.';

  @override
  String get permissionsBlockedTitle => 'Permissions blocked';

  @override
  String get permissionsBlockedBody =>
      'Some permissions were permanently denied. Open Settings to enable them manually.';

  @override
  String get generalInfoTitle => 'General';

  @override
  String get generalAccountSection => 'Account Info';

  @override
  String get generalFirstName => 'First Name';

  @override
  String get generalLastName => 'Last Name';

  @override
  String get generalPhoneNumber => 'Phone Number';

  @override
  String get generalNamePhoneLocked =>
      'Name and phone are managed by your account and cannot be changed here.';

  @override
  String get generalSecuritySection => 'Security';

  @override
  String get generalChangePassword => 'Change Password';

  @override
  String get generalCurrentPassword => 'Current Password';

  @override
  String get generalNewPassword => 'New Password';

  @override
  String get generalConfirmNewPassword => 'Re-enter new password';

  @override
  String get generalChangePasswordComingSoon =>
      'Changing your password in the app is coming soon. Contact support if you need help right away.';

  @override
  String get generalUpdatePassword => 'Update Password';

  @override
  String get distanceAtYourLocation => 'Right at your location';

  @override
  String distanceMetersAway(int meters) {
    return '$meters m away';
  }

  @override
  String distanceKmAway(String km) {
    return '$km km away';
  }

  @override
  String get distanceUnderOneKm => '< 1 km away';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptySubtitle =>
      'You will be notified about job updates,\nreviews, and more.';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String get workerRatingNew => 'New worker';

  @override
  String get workerRatingNone => 'No rating';

  @override
  String workerRatingWithJobs(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '$count job',
    );
    return '$rating ($_temp0)';
  }

  @override
  String get chatSeen => 'Seen';

  @override
  String get chatMessageDeleted => 'This message was deleted';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatCouldNotOpenMaps => 'Could not open maps';

  @override
  String get chatCouldNotOpenDialer => 'Could not open the phone dialer';

  @override
  String get chatSharedLocation => 'Shared location';

  @override
  String get chatComposerHint => 'Type a message...';

  @override
  String get chatAttachPhoto => 'Photo';

  @override
  String get chatAttachVideo => 'Video';

  @override
  String get chatAttachVoice => 'Voice';

  @override
  String get chatAttachLocation => 'Location';

  @override
  String get chatTakePhoto => 'Take Photo';

  @override
  String get chatRecordVideo => 'Record Video';

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
      'Your password has been changed successfully.';

  @override
  String get authForgotPasswordPrompt => 'Enter your registered mobile number';

  @override
  String get authSendOtp => 'Send OTP';

  @override
  String get authNewPasswordRequired => 'Please enter a new password.';

  @override
  String get authOr => 'OR';

  @override
  String get authLoginWithPassword => 'Log In With Password';

  @override
  String get authWorkerRegisterTitle => 'Create a new Ustaad\naccount';

  @override
  String get authCnicNameHint => 'Enter your full name exactly as on your CNIC';

  @override
  String get authCreatePasswordLabel => 'Create a password';

  @override
  String get authSelectSkill => 'Select your skill';

  @override
  String get authSkillsLoadFailed => 'Skills could not load. Please try again.';

  @override
  String get authSkillRequired => 'Please select a skill.';

  @override
  String get authConfirmNewPasswordButton => 'Confirm New Password';

  @override
  String get postJobOffersSoon =>
      'You will start getting Ustaad offers within minutes.';

  @override
  String get postJobSelectDateTimeFirst => 'Select date and time to continue.';

  @override
  String postJobGoesLiveAt(String time, String date) {
    return 'Job goes live at $time on $date — 1 hour before the Ustaad arrival time.';
  }

  @override
  String get postJobAddPhotoVideo => 'Photo/Video';

  @override
  String get postJobChoosePhoto => 'Choose Photo';

  @override
  String get postJobChooseVideo => 'Choose Video - 30 sec';

  @override
  String get postJobCamera => 'Camera';

  @override
  String get postJobRecordVideo30 => 'Record Video - 30 sec';

  @override
  String get errorNoInternet =>
      'No internet connection. Please check your network.';

  @override
  String get postJobSaveFailed => 'Unable to save booking. Please try again.';

  @override
  String get postJobBookingUpdatedTitle => 'Booking Updated!';

  @override
  String get postJobBookingUpdatedBody =>
      'Your booking details have been updated successfully.';

  @override
  String get postJobViewBooking => 'View Booking';

  @override
  String get postJobSelectService => 'Select Service';

  @override
  String get postJobServicesLoadFailed =>
      'Failed to load services. Please restart the app.';

  @override
  String get postJobBookingType => 'Booking Type';

  @override
  String get postJobNormal => 'Normal';

  @override
  String get postJobUrgent => 'Urgent';

  @override
  String get postJobDateTime => 'Date & Time';

  @override
  String get postJobArrivalTime => 'Arrival time';

  @override
  String get postJobWhatNeedsFixing => 'What needs fixing?';

  @override
  String get postJobIssueHint =>
      'e.g. AC not cooling, water leaking, switch not working';

  @override
  String get postJobDescription => 'Description';

  @override
  String get postJobDescriptionHint => 'Describe the issue (optional)';

  @override
  String get postJobServiceAddress => 'Service Address';

  @override
  String get postJobAddressHint =>
      'e.g. House 12, Street 5, DHA Phase 6, Karachi';

  @override
  String get postJobAddLocationFirst => 'Add your location to continue.';

  @override
  String get postJobVoiceAndPhotos => 'Voice note & photos';

  @override
  String get postJobVoiceAttached => 'Voice note attached';

  @override
  String get postJobAttachmentHelper =>
      'Add photos or a video up to 30 seconds. Maximum 4 attachments.';

  @override
  String postJobAttachmentCount(int count) {
    return '$count/4 attachments added';
  }

  @override
  String postJobAttachmentsWillBeRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count existing attachments will be removed on save.',
      one: '$count existing attachment will be removed on save.',
    );
    return '$_temp0';
  }

  @override
  String get postJobTapToRecord =>
      'Tap to record — describe the problem in your own words';

  @override
  String get postJobService => 'Service';

  @override
  String get postJobWhatDoYouNeed => 'What do you need?';

  @override
  String get postJobChooseOneOption => 'Choose one option';

  @override
  String get postJobUnderstandingIsOurJob =>
      'Understanding the problem is our job — not yours.';

  @override
  String get postJobStandardWork => 'Standard work';

  @override
  String get postJobStandardWorkSubtitle => 'Work and price are clear upfront.';

  @override
  String get postJobIKnowThePart => 'I know the exact part';

  @override
  String get postJobIKnowThePartSubtitle =>
      'Ustaads send their rate, you choose';

  @override
  String get postJobIKnowThePartWarning =>
      'Only choose this if you are completely sure about the part. If it turns out wrong, the Ustaad visit is wasted and a new rate will apply.';

  @override
  String get postJobSomethingIsBroken => 'Something is broken';

  @override
  String get postJobDontKnowIssue => 'I do not know what the problem is';

  @override
  String get postJobInspectionFeeTitle => 'Inspection Fee';

  @override
  String get postJobChooseStandardService => 'Choose a standard service';

  @override
  String get postJobServicesUnavailable =>
      'Unable to load services. Please go back and try again.';

  @override
  String get postJobSelectCategoryFirst => 'Select a service category first.';

  @override
  String get postJobStandardServicesUnavailable =>
      'Unable to load standard services.';

  @override
  String get postJobNoStandardServices =>
      'No standard services are available for this service yet. Please choose another option above.';

  @override
  String get postJobMultiSelectHint => 'You can choose more than one service.';

  @override
  String get postJobTotal => 'Total';

  @override
  String get postJobInspectionFeeLower => 'Inspection fee';

  @override
  String get postJobInspectionFeeLoadFailed =>
      'Unable to load the inspection fee.';

  @override
  String get postJobHowInspectionWorks => 'How inspection works';

  @override
  String get postJobWhatDoYouSee => 'What problem do you observe? (required)';

  @override
  String get postJobWhatDoYouSeeHint => 'e.g. AC turns on but room stays hot…';

  @override
  String get postJobBack => 'Back';

  @override
  String get postJobNext => 'Next';

  @override
  String get postJobStepAddress => 'Address';

  @override
  String get postJobStepLaneSelection => 'Choose Type';

  @override
  String get postJobStepDetails => 'Details';

  @override
  String get postJobStepTimeSelection => 'Time Selection';

  @override
  String postJobStepIndicator(int current, int total, String title) {
    return 'Step $current of $total  ·  $title';
  }

  @override
  String get postJobProgressBarTime => 'Time';

  @override
  String get postJobRecommendedBadge => 'RECOMMENDED';

  @override
  String get trackLiveBadge => 'LIVE';

  @override
  String get clientHomeYourArea => 'Your Area';

  @override
  String get clientHomeSectionRepairs => 'Repairs';

  @override
  String get clientHomeSectionCleaning => 'Cleaning';

  @override
  String get clientHomeSectionPainting => 'Painting';

  @override
  String get clientHomeSectionOutdoorVehicle => 'Outdoor & Vehicle';

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
  String get clientHomeNoServicesFound => 'No services found';

  @override
  String get clientHomeSearchResults => 'Search Results';

  @override
  String get clientHomeBookUrgently => 'Book Urgently';

  @override
  String get clientHomeChooseServiceHelp =>
      'Choose a service to get help right away.';

  @override
  String clientHomeHello(String name) {
    return 'Hello, $name';
  }

  @override
  String get clientHomeGuest => 'there';

  @override
  String get clientHomeLocating => 'Finding your location…';

  @override
  String get clientHomeUrgentTitle => 'Need help right now?';

  @override
  String get clientHomeUrgentPromise =>
      'We’ll send an Ustaad quickly — same rate, no extra charge';

  @override
  String get clientHomeWhatNeedsDoing => 'What needs to be done?';

  @override
  String get clientHomeTrustMessage =>
      'Every Ustaad is CNIC verified · Rate is agreed first';

  @override
  String get clientHomeSupportUnavailable =>
      'HandyGo Support is unavailable right now. Please try again.';

  @override
  String clientHomeGreeting(String name) {
    return 'Hi $name 👋';
  }

  @override
  String get clientHomeBeatTheHeat => 'Beat the Karachi Heat ☀️';

  @override
  String get clientHomeAcServiceBanner =>
      'Get your AC serviced\nbefore it gets worse.';

  @override
  String get clientHomeBookAcTechnician => 'Book AC Technician';

  @override
  String get clientHomeNeedHelpNow => 'Need help now?';

  @override
  String get clientHomeUrgentSubtitle => 'For urgent issues, book instantly.';

  @override
  String get clientHome247Service => '24/7 Service';

  @override
  String get clientHomeRecent => 'Recent';

  @override
  String get clientHomeSeeAll => 'See all';

  @override
  String get timeNow => 'Now';

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
      'Profile image saved on this device. Cloud sync is not available yet.';

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
  String get commonRemove => 'Remove';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmBody =>
      'This will delete your HandyGo account and sign you out. This action may not be reversible.';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountRequestByEmail => 'Request deletion by email';

  @override
  String get commonLogout => 'Logout';

  @override
  String get clientJobsTitle => 'My Jobs';

  @override
  String get clientJobsEmpty => '📋  No jobs yet';

  @override
  String get locationSelected => 'Selected location';

  @override
  String get locationSearchHint => 'Search for an area or landmark…';

  @override
  String get locationGettingAddress => 'Getting address…';

  @override
  String get locationUseThis => 'Use This Location';

  @override
  String get serviceComingSoon => 'Coming Soon';

  @override
  String get clientHomeSearchHint => 'Search services...';

  @override
  String get profileDeleteFailed => 'Failed to delete account.';

  @override
  String get serviceBookNow => 'Book Now';

  @override
  String get serviceSelectedTick => 'Selected ✓';

  @override
  String get locationMoveMapHint => 'Move the map or tap to pick a location';

  @override
  String get slotMorning => 'Morning';

  @override
  String get slotAfternoon => 'Afternoon';

  @override
  String get slotEvening => 'Evening';

  @override
  String get slotNight => 'Night';

  @override
  String get slotMorningRange => '9 AM – 12 PM';

  @override
  String get slotAfternoonRange => '12 PM – 4 PM';

  @override
  String get slotEveningRange => '4 PM – 8 PM';

  @override
  String get slotNightRange => '8 PM – 11 PM';

  @override
  String get postJobSelectDate => 'Select date';

  @override
  String get postJobLocationAdded => 'Location added';

  @override
  String get postJobCurrentLocation => 'Current Location';

  @override
  String get postJobMapLocationAdded => 'Map location added';

  @override
  String get postJobPickOnMap => 'Pick on Map';

  @override
  String postJobMapPrefix(String address) {
    return 'Map: $address';
  }

  @override
  String get postJobGpsPrefix => 'Pinned Location';

  @override
  String get postJobBookService => 'Book';

  @override
  String get postJobSaveChanges => 'Save Changes';

  @override
  String get postJobBookAService => 'Book a Service';

  @override
  String get postJobEditBooking => 'Edit Booking';

  @override
  String get postJobNotAvailable => 'Not available';

  @override
  String get bookingLoadFailed => 'Failed to load booking.';

  @override
  String get bookingServiceDetails => 'Service Details';

  @override
  String get bookingIssue => 'Issue';

  @override
  String get bookingUrgency => 'Urgency';

  @override
  String get bookingTiming => 'Timing';

  @override
  String get bookingNotScheduledYet => 'Not scheduled yet';

  @override
  String get bookingTimeWindow => 'Time Window';

  @override
  String get bookingScheduledDate => 'Scheduled Date';

  @override
  String get bookingCreated => 'Created';

  @override
  String get bookingCancellationReason => 'Cancellation Reason';

  @override
  String get bookingInspectionCompletedBy => 'Inspection completed by';

  @override
  String get bookingWorkBeingCompletedBy => 'Work being completed by';

  @override
  String get bookingInspectionAndRepairBy => 'Inspection & repair by';

  @override
  String get bookingAssignedWorker => 'Assigned Worker';

  @override
  String get bookingDetailsTitle => 'Booking Details';

  @override
  String get bookingNoAddressProvided => 'No address provided';

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
  String get bookingPricing => 'Pricing';

  @override
  String get bookingEstimatedPrice => 'Estimated Price';

  @override
  String get bookingInspectionCharges => 'Inspection Charges';

  @override
  String get bookingWorkCharges => 'Work Charges';

  @override
  String get bookingFinalPrice => 'Final Price';

  @override
  String get bookingJobLocation => 'Job location';

  @override
  String get bookingLiveLocation => 'Live Location';

  @override
  String bookingTrackingWorker(String name) {
    return 'Tracking $name';
  }

  @override
  String get bookingWaitingForWorkerLocation =>
      'Waiting for worker to share location';

  @override
  String get bookingLiveLocationNotAvailable =>
      'Live location not available yet';

  @override
  String get bookingLocationPending => 'Location pending';

  @override
  String get bookingMapPreviewUnavailable => 'Map preview unavailable';

  @override
  String get bookingMapImageLoadFailed => 'Could not load the map image';

  @override
  String get bookingAppearsWhenEnRoute =>
      'Will appear once the worker is en route';

  @override
  String get bookingWorkerNearlyThere => 'Worker is nearly there';

  @override
  String get bookingWorkerOnTheWay => 'Worker is on the way';

  @override
  String get bookingLiveUpdatedNow => 'Live · Updated now';

  @override
  String get bookingStatusTimeline => 'Job Status Timeline';

  @override
  String get bookingJobExpired => 'This job expired';

  @override
  String get bookingExpiredExplanation =>
      'No worker was hired within 72 hours. Make it live again to keep looking.';

  @override
  String get bookingMakeLiveFailed => 'Failed to make job live again.';

  @override
  String get bookingMakeLiveAgain => 'Make Live Again';

  @override
  String bookingPreviousUstaadCancelledNamed(String name) {
    return 'Previous Ustaad cancelled: $name';
  }

  @override
  String get bookingPreviousUstaadCancelled => 'Previous Ustaad cancelled';

  @override
  String get bookingUstaadCancelledJob => 'The Ustaad cancelled this job';

  @override
  String bookingReasonPrefix(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get bookingFindAnotherUstaadFailed => 'Failed to find another Ustaad.';

  @override
  String get bookingFindAnotherUstaad => 'Find Another Ustaad';

  @override
  String get bookingSelectedServices => 'Selected Services';

  @override
  String bookingServiceQuantity(String name, int quantity) {
    return '$name x$quantity';
  }

  @override
  String get bookingChooseUstaad => 'Choose Ustaad';

  @override
  String get bookingSeeWorkerBids => 'See Worker Offers';

  @override
  String get bookingTrackWorker => 'Track Worker';

  @override
  String get bookingReviewWorker => 'Review Worker';

  @override
  String get bookingYourReview => 'Your Review';

  @override
  String get bookingCallWorker => 'Call Worker';

  @override
  String get bookingCancelBooking => 'Cancel Booking';

  @override
  String get bookingCancelFailed => 'The booking could not be cancelled.';

  @override
  String get bookingChatWithWorker => 'Chat with Worker';

  @override
  String get bookingLoadFailedShort => 'Failed to load booking';

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
  String get trackLoadFailed => 'Failed to load tracking data.';

  @override
  String get trackTitleUstaad => 'Track Ustaad';

  @override
  String get trackNoLocationForBooking =>
      'Location not available for this booking.';

  @override
  String get trackUstaadLocationUnavailable =>
      'The Ustaad\'s location is not available yet.';

  @override
  String get trackJobCompleted => 'Job Completed ✓';

  @override
  String get trackQuoteAcceptedRepairInProgress =>
      'Quote Accepted — Repair In Progress';

  @override
  String get trackReportSubmitted => 'Report Submitted';

  @override
  String get trackInspectionInProgress => 'Inspection In Progress';

  @override
  String get trackReviewReportAndDecide =>
      'Review the report below and decide how to proceed';

  @override
  String get trackWorkerLabel => 'Worker';

  @override
  String trackHiredAt(String price) {
    return 'Hired at $price';
  }

  @override
  String get trackPhoneUnavailable => 'Phone number unavailable';

  @override
  String get trackDialerFailed => 'Could not open phone dialer';

  @override
  String get trackAssignedWorkerCaps => 'ASSIGNED WORKER';

  @override
  String get trackCall => 'Call';

  @override
  String get trackLocationUnavailable => 'Location unavailable';

  @override
  String trackArrivingIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Arriving in ~$count minutes',
      one: 'Arriving in ~$count minute',
    );
    return '$_temp0';
  }

  @override
  String get trackEtaUnavailable => 'Arrival time unavailable';

  @override
  String get trackStepHired => 'Hired';

  @override
  String get trackStepUstaadOnTheWay => 'Ustaad on the way';

  @override
  String get trackStepInspectionInProgress => 'Inspection in progress';

  @override
  String get trackStepReportSubmitted => 'Report submitted';

  @override
  String get trackStepClosedAfterInspection => 'Closed after inspection';

  @override
  String get trackStepQuoteAccepted => 'Quote accepted';

  @override
  String get trackStepReviewed => 'Reviewed';

  @override
  String get trackStepWorkInProgress => 'Work in progress';

  @override
  String get trackStepReviewPending => 'Review pending';

  @override
  String get trackJobProgress => 'Job Progress';

  @override
  String get trackLoadFailedShort => 'Failed to load tracking';

  @override
  String get discoveryJobLocation => 'Job Location';

  @override
  String get discoveryJobLocationUnavailable => 'Job location not available';

  @override
  String get discoveryLiveWorkerOffers => 'Live Worker Offers';

  @override
  String get discoveryRefresh => 'Refresh';

  @override
  String get discoveryBidsLoadFailed => 'Could not load offers.';

  @override
  String get discoveryNoBidsYet => 'No offers yet';

  @override
  String discoveryPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending',
      one: '$count pending',
    );
    return '$_temp0';
  }

  @override
  String get discoveryHire => 'Hire';

  @override
  String get discoveryHiring => 'Hiring…';

  @override
  String discoveryHireNamed(String name) {
    return 'Hire $name?';
  }

  @override
  String discoveryAcceptBid(String name, String price) {
    return 'Accept $name\'s offer of $price?';
  }

  @override
  String get discoveryInspectionFeeSeparate =>
      'The inspection fee is paid separately.\nThe new Ustaad\'s offer is charged separately.';

  @override
  String get discoveryBidLabourOnlyNote =>
      'This offer covers labour only. Parts and materials will be purchased or charged separately with your approval.';

  @override
  String get discoveryBidInspectionBasedNote =>
      'This offer is based on the inspection report and includes labour and the parts or materials required for the reported work.';

  @override
  String get discoveryWorkerHired => 'Worker hired successfully';

  @override
  String get discoveryHireFailed => 'Failed to hire worker.';

  @override
  String get discoveryInspectedThisJob => 'INSPECTED THIS JOB';

  @override
  String get discoveryTheirQuote => 'their quote';

  @override
  String get discoveryInspectionCompletedByThis =>
      'Inspection completed by this Ustaad.';

  @override
  String get discoveryViewInspectionReport => 'View Inspection Report';

  @override
  String get discoveryHireAgain => 'Hire Again';

  @override
  String discoveryHireAgainNamed(String name) {
    return 'Hire $name again?';
  }

  @override
  String get discoveryOriginalQuoteContinues =>
      'They\'ll continue using their original inspection quote.';

  @override
  String get discoveryWorkersWillAppear =>
      'Workers who apply will appear here.\nCheck back shortly.';

  @override
  String get discoveryTryAgain => 'Try again';

  @override
  String get postJobInspectionReportSectionTitle =>
      'Inspection Report (Optional)';

  @override
  String get postJobAttachInspectionReport =>
      'Attach previous inspection report';

  @override
  String get postJobAttachInspectionHint =>
      'Help bidders understand the job by sharing an earlier diagnosis.';

  @override
  String get postJobChangeInspectionReport => 'Change report';

  @override
  String get postJobSelectInspectionReport => 'Select an inspection report';

  @override
  String get postJobNoInspectionReports =>
      'No previous inspection reports available for this service.';

  @override
  String get postJobInspectionReportsFailed =>
      'Could not load your inspection reports.';

  @override
  String get postJobInspectionReportCleared =>
      'Attached inspection report was removed because the service changed.';

  @override
  String get inspectionReportTitle => 'Inspection Report';

  @override
  String get inspectionReportNotAvailable => 'Report not available yet.';

  @override
  String get inspectionUstaadVoiceNote => 'Ustaad Voice Note';

  @override
  String get inspectionPhotos => 'Photos';

  @override
  String get inspectionParts => 'Parts';

  @override
  String get inspectionRepairQuoteTotal => 'Repair quote total';

  @override
  String get inspectionAcceptQuoteContinue => 'Accept Quote & Continue Repair';

  @override
  String get inspectionFindOtherUstaad => 'Find Other Ustaad';

  @override
  String get inspectionCloseAfterInspection => 'Close After Inspection';

  @override
  String get inspectionAcceptQuoteConfirmTitle =>
      'Accept quote & continue repair?';

  @override
  String get inspectionCloseConfirmTitle => 'Close after inspection?';

  @override
  String get inspectionAcceptQuoteConfirmBody =>
      'The same Ustaad will continue the repair. The inspection fee is waived — you will only pay the repair quote.';

  @override
  String get inspectionCloseConfirmBody =>
      'You will only be charged the inspection fee. The job will be marked completed.';

  @override
  String get inspectionClosedAfterInspection => 'Closed after inspection.';

  @override
  String get inspectionQuoteAcceptedRepairInProgress =>
      'Quote accepted — repair in progress.';

  @override
  String get inspectionActionFailed => 'Action failed. Try again.';

  @override
  String get inspectionFindAnotherConfirmTitle => 'Find another Ustaad?';

  @override
  String get inspectionFindAnotherConfirmBody =>
      'Confirming completes the inspection and charges the inspection fee. Your job goes live again so other Ustaads can send their rates.';

  @override
  String get inspectionBadge => 'Inspection';

  @override
  String get chooseHireConfirmTitle => 'Hire this Ustaad?';

  @override
  String chooseHireConfirmBody(String name) {
    return 'Hire $name for this job? You won\'t be able to choose a different Ustaad afterwards.';
  }

  @override
  String get chooseAssignFailed =>
      'Unable to assign this Ustaad. Please try again.';

  @override
  String chooseServiceTotal(String price) {
    return 'Service Total $price';
  }

  @override
  String chooseInspectionFeeAmount(String price) {
    return 'Inspection fee $price';
  }

  @override
  String get chooseFindingUstaads => 'Finding verified Ustaads near you…';

  @override
  String get chooseLoadFailed => 'Unable to load available Ustaads right now.';

  @override
  String get chooseNoUstaadAvailable =>
      'No verified Ustaad available right now.';

  @override
  String get chooseAutoRefreshNote =>
      'The list refreshes automatically every 45 seconds.';

  @override
  String get chooseRefreshOrWait =>
      'You can refresh or wait a little — checking available Ustaads…';

  @override
  String get chooseNewBadge => 'New';

  @override
  String get chooseSelect => 'Select';

  @override
  String get chooseRecommended => 'Recommended';

  @override
  String get chooseSkills => 'Skills';

  @override
  String get myBookingsLoadFailed =>
      'Unable to load your bookings. Please try again.';

  @override
  String get myBookingsTitle => 'My Bookings';

  @override
  String get myBookingsEmptyTitle => 'No bookings yet';

  @override
  String get myBookingsNoResults => 'No results found';

  @override
  String get myBookingsAdjustFilters =>
      'Try adjusting your filters or search term';

  @override
  String get myBookingsBookFirst => 'Book your first service to get started';

  @override
  String get myBookingsRefreshFailed => 'Could not refresh. Pull to retry.';

  @override
  String get myBookingsSomethingWrong => 'Something went wrong';

  @override
  String cardTodayAt(String time) {
    return 'Today, $time';
  }

  @override
  String get cardGoesLiveBefore => 'Goes live 1h before window';

  @override
  String get cardWorkersNotified => 'Workers are notified immediately';

  @override
  String get cardSearchingWorkers => 'Searching for workers...';

  @override
  String get cardNoWorkerYet => 'No worker yet';

  @override
  String get cardEstimatePrefix => 'est.';

  @override
  String get cardFindWorkers => 'Find Workers';

  @override
  String get cardEdit => 'Edit';

  @override
  String get filterTitle => 'Filter Bookings';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterAll => 'All';

  @override
  String get filterUrgentOption => '⚡ Urgent';

  @override
  String get filterNormalOption => '🗓 Normal';

  @override
  String get filterSortByDate => 'Sort by date';

  @override
  String get filterNewestFirst => 'Newest first';

  @override
  String get filterOldestFirst => 'Oldest first';

  @override
  String get filterApply => 'Apply Filters';

  @override
  String get searchBookingsHint => 'Search bookings, services...';

  @override
  String get cancelReasonTitle => 'Reason for cancelling the booking';

  @override
  String get cancelReasonRequired => 'Please give a reason.';

  @override
  String get cancelReasonSelect => 'Select a reason';

  @override
  String get cancelReasonWriteOwn => 'Write your own reason';

  @override
  String get reviewSubmitFailed => 'The review could not be submitted.';

  @override
  String get reviewPromptBeforeContinuing =>
      'Please review your Ustaad before continuing.';

  @override
  String get reviewHowWasWork => 'How was the work?';

  @override
  String get reviewCommentHint => 'Write a comment (optional)...';

  @override
  String get reviewSubmit => 'Submit Review';

  @override
  String get reviewLater => 'Later';

  @override
  String get chatOpenFailed => 'Could not open chat.';

  @override
  String get mediaTapToPlay => 'Tap to play';

  @override
  String get inspectionConfirm => 'Confirm';

  @override
  String trackSubtextCompleted(String name) {
    return '$name has completed the job';
  }

  @override
  String trackSubtextContinuingRepair(String name) {
    return '$name is continuing the repair';
  }

  @override
  String trackSubtextOnTheWay(String name) {
    return '$name is on the way to your location';
  }

  @override
  String trackSubtextArrived(String name) {
    return '$name has arrived at your location';
  }

  @override
  String trackSubtextInspecting(String name) {
    return '$name is inspecting the issue';
  }

  @override
  String trackSubtextHiredForInspection(String name) {
    return '$name has been hired for this inspection';
  }

  @override
  String trackSubtextWorking(String name) {
    return '$name is working on your job';
  }

  @override
  String trackSubtextHiredForJob(String name) {
    return '$name has been hired for this job';
  }

  @override
  String get urgentWithin1Hour => 'Within 1 hour';

  @override
  String get urgentWithin2Hours => 'Within 2 hours';

  @override
  String get urgentWithin4Hours => 'Within 4 hours';

  @override
  String get inspectionFeePaid => 'Inspection fee paid';

  @override
  String get inspectionFeeNotPaid => 'Inspection fee not paid';

  @override
  String chooseWithinRadius(String km) {
    return 'within $km km';
  }

  @override
  String chooseHireConfirmBodyFull(String name) {
    return 'Hire $name for this job? You will not be able to choose a different Ustaad afterwards.';
  }

  @override
  String get trackHeadlineUstaadOnTheWay => 'Ustaad On The Way';

  @override
  String get trackHeadlineUstaadArrived => 'Ustaad Arrived';

  @override
  String get trackHeadlineWorkInProgress => 'Work In Progress';

  @override
  String get trackHeadlineHired => 'Hired ✓';

  @override
  String trackRatingOutOfFive(String rating) {
    return '$rating / 5.0';
  }

  @override
  String get discoveryLoadingBids => 'Loading offers...';

  @override
  String get discoveryBidsLoadFailedShort => 'Could not load offers';

  @override
  String bookingWorkersAvailableNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workers available nearby',
      one: '$count worker available nearby',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending offers · sorted by price',
      one: '$count pending offer · sorted by price',
    );
    return '$_temp0';
  }

  @override
  String get workerOffline => 'Offline';

  @override
  String get workerOnline => 'Online';

  @override
  String get workerBusy => 'Busy';

  @override
  String get workerOfflineHelper => 'You are hidden from clients';

  @override
  String get workerOnlineHelper => 'Clients near your location can see you';

  @override
  String get workerBusyHelper => 'You are currently working on a job';

  @override
  String get workerStatusOnTheWay => 'On the Way';

  @override
  String get workerActionOnMyWay => 'On My Way';

  @override
  String get workerActionArrived => 'Arrived';

  @override
  String get workerActionStartJob => 'Start Job';

  @override
  String get workerActionCompleteJob => 'Complete Job';

  @override
  String get workerActionStartInspection => 'Start Inspection';

  @override
  String get workerActionStartWork => 'Start Work';

  @override
  String get workerActionFillReport => 'Fill Inspection Report';

  @override
  String get workerActionWaitingForClient => 'Waiting for Client Decision';

  @override
  String get workerSuccessOnTheWay => 'On the way — client notified.';

  @override
  String get workerSuccessArrived => 'Marked as arrived.';

  @override
  String get workerSuccessJobStarted => 'Job started.';

  @override
  String get workerSuccessJobCompleted => 'Job marked as completed.';

  @override
  String get workerSuccessInspectionStarted => 'Inspection started.';

  @override
  String get workerSuccessWorkStarted => 'Work started.';

  @override
  String get workerSkillNotSelected => 'Skill not selected';

  @override
  String get workerLocating => 'Locating…';

  @override
  String get workerTapToRetry => 'Tap to retry';

  @override
  String get workerTapForLocation => 'Tap for location';

  @override
  String get workerOnActiveJob => 'On Active Job';

  @override
  String get workerConnecting => 'Connecting...';

  @override
  String get workerGoingOffline => 'Going offline...';

  @override
  String get workerGoOffline => 'Go Offline';

  @override
  String get workerGoOnline => 'Go Online';

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
  String get workerGoOfflineConfirmTitle => 'Go Offline?';

  @override
  String get workerGoOfflineConfirmBody =>
      'You will stop appearing to nearby clients.';

  @override
  String get workerGoOfflineConfirmYes => 'Yes, Go Offline';

  @override
  String get workerFindNewWork => 'New Complaints';

  @override
  String get workerViewNewJobs => 'Dekhein';

  @override
  String get workerActiveJobCaps => 'ACTIVE JOB';

  @override
  String get workerMap => 'Map';

  @override
  String get workerViewDetails => 'View details →';

  @override
  String get workerNoActiveJob => 'No active job right now';

  @override
  String get workerStayOnlineHint => 'Stay online to find work nearby.';

  @override
  String get workerReady => 'Ready';

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
  String get workerSeeAll => 'See all →';

  @override
  String get workerNoReviewsYet => 'No reviews yet';

  @override
  String get workerReviewsAppearHint =>
      'Client reviews will appear here after your completed jobs.';

  @override
  String get workerSelectMainSkill => 'Select your main skill';

  @override
  String get workerSelectMainSkillHint =>
      'Select your main skill to start receiving work';

  @override
  String workerCategoriesLoadFailed(String error) {
    return 'Failed to load categories: $error';
  }

  @override
  String get workerSkillsSaveFailed =>
      'Failed to save skills. Please try again.';

  @override
  String get workerSaveAndGoOnline => 'Save & Go Online';

  @override
  String get workerDashboardLoadFailed => 'Failed to load dashboard';

  @override
  String get workerNewJobsTitle => 'New Jobs';

  @override
  String get workerNewJobsSubtitle => 'Work matching your skills';

  @override
  String get workerCompleteProfileForNewJobs =>
      'Complete your profile. Once it is approved you will start seeing new jobs.';

  @override
  String get workerNewJobsLoadFailed => 'Failed to load new jobs.';

  @override
  String workerOfferCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers',
      one: '$count offer',
    );
    return '$_temp0';
  }

  @override
  String get workerDirectHireNote =>
      'The client can hire you directly. No offer needed.';

  @override
  String get workerListedJob => 'Listed Job';

  @override
  String get workerOfferSent => 'Offer sent';

  @override
  String get workerNoNewJobs => 'No new jobs right now';

  @override
  String get workerNoNewJobsHint =>
      'New job requests matching your skills will appear here. Pull down to refresh.';

  @override
  String get workerCompleteProfileForJobs =>
      'Complete your profile. Once it is approved you can manage your jobs.';

  @override
  String get workerJobsLoadFailed => 'Failed to load jobs. Please try again.';

  @override
  String get workerClientCancelledBooking =>
      'The client cancelled this booking';

  @override
  String get workerOnlyInspectionCompleted =>
      'Only the inspection was completed';

  @override
  String get workerComplete => 'Complete';

  @override
  String get workerCompleting => 'Completing...';

  @override
  String get workerMarkCompletedTitle => 'Mark as Completed?';

  @override
  String get workerMarkCompletedBody =>
      'This will close the job and notify the client.';

  @override
  String get workerNoActiveJobs => 'No active jobs';

  @override
  String get workerNoCompletedJobs => 'No completed jobs yet';

  @override
  String get workerNoCancelledJobs => 'No cancelled jobs';

  @override
  String get workerNoJobsAssigned => 'No jobs assigned yet';

  @override
  String get workerNoAppliedJobs => 'No applied jobs yet';

  @override
  String get workerNewRequestsHere => 'New requests will appear here';

  @override
  String get workerCompletedJobsHere => 'Completed jobs will show up here';

  @override
  String get workerCancelledJobsHere => 'Cancelled jobs will show up here';

  @override
  String get workerAppliedJobsHere =>
      'Jobs you\'ve placed an offer on will show up here';

  @override
  String get workerAcceptToGetStarted =>
      'Accept a booking request to get started';

  @override
  String get workerFilterCancelled => 'Cancelled';

  @override
  String get workerFilterAllWork => 'All Work';

  @override
  String get workerFilterMyOffers => 'My Offers';

  @override
  String get workerFilterNoOfferSent => 'No offer sent';

  @override
  String get bidPlaceABid => 'Send an Offer';

  @override
  String get bidChatWithClient => 'Chat with Client';

  @override
  String get bidLiveBids => 'Live Offers';

  @override
  String get bidAreaNotAvailable => 'Area not available';

  @override
  String get bidExactAddressAfterAccept =>
      'The exact address is shared once the client accepts your offer.';

  @override
  String get bidStatusAccepted => 'Accepted';

  @override
  String get bidStatusRejected => 'Rejected';

  @override
  String get bidStatusPending => 'Pending';

  @override
  String get bidYourCurrentBid => 'Your Current Offer';

  @override
  String get bidSubmit => 'Submit Offer';

  @override
  String get bidUpdate => 'Update Offer';

  @override
  String get bidPlaceYourBid => 'Send Your Offer';

  @override
  String get bidUpdateYourBid => 'Update Your Offer';

  @override
  String bidCanUpdateIn(String seconds) {
    return 'You can update your offer in ${seconds}s.';
  }

  @override
  String get bidCanUpdateNow => 'You can update your offer now.';

  @override
  String get bidAmountLabel => 'Offer Amount (PKR) *';

  @override
  String get bidAmountHint => 'e.g. 2500';

  @override
  String bidLabelWithCountdown(String label, String seconds) {
    return '$label (${seconds}s)';
  }

  @override
  String bidJobCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '$count job',
    );
    return '$_temp0';
  }

  @override
  String get bidBeFirstToBid => 'Be the first to send an offer on this job';

  @override
  String get earningBidding => 'Offers';

  @override
  String get earningHistoryTitle => 'Earning History';

  @override
  String get earningNoneYet => 'No earnings yet';

  @override
  String get earningNoneHint =>
      'Completed jobs will show up here with your daily earnings.';

  @override
  String get reviewsMyReviews => 'My Reviews';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$_temp0';
  }

  @override
  String get reviewsSubtitle => 'Reviews from clients for jobs you completed';

  @override
  String get reviewsAvg => 'Avg';

  @override
  String get reviewsMax => 'Max';

  @override
  String get reviewsMin => 'Min';

  @override
  String get reviewsEmptyHint =>
      'Once clients review your completed jobs,\ntheir reviews will appear here.';

  @override
  String reviewsRatingSummary(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$rating · $_temp0';
  }

  @override
  String reviewsHighestLowest(String max, String min) {
    return 'Highest: $max ★  ·  Lowest: $min ★';
  }

  @override
  String get inspFormChooseFromGallery => 'Choose from Gallery';

  @override
  String get inspFormSubmitted =>
      'Report submitted. Waiting for client decision.';

  @override
  String get inspFormSubmitFailed => 'Failed to submit report.';

  @override
  String get inspFormWhatWasIssue => 'What was the issue?';

  @override
  String get inspFormWhatWasIssueRequired => 'What was the issue? *';

  @override
  String get inspFormRecommendedRepair => 'Recommended Repair';

  @override
  String get inspFormRecommendedRepairRequired => 'Recommended Repair *';

  @override
  String get inspFormWhatWorkNeeded => 'What work will be needed';

  @override
  String get inspFormWriteOrRecord =>
      'Please write the report or record a voice note.';

  @override
  String get inspFormPartsRequired => 'Parts required?';

  @override
  String get inspFormAddPart => 'Add part';

  @override
  String get inspFormUstaadNotes => 'Ustaad notes';

  @override
  String get inspFormSubmitReport => 'Submit report';

  @override
  String inspFormIssuePhotos(int max) {
    return 'Issue photos — optional, max $max';
  }

  @override
  String get inspFormVoiceNote => 'Voice note';

  @override
  String get inspFormVoiceNoteHint =>
      'If writing is difficult, record a voice note instead.';

  @override
  String inspFormRecording(String duration) {
    return 'Recording  $duration';
  }

  @override
  String get inspFormStop => 'Stop';

  @override
  String get inspFormStartRecording => 'Start recording';

  @override
  String get inspFormPartNameHint => 'e.g. the part or material used';

  @override
  String get inspFormWarrantyHint => 'e.g. 7 days';

  @override
  String get inspFormRemovePart => 'Remove part';

  @override
  String get inspFormTotalAmount => 'Total amount for the work';

  @override
  String get inspFormFeeWaivedNote =>
      'If the customer continues with the repair, the inspection fee will not be charged.';

  @override
  String get inspHintElectrical => 'e.g. switch is broken, wire is shorted...';

  @override
  String get inspHintPlumbing => 'e.g. pipe is leaking, drain is blocked...';

  @override
  String get inspHintAc => 'e.g. AC is not cooling, gas leak...';

  @override
  String get inspHintCarpentry =>
      'e.g. door does not close properly, hinge is broken...';

  @override
  String get workerCompleteProfile => 'Complete Profile';

  @override
  String get workerApprovalRequired =>
      'Profile approval is required before you can receive jobs.';

  @override
  String get workerCompleteProfileDetails => 'Complete your profile details.';

  @override
  String get workerCompleteProfileWhy =>
      'You can only apply for or be hired for jobs once your profile is complete.';

  @override
  String earningJobsCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs completed',
      one: '$count job completed',
    );
    return '$_temp0';
  }

  @override
  String get bookingStatusLive => 'Live';

  @override
  String get bookingStatusAssigned => 'Assigned';

  @override
  String get bookingStatusCompleted => 'Completed';

  @override
  String get bookingStatusExpired => 'Expired';

  @override
  String get jobStatusEnRoute => 'En Route';

  @override
  String get jobStatusInProgress => 'In Progress';

  @override
  String get l10nFallbackProbe => 'English fallback works';

  @override
  String get workerJobDetailsTitle => 'Job Details';

  @override
  String get workerJobLoadFailed => 'Failed to load job.';

  @override
  String get workerStandardDirectHireNote =>
      'This is a Standard job. The client can hire you directly — you do not need to send an offer.';

  @override
  String get workerReportSubmittedWaiting =>
      'Report submitted. Waiting for the client to accept the quote or close after inspection.';

  @override
  String get workerClientSection => 'Client';

  @override
  String get workerPostedBy => 'Posted by';

  @override
  String get workerCategoryLabel => 'Category';

  @override
  String get workerTitleLabel => 'Title';

  @override
  String get workerTimeSlotLabel => 'Time Slot';

  @override
  String get workerTimelineSection => 'Timeline';

  @override
  String get workerTimelineScheduled => 'Scheduled';

  @override
  String get workerTimelineStarted => 'Started';

  @override
  String get workerEstimatedLabel => 'Estimated';

  @override
  String get workerFeeStatusLabel => 'Status';

  @override
  String get workerCancelJob => 'Cancel Job';

  @override
  String get workerCancelJobTitle => 'Cancel this job?';

  @override
  String get workerCancelJobBody =>
      'Please tell the client why you are cancelling.';

  @override
  String get workerCancelOwnReasonHint => 'Write your own reason (required)';

  @override
  String get workerKeepJob => 'Keep Job';

  @override
  String get workerYesCancel => 'Yes, cancel';

  @override
  String get workerCancelReasonEmergency => 'An emergency came up';

  @override
  String get workerCancelReasonTooFar => 'The location is too far';

  @override
  String get workerCancelReasonNoTools =>
      'Required tools or parts are not available';

  @override
  String get workerCancelReasonSchedule => 'Time or schedule issue';

  @override
  String get workerCancelReasonCustomer => 'Customer or site related issue';

  @override
  String get workerCancelReasonOther => 'Other';

  @override
  String get workerAttachmentsVideos => 'Videos';

  @override
  String get workerAttachmentsVoiceNotes => 'Voice Notes';

  @override
  String get workerStatusHistory => 'Status History';

  @override
  String get workerMarkAsCompleted => 'Mark as Completed';

  @override
  String get workerClientReview => 'Client Review';

  @override
  String workerReviewRatingOutOfFive(int rating) {
    return '$rating/5';
  }

  @override
  String workerApproximateArea(String city) {
    return 'Approximate area: $city';
  }

  @override
  String get workerApproximateAreaUnavailable =>
      'Approximate area not available';

  @override
  String workerDistanceLabel(String distance) {
    return 'Distance: $distance';
  }

  @override
  String get workerExactAddressAfterHire =>
      'The exact address and map become visible once you are hired for this job.';

  @override
  String get workerRoadRouteNotConfigured =>
      'Road route is not configured yet. Opening Google Maps for navigation.';

  @override
  String get workerLocationPermissionDenied => 'Location permission denied.';

  @override
  String get workerDirectionsLocationFailed =>
      'Unable to get your location for directions.';

  @override
  String get workerArrivedAtJobLocation =>
      'You have arrived at the job location.';

  @override
  String get workerYourLocation => 'Your Location';

  @override
  String get workerCityLabel => 'City';

  @override
  String get workerClientAddress => 'Client Address';

  @override
  String get workerPinnedJobLocation => 'Pinned Job Location';

  @override
  String get workerPinnedOnMap => 'Pinned on map';

  @override
  String get workerGettingLocation => 'Getting location...';

  @override
  String get workerDirections => 'Directions';

  @override
  String get workerOpenInMaps => 'Open in Maps';

  @override
  String get workerDirectionsActive => 'Directions active';

  @override
  String get workerUploadFailed => 'Upload failed. Please try again.';

  @override
  String get workerCompleteHighlightedFields =>
      'Please complete the highlighted fields below.';

  @override
  String get workerProfileSaveFailed =>
      'Failed to save profile. Please try again.';

  @override
  String get workerProfileSubmitted => 'Profile submitted for approval.';

  @override
  String get workerCompleteAllRequired =>
      'Please complete all required fields before submitting.';

  @override
  String get workerProfileLoadFailed => 'Failed to load profile.';

  @override
  String get workerFullLegalName => 'Full Legal Name';

  @override
  String get workerLegalNameHint => 'As written on your CNIC';

  @override
  String get workerLegalNameRequired => 'Full legal name is required.';

  @override
  String get workerCnicNumber => 'CNIC Number';

  @override
  String get workerCnicInvalid => 'Enter CNIC like 12345-1234567-1';

  @override
  String get workerMainSkill => 'Main Skill';

  @override
  String get workerMainSkillNotSelected => 'Not selected';

  @override
  String get workerChangeSkill => 'Change';

  @override
  String get workerMainSkillRequired => 'Please select your main skill.';

  @override
  String get workerExperienceYears => 'Experience in Years';

  @override
  String get workerExperienceHint => 'e.g. 3';

  @override
  String get workerExperienceInvalid =>
      'Enter a valid number of years (0 or more).';

  @override
  String get workerResidentialAddress => 'Residential Address';

  @override
  String get workerResidentialAddressHint => 'House #, street, area, city';

  @override
  String get workerResidentialAddressRequired =>
      'Residential address is required.';

  @override
  String get workerIdentityDocuments => 'Identity Documents';

  @override
  String get workerCnicFront => 'CNIC Front';

  @override
  String get workerCnicBack => 'CNIC Back';

  @override
  String get workerLiveSelfie => 'Live Selfie';

  @override
  String get workerDocumentRequired => 'Required';

  @override
  String get workerAgreements => 'Agreements';

  @override
  String get workerConfirmLegalName =>
      'I confirm my legal name matches my CNIC.';

  @override
  String get workerViewAgreement => 'View Agreement';

  @override
  String get workerConfirmationRequired => 'This confirmation is required.';

  @override
  String get workerSubmitForApproval => 'Submit for Approval';

  @override
  String workerAgreementVersion(String version) {
    return 'Version $version';
  }

  @override
  String get workerOnboardingSubmitted => 'Submitted for Review';

  @override
  String get workerOnboardingChangesRequired => 'Changes Required';

  @override
  String get workerOnboardingApproved => 'Approved';

  @override
  String get workerOnboardingDraft => 'Draft';

  @override
  String get workerRoleBadge => 'Ustaad';

  @override
  String workerMainSkillWithName(String skill) {
    return 'Main Skill: $skill';
  }

  @override
  String get workerNoMainSkillYet => 'No main skill selected yet';

  @override
  String get workerProfileApproval => 'Profile Approval';

  @override
  String get inspHintFallback => 'e.g. describe what you found';

  @override
  String get bidAmountRequired => 'Please enter an offer amount.';

  @override
  String get bidAmountRange => 'Offer amount must be between 100 and 500,000.';

  @override
  String get bidSubmitted => 'Offer submitted!';

  @override
  String get bidSubmitFailed => 'Failed to submit offer.';

  @override
  String get workerViewJobDetails => 'View Details';

  @override
  String get workerSendOffer => 'Send Offer';

  @override
  String get workerChangeOffer => 'Change Offer';

  @override
  String get workerOnboardingSubmittedBody =>
      'Your profile is with the admin for review.';

  @override
  String get workerOnboardingChangesRequiredBody =>
      'Your profile needs changes — see the details.';

  @override
  String get workerOnboardingRejectedBody =>
      'Your profile was rejected — see the reason.';

  @override
  String get workerProfileIncomplete => 'Profile Incomplete';

  @override
  String get inspFormLabourCostRequired => 'Labour cost *';

  @override
  String get inspFormNotesOptional => 'Notes (optional)';

  @override
  String get inspFormPartName => 'Part name';

  @override
  String get inspFormQty => 'Qty';

  @override
  String get inspFormUnitPrice => 'Unit price';

  @override
  String get inspFormWarrantyOptional => 'Warranty / guarantee (optional)';

  @override
  String get inspFormPartsTotal => 'Parts total';

  @override
  String get inspFormLabour => 'Labour';

  @override
  String get inspFormMicPermanentlyDenied =>
      'Microphone access is permanently denied. Enable it in Settings.';

  @override
  String get inspFormMicDenied => 'Microphone permission denied.';

  @override
  String get errorTimeout => 'The connection timed out. Please try again.';

  @override
  String get errorRequestCancelled => 'The request was cancelled.';

  @override
  String get errorInvalidRequest =>
      'Some details are not correct. Please check them and try again.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get errorForbidden => 'You do not have permission for this action.';

  @override
  String get errorNotFound => 'This is no longer available.';

  @override
  String get errorConflict =>
      'This has already been updated. Please refresh and try again.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorSmsSendFailed =>
      'The SMS could not be sent. Please try again.';

  @override
  String get errorOtpResendTooSoon =>
      'Please wait a moment before requesting the OTP again.';

  @override
  String get errorInspectorBusy =>
      'The inspecting Ustaad is busy on another job right now. Please choose another Ustaad from the list below.';

  @override
  String get errorPhoneNotRegistered => 'This number is not registered.';

  @override
  String get errorPhoneAlreadyRegistered =>
      'This number is already registered.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorOfflineActionBlocked =>
      'No internet connection. Connect to the internet to continue.';

  @override
  String get offlineCachedDataBanner => 'Offline — showing saved data';

  @override
  String get authForgotPasswordTitle => 'Forgot your\npassword?';

  @override
  String get authSetNewPasswordTitle => 'Set a new\npassword';

  @override
  String get authEnterCodeSentToNumber => 'Enter the code sent to your number.';

  @override
  String get authForgotPasswordClientOnly =>
      'For Client accounts only. A code will be sent to the registered number.';

  @override
  String get authForgotPasswordWorkerOnly =>
      'For Ustaad accounts only. A code will be sent to the registered number.';

  @override
  String get authErrorCodeSendFailed => 'The code could not be sent.';

  @override
  String get authErrorPasswordChangeFailed =>
      'The password could not be changed.';

  @override
  String get authErrorLoginFailed => 'Could not log you in.';

  @override
  String get authErrorRegisterFailed => 'The account could not be created.';

  @override
  String get authLoginWithOtp => 'Log In With OTP';

  @override
  String get authHintExampleFullName => 'Muhammad Ali Khan';

  @override
  String get notificationsBannerFallbackTitle => 'Notification';

  @override
  String get legalEnglishOnlyNotice =>
      'This legal document is currently available in English only.';

  @override
  String myBookingsTotalCount(int count) {
    return '$count total';
  }

  @override
  String get workerBidJobFallbackTitle => 'Job';

  @override
  String get navHome => 'Home';

  @override
  String get navBookings => 'Bookings';

  @override
  String get inspectionRowIssueFound => 'Issue found';

  @override
  String get inspectionRowNotes => 'Notes';

  @override
  String get inspectionBadgeAwaitingDecision =>
      'Report submitted — awaiting decision';

  @override
  String get inspectionBadgeQuoteAccepted =>
      'Quote accepted — repair in progress';

  @override
  String get inspectionBadgeFindingAnother =>
      'Finding another Ustaad — open for offers';

  @override
  String inspStripClosedFeeOnlyWithAmount(String fee) {
    return 'Closed after inspection — client pays inspection fee only: $fee';
  }

  @override
  String get inspStripClosedFeeOnly =>
      'Closed after inspection — client pays inspection fee only.';

  @override
  String get inspStripRepairCompletedFeeWaived =>
      'Repair completed — inspection fee waived.';

  @override
  String get inspStripQuoteAcceptedFeeWaived =>
      'Quote accepted — inspection fee waived. Repair in progress.';

  @override
  String get inspStripReportSubmitted =>
      'Inspection report submitted — review quote to continue repair or close after inspection.';

  @override
  String get inspStripUstaadHired => 'Ustaad hired';

  @override
  String get inspStripBookedChooseUstaad =>
      'Inspection booked — choose an Ustaad';

  @override
  String chooseChipCancelRate(int rate) {
    return '$rate% cancel';
  }

  @override
  String get locationCurrentFailed => 'Could not get current location.';

  @override
  String get locationResolveFailed => 'Could not resolve selected location.';

  @override
  String get locationOutsideKarachi =>
      'Location is outside the Karachi service area.';

  @override
  String postJobVideoTooLong(int seconds) {
    return 'Video must be $seconds seconds or shorter.';
  }

  @override
  String get postJobLocationRetrieveFailed =>
      'Could not retrieve location. Please try again.';

  @override
  String get postJobSelectOption => 'Select an option to continue.';

  @override
  String get postJobDescribeIssue => 'Please describe what needs fixing.';

  @override
  String get postJobSelectStandardService =>
      'Please select at least one standard service.';

  @override
  String get postJobSelectArrivalWindow => 'Please select an arrival window.';

  @override
  String get postJobSelectUrgencyWindow => 'Please select an urgency window.';

  @override
  String get postJobEnterAddress => 'Enter your address.';

  @override
  String get postJobAddAddressToContinue =>
      'Add your service address to continue.';

  @override
  String get postJobNearbyNotifiedNow =>
      'Nearby Ustaads are notified right away.';

  @override
  String get postJobInspectionNotAvailable =>
      'Inspection is not available for this service.';

  @override
  String get postJobInspectionHeroStep1 =>
      'The Ustaad comes and checks it himself';

  @override
  String get postJobInspectionHeroStep2 =>
      'The rate is agreed before any work starts.';

  @override
  String get postJobInspectionHeroStep3 =>
      'Go ahead if you like the quote, otherwise just pay the inspection fee.';

  @override
  String get postJobStandardTotalFinal =>
      'Total amount is final — no offers. You choose your Ustaad in the next step.';

  @override
  String get postJobHowInspectionStep1 => 'The inspection fee is fixed.';

  @override
  String get postJobHowInspectionStep2 =>
      'Ustaad visits, finds the problem, and gives you a fixed repair quote in the app.';

  @override
  String get postJobHowInspectionStep3 =>
      'Accept his quote and continue, or get offers from other Ustaads — your choice.';

  @override
  String get cancelReasonNoLongerNeeded => 'I no longer need the service';

  @override
  String get cancelReasonBookedByMistake => 'I booked it by mistake';

  @override
  String get cancelReasonProblemSolved => 'The problem sorted itself out';

  @override
  String get cancelReasonTimingNotSuitable =>
      'The time or date does not suit me';

  @override
  String get cancelReasonPriceNotSuitable =>
      'The price or budget does not suit me';

  @override
  String get cancelReasonCannotReachUstaad => 'I cannot reach the Ustaad';

  @override
  String get cancelReasonUstaadRunningLate => 'The Ustaad is running very late';

  @override
  String get cancelReasonOther => 'Another reason';

  @override
  String get bookingAgreedPrice => 'Agreed Price';

  @override
  String get inspRepairHintElectrical =>
      'e.g. replace the MCB and redo the socket wiring';

  @override
  String get inspRepairHintPlumbing =>
      'e.g. replace the leaking pipe and fit a new valve';

  @override
  String get inspRepairHintAc =>
      'e.g. refill the gas and replace the capacitor';

  @override
  String get inspRepairHintCarpentry =>
      'e.g. replace the hinges and straighten the door frame';

  @override
  String get inspRepairHintPainting =>
      'e.g. apply putty and primer, then two coats of emulsion';

  @override
  String get inspRepairHintFallback => 'e.g. what work is needed to fix it';

  @override
  String get inspPartHintElectrical => 'e.g. MCB, switch, socket';

  @override
  String get inspPartHintPlumbing => 'e.g. pipe, valve, tap';

  @override
  String get inspPartHintAc => 'e.g. gas refill, capacitor, compressor';

  @override
  String get inspPartHintCarpentry => 'e.g. hinges, plywood, door frame';

  @override
  String get inspPartHintPainting => 'e.g. primer, putty, emulsion';

  @override
  String get inspHintPainting =>
      'e.g. paint is peeling, damp patch on the wall...';

  @override
  String get agreementViewerTitle => 'Agreement';

  @override
  String get agreementLoadFailed =>
      'Could not load the agreement. Please try again.';

  @override
  String get agreementUnavailableForTrade =>
      'No approved agreement is available for your selected trade yet. Please contact HandyGo support.';

  @override
  String agreementLanguageChip(String language) {
    return 'Agreement Language: $language';
  }

  @override
  String agreementTradeChip(String trade) {
    return 'Trade: $trade';
  }

  @override
  String get agreementLanguageNotice =>
      'This approved legal agreement is currently available in Roman Urdu.';

  @override
  String get agreementLanguageRomanUrdu => 'Roman Urdu';

  @override
  String get agreementLanguageEnglish => 'English';

  @override
  String get agreementLanguageUrdu => 'Urdu';

  @override
  String get agreementAcceptCheckbox =>
      'I have read and accept this agreement.';

  @override
  String get agreementViewBeforeAccepting =>
      'Open and read the agreement before accepting it.';

  @override
  String get agreementAcceptRequired => 'This agreement must be accepted.';

  @override
  String get agreementTradeChangedReopen =>
      'Your main trade changed. Open and accept the trade agreement again.';

  @override
  String get agreementsLoadFailed => 'Agreements could not be loaded.';

  @override
  String get agreementsAllThreeRequired =>
      'Open and accept all three agreements before submitting.';

  @override
  String get workerFatherName => 'Father\'s Name';

  @override
  String get workerFatherNameRequired => 'Father\'s name is required.';

  @override
  String get workerDateOfBirth => 'Date of Birth';

  @override
  String get workerDateOfBirthHint => 'Select your date of birth';

  @override
  String get workerDateOfBirthRequired => 'Date of birth is required.';

  @override
  String get workerEmergencyContact => 'Emergency Contact (optional)';

  @override
  String get workerEmergencyContactHint => 'Name and phone number';

  @override
  String get workerAcceptedAgreementsTitle => 'My Agreements';

  @override
  String get workerAcceptedAgreementsEmpty =>
      'You have not accepted any agreements yet.';

  @override
  String agreementAcceptedOn(String date) {
    return 'Accepted on $date';
  }

  @override
  String agreementAcceptanceId(String id) {
    return 'Acceptance ID: $id';
  }

  @override
  String get agreementDownload => 'Download';

  @override
  String get agreementDownloadInProgress => 'Downloading agreement...';

  @override
  String agreementDownloadSaved(String path) {
    return 'Agreement saved to $path';
  }

  @override
  String get agreementDownloadFailed =>
      'Could not download the agreement. Please try again.';

  @override
  String get customerAgreementTitle =>
      'Customer Terms, Booking Rules & Privacy Notice';

  @override
  String get customerAgreementCheckboxLabel =>
      'I have read and agree to these Terms and Privacy Notice.';

  @override
  String get customerAgreementIAgree => 'I Agree';

  @override
  String get customerAgreementViewDownloadPdf => 'View/Download PDF';

  @override
  String get customerAgreementSaveFailed =>
      'Acceptance could not be saved. Please try again.';

  @override
  String get customerAgreementEffectiveDateNote =>
      'Effective from the date you accept below.';

  @override
  String get customerAgreementHistoryTitle => 'Accepted Agreements';

  @override
  String get workerSubmittedDetails => 'Submitted Details';

  @override
  String get workerViewSubmittedDetails => 'View Submitted Details';

  @override
  String get workerDetailsReadOnlyNotice =>
      'Your profile is approved. These details are locked and cannot be changed.';

  @override
  String get workerVerificationStatus => 'Verification Status';

  @override
  String get workerMainTrade => 'Main Trade';

  @override
  String get workerSuspendedMessage =>
      'Your HandyGo account has been suspended. Please contact Support for more information.';

  @override
  String get workerSuspendedContactSupport => 'Contact Support';

  @override
  String get earningGrossEarnings => 'Labour Earnings';

  @override
  String get earningCommissionLabel => 'HandyGo Commission (18%)';

  @override
  String get earningUstaadEarnings => 'Profit';

  @override
  String get earningCommissionStatusLabel => 'Commission Status';

  @override
  String get earningStatusPaid => 'Paid';

  @override
  String get notificationsPermissionOffMessage =>
      'Notifications are off. Allow notifications to receive booking and job updates.';

  @override
  String get notificationsAllowAction => 'Allow Notifications';

  @override
  String get locationPermissionRequiredMessage =>
      'Location permission is required.';

  @override
  String get locationAllowAction => 'Allow Location';

  @override
  String get locationPermanentlyDeniedMessage =>
      'Allow location permission from Settings.';

  @override
  String get locationGpsOffMessage =>
      'Your phone\'s Location/GPS is off. Turn it on to continue.';

  @override
  String get locationTurnOnAction => 'Turn On Location';

  @override
  String get locationUnavailableRetryMessage =>
      'Unable to get your location. Please try again.';

  @override
  String get locationStaleMessage =>
      'Your current location is required. Please update your location.';

  @override
  String get cameraPermissionDeniedMessage =>
      'Allow camera permission to continue.';

  @override
  String get galleryPermissionDeniedMessage =>
      'Allow photo access to select files.';

  @override
  String get unsupportedFileMessage =>
      'This file type is not supported. Select another file.';

  @override
  String get fileTooLargeMessage =>
      'The file is too large. Select a smaller file.';

  @override
  String get commonChooseAgain => 'Choose Again';

  @override
  String get pageNotAvailableTitle => 'Page Not Available';

  @override
  String get pageNotAvailableBody => 'This page is no longer available.';

  @override
  String get commonGoHome => 'Go to Home';

  @override
  String get resourceBookingUnavailable =>
      'This booking is no longer available.';

  @override
  String get resourceJobUnavailable => 'This job is no longer assigned to you.';

  @override
  String get resourceConversationUnavailable =>
      'This conversation is no longer available.';

  @override
  String get goToMyBookingsAction => 'Go to My Bookings';

  @override
  String get goToMyJobsAction => 'Go to My Jobs';

  @override
  String get goToChatsAction => 'Go to Chats';

  @override
  String get settingsSupportTitle => 'Support';

  @override
  String get settingsAboutTitle => 'About HandyGo';

  @override
  String get settingsAppVersionTitle => 'App Version';

  @override
  String get aboutAppDescription =>
      'HandyGo connects clients with nearby verified Ustaads for home repair and maintenance services.';

  @override
  String get aboutWebsiteLabel => 'Website';

  @override
  String get cashPaymentTitle => 'Confirm cash payment';

  @override
  String get cashPaymentQuestion => 'How much cash did you pay?';

  @override
  String cashPaymentExpected(Object amount) {
    return 'Expected booking amount: $amount';
  }

  @override
  String get cashPaymentInputLabel => 'Cash paid (PKR)';

  @override
  String get cashPaymentInputHint => 'Enter whole rupees, including 0';

  @override
  String get cashPaymentRequired => 'Enter the actual cash amount paid.';

  @override
  String get cashPaymentWholeRupees =>
      'Enter a whole PKR amount without decimals.';

  @override
  String get cashPaymentConfirmedTitle => 'Cash payment confirmed';

  @override
  String cashPaymentPaid(Object amount) {
    return 'Cash paid: $amount';
  }

  @override
  String cashPaymentExpectedReceipt(Object amount) {
    return 'Expected amount: $amount';
  }

  @override
  String cashPaymentShortfall(Object amount) {
    return 'Remaining amount: $amount';
  }

  @override
  String cashPaymentReference(Object reference) {
    return 'Confirmation reference: $reference';
  }

  @override
  String get cashPaymentContinueReview => 'Continue to review';

  @override
  String get cashPaymentConflict =>
      'Payment was already confirmed with a different amount. Please contact HandyGo support if it needs correction.';

  @override
  String get cashPaymentFailed =>
      'Cash payment could not be confirmed. Please try again.';

  @override
  String get cashPaymentReviewBlocked =>
      'Confirm the cash payment before reviewing the Ustaad.';

  @override
  String get postJobSelectBookingTypeFirst => 'Choose Normal or Urgent first.';

  @override
  String get postJobInspectionDescriptionRequired =>
      'Describe the problem you observe before continuing.';

  @override
  String get postJobCustomVoiceRequired =>
      'Add a voice note before continuing with Custom Kaam.';

  @override
  String get postJobCompleteAddressBeforeSaving =>
      'Add a complete address and map pin before saving it.';

  @override
  String get postJobDay => 'Day';

  @override
  String get postJobTomorrow => 'Tomorrow';

  @override
  String get postJobCustomVoiceAndPhotos =>
      'Voice note (required) & photos/video (optional)';

  @override
  String get postJobInspectionVoiceAndPhotos =>
      'Voice note & photos/video (optional)';

  @override
  String get postJobInspectionRateNote =>
      'You only pay the visit fee now. The repair quote appears in the app before work starts.';

  @override
  String get postJobBiddingRateNote =>
      'Ustaads will send a complete repair quote. The quote you accept is final and cannot change at the door.';

  @override
  String get savedAddresses => 'Saved addresses';

  @override
  String get savedAddressForNextTime => 'Save this address for next time';

  @override
  String get savedAddressOffice => 'Office';

  @override
  String get savedAddressName => 'Saved address name';

  @override
  String get savedAddressNameRequired => 'Enter a name.';

  @override
  String get savedAddressCustomNameTitle => 'Name this saved address';

  @override
  String get savedAddressRenameTitle => 'Rename saved address';

  @override
  String get savedAddressRenameConflict =>
      'That name is already used. Choose another name.';

  @override
  String get savedAddressSaved => 'Address saved.';

  @override
  String get savedAddressUse => 'Use address';

  @override
  String get savedAddressUpdateWithCurrent =>
      'Update with current address and pin';

  @override
  String get savedAddressRename => 'Rename';

  @override
  String get savedAddressDeleteTitle => 'Delete saved address?';

  @override
  String savedAddressDeleteBody(String name) {
    return 'Delete $name from your saved addresses?';
  }

  @override
  String savedAddressUpdateTitle(String name) {
    return 'Update $name?';
  }

  @override
  String savedAddressUpdateBody(String name) {
    return '$name is already saved. Update it with this address?';
  }

  @override
  String get savedAddressUpdateAction => 'Update address';

  @override
  String get postJobAddressIntro =>
      'First booking? Add the address once — you can save it for next time.';

  @override
  String get postJobCompleteAddressLabel => 'Enter your complete address';

  @override
  String get postJobAddressLandmarkHelper =>
      'A nearby landmark helps your Ustaad arrive without needing to call.';

  @override
  String get postJobAddressResolving => 'Finding this address on the map…';

  @override
  String get postJobAddressUnresolved =>
      'We couldn\'t find this address. Add more detail or choose it on the map.';

  @override
  String get postJobAddressRequired => 'Enter an address before continuing.';

  @override
  String get postJobMapPreviewEmpty => 'MAP — TAP TO PLACE THE PIN';

  @override
  String get postJobLanePageTitle => 'Choose a booking option';

  @override
  String postJobLaneStepIndicator(String service) {
    return 'Step 2 / 4 · $service';
  }

  @override
  String get postJobLaneFixedTitle => 'Fixed-price services';

  @override
  String get postJobLaneFixedSubtitle =>
      'Service and price are fixed in advance';

  @override
  String get postJobLaneFixedBody => 'See the final price before booking.';

  @override
  String get postJobLaneFixedAction => 'View services and prices →';

  @override
  String get postJobLaneFixedCta => 'View services and prices';

  @override
  String get postJobLaneInspectionTitle => 'Inspection';

  @override
  String get postJobLaneInspectionSubtitle => 'Not sure what the problem is?';

  @override
  String postJobLaneInspectionFeeBody(String fee) {
    return '$fee inspection fee — paid after inspection, not now.';
  }

  @override
  String get postJobLaneInspectionReportBody =>
      'The Ustaad checks the issue and sends the report and final quote in the app.';

  @override
  String postJobLaneInspectionWaiverBody(String fee) {
    return 'If you proceed with the repair, the $fee inspection fee is waived and you only pay the repair price.';
  }

  @override
  String get postJobLaneInspectionAction => 'Book inspection →';

  @override
  String get postJobLaneInspectionCta => 'Book inspection';

  @override
  String get postJobLaneCustomTitle => 'Custom Work';

  @override
  String get postJobLaneCustomBody =>
      'Send details and photos for a small repair, fitting, or replacement.';

  @override
  String get postJobLaneCustomRatesBody =>
      'Nearby Ustaads will send their prices.';

  @override
  String get postJobLaneCustomAction => 'Add job details →';

  @override
  String get postJobLaneCustomCta => 'Add job details';

  @override
  String get postJobLanePriceNote =>
      'The price can only change after a new quote is sent through the app — not after the Ustaad reaches your home.';

  @override
  String get postJobLaneChooseCta => 'Choose a booking option';

  @override
  String aboutVersionValue(String version, String build) {
    return 'Version $version ($build)';
  }
}
