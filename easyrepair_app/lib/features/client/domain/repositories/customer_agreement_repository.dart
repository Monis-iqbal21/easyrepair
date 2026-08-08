import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/customer_agreement_entity.dart';

abstract class CustomerAgreementRepository {
  /// GET /customer/agreements/required — the current agreement + whether
  /// this Client must accept it, resolved for [appLocale].
  Future<Either<Failure, CustomerAgreementStatusEntity>> getRequiredAgreement({
    required String appLocale,
  });

  /// POST /customer/agreements/customer-terms/accept — seals the one
  /// immutable Version 1.0 acceptance record. The backend resolves identity,
  /// version and hash server-side; only genuine Client-origin evidence is
  /// sent here.
  Future<Either<Failure, CustomerAgreementAcceptanceSummaryEntity>>
      acceptAgreement({
    required bool checkboxAccepted,
    String? deviceDescriptor,
  });

  /// GET /customer/agreements/history — this Client's own permanent
  /// acceptance records.
  Future<Either<Failure, List<AcceptedCustomerAgreementEntity>>> getHistory();

  /// GET /customer/agreements/acceptances/:acceptanceId/download — the
  /// accepted PDF bytes, ownership-checked server-side.
  Future<Either<Failure, List<int>>> downloadAgreementPdf(String acceptanceId);
}
