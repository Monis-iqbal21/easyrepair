import 'package:dio/dio.dart';

import '../models/customer_agreement_model.dart';

abstract class CustomerAgreementRemoteDatasource {
  Future<CustomerAgreementStatusModel> getRequiredAgreement({
    required String locale,
  });

  Future<CustomerAgreementAcceptanceSummaryModel> acceptAgreement({
    required bool checkboxAccepted,
    String? deviceDescriptor,
  });

  Future<List<AcceptedCustomerAgreementModel>> getHistory();

  Future<List<int>> downloadAgreementPdf(String acceptanceId);
}

class CustomerAgreementRemoteDatasourceImpl
    implements CustomerAgreementRemoteDatasource {
  final Dio _dio;

  const CustomerAgreementRemoteDatasourceImpl(this._dio);

  @override
  Future<CustomerAgreementStatusModel> getRequiredAgreement({
    required String locale,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/customer/agreements/required',
      queryParameters: {'locale': locale},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CustomerAgreementStatusModel.fromJson(data);
  }

  @override
  Future<CustomerAgreementAcceptanceSummaryModel> acceptAgreement({
    required bool checkboxAccepted,
    String? deviceDescriptor,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/customer/agreements/customer-terms/accept',
      data: {
        'checkboxAccepted': checkboxAccepted,
        if (deviceDescriptor != null) 'deviceDescriptor': deviceDescriptor,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return CustomerAgreementAcceptanceSummaryModel.fromJson(data);
  }

  @override
  Future<List<AcceptedCustomerAgreementModel>> getHistory() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/customer/agreements/history',
    );
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) =>
            AcceptedCustomerAgreementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<int>> downloadAgreementPdf(String acceptanceId) async {
    final response = await _dio.get<List<int>>(
      '/customer/agreements/acceptances/$acceptanceId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const <int>[];
  }
}
