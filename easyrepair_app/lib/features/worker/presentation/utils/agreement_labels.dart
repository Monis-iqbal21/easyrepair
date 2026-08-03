import '../../../../l10n/app_localizations.dart';

/// Display wording for the backend's stable agreement codes.
///
/// These translate the LABEL only. Which trade schedule an Ustaad is bound by,
/// and which language the legal body is in, are decided by the backend from
/// [TradeCode] and [AgreementLocale] — never by comparing displayed text, so
/// switching app language can never change the contract.

/// "Roman Urdu" / "اردو" / … for an agreement locale code.
String agreementLocaleLabel(AppLocalizations l10n, String locale) {
  switch (locale) {
    case 'en':
      return l10n.agreementLanguageEnglish;
    case 'ur':
      return l10n.agreementLanguageUrdu;
    case 'ur_Latn':
      return l10n.agreementLanguageRomanUrdu;
    default:
      // An unknown code is shown verbatim rather than guessed at.
      return locale;
  }
}

/// "Electrician" / "الیکٹریشن" / … for a trade code.
///
/// Reuses the service-category wording the rest of the app already ships, so
/// a trade is named the same way everywhere and there is only one place to
/// review it.
String tradeLabel(AppLocalizations l10n, String trade) {
  switch (trade) {
    case 'ELECTRICIAN':
      return l10n.serviceElectrician;
    case 'PLUMBER':
      return l10n.servicePlumber;
    case 'AC_TECHNICIAN':
      return l10n.serviceAcTechnician;
    case 'CARPENTER':
      return l10n.serviceCarpenter;
    default:
      return trade;
  }
}
