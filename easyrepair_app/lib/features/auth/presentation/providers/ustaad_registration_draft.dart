import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything the four Ustaad registration steps collect, in one place.
///
/// ## Why a provider and not route `extra`
///
/// The steps are a single conversation: Step 3 needs the phone Step 1 typed,
/// Step 4 needs the account Step 3 created, and going back must not lose what
/// was already entered. Threading that through route arguments would mean
/// every screen re-passing every field, and a back-navigation would drop
/// whatever the previous screen had not yet handed on.
///
/// ## Lifecycle
///
/// The provider is `autoDispose`, and every step keeps it alive while it is on
/// screen. Leaving the flow entirely therefore clears the draft — including
/// [registrationToken] and, importantly, the password. Nothing here is ever
/// persisted to disk.
///
/// ## What is deliberately NOT here
///
/// The OTP itself. It is verified and consumed at Step 2 in exchange for
/// [registrationToken]; keeping the code afterwards would serve no purpose and
/// would leave a live credential sitting in memory for the rest of the flow.
class UstaadRegistrationDraft {
  const UstaadRegistrationDraft({
    this.fullName = '',
    this.phone = '',
    this.cnicNumber = '',
    this.password = '',
    this.registrationToken,
    this.registrationTokenExpiresAt,
    this.photo,
    this.categoryId,
    this.experienceYears,
    this.fatherName = '',
    this.dateOfBirth,
    this.legalNameConfirmed = false,
    this.area = '',
    this.street = '',
    this.house = '',
    this.landmark = '',
    this.accountCreated = false,
  });

  // ── Step 1 ──────────────────────────────────────────────────────────────
  final String fullName;
  final String phone;
  final String cnicNumber;

  /// Held only until the account is created at the end of Step 3, then never
  /// read again. Cleared with the rest of the draft when the flow ends.
  final String password;

  // ── Step 2 ──────────────────────────────────────────────────────────────
  /// Proof that the number was verified, issued by `/auth/worker/otp-verify`
  /// in exchange for the code. Authorises finishing this registration and
  /// nothing else — it cannot authenticate the app.
  final String? registrationToken;
  final DateTime? registrationTokenExpiresAt;

  // ── Step 3 ──────────────────────────────────────────────────────────────
  final File? photo;

  /// The ONE trade selected from the live category list.
  ///
  /// Singular by type, because the backend is singular: `updateSkills` throws
  /// "Only one main skill is allowed." for anything longer, `UpdateSkillsDto`
  /// carries `@ArrayMaxSize(1)`, and `profileCompleted` — the flag every
  /// discovery query filters on — is literally defined as "has exactly one
  /// WorkerSkill". This used to be a list, and picking a second trade sent the
  /// one request the backend rejects.
  final String? categoryId;

  /// Lower bound of the selected experience band — see [experienceBands].
  final int? experienceYears;

  /// Father's name as per CNIC. Required: the Background Verification / EVS
  /// Consent document has a blank for it that cannot be generated without it,
  /// and `submitProfileForReview` refuses the whole submission when it is
  /// absent.
  final String fatherName;

  /// Date of birth as the ISO calendar date (yyyy-MM-dd) the backend stores
  /// and the legal document prints — the same representation the legacy
  /// profile-completion form uses, so no timezone can shift it by a day.
  final String? dateOfBirth;

  /// "I confirm my legal name matches my CNIC." Sent as `legalNameConfirmed`,
  /// which is what makes the backend stamp `legalNameConfirmedAt`.
  final bool legalNameConfirmed;

  final String area;
  final String street;
  final String house;
  final String landmark;

  /// True once Step 3 has created the Worker account, so a return trip to
  /// Step 3 edits the profile instead of trying to register a second time.
  final bool accountCreated;

  bool get isPhoneVerified => registrationToken != null;

  /// The single free-text address the backend stores, composed from the four
  /// fields the design collects. The backend model has one
  /// `residentialAddress` column; splitting it in the UI is a presentation
  /// choice, so the pieces are joined here rather than a column being added.
  String get residentialAddress => [
        if (house.trim().isNotEmpty) house.trim(),
        if (street.trim().isNotEmpty) 'Street ${street.trim()}',
        if (area.trim().isNotEmpty) area.trim(),
        if (landmark.trim().isNotEmpty) '(${landmark.trim()})',
      ].join(', ');

  UstaadRegistrationDraft copyWith({
    String? fullName,
    String? phone,
    String? cnicNumber,
    String? password,
    String? registrationToken,
    DateTime? registrationTokenExpiresAt,
    File? photo,
    String? categoryId,
    int? experienceYears,
    String? fatherName,
    String? dateOfBirth,
    bool? legalNameConfirmed,
    String? area,
    String? street,
    String? house,
    String? landmark,
    bool? accountCreated,
  }) {
    return UstaadRegistrationDraft(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      password: password ?? this.password,
      registrationToken: registrationToken ?? this.registrationToken,
      registrationTokenExpiresAt:
          registrationTokenExpiresAt ?? this.registrationTokenExpiresAt,
      photo: photo ?? this.photo,
      categoryId: categoryId ?? this.categoryId,
      experienceYears: experienceYears ?? this.experienceYears,
      fatherName: fatherName ?? this.fatherName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      legalNameConfirmed: legalNameConfirmed ?? this.legalNameConfirmed,
      area: area ?? this.area,
      street: street ?? this.street,
      house: house ?? this.house,
      landmark: landmark ?? this.landmark,
      accountCreated: accountCreated ?? this.accountCreated,
    );
  }
}

/// The experience choices the design offers, as (label, stored lower bound).
///
/// The backend stores a single `experienceYears` integer, so a band is stored
/// as the smallest number of years it guarantees — "6-10" means at least six.
/// The labels are digits and punctuation, identical in every language, so they
/// are not translated.
const experienceBands = <({String label, int years})>[
  (label: '1-2', years: 1),
  (label: '3-5', years: 3),
  (label: '6-10', years: 6),
  (label: '10+', years: 10),
];

class UstaadRegistrationDraftNotifier
    extends AutoDisposeNotifier<UstaadRegistrationDraft> {
  @override
  UstaadRegistrationDraft build() => const UstaadRegistrationDraft();

  void update(
    UstaadRegistrationDraft Function(UstaadRegistrationDraft) change,
  ) {
    state = change(state);
  }

  /// Explicitly drops everything — used when the flow completes, so the
  /// password and the registration token do not outlive it even if some other
  /// listener is still keeping the provider alive.
  void clear() => state = const UstaadRegistrationDraft();
}

final ustaadRegistrationDraftProvider = AutoDisposeNotifierProvider<
    UstaadRegistrationDraftNotifier, UstaadRegistrationDraft>(
  UstaadRegistrationDraftNotifier.new,
);
