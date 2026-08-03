import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handygo_app/core/errors/failure_messages.dart';
import 'package:handygo_app/core/errors/failures.dart';
import 'package:handygo_app/core/l10n/app_locale.dart';
import 'package:handygo_app/features/worker/data/datasources/worker_remote_datasource.dart';
import 'package:handygo_app/features/worker/data/models/agreement_template_model.dart';
import 'package:handygo_app/features/worker/data/repositories/worker_repository_impl.dart';
import 'package:handygo_app/l10n/app_localizations.dart';

import '../../support/l10n_test_app.dart';

/// Parsing of the agreement payloads.
///
/// This exists because of a production failure: the Agreements section of the
/// profile-completion page rendered
/// `type 'Null' is not a subtype of type 'String' in type cast`. The API was
/// answering with the pre-agreement payload — `{id, type, title, version,
/// contentText}` — which carries no `documentType`, no `sourceHash` and no
/// `agreementLocale`, so a blind `as String` blew up with a message that named
/// neither the field nor the cause.
///
/// Two rules are pinned here:
///   * a field the flow depends on must fail by name, never by cast;
///   * a field that is legitimately absent must parse to null, never throw.

/// Exactly what the current backend sends for the General agreement.
Map<String, dynamic> _validTemplate({
  String documentType = 'USTAAD_SERVICE_PROVIDER_AGREEMENT',
  String? applicableTrade,
}) =>
    {
      'documentType': documentType,
      'title': 'HandyGo Ustaad Service Provider Agreement',
      'version': '1.0',
      'agreementLocale': 'ur_Latn',
      'sourceHash': 'd9fa07a224991b43524d34b5277e6842',
      'applicableTrade': applicableTrade,
      'contentText': 'HANDYGO USTAAD SERVICE PROVIDER AGREEMENT\n\n1. TAARUF',
      'legalLanguageNoticeRequired': true,
      'requestedAppLocale': 'en',
    };

/// The payload that actually caused the production crash — the legacy
/// two-document response from a backend that has not been redeployed.
const _legacyTemplate = <String, dynamic>{
  'id': '9e1f7d2c-0b1a-4f1e-9a2b-3c4d5e6f7a8b',
  'type': 'GENERAL_USTAAD',
  'title': 'HandyGo Ustaad Service Provider Agreement',
  'version': '1.0',
  'contentText': 'HANDYGO USTAAD SERVICE PROVIDER AGREEMENT',
};

Map<String, dynamic> _validAccepted() => {
      'id': 'row-1',
      'acceptanceId': 'HG-ACC-2026-AAAA',
      'documentType': 'USTAAD_SERVICE_PROVIDER_AGREEMENT',
      'title': 'HandyGo Ustaad Service Provider Agreement',
      'version': '1.0',
      'agreementLocale': 'ur_Latn',
      'applicableTrade': null,
      'acceptedAt': '2026-08-03T09:05:00.000Z',
      'viewedAt': '2026-08-03T09:00:00.000Z',
    };

/// Fails the way the datasource does when the payload is malformed.
class _MalformedDatasource implements WorkerRemoteDatasource {
  @override
  Future<List<AgreementTemplateModel>> getAgreementTemplates({
    required String locale,
  }) async =>
      // Parsing the legacy payload is what throws, exactly as in production.
      [AgreementTemplateModel.fromJson(Map.of(_legacyTemplate))];

  @override
  Future<List<AcceptedAgreementModel>> getMyAgreements() async =>
      [AcceptedAgreementModel.fromJson(<String, dynamic>{'id': 'row-1'})];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Future<AppLocalizations> _l10nFor(WidgetTester tester, AppLocale locale) async {
  late AppLocalizations resolved;
  await tester.pumpWidget(
    localizedApp(
      Builder(
        builder: (context) {
          resolved = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return resolved;
}

void main() {
  group('AgreementTemplateModel', () {
    test('parses the current backend payload', () {
      final model = AgreementTemplateModel.fromJson(_validTemplate());

      expect(model.documentType, 'USTAAD_SERVICE_PROVIDER_AGREEMENT');
      expect(model.agreementLocale, 'ur_Latn');
      expect(model.sourceHash, isNotEmpty);
      expect(model.legalLanguageNoticeRequired, isTrue);
      expect(model.requestedAppLocale, 'en');
    });

    test('accepts a null applicableTrade on the General and EVS documents', () {
      for (final documentType in const [
        'USTAAD_SERVICE_PROVIDER_AGREEMENT',
        'BACKGROUND_VERIFICATION_EVS_PRIVACY_NOTICE',
      ]) {
        final model = AgreementTemplateModel.fromJson(
          _validTemplate(documentType: documentType),
        );
        expect(model.applicableTrade, isNull);
      }
    });

    test('keeps the trade on the trade-specific document', () {
      final model = AgreementTemplateModel.fromJson(
        _validTemplate(
          documentType: 'TRADE_SPECIFIC_SERVICE_AGREEMENT',
          applicableTrade: 'ELECTRICIAN',
        ),
      );
      expect(model.applicableTrade, 'ELECTRICIAN');
    });

    test('treats an omitted applicableTrade key the same as null', () {
      final json = _validTemplate()..remove('applicableTrade');
      expect(AgreementTemplateModel.fromJson(json).applicableTrade, isNull);
    });

    // ── The production crash ────────────────────────────────────────────────
    test('names the missing field on the legacy payload, instead of a cast '
        'error', () {
      expect(
        () => AgreementTemplateModel.fromJson(Map.of(_legacyTemplate)),
        throwsA(
          isA<AgreementResponseFormatException>()
              .having((e) => e.field, 'field', 'documentType'),
        ),
      );

      // Explicitly not the opaque failure this replaced.
      expect(
        () => AgreementTemplateModel.fromJson(Map.of(_legacyTemplate)),
        isNot(throwsA(isA<TypeError>())),
      );
    });

    test('refuses to invent evidence fields it did not receive', () {
      // A defaulted sourceHash/version/locale would be submitted back as
      // acceptance evidence describing a document that does not exist.
      for (final field in const [
        'documentType',
        'title',
        'version',
        'agreementLocale',
        'sourceHash',
        'contentText',
      ]) {
        final json = _validTemplate()..remove(field);
        expect(
          () => AgreementTemplateModel.fromJson(json),
          throwsA(
            isA<AgreementResponseFormatException>()
                .having((e) => e.field, 'field', field),
          ),
          reason: '$field must fail loudly rather than default',
        );

        final nulled = _validTemplate()..[field] = null;
        expect(
          () => AgreementTemplateModel.fromJson(nulled),
          throwsA(isA<AgreementResponseFormatException>()),
          reason: 'an explicit null $field must fail too',
        );
      }
    });

    test('defaults only presentation-only metadata', () {
      final json = _validTemplate()
        ..remove('legalLanguageNoticeRequired')
        ..remove('requestedAppLocale');
      final model = AgreementTemplateModel.fromJson(json);

      expect(model.legalLanguageNoticeRequired, isFalse);
      // The echo of the requested locale is cosmetic; the accepted language is
      // what matters and it comes from agreementLocale.
      expect(model.requestedAppLocale, 'ur_Latn');
      expect(model.agreementLocale, 'ur_Latn');
    });
  });

  group('AcceptedAgreementModel', () {
    test('parses a sealed record', () {
      final model = AcceptedAgreementModel.fromJson(_validAccepted());

      expect(model.acceptanceId, 'HG-ACC-2026-AAAA');
      expect(model.acceptedAt.toUtc().year, 2026);
      expect(model.viewedAt, isNotNull);
      expect(model.applicableTrade, isNull);
    });

    test('accepts records with no acceptance id, trade, type or viewed-at', () {
      final json = _validAccepted()
        ..['acceptanceId'] = null
        ..['documentType'] = null
        ..['applicableTrade'] = null
        ..['viewedAt'] = null;
      final model = AcceptedAgreementModel.fromJson(json);

      expect(model.acceptanceId, isNull);
      expect(model.documentType, isNull);
      expect(model.viewedAt, isNull);
      // Still addressable for the secure download.
      expect(model.toEntity().downloadId, 'row-1');
    });

    test('never shows a placeholder date on a legal record', () {
      final json = _validAccepted()..remove('acceptedAt');
      expect(
        () => AcceptedAgreementModel.fromJson(json),
        throwsA(
          isA<AgreementResponseFormatException>()
              .having((e) => e.field, 'field', 'acceptedAt'),
        ),
      );
    });

    test('rejects the legacy acceptance payload by name', () {
      // The pre-agreement backend called these agreementTitle/agreementVersion.
      const legacy = <String, dynamic>{
        'id': 'row-1',
        'agreementType': 'GENERAL_USTAAD',
        'agreementTitle': 'HandyGo Ustaad Service Provider Agreement',
        'agreementVersion': '1.0',
        'acceptedAt': '2026-08-03T09:05:00.000Z',
        'acceptancePdfUrl': 'https://cdn.example.com/x.pdf',
      };
      expect(
        () => AcceptedAgreementModel.fromJson(Map.of(legacy)),
        throwsA(
          isA<AgreementResponseFormatException>()
              .having((e) => e.field, 'field', 'title'),
        ),
      );
    });
  });

  group('what the Ustaad ends up seeing', () {
    test('a malformed payload becomes a Failure with no raw type error in it',
        () async {
      final repository = WorkerRepositoryImpl(_MalformedDatasource());

      final result = await repository.getAgreementTemplates(appLocale: 'en');

      final failure = result.fold(
        (f) => f,
        (_) => throw StateError('a malformed payload must not succeed'),
      );
      // Empty message ⇒ the screen renders its own localized wording.
      expect(failure.message, isEmpty);
      // The field that broke is kept for logs and support, never for display.
      expect(failure.diagnostic, contains('documentType'));
      expect(failure.diagnostic, isNot(contains('is not a subtype of')));
    });

    testWidgets('the section shows localized copy, not a Dart cast error',
        (tester) async {
      const failure = ServerFailure('', diagnostic: 'documentType missing');

      for (final locale in AppLocale.values) {
        final l10n = await _l10nFor(tester, locale);
        final shown = failureMessage(
          l10n,
          failure,
          fallback: l10n.agreementsLoadFailed,
        );

        expect(shown, isNotEmpty);
        expect(shown, isNot(contains('Null')));
        expect(shown, isNot(contains('subtype')));
        expect(shown, isNot(contains('documentType')));
      }
    });
  });
}
