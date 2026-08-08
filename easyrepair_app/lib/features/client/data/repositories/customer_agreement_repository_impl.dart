import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/customer_agreement_entity.dart';
import '../../domain/repositories/customer_agreement_repository.dart';
import '../datasources/customer_agreement_remote_datasource.dart';

class CustomerAgreementRepositoryImpl implements CustomerAgreementRepository {
  final CustomerAgreementRemoteDatasource _datasource;

  const CustomerAgreementRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, CustomerAgreementStatusEntity>> getRequiredAgreement({
    required String appLocale,
  }) async {
    try {
      final model =
          await _datasource.getRequiredAgreement(locale: appLocale);
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CustomerAgreementAcceptanceSummaryEntity>>
      acceptAgreement({
    required bool checkboxAccepted,
    String? deviceDescriptor,
  }) async {
    try {
      final model = await _datasource.acceptAgreement(
        checkboxAccepted: checkboxAccepted,
        deviceDescriptor: deviceDescriptor,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AcceptedCustomerAgreementEntity>>>
      getHistory() async {
    try {
      final models = await _datasource.getHistory();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<int>>> downloadAgreementPdf(
    String acceptanceId,
  ) async {
    try {
      final bytes = await _datasource.downloadAgreementPdf(acceptanceId);
      return Right(bytes);
    } on DioException catch (e) {
      return Left(dioExceptionToFailure(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
