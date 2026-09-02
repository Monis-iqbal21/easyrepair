import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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
    Locale('ur'),
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn'),
  ];

  /// Settings section heading above the language row
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get languageSectionTitle;

  /// Settings row that opens the language selector
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageRowLabel;

  /// Title of the language selector bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageSheetTitle;

  /// Heading of the onboarding language selection screen
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get languageOnboardingTitle;

  /// Supporting line under the onboarding language heading
  ///
  /// In en, this message translates to:
  /// **'Which language would you like to use the app in?'**
  String get languageOnboardingSubtitle;

  /// Supporting line on the Roman Urdu language card
  ///
  /// In en, this message translates to:
  /// **'Simple words, easy to understand'**
  String get languageOptionRomanUrduSubtitle;

  /// Supporting line on the English language card
  ///
  /// In en, this message translates to:
  /// **'Full application in English'**
  String get languageOptionEnglishSubtitle;

  /// Role selection screen heading
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get authRoleQuestion;

  /// Role selection screen supporting line, under the heading
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get authRoleSubtitle;

  /// No description provided for @authRoleClientTitle.
  ///
  /// In en, this message translates to:
  /// **'I need a home service'**
  String get authRoleClientTitle;

  /// No description provided for @authRoleClientSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book an Ustaad for repair, service, or installation.'**
  String get authRoleClientSubtitle;

  /// No description provided for @authRoleWorkerTitle.
  ///
  /// In en, this message translates to:
  /// **'I am an Ustaad'**
  String get authRoleWorkerTitle;

  /// No description provided for @authRoleWorkerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register to find and accept jobs.'**
  String get authRoleWorkerSubtitle;

  /// Ustaad new-or-existing screen heading. The line break is deliberate.
  ///
  /// In en, this message translates to:
  /// **'Are you already a HandyGo\nUstaad?'**
  String get authWorkerTypeQuestion;

  /// No description provided for @authWorkerTypeNewTitle.
  ///
  /// In en, this message translates to:
  /// **'I am a new Ustaad'**
  String get authWorkerTypeNewTitle;

  /// No description provided for @authWorkerTypeNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your new account on HandyGo.'**
  String get authWorkerTypeNewSubtitle;

  /// No description provided for @authWorkerTypeExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get authWorkerTypeExistingTitle;

  /// No description provided for @authWorkerTypeExistingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your account with OTP or password.'**
  String get authWorkerTypeExistingSubtitle;

  /// Toast after sign-in. {name} is the user's own name and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String authWelcomeToastTitle(String name);

  /// No description provided for @authWelcomeToastSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready to go.'**
  String get authWelcomeToastSubtitle;

  /// No description provided for @authOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'The code has expired. Request a new one.'**
  String get authOtpExpired;

  /// Countdown until the OTP stops working
  ///
  /// In en, this message translates to:
  /// **'Code expires in {time}'**
  String authOtpExpiresIn(String time);

  /// No description provided for @authOtpResendCooldown.
  ///
  /// In en, this message translates to:
  /// **'Resend code ({seconds}s)'**
  String authOtpResendCooldown(int seconds);

  /// No description provided for @authOtpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authOtpResend;

  /// No description provided for @authFieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get authFieldFullName;

  /// No description provided for @authFieldFullNameShort.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFieldFullNameShort;

  /// No description provided for @authHintFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get authHintFullName;

  /// No description provided for @authFieldMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get authFieldMobileNumber;

  /// No description provided for @authFieldMobileNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get authFieldMobileNumberTitle;

  /// No description provided for @authFieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authFieldPassword;

  /// No description provided for @authFieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter password'**
  String get authFieldConfirmPassword;

  /// No description provided for @authValidationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get authValidationNameRequired;

  /// No description provided for @authValidationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a mobile number.'**
  String get authValidationPhoneRequired;

  /// No description provided for @authValidationPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Pakistani mobile number.'**
  String get authValidationPhoneInvalid;

  /// No description provided for @authValidationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password.'**
  String get authValidationPasswordRequired;

  /// No description provided for @authValidationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get authValidationPasswordTooShort;

  /// No description provided for @authValidationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please re-enter your password.'**
  String get authValidationConfirmPasswordRequired;

  /// No description provided for @authValidationPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authValidationPasswordsDoNotMatch;

  /// Client sign-in heading. The line break is deliberate.
  ///
  /// In en, this message translates to:
  /// **'Log in to book\nan Ustaad'**
  String get authClientLoginTitle;

  /// No description provided for @authClientOtpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your name and mobile number. We will send a verification code.'**
  String get authClientOtpSubtitle;

  /// No description provided for @authClientPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue with your mobile number and password.'**
  String get authClientPasswordSubtitle;

  /// No description provided for @authOtpWillBeSentNotice.
  ///
  /// In en, this message translates to:
  /// **'A verification code will be sent to this number.'**
  String get authOtpWillBeSentNotice;

  /// No description provided for @authButtonSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get authButtonSendCode;

  /// No description provided for @authButtonVerifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and Continue'**
  String get authButtonVerifyAndContinue;

  /// No description provided for @authButtonLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authButtonLogIn;

  /// No description provided for @authButtonCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authButtonCreateAccount;

  /// No description provided for @authButtonForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authButtonForgotPassword;

  /// No description provided for @authButtonContinueWithOtp.
  ///
  /// In en, this message translates to:
  /// **'Continue with OTP'**
  String get authButtonContinueWithOtp;

  /// No description provided for @authButtonContinueWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Continue with password'**
  String get authButtonContinueWithPassword;

  /// No description provided for @authButtonUstaadLogin.
  ///
  /// In en, this message translates to:
  /// **'Ustaad Login'**
  String get authButtonUstaadLogin;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorOtpSendFailed.
  ///
  /// In en, this message translates to:
  /// **'The OTP could not be sent right now. Continue with your password, or try again shortly.'**
  String get authErrorOtpSendFailed;

  /// Client login screen heading
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authClientLoginHeading;

  /// Client login screen supporting line
  ///
  /// In en, this message translates to:
  /// **'Login with your mobile number and password.'**
  String get authClientLoginSubtitle;

  /// In-field action that reveals the typed password
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get authClientPasswordShow;

  /// Action that obscures a currently visible password
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get authClientPasswordHide;

  /// Client login link to the password-reset flow
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authClientForgotPassword;

  /// Client login primary button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authClientLoginButton;

  /// Client registration footer action back to login
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authClientLoginAction;

  /// Client login secondary button opening the OTP login flow
  ///
  /// In en, this message translates to:
  /// **'Login with OTP'**
  String get authClientOtpLoginButton;

  /// Client login: switches the page back from OTP mode to password mode
  ///
  /// In en, this message translates to:
  /// **'Login with Password'**
  String get authClientLoginWithPassword;

  /// Shown when OTP login is attempted with a number that has no Client account. Deliberately identical for an unknown number and a Worker-owned one, so it cannot be used to probe roles.
  ///
  /// In en, this message translates to:
  /// **'No Client account was found for this number. Create an account.'**
  String get authClientNoAccountFound;

  /// Supporting line beside the Ustaad header
  ///
  /// In en, this message translates to:
  /// **'Work with HandyGo'**
  String get ustaadLoginBrandSubtitle;

  /// Ustaad login supporting line
  ///
  /// In en, this message translates to:
  /// **'Login with your mobile number to find work.'**
  String get ustaadLoginSubtitle;

  /// Reassurance box on the Ustaad login screen
  ///
  /// In en, this message translates to:
  /// **'Every Ustaad\'s CNIC is verified. Approval is usually completed within 24 hours after registration.'**
  String get ustaadLoginInfoBox;

  /// Ustaad login footer prompt before the register action
  ///
  /// In en, this message translates to:
  /// **'New Ustaad?'**
  String get ustaadLoginNewPrompt;

  /// Ustaad login footer action opening registration
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get ustaadLoginRegisterAction;

  /// Header on Ustaad registration step 1
  ///
  /// In en, this message translates to:
  /// **'Ustaad registration'**
  String get ustaadRegisterHeader;

  /// Progress line under each Ustaad registration heading
  ///
  /// In en, this message translates to:
  /// **'Step {current} / {total}'**
  String ustaadStepIndicator(int current, int total);

  /// Ustaad registration step 1 heading
  ///
  /// In en, this message translates to:
  /// **'Enter your details'**
  String get ustaadStep1Heading;

  /// Ustaad registration full-name label
  ///
  /// In en, this message translates to:
  /// **'Full Name · As shown on CNIC'**
  String get ustaadFullNameLabel;

  /// Ustaad registration full-name placeholder
  ///
  /// In en, this message translates to:
  /// **'For example: Kamran Sheikh'**
  String get ustaadFullNameHint;

  /// Ustaad registration CNIC label
  ///
  /// In en, this message translates to:
  /// **'CNIC Number'**
  String get ustaadCnicLabel;

  /// Ustaad registration password label
  ///
  /// In en, this message translates to:
  /// **'Create Password'**
  String get ustaadCreatePasswordLabel;

  /// Ustaad registration step 1 primary button
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get ustaadSendOtpButton;

  /// Header on the Ustaad OTP and CNIC steps
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get ustaadVerificationHeader;

  /// Ustaad registration step 2 heading
  ///
  /// In en, this message translates to:
  /// **'Verify your number'**
  String get ustaadStep2Heading;

  /// Ustaad registration step 2 supporting line
  ///
  /// In en, this message translates to:
  /// **'Code sent to +92 {phone} · Step 2 / 4'**
  String ustaadStep2Subtitle(String phone);

  /// Ustaad registration step 2 primary button
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get ustaadVerifyButton;

  /// Ustaad registration step 3 heading
  ///
  /// In en, this message translates to:
  /// **'Profile and work'**
  String get ustaadStep3Heading;

  /// Ustaad registration profile-photo card title
  ///
  /// In en, this message translates to:
  /// **'Add your photo'**
  String get ustaadPhotoTitle;

  /// Ustaad registration profile-photo card subtitle
  ///
  /// In en, this message translates to:
  /// **'This is the photo customers see'**
  String get ustaadPhotoSubtitle;

  /// Placeholder text inside the empty profile-photo circle
  ///
  /// In en, this message translates to:
  /// **'PHOTO'**
  String get ustaadPhotoPlaceholder;

  /// Ustaad registration profile-photo upload button
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get ustaadPhotoUpload;

  /// Ustaad registration skills section title
  ///
  /// In en, this message translates to:
  /// **'What work do you do?'**
  String get ustaadSkillsTitle;

  /// Ustaad registration experience section title
  ///
  /// In en, this message translates to:
  /// **'How many years of experience?'**
  String get ustaadExperienceTitle;

  /// Ustaad registration home-address section title
  ///
  /// In en, this message translates to:
  /// **'Home address'**
  String get ustaadAddressTitle;

  /// Ustaad registration home-address privacy note
  ///
  /// In en, this message translates to:
  /// **'Where you live — for verification. Customers never see this.'**
  String get ustaadAddressSubtitle;

  /// Ustaad registration address area label
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get ustaadAreaLabel;

  /// Ustaad registration address area placeholder
  ///
  /// In en, this message translates to:
  /// **'For example: Saddar'**
  String get ustaadAreaHint;

  /// Ustaad registration address street label
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get ustaadStreetLabel;

  /// Ustaad registration address house label
  ///
  /// In en, this message translates to:
  /// **'House / Flat number'**
  String get ustaadHouseLabel;

  /// Ustaad registration address landmark label
  ///
  /// In en, this message translates to:
  /// **'Landmark · optional'**
  String get ustaadLandmarkLabel;

  /// Ustaad registration address landmark placeholder
  ///
  /// In en, this message translates to:
  /// **'Opposite the mosque'**
  String get ustaadLandmarkHint;

  /// Ustaad registration step 4 heading
  ///
  /// In en, this message translates to:
  /// **'CNIC verification'**
  String get ustaadStep4Heading;

  /// Ustaad registration step 4 supporting line
  ///
  /// In en, this message translates to:
  /// **'Step 4 / 4 · customers never see this'**
  String get ustaadStep4Subtitle;

  /// Ustaad registration CNIC front card title
  ///
  /// In en, this message translates to:
  /// **'CNIC front'**
  String get ustaadCnicFrontTitle;

  /// Ustaad registration CNIC front card subtitle
  ///
  /// In en, this message translates to:
  /// **'Clear photo, whole card'**
  String get ustaadCnicFrontSubtitle;

  /// Ustaad registration CNIC back card title
  ///
  /// In en, this message translates to:
  /// **'CNIC back'**
  String get ustaadCnicBackTitle;

  /// Ustaad registration CNIC back card subtitle
  ///
  /// In en, this message translates to:
  /// **'The back side'**
  String get ustaadCnicBackSubtitle;

  /// Label inside an empty CNIC upload tile
  ///
  /// In en, this message translates to:
  /// **'UPLOAD'**
  String get ustaadUploadAction;

  /// Badge on a CNIC card that has not been uploaded yet
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ustaadPendingBadge;

  /// Badge on a CNIC card that has been uploaded
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get ustaadUploadedBadge;

  /// Section label above the Ustaad agreement cards
  ///
  /// In en, this message translates to:
  /// **'AGREEMENTS'**
  String get ustaadAgreementsLabel;

  /// Opens the full agreement document
  ///
  /// In en, this message translates to:
  /// **'Read →'**
  String get ustaadReadAction;

  /// Ustaad registration step 4 primary button
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get ustaadSubmitButton;

  /// Title of the calm status card a Worker sees while an admin reviews their submitted profile. Deliberately not a call to action.
  ///
  /// In en, this message translates to:
  /// **'Profile under review'**
  String get workerPendingReviewTitle;

  /// Body of the pending-review status card. No time promise.
  ///
  /// In en, this message translates to:
  /// **'Your details have been submitted for verification. You can start receiving jobs after approval.'**
  String get workerPendingReviewBody;

  /// Ustaad password-reset step 1 heading
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get ustaadForgotHeading;

  /// Ustaad password-reset step 1 supporting line
  ///
  /// In en, this message translates to:
  /// **'Enter your registered mobile number.'**
  String get ustaadForgotSubtitle;

  /// Ustaad password-reset OTP step heading
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get ustaadForgotOtpHeading;

  /// Ustaad password-reset OTP step supporting line
  ///
  /// In en, this message translates to:
  /// **'A code was sent to +92 {phone}.'**
  String ustaadForgotOtpBody(String phone);

  /// Ustaad password-reset new-password step heading
  ///
  /// In en, this message translates to:
  /// **'Create a New Password'**
  String get ustaadForgotNewPasswordHeading;

  /// Ustaad password-reset confirm-password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get ustaadConfirmPasswordLabel;

  /// Ustaad password-reset primary button
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get ustaadChangePasswordButton;

  /// Ustaad password-reset success heading
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get ustaadResetSuccessTitle;

  /// Ustaad password-reset success body
  ///
  /// In en, this message translates to:
  /// **'You can now login with your new password.'**
  String get ustaadResetSuccessBody;

  /// Returns to the login screen after a successful password reset
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get ustaadGoToLoginButton;

  /// Ustaad password-reset new-password field label. The Roman Urdu deliberately keeps the English words, unlike the settings screen.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get ustaadNewPasswordLabel;

  /// One-line summary under the Ustaad General Agreement card. The binding text is the backend document itself; this only says what it covers.
  ///
  /// In en, this message translates to:
  /// **'How work is done, punctuality, uniform and ID, and the rate rules.'**
  String get ustaadAgreementGeneralSummary;

  /// One-line summary under the Trade Specific Agreement card.
  ///
  /// In en, this message translates to:
  /// **'Matched to your trade — parts, grade and safety rules.'**
  String get ustaadAgreementTradeSummary;

  /// One-line summary under the Background Verification Consent card.
  ///
  /// In en, this message translates to:
  /// **'Permission for CNIC, police verification and reference checks.'**
  String get ustaadAgreementBackgroundSummary;

  /// Helper line under the OTP login button
  ///
  /// In en, this message translates to:
  /// **'An OTP will be sent to your registered mobile number.'**
  String get authClientOtpHelp;

  /// Client login footer prompt before Create Account
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get authClientNewHere;

  /// Client registration step 1 supporting line
  ///
  /// In en, this message translates to:
  /// **'Create your account once. After that, login with your mobile number and password.'**
  String get authClientRegisterSubtitle;

  /// Client registration new-password field label
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get authClientCreatePasswordLabel;

  /// Client registration new-password placeholder
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authClientPasswordHint;

  /// Client registration confirm-password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authClientConfirmPasswordLabel;

  /// Client registration confirm-password placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your password again'**
  String get authClientConfirmPasswordHint;

  /// Client registration reassurance box about address
  ///
  /// In en, this message translates to:
  /// **'We do not need your address yet. We will ask for it when you make your first booking.'**
  String get authClientAddressNotice;

  /// Client registration footer prompt before the login action
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authClientHaveAccount;

  /// Client registration OTP screen heading
  ///
  /// In en, this message translates to:
  /// **'Verify Mobile Number'**
  String get authClientVerifyHeading;

  /// Client registration OTP resend prompt
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get authClientResendPrompt;

  /// Client registration OTP resend action
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get authClientResendAction;

  /// Client registration OTP primary button
  ///
  /// In en, this message translates to:
  /// **'Verify & Create Account'**
  String get authClientVerifyButton;

  /// Client registration success heading
  ///
  /// In en, this message translates to:
  /// **'Your account is ready'**
  String get authClientReadyHeading;

  /// Client registration success supporting line
  ///
  /// In en, this message translates to:
  /// **'Welcome to HandyGo. You can now book a service.'**
  String get authClientReadySubtitle;

  /// Label above the new account details on the success screen
  ///
  /// In en, this message translates to:
  /// **'YOUR ACCOUNT'**
  String get authClientAccountCardLabel;

  /// Role shown beside the phone number on the success screen
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get authClientRoleCustomer;

  /// Client registration OTP screen supporting line. count is the OTP length the backend actually issues; phone is the national number, already grouped for reading.
  ///
  /// In en, this message translates to:
  /// **'A {count}-digit code was sent to +92 {phone}.'**
  String authClientVerifySentTo(int count, String phone);

  /// Client registration heading and the login footer action
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authClientCreateAccountTitle;

  /// Client full-name field label
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authClientFullNameLabel;

  /// Client registration primary button
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get authClientSendOtpButton;

  /// Client registration success primary button
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get authClientGoHome;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUser;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get commonUploading;

  /// No description provided for @chatTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitleFallback;

  /// No description provided for @chatListTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatListTitle;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats or type “support”'**
  String get chatSearchHint;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Messages will appear here'**
  String get chatEmptySubtitle;

  /// No description provided for @chatNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get chatNoResultsTitle;

  /// No description provided for @chatNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different name, or search “support”'**
  String get chatNoResultsSubtitle;

  /// No description provided for @chatNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get chatNoMessagesYet;

  /// No description provided for @chatNewMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new message} other{{count} new messages}}'**
  String chatNewMessages(int count);

  /// No description provided for @chatSupportBanner.
  ///
  /// In en, this message translates to:
  /// **'Write your problem or question here. HandyGo Support will help you.'**
  String get chatSupportBanner;

  /// No description provided for @chatEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessage;

  /// No description provided for @chatEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit your message...'**
  String get chatEditHint;

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessage;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This message will be deleted for everyone in the chat.'**
  String get chatDeleteConfirm;

  /// No description provided for @chatMicPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to send a voice message.'**
  String get chatMicPermissionRequired;

  /// No description provided for @chatLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get chatLocationPermissionDenied;

  /// No description provided for @chatLocationPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied — enable it in Settings'**
  String get chatLocationPermissionPermanentlyDenied;

  /// No description provided for @chatLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location: {error}'**
  String chatLocationFailed(String error);

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

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commonOpenSettings;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow permissions'**
  String get permissionsTitle;

  /// No description provided for @permissionsRationale.
  ///
  /// In en, this message translates to:
  /// **'HandyGo needs camera, microphone, and location permissions so you can upload photos and videos, send voice notes, and share or track job location.'**
  String get permissionsRationale;

  /// No description provided for @permissionsBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions blocked'**
  String get permissionsBlockedTitle;

  /// No description provided for @permissionsBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Some permissions were permanently denied. Open Settings to enable them manually.'**
  String get permissionsBlockedBody;

  /// No description provided for @generalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalInfoTitle;

  /// No description provided for @generalAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get generalAccountSection;

  /// No description provided for @generalFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get generalFirstName;

  /// No description provided for @generalLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get generalLastName;

  /// No description provided for @generalPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get generalPhoneNumber;

  /// No description provided for @generalNamePhoneLocked.
  ///
  /// In en, this message translates to:
  /// **'Name and phone are managed by your account and cannot be changed here.'**
  String get generalNamePhoneLocked;

  /// No description provided for @generalSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get generalSecuritySection;

  /// No description provided for @generalChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get generalChangePassword;

  /// No description provided for @generalCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get generalCurrentPassword;

  /// No description provided for @generalNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get generalNewPassword;

  /// No description provided for @generalConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get generalConfirmNewPassword;

  /// No description provided for @generalChangePasswordComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Changing your password in the app is coming soon. Contact support if you need help right away.'**
  String get generalChangePasswordComingSoon;

  /// No description provided for @generalUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get generalUpdatePassword;

  /// No description provided for @distanceAtYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Right at your location'**
  String get distanceAtYourLocation;

  /// No description provided for @distanceMetersAway.
  ///
  /// In en, this message translates to:
  /// **'{meters} m away'**
  String distanceMetersAway(int meters);

  /// No description provided for @distanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceKmAway(String km);

  /// No description provided for @distanceUnderOneKm.
  ///
  /// In en, this message translates to:
  /// **'< 1 km away'**
  String get distanceUnderOneKm;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will be notified about job updates,\nreviews, and more.'**
  String get notificationsEmptySubtitle;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @workerRatingNew.
  ///
  /// In en, this message translates to:
  /// **'New worker'**
  String get workerRatingNew;

  /// No description provided for @workerRatingNone.
  ///
  /// In en, this message translates to:
  /// **'No rating'**
  String get workerRatingNone;

  /// No description provided for @workerRatingWithJobs.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count, plural, =1{{count} job} other{{count} jobs}})'**
  String workerRatingWithJobs(String rating, int count);

  /// No description provided for @chatSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get chatSeen;

  /// No description provided for @chatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get chatMessageDeleted;

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chatEdited;

  /// No description provided for @chatCouldNotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps'**
  String get chatCouldNotOpenMaps;

  /// No description provided for @chatCouldNotOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone dialer'**
  String get chatCouldNotOpenDialer;

  /// No description provided for @chatSharedLocation.
  ///
  /// In en, this message translates to:
  /// **'Shared location'**
  String get chatSharedLocation;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatComposerHint;

  /// No description provided for @chatAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatAttachPhoto;

  /// No description provided for @chatAttachVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatAttachVideo;

  /// No description provided for @chatAttachVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get chatAttachVoice;

  /// No description provided for @chatAttachLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatAttachLocation;

  /// No description provided for @chatTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get chatTakePhoto;

  /// No description provided for @chatRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get chatRecordVideo;

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

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

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

  /// No description provided for @dateDayMonthYear.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year}'**
  String dateDayMonthYear(int day, String month, int year);

  /// No description provided for @authPasswordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed successfully.'**
  String get authPasswordResetSuccess;

  /// No description provided for @authForgotPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered mobile number'**
  String get authForgotPasswordPrompt;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get authSendOtp;

  /// No description provided for @authNewPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password.'**
  String get authNewPasswordRequired;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authOr;

  /// No description provided for @authLoginWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Log In With Password'**
  String get authLoginWithPassword;

  /// No description provided for @authWorkerRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new Ustaad\naccount'**
  String get authWorkerRegisterTitle;

  /// No description provided for @authCnicNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name exactly as on your CNIC'**
  String get authCnicNameHint;

  /// No description provided for @authCreatePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get authCreatePasswordLabel;

  /// No description provided for @authSelectSkill.
  ///
  /// In en, this message translates to:
  /// **'Select your skill'**
  String get authSelectSkill;

  /// No description provided for @authSkillsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Skills could not load. Please try again.'**
  String get authSkillsLoadFailed;

  /// No description provided for @authSkillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a skill.'**
  String get authSkillRequired;

  /// No description provided for @authConfirmNewPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get authConfirmNewPasswordButton;

  /// No description provided for @postJobOffersSoon.
  ///
  /// In en, this message translates to:
  /// **'You will start getting Ustaad offers within minutes.'**
  String get postJobOffersSoon;

  /// No description provided for @postJobSelectDateTimeFirst.
  ///
  /// In en, this message translates to:
  /// **'Select date and time to continue.'**
  String get postJobSelectDateTimeFirst;

  /// No description provided for @postJobGoesLiveAt.
  ///
  /// In en, this message translates to:
  /// **'Job goes live at {time} on {date} — 1 hour before the Ustaad arrival time.'**
  String postJobGoesLiveAt(String time, String date);

  /// No description provided for @postJobAddPhotoVideo.
  ///
  /// In en, this message translates to:
  /// **'Photo/Video'**
  String get postJobAddPhotoVideo;

  /// No description provided for @postJobChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get postJobChoosePhoto;

  /// No description provided for @postJobChooseVideo.
  ///
  /// In en, this message translates to:
  /// **'Choose Video - 30 sec'**
  String get postJobChooseVideo;

  /// No description provided for @postJobCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get postJobCamera;

  /// No description provided for @postJobRecordVideo30.
  ///
  /// In en, this message translates to:
  /// **'Record Video - 30 sec'**
  String get postJobRecordVideo30;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get errorNoInternet;

  /// No description provided for @postJobSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save booking. Please try again.'**
  String get postJobSaveFailed;

  /// No description provided for @postJobBookingUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Updated!'**
  String get postJobBookingUpdatedTitle;

  /// No description provided for @postJobBookingUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your booking details have been updated successfully.'**
  String get postJobBookingUpdatedBody;

  /// No description provided for @postJobViewBooking.
  ///
  /// In en, this message translates to:
  /// **'View Booking'**
  String get postJobViewBooking;

  /// No description provided for @postJobSelectService.
  ///
  /// In en, this message translates to:
  /// **'Select Service'**
  String get postJobSelectService;

  /// No description provided for @postJobServicesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load services. Please restart the app.'**
  String get postJobServicesLoadFailed;

  /// No description provided for @postJobBookingType.
  ///
  /// In en, this message translates to:
  /// **'Booking Type'**
  String get postJobBookingType;

  /// No description provided for @postJobNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get postJobNormal;

  /// No description provided for @postJobUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get postJobUrgent;

  /// No description provided for @postJobDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get postJobDateTime;

  /// No description provided for @postJobArrivalTime.
  ///
  /// In en, this message translates to:
  /// **'Arrival time'**
  String get postJobArrivalTime;

  /// No description provided for @postJobWhatNeedsFixing.
  ///
  /// In en, this message translates to:
  /// **'What needs fixing?'**
  String get postJobWhatNeedsFixing;

  /// No description provided for @postJobIssueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AC not cooling, water leaking, switch not working'**
  String get postJobIssueHint;

  /// No description provided for @postJobDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get postJobDescription;

  /// No description provided for @postJobDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue (optional)'**
  String get postJobDescriptionHint;

  /// No description provided for @postJobServiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Service Address'**
  String get postJobServiceAddress;

  /// No description provided for @postJobAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Building/house, apartment/flat, floor/unit, area, Karachi'**
  String get postJobAddressHint;

  /// No description provided for @postJobAddLocationFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your location to continue.'**
  String get postJobAddLocationFirst;

  /// No description provided for @postJobVoiceAndPhotos.
  ///
  /// In en, this message translates to:
  /// **'Voice note & photos'**
  String get postJobVoiceAndPhotos;

  /// No description provided for @postJobVoiceAttached.
  ///
  /// In en, this message translates to:
  /// **'Voice note attached'**
  String get postJobVoiceAttached;

  /// No description provided for @postJobAttachmentHelper.
  ///
  /// In en, this message translates to:
  /// **'Add photos or a video up to 30 seconds. Maximum 4 attachments.'**
  String get postJobAttachmentHelper;

  /// No description provided for @postJobAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/4 attachments added'**
  String postJobAttachmentCount(int count);

  /// No description provided for @postJobAttachmentsWillBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} existing attachment will be removed on save.} other{{count} existing attachments will be removed on save.}}'**
  String postJobAttachmentsWillBeRemoved(int count);

  /// No description provided for @postJobTapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record — describe the problem in your own words'**
  String get postJobTapToRecord;

  /// No description provided for @postJobService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get postJobService;

  /// No description provided for @postJobWhatDoYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get postJobWhatDoYouNeed;

  /// No description provided for @postJobChooseOneOption.
  ///
  /// In en, this message translates to:
  /// **'Choose one option'**
  String get postJobChooseOneOption;

  /// No description provided for @postJobUnderstandingIsOurJob.
  ///
  /// In en, this message translates to:
  /// **'Understanding the problem is our job — not yours.'**
  String get postJobUnderstandingIsOurJob;

  /// No description provided for @postJobStandardWork.
  ///
  /// In en, this message translates to:
  /// **'Standard work'**
  String get postJobStandardWork;

  /// No description provided for @postJobStandardWorkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Work and price are clear upfront.'**
  String get postJobStandardWorkSubtitle;

  /// No description provided for @postJobIKnowThePart.
  ///
  /// In en, this message translates to:
  /// **'I know the exact part'**
  String get postJobIKnowThePart;

  /// No description provided for @postJobIKnowThePartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ustaads send their rate, you choose'**
  String get postJobIKnowThePartSubtitle;

  /// No description provided for @postJobIKnowThePartWarning.
  ///
  /// In en, this message translates to:
  /// **'Only choose this if you are completely sure about the part. If it turns out wrong, the Ustaad visit is wasted and a new rate will apply.'**
  String get postJobIKnowThePartWarning;

  /// No description provided for @postJobSomethingIsBroken.
  ///
  /// In en, this message translates to:
  /// **'Something is broken'**
  String get postJobSomethingIsBroken;

  /// No description provided for @postJobDontKnowIssue.
  ///
  /// In en, this message translates to:
  /// **'I do not know what the problem is'**
  String get postJobDontKnowIssue;

  /// No description provided for @postJobInspectionFeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection Fee'**
  String get postJobInspectionFeeTitle;

  /// No description provided for @postJobInspectionDetailsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us the problem'**
  String get postJobInspectionDetailsPageTitle;

  /// No description provided for @postJobInspectionDetailsStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Step 3 / 4 · {service}'**
  String postJobInspectionDetailsStepIndicator(String service);

  /// No description provided for @postJobInspectionDetailsFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'INSPECTION FEE'**
  String get postJobInspectionDetailsFeeLabel;

  /// No description provided for @postJobInspectionDetailsFeeWaiver.
  ///
  /// In en, this message translates to:
  /// **'Approve the repair and this fee is waived — you only pay the repair price'**
  String get postJobInspectionDetailsFeeWaiver;

  /// No description provided for @postJobInspectionProblemHeading.
  ///
  /// In en, this message translates to:
  /// **'What do you see? · required'**
  String get postJobInspectionProblemHeading;

  /// No description provided for @postJobInspectionVoiceHeading.
  ///
  /// In en, this message translates to:
  /// **'Voice note · optional'**
  String get postJobInspectionVoiceHeading;

  /// No description provided for @postJobInspectionRecordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap and describe it in your own words'**
  String get postJobInspectionRecordPrompt;

  /// No description provided for @postJobInspectionAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get postJobInspectionAddPhoto;

  /// No description provided for @postJobInspectionAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / 4 attachments'**
  String postJobInspectionAttachmentCount(int count);

  /// No description provided for @postJobChooseStandardService.
  ///
  /// In en, this message translates to:
  /// **'Choose a standard service'**
  String get postJobChooseStandardService;

  /// No description provided for @postJobServicesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to load services. Please go back and try again.'**
  String get postJobServicesUnavailable;

  /// No description provided for @postJobSelectCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a service category first.'**
  String get postJobSelectCategoryFirst;

  /// No description provided for @postJobStandardServicesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to load standard services.'**
  String get postJobStandardServicesUnavailable;

  /// No description provided for @postJobNoStandardServices.
  ///
  /// In en, this message translates to:
  /// **'No standard services are available for this service yet. Please choose another option above.'**
  String get postJobNoStandardServices;

  /// No description provided for @postJobMultiSelectHint.
  ///
  /// In en, this message translates to:
  /// **'You can choose more than one service.'**
  String get postJobMultiSelectHint;

  /// No description provided for @postJobTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get postJobTotal;

  /// No description provided for @postJobInspectionFeeLower.
  ///
  /// In en, this message translates to:
  /// **'Inspection fee'**
  String get postJobInspectionFeeLower;

  /// No description provided for @postJobInspectionFeeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the inspection fee.'**
  String get postJobInspectionFeeLoadFailed;

  /// No description provided for @postJobHowInspectionWorks.
  ///
  /// In en, this message translates to:
  /// **'How inspection works'**
  String get postJobHowInspectionWorks;

  /// No description provided for @postJobWhatDoYouSee.
  ///
  /// In en, this message translates to:
  /// **'What problem do you observe? (required)'**
  String get postJobWhatDoYouSee;

  /// No description provided for @postJobWhatDoYouSeeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AC turns on but room stays hot…'**
  String get postJobWhatDoYouSeeHint;

  /// No description provided for @postJobBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get postJobBack;

  /// No description provided for @postJobNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get postJobNext;

  /// No description provided for @postJobStepAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get postJobStepAddress;

  /// No description provided for @postJobStepLaneSelection.
  ///
  /// In en, this message translates to:
  /// **'Choose Type'**
  String get postJobStepLaneSelection;

  /// No description provided for @postJobStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get postJobStepDetails;

  /// No description provided for @postJobStepTimeSelection.
  ///
  /// In en, this message translates to:
  /// **'Time Selection'**
  String get postJobStepTimeSelection;

  /// No description provided for @postJobStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}  ·  {title}'**
  String postJobStepIndicator(int current, int total, String title);

  /// Short label under segment 4 of the booking-form progress bar
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get postJobProgressBarTime;

  /// Small badge on the inspection lane card in booking-form lane selection
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get postJobRecommendedBadge;

  /// Small badge shown over the live map on the Track Worker screen
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get trackLiveBadge;

  /// No description provided for @clientHomeYourArea.
  ///
  /// In en, this message translates to:
  /// **'Your Area'**
  String get clientHomeYourArea;

  /// No description provided for @clientHomeSectionRepairs.
  ///
  /// In en, this message translates to:
  /// **'Repairs'**
  String get clientHomeSectionRepairs;

  /// No description provided for @clientHomeSectionCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get clientHomeSectionCleaning;

  /// No description provided for @clientHomeSectionPainting.
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get clientHomeSectionPainting;

  /// No description provided for @clientHomeSectionOutdoorVehicle.
  ///
  /// In en, this message translates to:
  /// **'Outdoor & Vehicle'**
  String get clientHomeSectionOutdoorVehicle;

  /// No description provided for @serviceAcTechnician.
  ///
  /// In en, this message translates to:
  /// **'AC Technician'**
  String get serviceAcTechnician;

  /// No description provided for @serviceElectrician.
  ///
  /// In en, this message translates to:
  /// **'Electrician'**
  String get serviceElectrician;

  /// No description provided for @servicePlumber.
  ///
  /// In en, this message translates to:
  /// **'Plumber'**
  String get servicePlumber;

  /// No description provided for @serviceCarpenter.
  ///
  /// In en, this message translates to:
  /// **'Carpenter'**
  String get serviceCarpenter;

  /// Service category name - inspection-only appliance repair
  ///
  /// In en, this message translates to:
  /// **'Appliances Repair'**
  String get serviceAppliancesRepair;

  /// No description provided for @serviceDeepCleaning.
  ///
  /// In en, this message translates to:
  /// **'Deep Cleaning'**
  String get serviceDeepCleaning;

  /// No description provided for @servicePestControl.
  ///
  /// In en, this message translates to:
  /// **'Pest Control'**
  String get servicePestControl;

  /// No description provided for @servicePainter.
  ///
  /// In en, this message translates to:
  /// **'Painter'**
  String get servicePainter;

  /// No description provided for @serviceGardening.
  ///
  /// In en, this message translates to:
  /// **'Gardening'**
  String get serviceGardening;

  /// No description provided for @serviceCarWash.
  ///
  /// In en, this message translates to:
  /// **'Car Wash'**
  String get serviceCarWash;

  /// No description provided for @serviceMoversPackers.
  ///
  /// In en, this message translates to:
  /// **'Movers & Packers'**
  String get serviceMoversPackers;

  /// No description provided for @clientHomeNoServicesFound.
  ///
  /// In en, this message translates to:
  /// **'No services found'**
  String get clientHomeNoServicesFound;

  /// No description provided for @clientHomeSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get clientHomeSearchResults;

  /// No description provided for @clientHomeBookUrgently.
  ///
  /// In en, this message translates to:
  /// **'Book Urgently'**
  String get clientHomeBookUrgently;

  /// No description provided for @clientHomeChooseServiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a service to get help right away.'**
  String get clientHomeChooseServiceHelp;

  /// No description provided for @clientHomeHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String clientHomeHello(String name);

  /// No description provided for @clientHomeGuest.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get clientHomeGuest;

  /// No description provided for @clientHomeLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get clientHomeLocating;

  /// No description provided for @clientHomeUrgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Need help right now?'**
  String get clientHomeUrgentTitle;

  /// No description provided for @clientHomeUrgentPromise.
  ///
  /// In en, this message translates to:
  /// **'We’ll send an Ustaad quickly — same rate, no extra charge'**
  String get clientHomeUrgentPromise;

  /// No description provided for @clientHomeWhatNeedsDoing.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done?'**
  String get clientHomeWhatNeedsDoing;

  /// No description provided for @clientHomeTrustMessage.
  ///
  /// In en, this message translates to:
  /// **'Every Ustaad is CNIC verified · Rate is agreed first'**
  String get clientHomeTrustMessage;

  /// No description provided for @clientHomeSupportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'HandyGo Support is unavailable right now. Please try again.'**
  String get clientHomeSupportUnavailable;

  /// No description provided for @clientHomeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi {name} 👋'**
  String clientHomeGreeting(String name);

  /// No description provided for @clientHomeBeatTheHeat.
  ///
  /// In en, this message translates to:
  /// **'Beat the Karachi Heat ☀️'**
  String get clientHomeBeatTheHeat;

  /// No description provided for @clientHomeAcServiceBanner.
  ///
  /// In en, this message translates to:
  /// **'Get your AC serviced\nbefore it gets worse.'**
  String get clientHomeAcServiceBanner;

  /// No description provided for @clientHomeBookAcTechnician.
  ///
  /// In en, this message translates to:
  /// **'Book AC Technician'**
  String get clientHomeBookAcTechnician;

  /// No description provided for @clientHomeNeedHelpNow.
  ///
  /// In en, this message translates to:
  /// **'Need help now?'**
  String get clientHomeNeedHelpNow;

  /// No description provided for @clientHomeUrgentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For urgent issues, book instantly.'**
  String get clientHomeUrgentSubtitle;

  /// No description provided for @clientHome247Service.
  ///
  /// In en, this message translates to:
  /// **'24/7 Service'**
  String get clientHome247Service;

  /// No description provided for @clientHomeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get clientHomeRecent;

  /// No description provided for @clientHomeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get clientHomeSeeAll;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get timeNow;

  /// No description provided for @timeMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String timeMinutesShort(int minutes);

  /// No description provided for @timeHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String timeHoursShort(int hours);

  /// No description provided for @clientProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get clientProfileTitle;

  /// No description provided for @clientProfileAvatarLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Profile image saved on this device. Cloud sync is not available yet.'**
  String get clientProfileAvatarLocalOnly;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsSectionLegal;

  /// No description provided for @settingsSectionDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsSectionDangerZone;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get settingsTermsConditions;

  /// No description provided for @profilePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhotoTitle;

  /// No description provided for @commonGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get commonGallery;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete your HandyGo account and sign you out. This action may not be reversible.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountRequestByEmail.
  ///
  /// In en, this message translates to:
  /// **'Request deletion by email'**
  String get deleteAccountRequestByEmail;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get commonLogout;

  /// No description provided for @clientJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Jobs'**
  String get clientJobsTitle;

  /// No description provided for @clientJobsEmpty.
  ///
  /// In en, this message translates to:
  /// **'📋  No jobs yet'**
  String get clientJobsEmpty;

  /// No description provided for @locationSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected location'**
  String get locationSelected;

  /// No description provided for @locationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search places, areas, or landmarks…'**
  String get locationSearchHint;

  /// No description provided for @locationNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No matching places found. Try a nearby landmark or area name.'**
  String get locationNoSuggestions;

  /// No description provided for @locationSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Place suggestions are unavailable right now. You can still move the pin manually.'**
  String get locationSearchFailed;

  /// No description provided for @locationGettingAddress.
  ///
  /// In en, this message translates to:
  /// **'Getting address…'**
  String get locationGettingAddress;

  /// No description provided for @locationUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use This Location'**
  String get locationUseThis;

  /// No description provided for @serviceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get serviceComingSoon;

  /// No description provided for @clientHomeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search services...'**
  String get clientHomeSearchHint;

  /// No description provided for @profileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account.'**
  String get profileDeleteFailed;

  /// No description provided for @serviceBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get serviceBookNow;

  /// No description provided for @serviceSelectedTick.
  ///
  /// In en, this message translates to:
  /// **'Selected ✓'**
  String get serviceSelectedTick;

  /// No description provided for @locationMoveMapHint.
  ///
  /// In en, this message translates to:
  /// **'Move the map or tap to pick a location'**
  String get locationMoveMapHint;

  /// No description provided for @slotMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get slotMorning;

  /// No description provided for @slotAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get slotAfternoon;

  /// No description provided for @slotEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get slotEvening;

  /// No description provided for @slotNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get slotNight;

  /// No description provided for @slotMorningRange.
  ///
  /// In en, this message translates to:
  /// **'9 AM – 12 PM'**
  String get slotMorningRange;

  /// No description provided for @slotAfternoonRange.
  ///
  /// In en, this message translates to:
  /// **'12 PM – 4 PM'**
  String get slotAfternoonRange;

  /// No description provided for @slotEveningRange.
  ///
  /// In en, this message translates to:
  /// **'4 PM – 8 PM'**
  String get slotEveningRange;

  /// No description provided for @slotNightRange.
  ///
  /// In en, this message translates to:
  /// **'8 PM – 11 PM'**
  String get slotNightRange;

  /// No description provided for @postJobSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get postJobSelectDate;

  /// No description provided for @postJobLocationAdded.
  ///
  /// In en, this message translates to:
  /// **'Location added'**
  String get postJobLocationAdded;

  /// No description provided for @postJobCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get postJobCurrentLocation;

  /// No description provided for @postJobMapLocationAdded.
  ///
  /// In en, this message translates to:
  /// **'Map location added'**
  String get postJobMapLocationAdded;

  /// No description provided for @postJobPickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on Map'**
  String get postJobPickOnMap;

  /// No description provided for @postJobMapPrefix.
  ///
  /// In en, this message translates to:
  /// **'Map: {address}'**
  String postJobMapPrefix(String address);

  /// No description provided for @postJobGpsPrefix.
  ///
  /// In en, this message translates to:
  /// **'Pinned Location'**
  String get postJobGpsPrefix;

  /// No description provided for @postJobBookService.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get postJobBookService;

  /// No description provided for @postJobSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get postJobSaveChanges;

  /// No description provided for @postJobBookAService.
  ///
  /// In en, this message translates to:
  /// **'Book a Service'**
  String get postJobBookAService;

  /// No description provided for @postJobEditBooking.
  ///
  /// In en, this message translates to:
  /// **'Edit Booking'**
  String get postJobEditBooking;

  /// No description provided for @postJobNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get postJobNotAvailable;

  /// No description provided for @bookingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load booking.'**
  String get bookingLoadFailed;

  /// No description provided for @bookingServiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Service Details'**
  String get bookingServiceDetails;

  /// No description provided for @bookingIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get bookingIssue;

  /// No description provided for @bookingUrgency.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get bookingUrgency;

  /// No description provided for @bookingTiming.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get bookingTiming;

  /// No description provided for @bookingNotScheduledYet.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled yet'**
  String get bookingNotScheduledYet;

  /// No description provided for @bookingTimeWindow.
  ///
  /// In en, this message translates to:
  /// **'Time Window'**
  String get bookingTimeWindow;

  /// No description provided for @bookingScheduledDate.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Date'**
  String get bookingScheduledDate;

  /// No description provided for @bookingCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get bookingCreated;

  /// No description provided for @bookingCancellationReason.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Reason'**
  String get bookingCancellationReason;

  /// No description provided for @bookingInspectionCompletedBy.
  ///
  /// In en, this message translates to:
  /// **'Inspection completed by'**
  String get bookingInspectionCompletedBy;

  /// No description provided for @bookingWorkBeingCompletedBy.
  ///
  /// In en, this message translates to:
  /// **'Work being completed by'**
  String get bookingWorkBeingCompletedBy;

  /// No description provided for @bookingInspectionAndRepairBy.
  ///
  /// In en, this message translates to:
  /// **'Inspection & repair by'**
  String get bookingInspectionAndRepairBy;

  /// No description provided for @bookingAssignedWorker.
  ///
  /// In en, this message translates to:
  /// **'Assigned Worker'**
  String get bookingAssignedWorker;

  /// No description provided for @bookingDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Details'**
  String get bookingDetailsTitle;

  /// No description provided for @bookingNoAddressProvided.
  ///
  /// In en, this message translates to:
  /// **'No address provided'**
  String get bookingNoAddressProvided;

  /// No description provided for @bookingAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get bookingAttachments;

  /// No description provided for @bookingPhotosCount.
  ///
  /// In en, this message translates to:
  /// **'Photos ({count})'**
  String bookingPhotosCount(int count);

  /// No description provided for @bookingVideosCount.
  ///
  /// In en, this message translates to:
  /// **'Videos ({count})'**
  String bookingVideosCount(int count);

  /// No description provided for @bookingVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice Note'**
  String get bookingVoiceNote;

  /// No description provided for @bookingPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get bookingPricing;

  /// No description provided for @bookingEstimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated Price'**
  String get bookingEstimatedPrice;

  /// No description provided for @bookingInspectionCharges.
  ///
  /// In en, this message translates to:
  /// **'Inspection Charges'**
  String get bookingInspectionCharges;

  /// No description provided for @bookingWorkCharges.
  ///
  /// In en, this message translates to:
  /// **'Work Charges'**
  String get bookingWorkCharges;

  /// No description provided for @bookingFinalPrice.
  ///
  /// In en, this message translates to:
  /// **'Final Price'**
  String get bookingFinalPrice;

  /// No description provided for @bookingJobLocation.
  ///
  /// In en, this message translates to:
  /// **'Job location'**
  String get bookingJobLocation;

  /// No description provided for @bookingLiveLocation.
  ///
  /// In en, this message translates to:
  /// **'Live Location'**
  String get bookingLiveLocation;

  /// No description provided for @bookingTrackingWorker.
  ///
  /// In en, this message translates to:
  /// **'Tracking {name}'**
  String bookingTrackingWorker(String name);

  /// No description provided for @bookingWaitingForWorkerLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for worker to share location'**
  String get bookingWaitingForWorkerLocation;

  /// No description provided for @bookingLiveLocationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Live location not available yet'**
  String get bookingLiveLocationNotAvailable;

  /// No description provided for @bookingLocationPending.
  ///
  /// In en, this message translates to:
  /// **'Location pending'**
  String get bookingLocationPending;

  /// No description provided for @bookingMapPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map preview unavailable'**
  String get bookingMapPreviewUnavailable;

  /// No description provided for @bookingMapImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the map image'**
  String get bookingMapImageLoadFailed;

  /// No description provided for @bookingAppearsWhenEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Will appear once the worker is en route'**
  String get bookingAppearsWhenEnRoute;

  /// No description provided for @bookingWorkerNearlyThere.
  ///
  /// In en, this message translates to:
  /// **'Worker is nearly there'**
  String get bookingWorkerNearlyThere;

  /// No description provided for @bookingWorkerOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Worker is on the way'**
  String get bookingWorkerOnTheWay;

  /// No description provided for @bookingLiveUpdatedNow.
  ///
  /// In en, this message translates to:
  /// **'Live · Updated now'**
  String get bookingLiveUpdatedNow;

  /// No description provided for @bookingStatusTimeline.
  ///
  /// In en, this message translates to:
  /// **'Job Status Timeline'**
  String get bookingStatusTimeline;

  /// No description provided for @bookingJobExpired.
  ///
  /// In en, this message translates to:
  /// **'This job expired'**
  String get bookingJobExpired;

  /// No description provided for @bookingExpiredExplanation.
  ///
  /// In en, this message translates to:
  /// **'No worker was hired within 72 hours. Make it live again to keep looking.'**
  String get bookingExpiredExplanation;

  /// No description provided for @bookingMakeLiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to make job live again.'**
  String get bookingMakeLiveFailed;

  /// No description provided for @bookingMakeLiveAgain.
  ///
  /// In en, this message translates to:
  /// **'Make Live Again'**
  String get bookingMakeLiveAgain;

  /// No description provided for @bookingPreviousUstaadCancelledNamed.
  ///
  /// In en, this message translates to:
  /// **'Previous Ustaad cancelled: {name}'**
  String bookingPreviousUstaadCancelledNamed(String name);

  /// No description provided for @bookingPreviousUstaadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Previous Ustaad cancelled'**
  String get bookingPreviousUstaadCancelled;

  /// No description provided for @bookingUstaadCancelledJob.
  ///
  /// In en, this message translates to:
  /// **'The Ustaad cancelled this job'**
  String get bookingUstaadCancelledJob;

  /// No description provided for @bookingReasonPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String bookingReasonPrefix(String reason);

  /// No description provided for @bookingFindAnotherUstaadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to find another Ustaad.'**
  String get bookingFindAnotherUstaadFailed;

  /// No description provided for @bookingFindAnotherUstaad.
  ///
  /// In en, this message translates to:
  /// **'Find Another Ustaad'**
  String get bookingFindAnotherUstaad;

  /// No description provided for @bookingSelectedServices.
  ///
  /// In en, this message translates to:
  /// **'Selected Services'**
  String get bookingSelectedServices;

  /// No description provided for @bookingServiceQuantity.
  ///
  /// In en, this message translates to:
  /// **'{name} x{quantity}'**
  String bookingServiceQuantity(String name, int quantity);

  /// No description provided for @bookingChooseUstaad.
  ///
  /// In en, this message translates to:
  /// **'Choose Ustaad'**
  String get bookingChooseUstaad;

  /// No description provided for @bookingSeeWorkerBids.
  ///
  /// In en, this message translates to:
  /// **'See Worker Offers'**
  String get bookingSeeWorkerBids;

  /// No description provided for @bookingTrackWorker.
  ///
  /// In en, this message translates to:
  /// **'Track Worker'**
  String get bookingTrackWorker;

  /// No description provided for @bookingReviewWorker.
  ///
  /// In en, this message translates to:
  /// **'Review Worker'**
  String get bookingReviewWorker;

  /// No description provided for @bookingYourReview.
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get bookingYourReview;

  /// No description provided for @bookingCallWorker.
  ///
  /// In en, this message translates to:
  /// **'Call Worker'**
  String get bookingCallWorker;

  /// No description provided for @bookingCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get bookingCancelBooking;

  /// No description provided for @bookingCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'The booking could not be cancelled.'**
  String get bookingCancelFailed;

  /// No description provided for @bookingChatWithWorker.
  ///
  /// In en, this message translates to:
  /// **'Chat with Worker'**
  String get bookingChatWithWorker;

  /// No description provided for @bookingLoadFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Failed to load booking'**
  String get bookingLoadFailedShort;

  /// No description provided for @workerLevelMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get workerLevelMaster;

  /// No description provided for @workerLevelElite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get workerLevelElite;

  /// No description provided for @workerLevelProUstaad.
  ///
  /// In en, this message translates to:
  /// **'Pro Ustaad'**
  String get workerLevelProUstaad;

  /// No description provided for @workerLevelPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get workerLevelPro;

  /// No description provided for @workerLevelStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get workerLevelStandard;

  /// No description provided for @trackLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tracking data.'**
  String get trackLoadFailed;

  /// No description provided for @trackTitleUstaad.
  ///
  /// In en, this message translates to:
  /// **'Track Ustaad'**
  String get trackTitleUstaad;

  /// No description provided for @trackNoLocationForBooking.
  ///
  /// In en, this message translates to:
  /// **'Location not available for this booking.'**
  String get trackNoLocationForBooking;

  /// No description provided for @trackUstaadLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Ustaad\'s location is not available yet.'**
  String get trackUstaadLocationUnavailable;

  /// No description provided for @trackJobCompleted.
  ///
  /// In en, this message translates to:
  /// **'Job Completed ✓'**
  String get trackJobCompleted;

  /// No description provided for @trackQuoteAcceptedRepairInProgress.
  ///
  /// In en, this message translates to:
  /// **'Quote Accepted — Repair In Progress'**
  String get trackQuoteAcceptedRepairInProgress;

  /// No description provided for @trackReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report Submitted'**
  String get trackReportSubmitted;

  /// No description provided for @trackInspectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Inspection In Progress'**
  String get trackInspectionInProgress;

  /// No description provided for @trackReviewReportAndDecide.
  ///
  /// In en, this message translates to:
  /// **'Review the report below and decide how to proceed'**
  String get trackReviewReportAndDecide;

  /// No description provided for @trackWorkerLabel.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get trackWorkerLabel;

  /// No description provided for @trackHiredAt.
  ///
  /// In en, this message translates to:
  /// **'Hired at {price}'**
  String trackHiredAt(String price);

  /// No description provided for @trackPhoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Phone number unavailable'**
  String get trackPhoneUnavailable;

  /// No description provided for @trackDialerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open phone dialer'**
  String get trackDialerFailed;

  /// No description provided for @trackAssignedWorkerCaps.
  ///
  /// In en, this message translates to:
  /// **'ASSIGNED WORKER'**
  String get trackAssignedWorkerCaps;

  /// No description provided for @trackCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get trackCall;

  /// No description provided for @trackLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get trackLocationUnavailable;

  /// No description provided for @trackArrivingIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Arriving in ~{count} minute} other{Arriving in ~{count} minutes}}'**
  String trackArrivingIn(int count);

  /// No description provided for @trackEtaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Arrival time unavailable'**
  String get trackEtaUnavailable;

  /// No description provided for @trackStepHired.
  ///
  /// In en, this message translates to:
  /// **'Hired'**
  String get trackStepHired;

  /// No description provided for @trackStepUstaadOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Ustaad on the way'**
  String get trackStepUstaadOnTheWay;

  /// No description provided for @trackStepInspectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Inspection in progress'**
  String get trackStepInspectionInProgress;

  /// No description provided for @trackStepReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get trackStepReportSubmitted;

  /// No description provided for @trackStepClosedAfterInspection.
  ///
  /// In en, this message translates to:
  /// **'Closed after inspection'**
  String get trackStepClosedAfterInspection;

  /// No description provided for @trackStepQuoteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Quote accepted'**
  String get trackStepQuoteAccepted;

  /// No description provided for @trackStepReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get trackStepReviewed;

  /// No description provided for @trackStepWorkInProgress.
  ///
  /// In en, this message translates to:
  /// **'Work in progress'**
  String get trackStepWorkInProgress;

  /// No description provided for @trackStepReviewPending.
  ///
  /// In en, this message translates to:
  /// **'Review pending'**
  String get trackStepReviewPending;

  /// No description provided for @trackJobProgress.
  ///
  /// In en, this message translates to:
  /// **'Job Progress'**
  String get trackJobProgress;

  /// No description provided for @trackLoadFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tracking'**
  String get trackLoadFailedShort;

  /// No description provided for @discoveryJobLocation.
  ///
  /// In en, this message translates to:
  /// **'Job Location'**
  String get discoveryJobLocation;

  /// No description provided for @discoveryJobLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Job location not available'**
  String get discoveryJobLocationUnavailable;

  /// No description provided for @discoveryLiveWorkerOffers.
  ///
  /// In en, this message translates to:
  /// **'Live Worker Offers'**
  String get discoveryLiveWorkerOffers;

  /// No description provided for @discoveryRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get discoveryRefresh;

  /// No description provided for @discoveryBidsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load offers.'**
  String get discoveryBidsLoadFailed;

  /// No description provided for @discoveryNoBidsYet.
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get discoveryNoBidsYet;

  /// No description provided for @discoveryPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} pending} other{{count} pending}}'**
  String discoveryPendingCount(int count);

  /// No description provided for @discoveryHire.
  ///
  /// In en, this message translates to:
  /// **'Hire'**
  String get discoveryHire;

  /// No description provided for @discoveryHiring.
  ///
  /// In en, this message translates to:
  /// **'Hiring…'**
  String get discoveryHiring;

  /// No description provided for @discoveryHireNamed.
  ///
  /// In en, this message translates to:
  /// **'Hire {name}?'**
  String discoveryHireNamed(String name);

  /// No description provided for @discoveryAcceptBid.
  ///
  /// In en, this message translates to:
  /// **'Accept {name}\'s offer of {price}?'**
  String discoveryAcceptBid(String name, String price);

  /// No description provided for @discoveryInspectionFeeSeparate.
  ///
  /// In en, this message translates to:
  /// **'The inspection fee is paid separately.\nThe new Ustaad\'s offer is charged separately.'**
  String get discoveryInspectionFeeSeparate;

  /// No description provided for @discoveryBidLabourOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'This bid covers labour only. Parts and materials will be purchased or charged separately with your approval.'**
  String get discoveryBidLabourOnlyNote;

  /// No description provided for @discoveryBidInspectionBasedNote.
  ///
  /// In en, this message translates to:
  /// **'This bid is based on the inspection report and includes labour and the parts or materials required for the reported work.'**
  String get discoveryBidInspectionBasedNote;

  /// No description provided for @discoveryWorkerHired.
  ///
  /// In en, this message translates to:
  /// **'Worker hired successfully'**
  String get discoveryWorkerHired;

  /// No description provided for @discoveryHireFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to hire worker.'**
  String get discoveryHireFailed;

  /// No description provided for @discoveryInspectedThisJob.
  ///
  /// In en, this message translates to:
  /// **'INSPECTED THIS JOB'**
  String get discoveryInspectedThisJob;

  /// No description provided for @discoveryTheirQuote.
  ///
  /// In en, this message translates to:
  /// **'their quote'**
  String get discoveryTheirQuote;

  /// No description provided for @discoveryInspectionCompletedByThis.
  ///
  /// In en, this message translates to:
  /// **'Inspection completed by this Ustaad.'**
  String get discoveryInspectionCompletedByThis;

  /// No description provided for @discoveryViewInspectionReport.
  ///
  /// In en, this message translates to:
  /// **'View Inspection Report'**
  String get discoveryViewInspectionReport;

  /// No description provided for @discoveryHireAgain.
  ///
  /// In en, this message translates to:
  /// **'Hire Again'**
  String get discoveryHireAgain;

  /// No description provided for @discoveryHireAgainNamed.
  ///
  /// In en, this message translates to:
  /// **'Hire {name} again?'**
  String discoveryHireAgainNamed(String name);

  /// No description provided for @discoveryOriginalQuoteContinues.
  ///
  /// In en, this message translates to:
  /// **'They\'ll continue using their original inspection quote.'**
  String get discoveryOriginalQuoteContinues;

  /// No description provided for @discoveryWorkersWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Workers who apply will appear here.\nCheck back shortly.'**
  String get discoveryWorkersWillAppear;

  /// No description provided for @discoveryTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get discoveryTryAgain;

  /// No description provided for @postJobInspectionReportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection Report (Optional)'**
  String get postJobInspectionReportSectionTitle;

  /// No description provided for @postJobAttachInspectionReport.
  ///
  /// In en, this message translates to:
  /// **'Attach previous inspection report'**
  String get postJobAttachInspectionReport;

  /// No description provided for @postJobAttachInspectionHint.
  ///
  /// In en, this message translates to:
  /// **'Help bidders understand the job by sharing an earlier diagnosis.'**
  String get postJobAttachInspectionHint;

  /// No description provided for @postJobChangeInspectionReport.
  ///
  /// In en, this message translates to:
  /// **'Change report'**
  String get postJobChangeInspectionReport;

  /// No description provided for @postJobSelectInspectionReport.
  ///
  /// In en, this message translates to:
  /// **'Select an inspection report'**
  String get postJobSelectInspectionReport;

  /// No description provided for @postJobNoInspectionReports.
  ///
  /// In en, this message translates to:
  /// **'No previous inspection reports available for this service.'**
  String get postJobNoInspectionReports;

  /// No description provided for @postJobInspectionReportsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your inspection reports.'**
  String get postJobInspectionReportsFailed;

  /// No description provided for @postJobInspectionReportCleared.
  ///
  /// In en, this message translates to:
  /// **'Attached inspection report was removed because the service changed.'**
  String get postJobInspectionReportCleared;

  /// No description provided for @inspectionReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection Report'**
  String get inspectionReportTitle;

  /// No description provided for @inspectionReportNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Report not available yet.'**
  String get inspectionReportNotAvailable;

  /// No description provided for @inspectionUstaadVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Ustaad Voice Note'**
  String get inspectionUstaadVoiceNote;

  /// No description provided for @inspectionPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get inspectionPhotos;

  /// No description provided for @inspectionParts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get inspectionParts;

  /// No description provided for @inspectionRepairQuoteTotal.
  ///
  /// In en, this message translates to:
  /// **'Repair quote total'**
  String get inspectionRepairQuoteTotal;

  /// No description provided for @inspectionAcceptQuoteContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept Quote & Continue Repair'**
  String get inspectionAcceptQuoteContinue;

  /// No description provided for @inspectionFindOtherUstaad.
  ///
  /// In en, this message translates to:
  /// **'Find Other Ustaad'**
  String get inspectionFindOtherUstaad;

  /// No description provided for @inspectionCloseAfterInspection.
  ///
  /// In en, this message translates to:
  /// **'Close After Inspection'**
  String get inspectionCloseAfterInspection;

  /// No description provided for @inspectionAcceptQuoteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept quote & continue repair?'**
  String get inspectionAcceptQuoteConfirmTitle;

  /// No description provided for @inspectionCloseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close after inspection?'**
  String get inspectionCloseConfirmTitle;

  /// No description provided for @inspectionAcceptQuoteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The same Ustaad will continue the repair. The inspection fee is waived — you will only pay the repair quote.'**
  String get inspectionAcceptQuoteConfirmBody;

  /// No description provided for @inspectionCloseConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will only be charged the inspection fee. The job will be marked completed.'**
  String get inspectionCloseConfirmBody;

  /// No description provided for @inspectionClosedAfterInspection.
  ///
  /// In en, this message translates to:
  /// **'Closed after inspection.'**
  String get inspectionClosedAfterInspection;

  /// No description provided for @inspectionQuoteAcceptedRepairInProgress.
  ///
  /// In en, this message translates to:
  /// **'Quote accepted — repair in progress.'**
  String get inspectionQuoteAcceptedRepairInProgress;

  /// No description provided for @inspectionActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed. Try again.'**
  String get inspectionActionFailed;

  /// No description provided for @inspectionFindAnotherConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Find another Ustaad?'**
  String get inspectionFindAnotherConfirmTitle;

  /// No description provided for @inspectionFindAnotherConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Confirming completes the inspection and charges the inspection fee. Your job goes live again so other Ustaads can send their rates.'**
  String get inspectionFindAnotherConfirmBody;

  /// No description provided for @inspectionBadge.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get inspectionBadge;

  /// No description provided for @chooseHireConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Hire this Ustaad?'**
  String get chooseHireConfirmTitle;

  /// No description provided for @chooseHireConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Hire {name} for this job? You won\'t be able to choose a different Ustaad afterwards.'**
  String chooseHireConfirmBody(String name);

  /// No description provided for @chooseAssignFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to assign this Ustaad. Please try again.'**
  String get chooseAssignFailed;

  /// No description provided for @chooseServiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Service Total {price}'**
  String chooseServiceTotal(String price);

  /// No description provided for @chooseInspectionFeeAmount.
  ///
  /// In en, this message translates to:
  /// **'Inspection fee {price}'**
  String chooseInspectionFeeAmount(String price);

  /// No description provided for @chooseFindingUstaads.
  ///
  /// In en, this message translates to:
  /// **'Finding verified Ustaads near you…'**
  String get chooseFindingUstaads;

  /// No description provided for @chooseLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load available Ustaads right now.'**
  String get chooseLoadFailed;

  /// No description provided for @chooseNoUstaadAvailable.
  ///
  /// In en, this message translates to:
  /// **'No verified Ustaad available right now.'**
  String get chooseNoUstaadAvailable;

  /// No description provided for @chooseAutoRefreshNote.
  ///
  /// In en, this message translates to:
  /// **'The list refreshes automatically every 45 seconds.'**
  String get chooseAutoRefreshNote;

  /// No description provided for @chooseRefreshOrWait.
  ///
  /// In en, this message translates to:
  /// **'You can refresh or wait a little — checking available Ustaads…'**
  String get chooseRefreshOrWait;

  /// No description provided for @chooseNewBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get chooseNewBadge;

  /// No description provided for @chooseSelect.
  ///
  /// In en, this message translates to:
  /// **'Chunain'**
  String get chooseSelect;

  /// No description provided for @chooseRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get chooseRecommended;

  /// No description provided for @chooseSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get chooseSkills;

  /// No description provided for @chooseNearestFirst.
  ///
  /// In en, this message translates to:
  /// **'Nearest first'**
  String get chooseNearestFirst;

  /// No description provided for @chooseAvailableCount.
  ///
  /// In en, this message translates to:
  /// **'{count} available'**
  String chooseAvailableCount(int count);

  /// No description provided for @chooseViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get chooseViewProfile;

  /// No description provided for @chooseNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews available'**
  String get chooseNoReviews;

  /// No description provided for @chooseCnicVerified.
  ///
  /// In en, this message translates to:
  /// **'CNIC verified'**
  String get chooseCnicVerified;

  /// No description provided for @chooseCnicVerifiedUstaad.
  ///
  /// In en, this message translates to:
  /// **'CNIC Verified Ustaad'**
  String get chooseCnicVerifiedUstaad;

  /// No description provided for @chooseExperienceYears.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{{years} yr experience} other{{years} yrs experience}}'**
  String chooseExperienceYears(int years);

  /// No description provided for @choosePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get choosePhoneLabel;

  /// No description provided for @chooseProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this Ustaad\'s profile.'**
  String get chooseProfileLoadFailed;

  /// No description provided for @myBookingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your bookings. Please try again.'**
  String get myBookingsLoadFailed;

  /// No description provided for @myBookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookingsTitle;

  /// No description provided for @myBookingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All your bookings in one place'**
  String get myBookingsSubtitle;

  /// No description provided for @myBookingsEmptyActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'No work in progress'**
  String get myBookingsEmptyActiveTitle;

  /// No description provided for @myBookingsEmptyCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'No completed work yet'**
  String get myBookingsEmptyCompletedTitle;

  /// No description provided for @myBookingsEmptyCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'No cancelled bookings'**
  String get myBookingsEmptyCancelledTitle;

  /// No description provided for @myBookingsEmptyActiveHelper.
  ///
  /// In en, this message translates to:
  /// **'Book a new job to see its live status here.'**
  String get myBookingsEmptyActiveHelper;

  /// No description provided for @myBookingsEmptyHistoryHelper.
  ///
  /// In en, this message translates to:
  /// **'Every job you book will stay here as a complete record.'**
  String get myBookingsEmptyHistoryHelper;

  /// No description provided for @myBookingsEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Book a new job'**
  String get myBookingsEmptyCta;

  /// No description provided for @myBookingsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get myBookingsEmptyTitle;

  /// No description provided for @myBookingsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get myBookingsNoResults;

  /// No description provided for @myBookingsAdjustFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or search term'**
  String get myBookingsAdjustFilters;

  /// No description provided for @myBookingsBookFirst.
  ///
  /// In en, this message translates to:
  /// **'Book your first service to get started'**
  String get myBookingsBookFirst;

  /// No description provided for @myBookingsRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Pull to retry.'**
  String get myBookingsRefreshFailed;

  /// No description provided for @myBookingsSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get myBookingsSomethingWrong;

  /// No description provided for @cardTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String cardTodayAt(String time);

  /// No description provided for @cardGoesLiveBefore.
  ///
  /// In en, this message translates to:
  /// **'Goes live 1h before window'**
  String get cardGoesLiveBefore;

  /// No description provided for @cardWorkersNotified.
  ///
  /// In en, this message translates to:
  /// **'Workers are notified immediately'**
  String get cardWorkersNotified;

  /// No description provided for @cardSearchingWorkers.
  ///
  /// In en, this message translates to:
  /// **'Searching for workers...'**
  String get cardSearchingWorkers;

  /// No description provided for @cardNoWorkerYet.
  ///
  /// In en, this message translates to:
  /// **'No worker yet'**
  String get cardNoWorkerYet;

  /// No description provided for @cardEstimatePrefix.
  ///
  /// In en, this message translates to:
  /// **'est.'**
  String get cardEstimatePrefix;

  /// No description provided for @cardFindWorkers.
  ///
  /// In en, this message translates to:
  /// **'Find Workers'**
  String get cardFindWorkers;

  /// No description provided for @cardEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get cardEdit;

  /// No description provided for @bookingCardLaneBidding.
  ///
  /// In en, this message translates to:
  /// **'Bidding'**
  String get bookingCardLaneBidding;

  /// No description provided for @bookingCardDetails.
  ///
  /// In en, this message translates to:
  /// **'Details →'**
  String get bookingCardDetails;

  /// No description provided for @bookingCardPaymentAfterWork.
  ///
  /// In en, this message translates to:
  /// **'Cash — after work'**
  String get bookingCardPaymentAfterWork;

  /// No description provided for @bookingCardPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get bookingCardPaymentPending;

  /// No description provided for @bookingCardNothingPaid.
  ///
  /// In en, this message translates to:
  /// **'Nothing paid'**
  String get bookingCardNothingPaid;

  /// No description provided for @bookingCardPartialPayment.
  ///
  /// In en, this message translates to:
  /// **'{received} paid · {remaining} remaining'**
  String bookingCardPartialPayment(String received, String remaining);

  /// No description provided for @bookingCardNoPaymentTaken.
  ///
  /// In en, this message translates to:
  /// **'No payment taken'**
  String get bookingCardNoPaymentTaken;

  /// No description provided for @bookingCardStatusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get bookingCardStatusOnTheWay;

  /// No description provided for @bookingCardStatusWaitingQuote.
  ///
  /// In en, this message translates to:
  /// **'Waiting for quote'**
  String get bookingCardStatusWaitingQuote;

  /// No description provided for @bookingCardRomanActiveFilter.
  ///
  /// In en, this message translates to:
  /// **'Currently active'**
  String get bookingCardRomanActiveFilter;

  /// No description provided for @bookingCardRomanAssigned.
  ///
  /// In en, this message translates to:
  /// **'Ustaad assigned'**
  String get bookingCardRomanAssigned;

  /// No description provided for @bookingCardRomanWorkInProgress.
  ///
  /// In en, this message translates to:
  /// **'Job underway'**
  String get bookingCardRomanWorkInProgress;

  /// No description provided for @bookingCardRomanRejected.
  ///
  /// In en, this message translates to:
  /// **'Booking rejected'**
  String get bookingCardRomanRejected;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Bookings'**
  String get filterTitle;

  /// No description provided for @filterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterUrgentOption.
  ///
  /// In en, this message translates to:
  /// **'⚡ Urgent'**
  String get filterUrgentOption;

  /// No description provided for @filterNormalOption.
  ///
  /// In en, this message translates to:
  /// **'🗓 Normal'**
  String get filterNormalOption;

  /// No description provided for @filterSortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get filterSortByDate;

  /// No description provided for @filterNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get filterNewestFirst;

  /// No description provided for @filterOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get filterOldestFirst;

  /// No description provided for @filterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get filterApply;

  /// No description provided for @searchBookingsHint.
  ///
  /// In en, this message translates to:
  /// **'Search bookings, services...'**
  String get searchBookingsHint;

  /// No description provided for @cancelReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason for cancelling the booking'**
  String get cancelReasonTitle;

  /// No description provided for @cancelReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please give a reason.'**
  String get cancelReasonRequired;

  /// No description provided for @cancelReasonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a reason'**
  String get cancelReasonSelect;

  /// No description provided for @cancelReasonWriteOwn.
  ///
  /// In en, this message translates to:
  /// **'Write your own reason'**
  String get cancelReasonWriteOwn;

  /// No description provided for @reviewSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'The review could not be submitted.'**
  String get reviewSubmitFailed;

  /// No description provided for @reviewPromptBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Please review your Ustaad before continuing.'**
  String get reviewPromptBeforeContinuing;

  /// No description provided for @reviewHowWasWork.
  ///
  /// In en, this message translates to:
  /// **'How was the work?'**
  String get reviewHowWasWork;

  /// No description provided for @reviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment (optional)...'**
  String get reviewCommentHint;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get reviewSubmit;

  /// Shown under the stars when Submit Review is tapped with no rating chosen.
  ///
  /// In en, this message translates to:
  /// **'Please choose a star rating first.'**
  String get reviewSelectRating;

  /// Confirmation shown after a review is successfully submitted.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your review has been submitted.'**
  String get reviewSubmitSuccess;

  /// No description provided for @reviewLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get reviewLater;

  /// No description provided for @chatOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open chat.'**
  String get chatOpenFailed;

  /// No description provided for @mediaTapToPlay.
  ///
  /// In en, this message translates to:
  /// **'Tap to play'**
  String get mediaTapToPlay;

  /// No description provided for @inspectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get inspectionConfirm;

  /// No description provided for @trackSubtextCompleted.
  ///
  /// In en, this message translates to:
  /// **'{name} has completed the job'**
  String trackSubtextCompleted(String name);

  /// No description provided for @trackSubtextContinuingRepair.
  ///
  /// In en, this message translates to:
  /// **'{name} is continuing the repair'**
  String trackSubtextContinuingRepair(String name);

  /// No description provided for @trackSubtextOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'{name} is on the way to your location'**
  String trackSubtextOnTheWay(String name);

  /// No description provided for @trackSubtextArrived.
  ///
  /// In en, this message translates to:
  /// **'{name} has arrived at your location'**
  String trackSubtextArrived(String name);

  /// No description provided for @trackSubtextInspecting.
  ///
  /// In en, this message translates to:
  /// **'{name} is inspecting the issue'**
  String trackSubtextInspecting(String name);

  /// No description provided for @trackSubtextHiredForInspection.
  ///
  /// In en, this message translates to:
  /// **'{name} has been hired for this inspection'**
  String trackSubtextHiredForInspection(String name);

  /// No description provided for @trackSubtextWorking.
  ///
  /// In en, this message translates to:
  /// **'{name} is working on your job'**
  String trackSubtextWorking(String name);

  /// No description provided for @trackSubtextHiredForJob.
  ///
  /// In en, this message translates to:
  /// **'{name} has been hired for this job'**
  String trackSubtextHiredForJob(String name);

  /// No description provided for @urgentWithin1Hour.
  ///
  /// In en, this message translates to:
  /// **'Within 1 hour'**
  String get urgentWithin1Hour;

  /// No description provided for @urgentWithin2Hours.
  ///
  /// In en, this message translates to:
  /// **'Within 2 hours'**
  String get urgentWithin2Hours;

  /// No description provided for @urgentWithin4Hours.
  ///
  /// In en, this message translates to:
  /// **'Within 4 hours'**
  String get urgentWithin4Hours;

  /// No description provided for @inspectionFeePaid.
  ///
  /// In en, this message translates to:
  /// **'Inspection fee paid'**
  String get inspectionFeePaid;

  /// No description provided for @inspectionFeeNotPaid.
  ///
  /// In en, this message translates to:
  /// **'Inspection fee not paid'**
  String get inspectionFeeNotPaid;

  /// No description provided for @chooseWithinRadius.
  ///
  /// In en, this message translates to:
  /// **'within {km} km'**
  String chooseWithinRadius(String km);

  /// No description provided for @chooseHireConfirmBodyFull.
  ///
  /// In en, this message translates to:
  /// **'Hire {name} for this job? You will not be able to choose a different Ustaad afterwards.'**
  String chooseHireConfirmBodyFull(String name);

  /// No description provided for @trackHeadlineUstaadOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Ustaad On The Way'**
  String get trackHeadlineUstaadOnTheWay;

  /// No description provided for @trackHeadlineUstaadArrived.
  ///
  /// In en, this message translates to:
  /// **'Ustaad Arrived'**
  String get trackHeadlineUstaadArrived;

  /// No description provided for @trackHeadlineWorkInProgress.
  ///
  /// In en, this message translates to:
  /// **'Work In Progress'**
  String get trackHeadlineWorkInProgress;

  /// No description provided for @trackHeadlineHired.
  ///
  /// In en, this message translates to:
  /// **'Hired ✓'**
  String get trackHeadlineHired;

  /// No description provided for @trackRatingOutOfFive.
  ///
  /// In en, this message translates to:
  /// **'{rating} / 5.0'**
  String trackRatingOutOfFive(String rating);

  /// No description provided for @discoveryLoadingBids.
  ///
  /// In en, this message translates to:
  /// **'Loading offers...'**
  String get discoveryLoadingBids;

  /// No description provided for @discoveryBidsLoadFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Could not load offers'**
  String get discoveryBidsLoadFailedShort;

  /// No description provided for @bookingWorkersAvailableNearby.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} worker available nearby} other{{count} workers available nearby}}'**
  String bookingWorkersAvailableNearby(int count);

  /// No description provided for @bookingIdShort.
  ///
  /// In en, this message translates to:
  /// **'#ER-{code}'**
  String bookingIdShort(String code);

  /// No description provided for @inspectionPartWithWarranty.
  ///
  /// In en, this message translates to:
  /// **'{name} x{quantity} · {warranty}'**
  String inspectionPartWithWarranty(String name, int quantity, String warranty);

  /// No description provided for @discoveryPendingBidsSorted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} pending offer · sorted by price} other{{count} pending offers · sorted by price}}'**
  String discoveryPendingBidsSorted(int count);

  /// No description provided for @workerOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get workerOffline;

  /// No description provided for @workerOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get workerOnline;

  /// No description provided for @workerBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get workerBusy;

  /// No description provided for @workerOfflineHelper.
  ///
  /// In en, this message translates to:
  /// **'You are hidden from clients'**
  String get workerOfflineHelper;

  /// No description provided for @workerOnlineHelper.
  ///
  /// In en, this message translates to:
  /// **'Clients near your location can see you'**
  String get workerOnlineHelper;

  /// No description provided for @workerBusyHelper.
  ///
  /// In en, this message translates to:
  /// **'You are currently working on a job'**
  String get workerBusyHelper;

  /// No description provided for @workerStatusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get workerStatusOnTheWay;

  /// No description provided for @workerActionOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'On My Way'**
  String get workerActionOnMyWay;

  /// No description provided for @workerActionArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get workerActionArrived;

  /// No description provided for @workerActionStartJob.
  ///
  /// In en, this message translates to:
  /// **'Start Job'**
  String get workerActionStartJob;

  /// No description provided for @workerActionCompleteJob.
  ///
  /// In en, this message translates to:
  /// **'Complete Job'**
  String get workerActionCompleteJob;

  /// No description provided for @workerActionStartInspection.
  ///
  /// In en, this message translates to:
  /// **'Start Inspection'**
  String get workerActionStartInspection;

  /// No description provided for @workerActionStartWork.
  ///
  /// In en, this message translates to:
  /// **'Start Work'**
  String get workerActionStartWork;

  /// No description provided for @workerActionFillReport.
  ///
  /// In en, this message translates to:
  /// **'Fill Inspection Report'**
  String get workerActionFillReport;

  /// No description provided for @workerActionWaitingForClient.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Client Decision'**
  String get workerActionWaitingForClient;

  /// No description provided for @workerSuccessOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way — client notified.'**
  String get workerSuccessOnTheWay;

  /// No description provided for @workerSuccessArrived.
  ///
  /// In en, this message translates to:
  /// **'Marked as arrived.'**
  String get workerSuccessArrived;

  /// No description provided for @workerSuccessJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Job started.'**
  String get workerSuccessJobStarted;

  /// No description provided for @workerSuccessJobCompleted.
  ///
  /// In en, this message translates to:
  /// **'Job marked as completed.'**
  String get workerSuccessJobCompleted;

  /// No description provided for @workerSuccessInspectionStarted.
  ///
  /// In en, this message translates to:
  /// **'Inspection started.'**
  String get workerSuccessInspectionStarted;

  /// No description provided for @workerSuccessWorkStarted.
  ///
  /// In en, this message translates to:
  /// **'Work started.'**
  String get workerSuccessWorkStarted;

  /// No description provided for @workerSkillNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Skill not selected'**
  String get workerSkillNotSelected;

  /// No description provided for @workerLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get workerLocating;

  /// No description provided for @workerTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get workerTapToRetry;

  /// No description provided for @workerTapForLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap for location'**
  String get workerTapForLocation;

  /// No description provided for @workerOnActiveJob.
  ///
  /// In en, this message translates to:
  /// **'On Active Job'**
  String get workerOnActiveJob;

  /// No description provided for @workerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get workerConnecting;

  /// No description provided for @workerGoingOffline.
  ///
  /// In en, this message translates to:
  /// **'Going offline...'**
  String get workerGoingOffline;

  /// No description provided for @workerGoOffline.
  ///
  /// In en, this message translates to:
  /// **'Go Offline'**
  String get workerGoOffline;

  /// No description provided for @workerGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Go Online'**
  String get workerGoOnline;

  /// No description provided for @workerHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}'**
  String workerHelloName(String name);

  /// No description provided for @workerTodaysEarnings.
  ///
  /// In en, this message translates to:
  /// **'Kamai'**
  String get workerTodaysEarnings;

  /// No description provided for @workerRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get workerRating;

  /// No description provided for @workerActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get workerActive;

  /// No description provided for @workerGoOfflineConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Go Offline?'**
  String get workerGoOfflineConfirmTitle;

  /// No description provided for @workerGoOfflineConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will stop appearing to nearby clients.'**
  String get workerGoOfflineConfirmBody;

  /// No description provided for @workerGoOfflineConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, Go Offline'**
  String get workerGoOfflineConfirmYes;

  /// No description provided for @workerFindNewWork.
  ///
  /// In en, this message translates to:
  /// **'New Complaints'**
  String get workerFindNewWork;

  /// No description provided for @workerViewNewJobs.
  ///
  /// In en, this message translates to:
  /// **'Dekhein'**
  String get workerViewNewJobs;

  /// No description provided for @workerActiveJobCaps.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE JOB'**
  String get workerActiveJobCaps;

  /// No description provided for @workerMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get workerMap;

  /// No description provided for @workerViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details →'**
  String get workerViewDetails;

  /// No description provided for @workerNoActiveJob.
  ///
  /// In en, this message translates to:
  /// **'No active job right now'**
  String get workerNoActiveJob;

  /// No description provided for @workerStayOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Stay online to find work nearby.'**
  String get workerStayOnlineHint;

  /// No description provided for @workerReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get workerReady;

  /// No description provided for @workerPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get workerPerformance;

  /// No description provided for @workerJobsDone.
  ///
  /// In en, this message translates to:
  /// **'Jobs Done'**
  String get workerJobsDone;

  /// No description provided for @workerCancelRate.
  ///
  /// In en, this message translates to:
  /// **'Cancel Rate'**
  String get workerCancelRate;

  /// No description provided for @workerPercentValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String workerPercentValue(String value);

  /// No description provided for @workerResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get workerResponse;

  /// No description provided for @workerReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get workerReviews;

  /// No description provided for @workerSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all →'**
  String get workerSeeAll;

  /// No description provided for @workerNoReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get workerNoReviewsYet;

  /// No description provided for @workerReviewsAppearHint.
  ///
  /// In en, this message translates to:
  /// **'Client reviews will appear here after your completed jobs.'**
  String get workerReviewsAppearHint;

  /// No description provided for @workerSelectMainSkill.
  ///
  /// In en, this message translates to:
  /// **'Select your main skill'**
  String get workerSelectMainSkill;

  /// No description provided for @workerSelectMainSkillHint.
  ///
  /// In en, this message translates to:
  /// **'Select your main skill to start receiving work'**
  String get workerSelectMainSkillHint;

  /// No description provided for @workerCategoriesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load categories: {error}'**
  String workerCategoriesLoadFailed(String error);

  /// No description provided for @workerSkillsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save skills. Please try again.'**
  String get workerSkillsSaveFailed;

  /// No description provided for @workerSaveAndGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Save & Go Online'**
  String get workerSaveAndGoOnline;

  /// No description provided for @workerDashboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dashboard'**
  String get workerDashboardLoadFailed;

  /// No description provided for @workerNewJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'New Jobs'**
  String get workerNewJobsTitle;

  /// No description provided for @workerNewJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Work matching your skills'**
  String get workerNewJobsSubtitle;

  /// No description provided for @workerCompleteProfileForNewJobs.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile. Once it is approved you will start seeing new jobs.'**
  String get workerCompleteProfileForNewJobs;

  /// No description provided for @workerNewJobsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load new jobs.'**
  String get workerNewJobsLoadFailed;

  /// No description provided for @workerOfferCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} offer} other{{count} offers}}'**
  String workerOfferCount(int count);

  /// No description provided for @workerDirectHireNote.
  ///
  /// In en, this message translates to:
  /// **'The client can hire you directly. No offer needed.'**
  String get workerDirectHireNote;

  /// No description provided for @workerListedJob.
  ///
  /// In en, this message translates to:
  /// **'Listed Job'**
  String get workerListedJob;

  /// No description provided for @workerOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent'**
  String get workerOfferSent;

  /// No description provided for @workerNoNewJobs.
  ///
  /// In en, this message translates to:
  /// **'No new jobs right now'**
  String get workerNoNewJobs;

  /// No description provided for @workerNoNewJobsHint.
  ///
  /// In en, this message translates to:
  /// **'New job requests matching your skills will appear here. Pull down to refresh.'**
  String get workerNoNewJobsHint;

  /// No description provided for @workerCompleteProfileForJobs.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile. Once it is approved you can manage your jobs.'**
  String get workerCompleteProfileForJobs;

  /// No description provided for @workerJobsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load jobs. Please try again.'**
  String get workerJobsLoadFailed;

  /// No description provided for @workerClientCancelledBooking.
  ///
  /// In en, this message translates to:
  /// **'The client cancelled this booking'**
  String get workerClientCancelledBooking;

  /// No description provided for @workerOnlyInspectionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Only the inspection was completed'**
  String get workerOnlyInspectionCompleted;

  /// No description provided for @workerComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get workerComplete;

  /// No description provided for @workerCompleting.
  ///
  /// In en, this message translates to:
  /// **'Completing...'**
  String get workerCompleting;

  /// No description provided for @workerMarkCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed?'**
  String get workerMarkCompletedTitle;

  /// No description provided for @workerMarkCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'This will close the job and notify the client.'**
  String get workerMarkCompletedBody;

  /// No description provided for @workerNoActiveJobs.
  ///
  /// In en, this message translates to:
  /// **'No active jobs'**
  String get workerNoActiveJobs;

  /// No description provided for @workerNoCompletedJobs.
  ///
  /// In en, this message translates to:
  /// **'No completed jobs yet'**
  String get workerNoCompletedJobs;

  /// No description provided for @workerNoCancelledJobs.
  ///
  /// In en, this message translates to:
  /// **'No cancelled jobs'**
  String get workerNoCancelledJobs;

  /// No description provided for @workerNoJobsAssigned.
  ///
  /// In en, this message translates to:
  /// **'No jobs assigned yet'**
  String get workerNoJobsAssigned;

  /// No description provided for @workerNoAppliedJobs.
  ///
  /// In en, this message translates to:
  /// **'No applied jobs yet'**
  String get workerNoAppliedJobs;

  /// No description provided for @workerNewRequestsHere.
  ///
  /// In en, this message translates to:
  /// **'New requests will appear here'**
  String get workerNewRequestsHere;

  /// No description provided for @workerCompletedJobsHere.
  ///
  /// In en, this message translates to:
  /// **'Completed jobs will show up here'**
  String get workerCompletedJobsHere;

  /// No description provided for @workerCancelledJobsHere.
  ///
  /// In en, this message translates to:
  /// **'Cancelled jobs will show up here'**
  String get workerCancelledJobsHere;

  /// No description provided for @workerAppliedJobsHere.
  ///
  /// In en, this message translates to:
  /// **'Jobs you\'ve placed an offer on will show up here'**
  String get workerAppliedJobsHere;

  /// No description provided for @workerAcceptToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Accept a booking request to get started'**
  String get workerAcceptToGetStarted;

  /// No description provided for @workerFilterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get workerFilterCancelled;

  /// No description provided for @workerFilterAllWork.
  ///
  /// In en, this message translates to:
  /// **'All New'**
  String get workerFilterAllWork;

  /// No description provided for @workerFilterMyOffers.
  ///
  /// In en, this message translates to:
  /// **'My Offers'**
  String get workerFilterMyOffers;

  /// No description provided for @workerFilterNoOfferSent.
  ///
  /// In en, this message translates to:
  /// **'No offer sent'**
  String get workerFilterNoOfferSent;

  /// No description provided for @bidPlaceABid.
  ///
  /// In en, this message translates to:
  /// **'Send an Offer'**
  String get bidPlaceABid;

  /// No description provided for @bidChatWithClient.
  ///
  /// In en, this message translates to:
  /// **'Chat with Client'**
  String get bidChatWithClient;

  /// No description provided for @bidLiveBids.
  ///
  /// In en, this message translates to:
  /// **'Live Offers'**
  String get bidLiveBids;

  /// No description provided for @bidAreaNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Area not available'**
  String get bidAreaNotAvailable;

  /// No description provided for @bidExactAddressAfterAccept.
  ///
  /// In en, this message translates to:
  /// **'The exact address is shared once the client accepts your offer.'**
  String get bidExactAddressAfterAccept;

  /// No description provided for @bidStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get bidStatusAccepted;

  /// No description provided for @bidStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get bidStatusRejected;

  /// No description provided for @bidStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get bidStatusPending;

  /// No description provided for @bidYourCurrentBid.
  ///
  /// In en, this message translates to:
  /// **'Your Current Offer'**
  String get bidYourCurrentBid;

  /// No description provided for @bidSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Offer'**
  String get bidSubmit;

  /// No description provided for @bidUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Offer'**
  String get bidUpdate;

  /// No description provided for @bidPlaceYourBid.
  ///
  /// In en, this message translates to:
  /// **'Send Your Offer'**
  String get bidPlaceYourBid;

  /// No description provided for @bidUpdateYourBid.
  ///
  /// In en, this message translates to:
  /// **'Update Your Offer'**
  String get bidUpdateYourBid;

  /// No description provided for @bidCanUpdateIn.
  ///
  /// In en, this message translates to:
  /// **'You can update your offer in {seconds}s.'**
  String bidCanUpdateIn(String seconds);

  /// No description provided for @bidCanUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'You can update your offer now.'**
  String get bidCanUpdateNow;

  /// No description provided for @bidAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Offer Amount (PKR) *'**
  String get bidAmountLabel;

  /// No description provided for @bidAmountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2500'**
  String get bidAmountHint;

  /// No description provided for @bidLabelWithCountdown.
  ///
  /// In en, this message translates to:
  /// **'{label} ({seconds}s)'**
  String bidLabelWithCountdown(String label, String seconds);

  /// No description provided for @bidJobCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} job} other{{count} jobs}}'**
  String bidJobCount(int count);

  /// No description provided for @bidBeFirstToBid.
  ///
  /// In en, this message translates to:
  /// **'Be the first to send an offer on this job'**
  String get bidBeFirstToBid;

  /// No description provided for @earningBidding.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get earningBidding;

  /// No description provided for @earningHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Earning History'**
  String get earningHistoryTitle;

  /// No description provided for @earningNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No earnings yet'**
  String get earningNoneYet;

  /// No description provided for @earningNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Completed jobs will show up here with your daily earnings.'**
  String get earningNoneHint;

  /// No description provided for @reviewsMyReviews.
  ///
  /// In en, this message translates to:
  /// **'My Reviews'**
  String get reviewsMyReviews;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @reviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews from clients for jobs you completed'**
  String get reviewsSubtitle;

  /// No description provided for @reviewsAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get reviewsAvg;

  /// No description provided for @reviewsMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get reviewsMax;

  /// No description provided for @reviewsMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get reviewsMin;

  /// No description provided for @reviewsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Once clients review your completed jobs,\ntheir reviews will appear here.'**
  String get reviewsEmptyHint;

  /// No description provided for @reviewsRatingSummary.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count, plural, =1{{count} review} other{{count} reviews}}'**
  String reviewsRatingSummary(String rating, int count);

  /// No description provided for @reviewsHighestLowest.
  ///
  /// In en, this message translates to:
  /// **'Highest: {max} ★  ·  Lowest: {min} ★'**
  String reviewsHighestLowest(String max, String min);

  /// No description provided for @inspFormChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get inspFormChooseFromGallery;

  /// No description provided for @inspFormSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Waiting for client decision.'**
  String get inspFormSubmitted;

  /// No description provided for @inspFormSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report.'**
  String get inspFormSubmitFailed;

  /// No description provided for @inspFormWhatWasIssue.
  ///
  /// In en, this message translates to:
  /// **'What was the issue?'**
  String get inspFormWhatWasIssue;

  /// No description provided for @inspFormWhatWasIssueRequired.
  ///
  /// In en, this message translates to:
  /// **'What was the issue? *'**
  String get inspFormWhatWasIssueRequired;

  /// No description provided for @inspFormRecommendedRepair.
  ///
  /// In en, this message translates to:
  /// **'Recommended Repair'**
  String get inspFormRecommendedRepair;

  /// No description provided for @inspFormRecommendedRepairRequired.
  ///
  /// In en, this message translates to:
  /// **'Recommended Repair *'**
  String get inspFormRecommendedRepairRequired;

  /// No description provided for @inspFormWhatWorkNeeded.
  ///
  /// In en, this message translates to:
  /// **'What work will be needed'**
  String get inspFormWhatWorkNeeded;

  /// No description provided for @inspFormWriteOrRecord.
  ///
  /// In en, this message translates to:
  /// **'Please write the report or record a voice note.'**
  String get inspFormWriteOrRecord;

  /// No description provided for @inspFormPartsRequired.
  ///
  /// In en, this message translates to:
  /// **'Parts required?'**
  String get inspFormPartsRequired;

  /// No description provided for @inspFormAddPart.
  ///
  /// In en, this message translates to:
  /// **'Add part'**
  String get inspFormAddPart;

  /// No description provided for @inspFormUstaadNotes.
  ///
  /// In en, this message translates to:
  /// **'Ustaad notes'**
  String get inspFormUstaadNotes;

  /// No description provided for @inspFormSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get inspFormSubmitReport;

  /// No description provided for @inspFormIssuePhotos.
  ///
  /// In en, this message translates to:
  /// **'Issue photos — optional, max {max}'**
  String inspFormIssuePhotos(int max);

  /// No description provided for @inspFormVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get inspFormVoiceNote;

  /// No description provided for @inspFormVoiceNoteHint.
  ///
  /// In en, this message translates to:
  /// **'If writing is difficult, record a voice note instead.'**
  String get inspFormVoiceNoteHint;

  /// No description provided for @inspFormRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording  {duration}'**
  String inspFormRecording(String duration);

  /// No description provided for @inspFormStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get inspFormStop;

  /// No description provided for @inspFormStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get inspFormStartRecording;

  /// No description provided for @inspFormPartNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. the part or material used'**
  String get inspFormPartNameHint;

  /// No description provided for @inspFormWarrantyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7 days'**
  String get inspFormWarrantyHint;

  /// No description provided for @inspFormRemovePart.
  ///
  /// In en, this message translates to:
  /// **'Remove part'**
  String get inspFormRemovePart;

  /// No description provided for @inspFormTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount for the work'**
  String get inspFormTotalAmount;

  /// No description provided for @inspFormFeeWaivedNote.
  ///
  /// In en, this message translates to:
  /// **'If the customer continues with the repair, the inspection fee will not be charged.'**
  String get inspFormFeeWaivedNote;

  /// No description provided for @inspHintElectrical.
  ///
  /// In en, this message translates to:
  /// **'e.g. switch is broken, wire is shorted...'**
  String get inspHintElectrical;

  /// No description provided for @inspHintPlumbing.
  ///
  /// In en, this message translates to:
  /// **'e.g. pipe is leaking, drain is blocked...'**
  String get inspHintPlumbing;

  /// No description provided for @inspHintAc.
  ///
  /// In en, this message translates to:
  /// **'e.g. AC is not cooling, gas leak...'**
  String get inspHintAc;

  /// No description provided for @inspHintCarpentry.
  ///
  /// In en, this message translates to:
  /// **'e.g. door does not close properly, hinge is broken...'**
  String get inspHintCarpentry;

  /// No description provided for @workerCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get workerCompleteProfile;

  /// No description provided for @workerApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Profile approval is required before you can receive jobs.'**
  String get workerApprovalRequired;

  /// No description provided for @workerCompleteProfileDetails.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile details.'**
  String get workerCompleteProfileDetails;

  /// No description provided for @workerCompleteProfileWhy.
  ///
  /// In en, this message translates to:
  /// **'You can only apply for or be hired for jobs once your profile is complete.'**
  String get workerCompleteProfileWhy;

  /// No description provided for @earningJobsCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} job completed} other{{count} jobs completed}}'**
  String earningJobsCompleted(int count);

  /// Booking badge: posted or work underway
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get bookingStatusLive;

  /// Booking badge: an Ustaad has taken the job
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get bookingStatusAssigned;

  /// No description provided for @bookingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingStatusCompleted;

  /// No description provided for @bookingStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get bookingStatusExpired;

  /// No description provided for @jobStatusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'En Route'**
  String get jobStatusEnRoute;

  /// No description provided for @jobStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get jobStatusInProgress;

  /// Intentionally left untranslated in app_ur.arb and app_ur_Latn.arb. Proves a missing key falls back to English rather than rendering blank or Urdu script on a Roman Urdu screen. Never shown in the UI; asserted by arb_parity_test.dart.
  ///
  /// In en, this message translates to:
  /// **'English fallback works'**
  String get l10nFallbackProbe;

  /// No description provided for @workerJobDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Details'**
  String get workerJobDetailsTitle;

  /// No description provided for @workerJobLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load job.'**
  String get workerJobLoadFailed;

  /// No description provided for @workerStandardDirectHireNote.
  ///
  /// In en, this message translates to:
  /// **'This is a Standard job. The client can hire you directly — you do not need to send an offer.'**
  String get workerStandardDirectHireNote;

  /// No description provided for @workerReportSubmittedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Waiting for the client to accept the quote or close after inspection.'**
  String get workerReportSubmittedWaiting;

  /// No description provided for @workerClientSection.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get workerClientSection;

  /// No description provided for @workerPostedBy.
  ///
  /// In en, this message translates to:
  /// **'Posted by'**
  String get workerPostedBy;

  /// No description provided for @workerCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get workerCategoryLabel;

  /// No description provided for @workerTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get workerTitleLabel;

  /// No description provided for @workerTimeSlotLabel.
  ///
  /// In en, this message translates to:
  /// **'Time Slot'**
  String get workerTimeSlotLabel;

  /// No description provided for @workerTimelineSection.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get workerTimelineSection;

  /// No description provided for @workerTimelineScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get workerTimelineScheduled;

  /// No description provided for @workerTimelineStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get workerTimelineStarted;

  /// No description provided for @workerEstimatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get workerEstimatedLabel;

  /// No description provided for @workerFeeStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get workerFeeStatusLabel;

  /// No description provided for @workerCancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel Job'**
  String get workerCancelJob;

  /// No description provided for @workerCancelJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this job?'**
  String get workerCancelJobTitle;

  /// No description provided for @workerCancelJobBody.
  ///
  /// In en, this message translates to:
  /// **'Please tell the client why you are cancelling.'**
  String get workerCancelJobBody;

  /// No description provided for @workerCancelOwnReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Write your own reason (required)'**
  String get workerCancelOwnReasonHint;

  /// No description provided for @workerKeepJob.
  ///
  /// In en, this message translates to:
  /// **'Keep Job'**
  String get workerKeepJob;

  /// No description provided for @workerYesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get workerYesCancel;

  /// No description provided for @workerCancelReasonEmergency.
  ///
  /// In en, this message translates to:
  /// **'An emergency came up'**
  String get workerCancelReasonEmergency;

  /// No description provided for @workerCancelReasonTooFar.
  ///
  /// In en, this message translates to:
  /// **'The location is too far'**
  String get workerCancelReasonTooFar;

  /// No description provided for @workerCancelReasonNoTools.
  ///
  /// In en, this message translates to:
  /// **'Required tools or parts are not available'**
  String get workerCancelReasonNoTools;

  /// No description provided for @workerCancelReasonSchedule.
  ///
  /// In en, this message translates to:
  /// **'Time or schedule issue'**
  String get workerCancelReasonSchedule;

  /// No description provided for @workerCancelReasonCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer or site related issue'**
  String get workerCancelReasonCustomer;

  /// No description provided for @workerCancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get workerCancelReasonOther;

  /// No description provided for @workerAttachmentsVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get workerAttachmentsVideos;

  /// No description provided for @workerAttachmentsVoiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Voice Notes'**
  String get workerAttachmentsVoiceNotes;

  /// No description provided for @workerStatusHistory.
  ///
  /// In en, this message translates to:
  /// **'Status History'**
  String get workerStatusHistory;

  /// No description provided for @workerMarkAsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get workerMarkAsCompleted;

  /// No description provided for @workerClientReview.
  ///
  /// In en, this message translates to:
  /// **'Client Review'**
  String get workerClientReview;

  /// Numeric rating shown next to the stars. Stays Latin digits in every language.
  ///
  /// In en, this message translates to:
  /// **'{rating}/5'**
  String workerReviewRatingOutOfFive(int rating);

  /// City comes from the backend and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Approximate area: {city}'**
  String workerApproximateArea(String city);

  /// No description provided for @workerApproximateAreaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Approximate area not available'**
  String get workerApproximateAreaUnavailable;

  /// {distance} is an already-formatted distance string such as "250 m away".
  ///
  /// In en, this message translates to:
  /// **'Distance: {distance}'**
  String workerDistanceLabel(String distance);

  /// No description provided for @workerExactAddressAfterHire.
  ///
  /// In en, this message translates to:
  /// **'The exact address and map become visible once you are hired for this job.'**
  String get workerExactAddressAfterHire;

  /// No description provided for @workerRoadRouteNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Road route is not configured yet. Opening Google Maps for navigation.'**
  String get workerRoadRouteNotConfigured;

  /// No description provided for @workerLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get workerLocationPermissionDenied;

  /// No description provided for @workerDirectionsLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to get your location for directions.'**
  String get workerDirectionsLocationFailed;

  /// No description provided for @workerArrivedAtJobLocation.
  ///
  /// In en, this message translates to:
  /// **'You have arrived at the job location.'**
  String get workerArrivedAtJobLocation;

  /// No description provided for @workerYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get workerYourLocation;

  /// No description provided for @workerCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get workerCityLabel;

  /// No description provided for @workerClientAddress.
  ///
  /// In en, this message translates to:
  /// **'Client Address'**
  String get workerClientAddress;

  /// No description provided for @workerPinnedJobLocation.
  ///
  /// In en, this message translates to:
  /// **'Pinned Job Location'**
  String get workerPinnedJobLocation;

  /// No description provided for @workerPinnedOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pinned on map'**
  String get workerPinnedOnMap;

  /// No description provided for @workerGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get workerGettingLocation;

  /// No description provided for @workerDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get workerDirections;

  /// No description provided for @workerOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get workerOpenInMaps;

  /// No description provided for @workerDirectionsActive.
  ///
  /// In en, this message translates to:
  /// **'Directions active'**
  String get workerDirectionsActive;

  /// No description provided for @workerUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get workerUploadFailed;

  /// No description provided for @workerCompleteHighlightedFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete the highlighted fields below.'**
  String get workerCompleteHighlightedFields;

  /// No description provided for @workerProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile. Please try again.'**
  String get workerProfileSaveFailed;

  /// No description provided for @workerProfileSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Profile submitted for approval.'**
  String get workerProfileSubmitted;

  /// No description provided for @workerCompleteAllRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete all required fields before submitting.'**
  String get workerCompleteAllRequired;

  /// No description provided for @workerProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile.'**
  String get workerProfileLoadFailed;

  /// No description provided for @workerFullLegalName.
  ///
  /// In en, this message translates to:
  /// **'Full Legal Name'**
  String get workerFullLegalName;

  /// No description provided for @workerLegalNameHint.
  ///
  /// In en, this message translates to:
  /// **'As written on your CNIC'**
  String get workerLegalNameHint;

  /// No description provided for @workerLegalNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full legal name is required.'**
  String get workerLegalNameRequired;

  /// No description provided for @workerCnicNumber.
  ///
  /// In en, this message translates to:
  /// **'CNIC Number'**
  String get workerCnicNumber;

  /// No description provided for @workerCnicInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter CNIC like 12345-1234567-1'**
  String get workerCnicInvalid;

  /// No description provided for @workerMainSkill.
  ///
  /// In en, this message translates to:
  /// **'Main Skill'**
  String get workerMainSkill;

  /// No description provided for @workerMainSkillNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get workerMainSkillNotSelected;

  /// No description provided for @workerChangeSkill.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get workerChangeSkill;

  /// No description provided for @workerMainSkillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select your main skill.'**
  String get workerMainSkillRequired;

  /// No description provided for @workerExperienceYears.
  ///
  /// In en, this message translates to:
  /// **'Experience in Years'**
  String get workerExperienceYears;

  /// No description provided for @workerExperienceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3'**
  String get workerExperienceHint;

  /// No description provided for @workerExperienceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number of years (0 or more).'**
  String get workerExperienceInvalid;

  /// No description provided for @workerResidentialAddress.
  ///
  /// In en, this message translates to:
  /// **'Residential Address'**
  String get workerResidentialAddress;

  /// No description provided for @workerResidentialAddressHint.
  ///
  /// In en, this message translates to:
  /// **'House #, street, area, city'**
  String get workerResidentialAddressHint;

  /// No description provided for @workerResidentialAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Residential address is required.'**
  String get workerResidentialAddressRequired;

  /// No description provided for @workerIdentityDocuments.
  ///
  /// In en, this message translates to:
  /// **'Identity Documents'**
  String get workerIdentityDocuments;

  /// No description provided for @workerCnicFront.
  ///
  /// In en, this message translates to:
  /// **'CNIC Front'**
  String get workerCnicFront;

  /// No description provided for @workerCnicBack.
  ///
  /// In en, this message translates to:
  /// **'CNIC Back'**
  String get workerCnicBack;

  /// No description provided for @workerLiveSelfie.
  ///
  /// In en, this message translates to:
  /// **'Live Selfie'**
  String get workerLiveSelfie;

  /// No description provided for @workerDocumentRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get workerDocumentRequired;

  /// No description provided for @workerAgreements.
  ///
  /// In en, this message translates to:
  /// **'Agreements'**
  String get workerAgreements;

  /// No description provided for @workerConfirmLegalName.
  ///
  /// In en, this message translates to:
  /// **'I confirm my legal name matches my CNIC.'**
  String get workerConfirmLegalName;

  /// No description provided for @workerViewAgreement.
  ///
  /// In en, this message translates to:
  /// **'View Agreement'**
  String get workerViewAgreement;

  /// No description provided for @workerConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'This confirmation is required.'**
  String get workerConfirmationRequired;

  /// No description provided for @workerSubmitForApproval.
  ///
  /// In en, this message translates to:
  /// **'Submit for Approval'**
  String get workerSubmitForApproval;

  /// {version} is the backend agreement version and stays Latin in every language.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String workerAgreementVersion(String version);

  /// No description provided for @workerOnboardingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted for Review'**
  String get workerOnboardingSubmitted;

  /// No description provided for @workerOnboardingChangesRequired.
  ///
  /// In en, this message translates to:
  /// **'Changes Required'**
  String get workerOnboardingChangesRequired;

  /// No description provided for @workerOnboardingApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get workerOnboardingApproved;

  /// No description provided for @workerOnboardingDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get workerOnboardingDraft;

  /// No description provided for @workerRoleBadge.
  ///
  /// In en, this message translates to:
  /// **'Ustaad'**
  String get workerRoleBadge;

  /// {skill} is the backend category name and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Main Skill: {skill}'**
  String workerMainSkillWithName(String skill);

  /// No description provided for @workerNoMainSkillYet.
  ///
  /// In en, this message translates to:
  /// **'No main skill selected yet'**
  String get workerNoMainSkillYet;

  /// No description provided for @workerProfileApproval.
  ///
  /// In en, this message translates to:
  /// **'Profile Approval'**
  String get workerProfileApproval;

  /// Issue-example hint shown when the booking's service category has no hint of its own.
  ///
  /// In en, this message translates to:
  /// **'e.g. describe what you found'**
  String get inspHintFallback;

  /// No description provided for @bidAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an offer amount.'**
  String get bidAmountRequired;

  /// No description provided for @bidAmountRange.
  ///
  /// In en, this message translates to:
  /// **'Offer amount must be between 100 and 500,000.'**
  String get bidAmountRange;

  /// No description provided for @bidSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Offer submitted!'**
  String get bidSubmitted;

  /// No description provided for @bidSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit offer.'**
  String get bidSubmitFailed;

  /// No description provided for @workerViewJobDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get workerViewJobDetails;

  /// No description provided for @workerSendOffer.
  ///
  /// In en, this message translates to:
  /// **'Send Offer'**
  String get workerSendOffer;

  /// No description provided for @workerChangeOffer.
  ///
  /// In en, this message translates to:
  /// **'Change Offer'**
  String get workerChangeOffer;

  /// No description provided for @workerOnboardingSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile is with the admin for review.'**
  String get workerOnboardingSubmittedBody;

  /// No description provided for @workerOnboardingChangesRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile needs changes — see the details.'**
  String get workerOnboardingChangesRequiredBody;

  /// No description provided for @workerOnboardingRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile was rejected — see the reason.'**
  String get workerOnboardingRejectedBody;

  /// No description provided for @workerProfileIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Profile Incomplete'**
  String get workerProfileIncomplete;

  /// No description provided for @inspFormLabourCostRequired.
  ///
  /// In en, this message translates to:
  /// **'Labour cost *'**
  String get inspFormLabourCostRequired;

  /// No description provided for @inspFormNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get inspFormNotesOptional;

  /// No description provided for @inspFormPartName.
  ///
  /// In en, this message translates to:
  /// **'Part name'**
  String get inspFormPartName;

  /// No description provided for @inspFormQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get inspFormQty;

  /// No description provided for @inspFormUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get inspFormUnitPrice;

  /// No description provided for @inspFormWarrantyOptional.
  ///
  /// In en, this message translates to:
  /// **'Warranty / guarantee (optional)'**
  String get inspFormWarrantyOptional;

  /// No description provided for @inspFormPartsTotal.
  ///
  /// In en, this message translates to:
  /// **'Parts total'**
  String get inspFormPartsTotal;

  /// No description provided for @inspFormLabour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get inspFormLabour;

  /// No description provided for @inspFormMicPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is permanently denied. Enable it in Settings.'**
  String get inspFormMicPermanentlyDenied;

  /// No description provided for @inspFormMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied.'**
  String get inspFormMicDenied;

  /// Request timed out (Dio connect/send/receive timeout)
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Please try again.'**
  String get errorTimeout;

  /// The app cancelled an in-flight request
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get errorRequestCancelled;

  /// HTTP 400 with no message from the backend
  ///
  /// In en, this message translates to:
  /// **'Some details are not correct. Please check them and try again.'**
  String get errorInvalidRequest;

  /// HTTP 401 - the refresh token is gone too
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errorSessionExpired;

  /// HTTP 403
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get errorForbidden;

  /// HTTP 404 - the booking/bid/profile is gone
  ///
  /// In en, this message translates to:
  /// **'This is no longer available.'**
  String get errorNotFound;

  /// HTTP 409 with no message from the backend
  ///
  /// In en, this message translates to:
  /// **'This has already been updated. Please refresh and try again.'**
  String get errorConflict;

  /// HTTP 429 - rate limited
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get errorTooManyRequests;

  /// HTTP 5xx
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServer;

  /// Backend SMS provider could not deliver the OTP
  ///
  /// In en, this message translates to:
  /// **'The SMS could not be sent. Please try again.'**
  String get errorSmsSendFailed;

  /// Backend code OTP_RESEND_TOO_SOON — fallback only; the backend's own message is shown when present, this covers the rare case it's empty
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before requesting the OTP again.'**
  String get errorOtpResendTooSoon;

  /// Backend code INSPECTOR_BUSY on a rehire attempt
  ///
  /// In en, this message translates to:
  /// **'The inspecting Ustaad is busy on another job right now. Please choose another Ustaad from the list below.'**
  String get errorInspectorBusy;

  /// Backend code PHONE_NOT_REGISTERED — login with a phone that either doesn't exist or belongs to the opposite role. Deliberately identical wording for both cases (role-privacy).
  ///
  /// In en, this message translates to:
  /// **'This number is not registered.'**
  String get errorPhoneNotRegistered;

  /// Backend code PHONE_ALREADY_REGISTERED — registration with a phone that already has an account, regardless of role.
  ///
  /// In en, this message translates to:
  /// **'This number is already registered.'**
  String get errorPhoneAlreadyRegistered;

  /// Last-resort wording when nothing more specific is known
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// A server-changing action (create/cancel booking, send message, etc.) was blocked client-side because the device has no network
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Connect to the internet to continue.'**
  String get errorOfflineActionBlocked;

  /// Small non-blocking banner shown when a screen is displaying cached data because the live fetch failed
  ///
  /// In en, this message translates to:
  /// **'Offline — showing saved data'**
  String get offlineCachedDataBanner;

  /// Forgot-password screen, step 1 heading
  ///
  /// In en, this message translates to:
  /// **'Forgot your\npassword?'**
  String get authForgotPasswordTitle;

  /// Forgot-password screen, step 2 heading
  ///
  /// In en, this message translates to:
  /// **'Set a new\npassword'**
  String get authSetNewPasswordTitle;

  /// Forgot-password screen, step 2 subtitle
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your number.'**
  String get authEnterCodeSentToNumber;

  /// Client forgot-password screen subtitle
  ///
  /// In en, this message translates to:
  /// **'For Client accounts only. A code will be sent to the registered number.'**
  String get authForgotPasswordClientOnly;

  /// Ustaad forgot-password screen subtitle
  ///
  /// In en, this message translates to:
  /// **'For Ustaad accounts only. A code will be sent to the registered number.'**
  String get authForgotPasswordWorkerOnly;

  /// Snackbar when an OTP request fails
  ///
  /// In en, this message translates to:
  /// **'The code could not be sent.'**
  String get authErrorCodeSendFailed;

  /// Snackbar when a password reset fails
  ///
  /// In en, this message translates to:
  /// **'The password could not be changed.'**
  String get authErrorPasswordChangeFailed;

  /// Snackbar when a login attempt fails
  ///
  /// In en, this message translates to:
  /// **'Could not log you in.'**
  String get authErrorLoginFailed;

  /// Snackbar when Ustaad registration fails
  ///
  /// In en, this message translates to:
  /// **'The account could not be created.'**
  String get authErrorRegisterFailed;

  /// Ustaad login button once the code has been sent
  ///
  /// In en, this message translates to:
  /// **'Log In With OTP'**
  String get authLoginWithOtp;

  /// Example name shown as the full-name field hint
  ///
  /// In en, this message translates to:
  /// **'Muhammad Ali Khan'**
  String get authHintExampleFullName;

  /// In-app banner title when the payload carries none
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationsBannerFallbackTitle;

  /// Shown above the Privacy Policy and Terms bodies, which are approved in English only
  ///
  /// In en, this message translates to:
  /// **'This legal document is currently available in English only.'**
  String get legalEnglishOnlyNotice;

  /// Pill above the bookings list showing how many there are
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String myBookingsTotalCount(int count);

  /// Heading on the bid screen when the job title was not passed through
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get workerBidJobFallbackTitle;

  /// Bottom-navigation tab: the home screen. Client and Ustaad share it.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom-navigation tab: the client's bookings list.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get navBookings;

  /// Row label above what the Ustaad found during the inspection
  ///
  /// In en, this message translates to:
  /// **'Issue found'**
  String get inspectionRowIssueFound;

  /// Row label above the Ustaad's free-text notes on the report
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get inspectionRowNotes;

  /// Status badge on the inspection report while the client has not decided
  ///
  /// In en, this message translates to:
  /// **'Report submitted — awaiting decision'**
  String get inspectionBadgeAwaitingDecision;

  /// Status badge on the inspection report once the repair quote was accepted
  ///
  /// In en, this message translates to:
  /// **'Quote accepted — repair in progress'**
  String get inspectionBadgeQuoteAccepted;

  /// Status badge on the inspection report after the client chose to re-open bidding
  ///
  /// In en, this message translates to:
  /// **'Finding another Ustaad — open for offers'**
  String get inspectionBadgeFindingAnother;

  /// Status strip when the job closed after inspection and the fee amount is known
  ///
  /// In en, this message translates to:
  /// **'Closed after inspection — client pays inspection fee only: {fee}'**
  String inspStripClosedFeeOnlyWithAmount(String fee);

  /// Same strip when no fee snapshot is available to show
  ///
  /// In en, this message translates to:
  /// **'Closed after inspection — client pays inspection fee only.'**
  String get inspStripClosedFeeOnly;

  /// Status strip once an inspection-lane repair finished
  ///
  /// In en, this message translates to:
  /// **'Repair completed — inspection fee waived.'**
  String get inspStripRepairCompletedFeeWaived;

  /// Status strip while the accepted repair is being carried out
  ///
  /// In en, this message translates to:
  /// **'Quote accepted — inspection fee waived. Repair in progress.'**
  String get inspStripQuoteAcceptedFeeWaived;

  /// Status strip once the Ustaad submitted the report and the client must decide
  ///
  /// In en, this message translates to:
  /// **'Inspection report submitted — review quote to continue repair or close after inspection.'**
  String get inspStripReportSubmitted;

  /// Status strip once an Ustaad is assigned to the inspection
  ///
  /// In en, this message translates to:
  /// **'Ustaad hired'**
  String get inspStripUstaadHired;

  /// Status strip while the inspection is still pending an Ustaad
  ///
  /// In en, this message translates to:
  /// **'Inspection booked — choose an Ustaad'**
  String get inspStripBookedChooseUstaad;

  /// Stat chip on an Ustaad card: their cancellation rate
  ///
  /// In en, this message translates to:
  /// **'{rate}% cancel'**
  String chooseChipCancelRate(int rate);

  /// Shown when the GPS button fails to resolve a position
  ///
  /// In en, this message translates to:
  /// **'Could not get current location.'**
  String get locationCurrentFailed;

  /// Shown when a search result cannot be turned into coordinates
  ///
  /// In en, this message translates to:
  /// **'Could not resolve selected location.'**
  String get locationResolveFailed;

  /// Shown when the picked point falls outside the serviceable area
  ///
  /// In en, this message translates to:
  /// **'Location is outside the Karachi service area.'**
  String get locationOutsideKarachi;

  /// Rejects an attached video that is longer than the allowed duration
  ///
  /// In en, this message translates to:
  /// **'Video must be {seconds} seconds or shorter.'**
  String postJobVideoTooLong(int seconds);

  /// Shown when reading the device location fails on the post-job form
  ///
  /// In en, this message translates to:
  /// **'Could not retrieve location. Please try again.'**
  String get postJobLocationRetrieveFailed;

  /// Validation: no booking lane was picked
  ///
  /// In en, this message translates to:
  /// **'Select an option to continue.'**
  String get postJobSelectOption;

  /// Validation: the job description is too short
  ///
  /// In en, this message translates to:
  /// **'Please describe what needs fixing.'**
  String get postJobDescribeIssue;

  /// Validation: the standard lane needs at least one service ticked
  ///
  /// In en, this message translates to:
  /// **'Please select at least one standard service.'**
  String get postJobSelectStandardService;

  /// Validation: no time slot was picked for a scheduled booking
  ///
  /// In en, this message translates to:
  /// **'Please select an arrival window.'**
  String get postJobSelectArrivalWindow;

  /// Validation: no window was picked for an urgent booking
  ///
  /// In en, this message translates to:
  /// **'Please select an urgency window.'**
  String get postJobSelectUrgencyWindow;

  /// Validation: the address field is empty on final submit
  ///
  /// In en, this message translates to:
  /// **'Enter your address.'**
  String get postJobEnterAddress;

  /// Validation: the address step cannot be left without an address
  ///
  /// In en, this message translates to:
  /// **'Add your service address to continue.'**
  String get postJobAddAddressToContinue;

  /// Note under the urgent option explaining what happens on submit
  ///
  /// In en, this message translates to:
  /// **'Nearby Ustaads are notified right away.'**
  String get postJobNearbyNotifiedNow;

  /// Shown when tapping the inspection lane on a category that does not offer it
  ///
  /// In en, this message translates to:
  /// **'Inspection is not available for this service.'**
  String get postJobInspectionNotAvailable;

  /// Inspection explainer, step 1
  ///
  /// In en, this message translates to:
  /// **'The Ustaad comes and checks it himself'**
  String get postJobInspectionHeroStep1;

  /// Inspection explainer, step 2
  ///
  /// In en, this message translates to:
  /// **'The rate is agreed before any work starts.'**
  String get postJobInspectionHeroStep2;

  /// Inspection explainer, step 3
  ///
  /// In en, this message translates to:
  /// **'Go ahead if you like the quote, otherwise just pay the inspection fee.'**
  String get postJobInspectionHeroStep3;

  /// Note under the standard-lane price summary
  ///
  /// In en, this message translates to:
  /// **'This price is final. It will not change at your door.'**
  String get postJobStandardTotalFinal;

  /// "How inspection works" card, step 1
  ///
  /// In en, this message translates to:
  /// **'The inspection fee is fixed.'**
  String get postJobHowInspectionStep1;

  /// "How inspection works" card, step 2
  ///
  /// In en, this message translates to:
  /// **'Ustaad visits, finds the problem, and gives you a fixed repair quote in the app.'**
  String get postJobHowInspectionStep2;

  /// "How inspection works" card, step 3
  ///
  /// In en, this message translates to:
  /// **'Accept his quote and continue, or get offers from other Ustaads — your choice.'**
  String get postJobHowInspectionStep3;

  /// Cancellation reason label. The stored value is fixed in ClientCancelReason.
  ///
  /// In en, this message translates to:
  /// **'I no longer need the service'**
  String get cancelReasonNoLongerNeeded;

  /// Cancellation reason label. The stored value is fixed in ClientCancelReason.
  ///
  /// In en, this message translates to:
  /// **'I booked it by mistake'**
  String get cancelReasonBookedByMistake;

  /// Cancellation reason label. The stored value is fixed in ClientCancelReason.
  ///
  /// In en, this message translates to:
  /// **'The problem sorted itself out'**
  String get cancelReasonProblemSolved;

  /// Cancellation reason label. The stored value is fixed in ClientCancelReason.
  ///
  /// In en, this message translates to:
  /// **'The time or date does not suit me'**
  String get cancelReasonTimingNotSuitable;

  /// Cancellation reason label. The stored value is fixed in ClientCancelReason.
  ///
  /// In en, this message translates to:
  /// **'The price or budget does not suit me'**
  String get cancelReasonPriceNotSuitable;

  /// Cancellation reason label, shown only when an Ustaad is assigned.
  ///
  /// In en, this message translates to:
  /// **'I cannot reach the Ustaad'**
  String get cancelReasonCannotReachUstaad;

  /// Cancellation reason label, shown only when an Ustaad is assigned.
  ///
  /// In en, this message translates to:
  /// **'The Ustaad is running very late'**
  String get cancelReasonUstaadRunningLate;

  /// Free-text cancellation reason sentinel; picking it reveals a text field.
  ///
  /// In en, this message translates to:
  /// **'Another reason'**
  String get cancelReasonOther;

  /// Booking details: the amount agreed with the hired Ustaad, matching the figure Track Worker shows
  ///
  /// In en, this message translates to:
  /// **'Agreed Price'**
  String get bookingAgreedPrice;

  /// Recommended-repair example for Electrician bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. replace the MCB and redo the socket wiring'**
  String get inspRepairHintElectrical;

  /// Recommended-repair example for Plumber bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. replace the leaking pipe and fit a new valve'**
  String get inspRepairHintPlumbing;

  /// Recommended-repair example for AC Technician bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. refill the gas and replace the capacitor'**
  String get inspRepairHintAc;

  /// Recommended-repair example for Carpenter bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. replace the hinges and straighten the door frame'**
  String get inspRepairHintCarpentry;

  /// Recommended-repair example for Painter bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. apply putty and primer, then two coats of emulsion'**
  String get inspRepairHintPainting;

  /// Trade-neutral recommended-repair example for a category with no tailored hint
  ///
  /// In en, this message translates to:
  /// **'e.g. what work is needed to fix it'**
  String get inspRepairHintFallback;

  /// Part-name example for Electrician bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. MCB, switch, socket'**
  String get inspPartHintElectrical;

  /// Part-name example for Plumber bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. pipe, valve, tap'**
  String get inspPartHintPlumbing;

  /// Part-name example for AC Technician bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. gas refill, capacitor, compressor'**
  String get inspPartHintAc;

  /// Part-name example for Carpenter bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. hinges, plywood, door frame'**
  String get inspPartHintCarpentry;

  /// Part-name example for Painter bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. primer, putty, emulsion'**
  String get inspPartHintPainting;

  /// Issue example for Painter bookings
  ///
  /// In en, this message translates to:
  /// **'e.g. paint is peeling, damp patch on the wall...'**
  String get inspHintPainting;

  /// No description provided for @agreementViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get agreementViewerTitle;

  /// No description provided for @agreementLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the agreement. Please try again.'**
  String get agreementLoadFailed;

  /// No description provided for @agreementUnavailableForTrade.
  ///
  /// In en, this message translates to:
  /// **'No approved agreement is available for your selected trade yet. Please contact HandyGo support.'**
  String get agreementUnavailableForTrade;

  /// {language} is a localized language name, e.g. Roman Urdu.
  ///
  /// In en, this message translates to:
  /// **'Agreement Language: {language}'**
  String agreementLanguageChip(String language);

  /// {trade} is a localized trade name, e.g. Electrician.
  ///
  /// In en, this message translates to:
  /// **'Trade: {trade}'**
  String agreementTradeChip(String trade);

  /// No description provided for @agreementLanguageNotice.
  ///
  /// In en, this message translates to:
  /// **'This approved legal agreement is currently available in Roman Urdu.'**
  String get agreementLanguageNotice;

  /// No description provided for @agreementLanguageRomanUrdu.
  ///
  /// In en, this message translates to:
  /// **'Roman Urdu'**
  String get agreementLanguageRomanUrdu;

  /// No description provided for @agreementLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get agreementLanguageEnglish;

  /// No description provided for @agreementLanguageUrdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get agreementLanguageUrdu;

  /// No description provided for @agreementAcceptCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept this agreement.'**
  String get agreementAcceptCheckbox;

  /// No description provided for @agreementViewBeforeAccepting.
  ///
  /// In en, this message translates to:
  /// **'Open and read the agreement before accepting it.'**
  String get agreementViewBeforeAccepting;

  /// No description provided for @agreementAcceptRequired.
  ///
  /// In en, this message translates to:
  /// **'This agreement must be accepted.'**
  String get agreementAcceptRequired;

  /// No description provided for @agreementTradeChangedReopen.
  ///
  /// In en, this message translates to:
  /// **'Your main trade changed. Open and accept the trade agreement again.'**
  String get agreementTradeChangedReopen;

  /// No description provided for @agreementsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Agreements could not be loaded.'**
  String get agreementsLoadFailed;

  /// No description provided for @agreementsAllThreeRequired.
  ///
  /// In en, this message translates to:
  /// **'Open and accept all three agreements before submitting.'**
  String get agreementsAllThreeRequired;

  /// No description provided for @workerFatherName.
  ///
  /// In en, this message translates to:
  /// **'Father\'s Name'**
  String get workerFatherName;

  /// No description provided for @workerFatherNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Father\'s name is required.'**
  String get workerFatherNameRequired;

  /// No description provided for @workerDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get workerDateOfBirth;

  /// No description provided for @workerDateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get workerDateOfBirthHint;

  /// No description provided for @workerDateOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required.'**
  String get workerDateOfBirthRequired;

  /// No description provided for @workerEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact (optional)'**
  String get workerEmergencyContact;

  /// No description provided for @workerEmergencyContactHint.
  ///
  /// In en, this message translates to:
  /// **'Name and phone number'**
  String get workerEmergencyContactHint;

  /// No description provided for @workerAcceptedAgreementsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Agreements'**
  String get workerAcceptedAgreementsTitle;

  /// No description provided for @workerAcceptedAgreementsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not accepted any agreements yet.'**
  String get workerAcceptedAgreementsEmpty;

  /// {date} is an already-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Accepted on {date}'**
  String agreementAcceptedOn(String date);

  /// {id} is the backend acceptance identifier and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Acceptance ID: {id}'**
  String agreementAcceptanceId(String id);

  /// No description provided for @agreementDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get agreementDownload;

  /// No description provided for @agreementDownloadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading agreement...'**
  String get agreementDownloadInProgress;

  /// {path} is a file system path and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Agreement saved to {path}'**
  String agreementDownloadSaved(String path);

  /// No description provided for @agreementDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the agreement. Please try again.'**
  String get agreementDownloadFailed;

  /// No description provided for @customerAgreementTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Terms, Booking Rules & Privacy Notice'**
  String get customerAgreementTitle;

  /// No description provided for @customerAgreementCheckboxLabel.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to these Terms and Privacy Notice.'**
  String get customerAgreementCheckboxLabel;

  /// No description provided for @customerAgreementIAgree.
  ///
  /// In en, this message translates to:
  /// **'I Agree'**
  String get customerAgreementIAgree;

  /// No description provided for @customerAgreementViewDownloadPdf.
  ///
  /// In en, this message translates to:
  /// **'View/Download PDF'**
  String get customerAgreementViewDownloadPdf;

  /// No description provided for @customerAgreementSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Acceptance could not be saved. Please try again.'**
  String get customerAgreementSaveFailed;

  /// No description provided for @customerAgreementEffectiveDateNote.
  ///
  /// In en, this message translates to:
  /// **'Effective from the date you accept below.'**
  String get customerAgreementEffectiveDateNote;

  /// No description provided for @customerAgreementHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Accepted Agreements'**
  String get customerAgreementHistoryTitle;

  /// No description provided for @customerAgreementHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No accepted agreements yet'**
  String get customerAgreementHistoryEmptyTitle;

  /// No description provided for @customerAgreementHistoryEmptyHelper.
  ///
  /// In en, this message translates to:
  /// **'Customer agreements you accept will appear here.'**
  String get customerAgreementHistoryEmptyHelper;

  /// No description provided for @clientStateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get clientStateLoading;

  /// No description provided for @clientStateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this'**
  String get clientStateErrorTitle;

  /// No description provided for @trackLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading live tracking…'**
  String get trackLoading;

  /// No description provided for @reportCheckingExisting.
  ///
  /// In en, this message translates to:
  /// **'Checking for an existing report…'**
  String get reportCheckingExisting;

  /// No description provided for @postJobInspectionReportsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No inspection reports yet'**
  String get postJobInspectionReportsEmptyTitle;

  /// No description provided for @postJobInspectionReportsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection reports unavailable'**
  String get postJobInspectionReportsErrorTitle;

  /// No description provided for @workerSubmittedDetails.
  ///
  /// In en, this message translates to:
  /// **'Submitted Details'**
  String get workerSubmittedDetails;

  /// No description provided for @workerViewSubmittedDetails.
  ///
  /// In en, this message translates to:
  /// **'View Submitted Details'**
  String get workerViewSubmittedDetails;

  /// No description provided for @workerDetailsReadOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Your profile is approved. These details are locked and cannot be changed.'**
  String get workerDetailsReadOnlyNotice;

  /// No description provided for @workerVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification Status'**
  String get workerVerificationStatus;

  /// No description provided for @workerMainTrade.
  ///
  /// In en, this message translates to:
  /// **'Main Trade'**
  String get workerMainTrade;

  /// Full-screen lock shown to a WorkerStatus.SUSPENDED Ustaad — the only content on that screen
  ///
  /// In en, this message translates to:
  /// **'Your HandyGo account has been suspended. Please contact Support for more information.'**
  String get workerSuspendedMessage;

  /// Button on the suspended-account screen that dials HandyGo Support
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get workerSuspendedContactSupport;

  /// Label for the pre-commission total on Worker Earning History
  ///
  /// In en, this message translates to:
  /// **'Labour Earnings'**
  String get earningGrossEarnings;

  /// Label for HandyGo's 18% platform commission line
  ///
  /// In en, this message translates to:
  /// **'HandyGo Commission (18%)'**
  String get earningCommissionLabel;

  /// Label for Gross - Commission, the amount the Ustaad actually keeps
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get earningUstaadEarnings;

  /// Label above the Pending/Paid chip on each earning history job
  ///
  /// In en, this message translates to:
  /// **'Commission Status'**
  String get earningCommissionStatusLabel;

  /// Commission settled by admin for this job
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get earningStatusPaid;

  /// Shown as a non-blocking recovery row in Profile/Settings when notification permission is denied or permanently denied
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. Allow notifications to receive booking and job updates.'**
  String get notificationsPermissionOffMessage;

  /// Button that (re)requests notification permission from the Profile/Settings recovery row
  ///
  /// In en, this message translates to:
  /// **'Allow Notifications'**
  String get notificationsAllowAction;

  /// Shown when location permission was denied but can still be requested again
  ///
  /// In en, this message translates to:
  /// **'Location permission is required.'**
  String get locationPermissionRequiredMessage;

  /// Button that (re)requests location permission
  ///
  /// In en, this message translates to:
  /// **'Allow Location'**
  String get locationAllowAction;

  /// Shown when location permission was permanently denied — the OS will not show the request dialog again
  ///
  /// In en, this message translates to:
  /// **'Allow location permission from Settings.'**
  String get locationPermanentlyDeniedMessage;

  /// Shown when location permission is granted but the device's location service itself is disabled
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s Location/GPS is off. Turn it on to continue.'**
  String get locationGpsOffMessage;

  /// Button that opens the location-services settings screen
  ///
  /// In en, this message translates to:
  /// **'Turn On Location'**
  String get locationTurnOnAction;

  /// Shown when a location fix could not be obtained (timeout/failure) despite permission and GPS both being available
  ///
  /// In en, this message translates to:
  /// **'Unable to get your location. Please try again.'**
  String get locationUnavailableRetryMessage;

  /// Shown when a cached worker location is too old to use for live job/discovery decisions
  ///
  /// In en, this message translates to:
  /// **'Your current location is required. Please update your location.'**
  String get locationStaleMessage;

  /// Shown when camera permission is denied or permanently denied
  ///
  /// In en, this message translates to:
  /// **'Allow camera permission to continue.'**
  String get cameraPermissionDeniedMessage;

  /// Shown when photo library/gallery permission is denied or permanently denied
  ///
  /// In en, this message translates to:
  /// **'Allow photo access to select files.'**
  String get galleryPermissionDeniedMessage;

  /// Shown when a picked file's type is not accepted by the upload target
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported. Select another file.'**
  String get unsupportedFileMessage;

  /// Shown when a picked file exceeds the upload size limit
  ///
  /// In en, this message translates to:
  /// **'The file is too large. Select a smaller file.'**
  String get fileTooLargeMessage;

  /// Button that reopens the file/photo picker after a failed selection
  ///
  /// In en, this message translates to:
  /// **'Choose Again'**
  String get commonChooseAgain;

  /// Title of the global screen shown for an unknown/invalid route
  ///
  /// In en, this message translates to:
  /// **'Page Not Available'**
  String get pageNotAvailableTitle;

  /// Body of the global screen shown for an unknown/invalid route
  ///
  /// In en, this message translates to:
  /// **'This page is no longer available.'**
  String get pageNotAvailableBody;

  /// Button that navigates back to the caller's role-appropriate home screen
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get commonGoHome;

  /// Shown on the booking detail screen when the booking has been deleted, or is otherwise no longer accessible to this account (404/403 from the API)
  ///
  /// In en, this message translates to:
  /// **'This booking is no longer available.'**
  String get resourceBookingUnavailable;

  /// Shown on the worker job detail screen when the job is no longer assigned to this worker (404/403 from the API)
  ///
  /// In en, this message translates to:
  /// **'This job is no longer assigned to you.'**
  String get resourceJobUnavailable;

  /// Shown on the chat detail screen when the conversation has been deleted, or is otherwise no longer accessible to this account (404/403 from the API)
  ///
  /// In en, this message translates to:
  /// **'This conversation is no longer available.'**
  String get resourceConversationUnavailable;

  /// Safe-navigation button on the client's booking-unavailable state
  ///
  /// In en, this message translates to:
  /// **'Go to My Bookings'**
  String get goToMyBookingsAction;

  /// Safe-navigation button on the worker's job-unavailable state
  ///
  /// In en, this message translates to:
  /// **'Go to My Jobs'**
  String get goToMyJobsAction;

  /// Safe-navigation button on the chat-unavailable state
  ///
  /// In en, this message translates to:
  /// **'Go to Chats'**
  String get goToChatsAction;

  /// Profile/Settings menu row that opens HandyGo Support (chat and/or phone)
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupportTitle;

  /// Profile/Settings menu row that opens the About HandyGo page, and that page's title
  ///
  /// In en, this message translates to:
  /// **'About HandyGo'**
  String get settingsAboutTitle;

  /// Profile/Settings menu row label showing the running app version
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersionTitle;

  /// Short factual description shown on the About HandyGo page
  ///
  /// In en, this message translates to:
  /// **'HandyGo connects clients with nearby verified Ustaads for home repair and maintenance services.'**
  String get aboutAppDescription;

  /// Label above the official HandyGo website link on the About page
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsiteLabel;

  /// No description provided for @cashPaymentLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get cashPaymentLater;

  /// No description provided for @cashPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm cash payment'**
  String get cashPaymentTitle;

  /// No description provided for @cashPaymentQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much cash did you pay?'**
  String get cashPaymentQuestion;

  /// No description provided for @cashPaymentExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected booking amount: {amount}'**
  String cashPaymentExpected(Object amount);

  /// No description provided for @cashPaymentInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash paid (PKR)'**
  String get cashPaymentInputLabel;

  /// No description provided for @cashPaymentInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter whole rupees, including 0'**
  String get cashPaymentInputHint;

  /// No description provided for @cashPaymentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the actual cash amount paid.'**
  String get cashPaymentRequired;

  /// No description provided for @cashPaymentWholeRupees.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole PKR amount without decimals.'**
  String get cashPaymentWholeRupees;

  /// No description provided for @cashPaymentConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash payment confirmed'**
  String get cashPaymentConfirmedTitle;

  /// No description provided for @cashPaymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Cash paid: {amount}'**
  String cashPaymentPaid(Object amount);

  /// No description provided for @cashPaymentExpectedReceipt.
  ///
  /// In en, this message translates to:
  /// **'Expected amount: {amount}'**
  String cashPaymentExpectedReceipt(Object amount);

  /// No description provided for @cashPaymentShortfall.
  ///
  /// In en, this message translates to:
  /// **'Remaining amount: {amount}'**
  String cashPaymentShortfall(Object amount);

  /// No description provided for @cashPaymentReference.
  ///
  /// In en, this message translates to:
  /// **'Confirmation reference: {reference}'**
  String cashPaymentReference(Object reference);

  /// No description provided for @cashPaymentContinueReview.
  ///
  /// In en, this message translates to:
  /// **'Continue to review'**
  String get cashPaymentContinueReview;

  /// No description provided for @cashPaymentConflict.
  ///
  /// In en, this message translates to:
  /// **'Payment was already confirmed with a different amount. Please contact HandyGo support if it needs correction.'**
  String get cashPaymentConflict;

  /// No description provided for @cashPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Cash payment could not be confirmed. Please try again.'**
  String get cashPaymentFailed;

  /// No description provided for @cashPaymentReviewBlocked.
  ///
  /// In en, this message translates to:
  /// **'Confirm the cash payment before reviewing the Ustaad.'**
  String get cashPaymentReviewBlocked;

  /// No description provided for @postJobSelectBookingTypeFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose Normal or Urgent first.'**
  String get postJobSelectBookingTypeFirst;

  /// No description provided for @postJobInspectionDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem you observe before continuing.'**
  String get postJobInspectionDescriptionRequired;

  /// No description provided for @postJobCustomVoiceRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a voice note before continuing with Custom Kaam.'**
  String get postJobCustomVoiceRequired;

  /// No description provided for @postJobCompleteAddressBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Add a complete address and map pin before saving it.'**
  String get postJobCompleteAddressBeforeSaving;

  /// No description provided for @postJobDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get postJobDay;

  /// No description provided for @postJobTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get postJobTomorrow;

  /// No description provided for @postJobCustomVoiceAndPhotos.
  ///
  /// In en, this message translates to:
  /// **'Voice note (required) & photos/video (optional)'**
  String get postJobCustomVoiceAndPhotos;

  /// No description provided for @postJobInspectionVoiceAndPhotos.
  ///
  /// In en, this message translates to:
  /// **'Voice note & photos/video (optional)'**
  String get postJobInspectionVoiceAndPhotos;

  /// No description provided for @postJobInspectionRateNote.
  ///
  /// In en, this message translates to:
  /// **'You only pay the visit fee now. The repair quote appears in the app before work starts.'**
  String get postJobInspectionRateNote;

  /// No description provided for @postJobBiddingRateNote.
  ///
  /// In en, this message translates to:
  /// **'Ustaads will send a complete repair quote. The quote you accept is final and cannot change at the door.'**
  String get postJobBiddingRateNote;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get savedAddresses;

  /// No description provided for @savedAddressForNextTime.
  ///
  /// In en, this message translates to:
  /// **'Save this address for next time'**
  String get savedAddressForNextTime;

  /// No description provided for @savedAddressOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get savedAddressOffice;

  /// No description provided for @savedAddressName.
  ///
  /// In en, this message translates to:
  /// **'Saved address name'**
  String get savedAddressName;

  /// No description provided for @savedAddressNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get savedAddressNameRequired;

  /// No description provided for @savedAddressCustomNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this saved address'**
  String get savedAddressCustomNameTitle;

  /// No description provided for @savedAddressRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename saved address'**
  String get savedAddressRenameTitle;

  /// No description provided for @savedAddressRenameConflict.
  ///
  /// In en, this message translates to:
  /// **'That name is already used. Choose another name.'**
  String get savedAddressRenameConflict;

  /// No description provided for @savedAddressSaved.
  ///
  /// In en, this message translates to:
  /// **'Address saved.'**
  String get savedAddressSaved;

  /// No description provided for @savedAddressUse.
  ///
  /// In en, this message translates to:
  /// **'Use address'**
  String get savedAddressUse;

  /// No description provided for @savedAddressUpdateWithCurrent.
  ///
  /// In en, this message translates to:
  /// **'Update with current address and pin'**
  String get savedAddressUpdateWithCurrent;

  /// No description provided for @savedAddressRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get savedAddressRename;

  /// No description provided for @savedAddressDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete saved address?'**
  String get savedAddressDeleteTitle;

  /// No description provided for @savedAddressDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from your saved addresses?'**
  String savedAddressDeleteBody(String name);

  /// No description provided for @savedAddressUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update {name}?'**
  String savedAddressUpdateTitle(String name);

  /// No description provided for @savedAddressUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is already saved. Update it with this address?'**
  String savedAddressUpdateBody(String name);

  /// No description provided for @savedAddressUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update address'**
  String get savedAddressUpdateAction;

  /// No description provided for @postJobAddressIntro.
  ///
  /// In en, this message translates to:
  /// **'First booking? Add the address once — you can save it for next time.'**
  String get postJobAddressIntro;

  /// No description provided for @postJobCompleteAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter your complete service address'**
  String get postJobCompleteAddressLabel;

  /// No description provided for @postJobAddressLandmarkHelper.
  ///
  /// In en, this message translates to:
  /// **'Include building/house, apartment/flat, floor/unit, and a nearby landmark.'**
  String get postJobAddressLandmarkHelper;

  /// No description provided for @postJobAddressResolving.
  ///
  /// In en, this message translates to:
  /// **'Finding this address on the map…'**
  String get postJobAddressResolving;

  /// No description provided for @postJobAddressUnresolved.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find this address. Add more detail or choose it on the map.'**
  String get postJobAddressUnresolved;

  /// No description provided for @postJobAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an address before continuing.'**
  String get postJobAddressRequired;

  /// No description provided for @postJobMapPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'MAP — TAP TO PLACE THE PIN'**
  String get postJobMapPreviewEmpty;

  /// No description provided for @postJobLanePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a booking option'**
  String get postJobLanePageTitle;

  /// No description provided for @postJobLaneStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Step 2 / 4 · {service}'**
  String postJobLaneStepIndicator(String service);

  /// No description provided for @postJobLaneFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixed-price services'**
  String get postJobLaneFixedTitle;

  /// No description provided for @postJobLaneFixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Service and price are fixed in advance'**
  String get postJobLaneFixedSubtitle;

  /// No description provided for @postJobLaneFixedBody.
  ///
  /// In en, this message translates to:
  /// **'See the final price before booking.'**
  String get postJobLaneFixedBody;

  /// No description provided for @postJobLaneFixedAction.
  ///
  /// In en, this message translates to:
  /// **'View services and prices →'**
  String get postJobLaneFixedAction;

  /// No description provided for @postJobLaneFixedCta.
  ///
  /// In en, this message translates to:
  /// **'View services and prices'**
  String get postJobLaneFixedCta;

  /// No description provided for @postJobFixedPricePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixed Price Services'**
  String get postJobFixedPricePageTitle;

  /// Fixed-price booking page subtitle with the selected service category
  ///
  /// In en, this message translates to:
  /// **'Step 3 / 4 · {service}'**
  String postJobFixedPriceStepIndicator(String service);

  /// No description provided for @postJobLaneInspectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get postJobLaneInspectionTitle;

  /// No description provided for @postJobLaneInspectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not sure what the problem is?'**
  String get postJobLaneInspectionSubtitle;

  /// No description provided for @postJobLaneInspectionFeeBody.
  ///
  /// In en, this message translates to:
  /// **'{fee} inspection fee — paid after inspection, not now.'**
  String postJobLaneInspectionFeeBody(String fee);

  /// No description provided for @postJobLaneInspectionReportBody.
  ///
  /// In en, this message translates to:
  /// **'The Ustaad checks the issue and sends the report and final quote in the app.'**
  String get postJobLaneInspectionReportBody;

  /// No description provided for @postJobLaneInspectionWaiverBody.
  ///
  /// In en, this message translates to:
  /// **'If you proceed with the repair, the {fee} inspection fee is waived and you only pay the repair price.'**
  String postJobLaneInspectionWaiverBody(String fee);

  /// No description provided for @postJobLaneInspectionAction.
  ///
  /// In en, this message translates to:
  /// **'Book inspection →'**
  String get postJobLaneInspectionAction;

  /// No description provided for @postJobLaneInspectionCta.
  ///
  /// In en, this message translates to:
  /// **'Book inspection'**
  String get postJobLaneInspectionCta;

  /// No description provided for @postJobLaneCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Work'**
  String get postJobLaneCustomTitle;

  /// No description provided for @postJobLaneCustomBody.
  ///
  /// In en, this message translates to:
  /// **'Send details and photos for a small repair, fitting, or replacement.'**
  String get postJobLaneCustomBody;

  /// No description provided for @postJobLaneCustomRatesBody.
  ///
  /// In en, this message translates to:
  /// **'Nearby Ustaads will send their prices.'**
  String get postJobLaneCustomRatesBody;

  /// No description provided for @postJobLaneCustomAction.
  ///
  /// In en, this message translates to:
  /// **'Add job details →'**
  String get postJobLaneCustomAction;

  /// No description provided for @postJobLaneCustomCta.
  ///
  /// In en, this message translates to:
  /// **'Add job details'**
  String get postJobLaneCustomCta;

  /// No description provided for @postJobLanePriceNote.
  ///
  /// In en, this message translates to:
  /// **'The price can only change after a new quote is sent through the app — not after the Ustaad reaches your home.'**
  String get postJobLanePriceNote;

  /// No description provided for @postJobLaneChooseCta.
  ///
  /// In en, this message translates to:
  /// **'Choose a booking option'**
  String get postJobLaneChooseCta;

  /// No description provided for @postJobCustomRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Your request'**
  String get postJobCustomRequestTitle;

  /// No description provided for @postJobCustomRequestStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Step 3 / 4 · {service}'**
  String postJobCustomRequestStepIndicator(String service);

  /// No description provided for @postJobCustomWorkTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'WHAT NEEDS TO BE DONE?'**
  String get postJobCustomWorkTitleLabel;

  /// No description provided for @postJobCustomRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get postJobCustomRequired;

  /// No description provided for @postJobCustomWorkTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Install a ceiling fan'**
  String get postJobCustomWorkTitleHint;

  /// No description provided for @postJobCustomDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tell us the details'**
  String get postJobCustomDetailsLabel;

  /// No description provided for @postJobCustomOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get postJobCustomOptional;

  /// No description provided for @postJobCustomDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add anything else that may help'**
  String get postJobCustomDetailsHint;

  /// No description provided for @postJobCustomVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get postJobCustomVoiceLabel;

  /// No description provided for @postJobCustomAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get postJobCustomAddPhotos;

  /// No description provided for @postJobCustomMediaAttached.
  ///
  /// In en, this message translates to:
  /// **'{count} / 4 photos · Voice note attached'**
  String postJobCustomMediaAttached(int count);

  /// No description provided for @postJobCustomMediaPending.
  ///
  /// In en, this message translates to:
  /// **'{count} / 4 photos · Voice note not attached'**
  String postJobCustomMediaPending(int count);

  /// No description provided for @postJobCustomHelperNote.
  ///
  /// In en, this message translates to:
  /// **'Photos and a voice note help the Ustaad understand best. No technical details needed.'**
  String get postJobCustomHelperNote;

  /// No description provided for @postJobCustomReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous inspection report'**
  String get postJobCustomReportLabel;

  /// No description provided for @postJobCustomAttachReport.
  ///
  /// In en, this message translates to:
  /// **'Attach report'**
  String get postJobCustomAttachReport;

  /// No description provided for @postJobInspectionReportAttached.
  ///
  /// In en, this message translates to:
  /// **'Report attached'**
  String get postJobInspectionReportAttached;

  /// Runtime app version/build shown on the About page and Settings row
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersionValue(String version, String build);

  /// No description provided for @reportProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblemTitle;

  /// No description provided for @reportProblemHelper.
  ///
  /// In en, this message translates to:
  /// **'Select the issue you experienced.'**
  String get reportProblemHelper;

  /// No description provided for @reportProblemAction.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblemAction;

  /// No description provided for @reportIssueWorkQuality.
  ///
  /// In en, this message translates to:
  /// **'Work quality issue'**
  String get reportIssueWorkQuality;

  /// No description provided for @reportIssuePricePayment.
  ///
  /// In en, this message translates to:
  /// **'Price / payment issue'**
  String get reportIssuePricePayment;

  /// No description provided for @reportIssueUstaadBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Ustaad behaviour'**
  String get reportIssueUstaadBehaviour;

  /// No description provided for @reportIssueDamage.
  ///
  /// In en, this message translates to:
  /// **'Something was damaged'**
  String get reportIssueDamage;

  /// No description provided for @reportIssuePartMaterial.
  ///
  /// In en, this message translates to:
  /// **'Part / material issue'**
  String get reportIssuePartMaterial;

  /// No description provided for @reportIssueWarrantyRework.
  ///
  /// In en, this message translates to:
  /// **'Warranty / rework needed'**
  String get reportIssueWarrantyRework;

  /// No description provided for @reportIssueOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportIssueOther;

  /// No description provided for @reportOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened'**
  String get reportOtherLabel;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSelectAtLeastOneError.
  ///
  /// In en, this message translates to:
  /// **'Select at least one issue.'**
  String get reportSelectAtLeastOneError;

  /// No description provided for @reportOtherRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Tell us what the other issue is.'**
  String get reportOtherRequiredError;

  /// No description provided for @reportSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get reportSubmittedTitle;

  /// No description provided for @reportSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'The HandyGo team will review it.'**
  String get reportSubmittedBody;

  /// No description provided for @reportYourReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Your report'**
  String get reportYourReportTitle;

  /// No description provided for @reportSubmittedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get reportSubmittedAtLabel;

  /// No description provided for @reportReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reportReferenceLabel;

  /// No description provided for @reportLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load the report right now.'**
  String get reportLookupFailed;

  /// No description provided for @reportActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get reportActionFailed;

  /// No description provided for @reportTalkToSupport.
  ///
  /// In en, this message translates to:
  /// **'Talk to support'**
  String get reportTalkToSupport;

  /// No description provided for @reportHumanRequestedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'The support team has been notified.'**
  String get reportHumanRequestedConfirmation;

  /// No description provided for @reportStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get reportStatusPending;

  /// No description provided for @reportStatusInReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get reportStatusInReview;

  /// No description provided for @reportStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get reportStatusResolved;

  /// No description provided for @reportAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A report already exists for this booking.'**
  String get reportAlreadyExists;

  /// No description provided for @reportBackToBooking.
  ///
  /// In en, this message translates to:
  /// **'Back to booking'**
  String get reportBackToBooking;

  /// No description provided for @bookingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get bookingSchedule;

  /// No description provided for @bookingPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get bookingPrice;

  /// No description provided for @bookingPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get bookingPaymentTitle;

  /// No description provided for @bookingPaymentUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get bookingPaymentUnpaid;

  /// No description provided for @bookingPaymentPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get bookingPaymentPartial;

  /// No description provided for @bookingStatusSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get bookingStatusSectionLabel;

  /// No description provided for @bookingHireNewUstaad.
  ///
  /// In en, this message translates to:
  /// **'Hire New Ustaad'**
  String get bookingHireNewUstaad;

  /// No description provided for @bookingJobClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Job completed'**
  String get bookingJobClosedTitle;

  /// No description provided for @bookingJobClosedBody.
  ///
  /// In en, this message translates to:
  /// **'This job is closed. You can still review your Ustaad or report a problem.'**
  String get bookingJobClosedBody;

  /// No description provided for @bookingReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get bookingReportLabel;

  /// No description provided for @bookingPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get bookingPaymentReceived;

  /// No description provided for @bookingPaymentRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get bookingPaymentRemaining;

  /// No description provided for @bookingPaymentExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get bookingPaymentExpected;

  /// No description provided for @timelineStepWorkConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Work confirmed'**
  String get timelineStepWorkConfirmed;

  /// No description provided for @timelineStepInspectionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Inspection confirmed'**
  String get timelineStepInspectionConfirmed;

  /// No description provided for @timelineStepUstaadHired.
  ///
  /// In en, this message translates to:
  /// **'Ustaad hired'**
  String get timelineStepUstaadHired;

  /// No description provided for @timelineStepWorkStarted.
  ///
  /// In en, this message translates to:
  /// **'Work started'**
  String get timelineStepWorkStarted;

  /// No description provided for @timelineStepInspectionStarted.
  ///
  /// In en, this message translates to:
  /// **'Inspection started'**
  String get timelineStepInspectionStarted;

  /// No description provided for @timelineStepWorkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Work completed'**
  String get timelineStepWorkCompleted;

  /// No description provided for @timelineStepInspectionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Inspection completed'**
  String get timelineStepInspectionCompleted;

  /// No description provided for @timelineWaitingForUstaadTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an Ustaad'**
  String get timelineWaitingForUstaadTitle;

  /// No description provided for @timelineWaitingForUstaadBody.
  ///
  /// In en, this message translates to:
  /// **'Work starts once you hire an Ustaad for this job.'**
  String get timelineWaitingForUstaadBody;

  /// Ustaad registration step 3 identity section heading
  ///
  /// In en, this message translates to:
  /// **'Identity details'**
  String get ustaadIdentityTitle;

  /// Ustaad registration step 4 live selfie card subtitle
  ///
  /// In en, this message translates to:
  /// **'Take it now — your face must be clearly visible'**
  String get ustaadLiveSelfieSubtitle;

  /// No description provided for @reportDetailsHelper.
  ///
  /// In en, this message translates to:
  /// **'A short description helps our team act on your report.'**
  String get reportDetailsHelper;

  /// No description provided for @reportDetailsRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please describe the problem in at least 10 characters.'**
  String get reportDetailsRequiredError;

  /// No description provided for @workerPaymentPartsLabel.
  ///
  /// In en, this message translates to:
  /// **'Parts recovered'**
  String get workerPaymentPartsLabel;

  /// No description provided for @workerPaymentLabourLabel.
  ///
  /// In en, this message translates to:
  /// **'Labour received'**
  String get workerPaymentLabourLabel;

  /// No description provided for @workerPaymentAwaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment not recorded yet'**
  String get workerPaymentAwaitingTitle;

  /// No description provided for @workerPaymentAwaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Once the cash is recorded you will see exactly what came in.'**
  String get workerPaymentAwaitingBody;

  /// No description provided for @workerReportPaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Kam paisa mila?'**
  String get workerReportPaymentAction;

  /// No description provided for @workerReportPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'How much did you actually receive?'**
  String get workerReportPaymentTitle;

  /// No description provided for @workerReportPaymentHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter the cash the customer handed you. HandyGo works out the rest.'**
  String get workerReportPaymentHelper;

  /// No description provided for @workerReportPaymentFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get workerReportPaymentFieldLabel;

  /// No description provided for @workerReportPaymentInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole rupee amount of 0 or more.'**
  String get workerReportPaymentInvalidError;

  /// No description provided for @workerReportPaymentSubmit.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get workerReportPaymentSubmit;

  /// No description provided for @workerReportPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded. HandyGo will follow up on anything still owed.'**
  String get workerReportPaymentSuccess;

  /// No description provided for @workerReportPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not record the payment. Please try again.'**
  String get workerReportPaymentFailed;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'ur':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsUrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
