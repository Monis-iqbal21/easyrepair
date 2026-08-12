import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/locale_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/customer_agreement_remote_datasource.dart';
import '../../data/repositories/customer_agreement_repository_impl.dart';
import '../../domain/entities/customer_agreement_entity.dart';
import '../../domain/repositories/customer_agreement_repository.dart';

final customerAgreementRemoteDatasourceProvider =
    Provider<CustomerAgreementRemoteDatasource>(
  (ref) => CustomerAgreementRemoteDatasourceImpl(ref.watch(dioProvider)),
);

final customerAgreementRepositoryProvider =
    Provider<CustomerAgreementRepository>(
  (ref) => CustomerAgreementRepositoryImpl(
    ref.watch(customerAgreementRemoteDatasourceProvider),
  ),
);

/// Whether the authenticated CLIENT must accept Customer Terms Version 1.0
/// right now, and the document/existing-acceptance metadata to show.
///
/// Null only for a logged-out user or a WORKER — the gate never applies to
/// them. Backend is the sole source of truth: a network/server error here
/// surfaces as an [AsyncError], which the gate (and the router redirect)
/// treat as "must still show the gate, with a retry" — never as "accepted".
/// Re-evaluated whenever auth state or the app locale changes, and whenever
/// explicitly invalidated after a successful acceptance.
final requiredCustomerAgreementProvider =
    FutureProvider.autoDispose<CustomerAgreementStatusEntity?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.isWorker) return null;

  final locale = ref.watch(localeProvider);
  final result = await ref
      .read(customerAgreementRepositoryProvider)
      .getRequiredAgreement(appLocale: locale.storageValue);
  return result.fold((f) => throw f, (status) => status);
});

/// Submits the Version 1.0 acceptance. Never marks acceptance locally before
/// the backend confirms success — success is entirely defined by the
/// invalidated [requiredCustomerAgreementProvider] resolving with
/// `acceptanceRequired: false` afterward.
class AcceptCustomerAgreementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns true on success. On failure, sets [state] to [AsyncError] and
  /// returns false — the gate stays open and shows a retryable error.
  Future<bool> accept({String? deviceDescriptor}) async {
    final offline = offlineActionGuard();
    if (offline != null) {
      state = AsyncError(offline, StackTrace.current);
      return false;
    }
    state = const AsyncLoading();
    final result =
        await ref.read(customerAgreementRepositoryProvider).acceptAgreement(
              checkboxAccepted: true,
              deviceDescriptor: deviceDescriptor,
            );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(requiredCustomerAgreementProvider);
        return true;
      },
    );
  }
}

final acceptCustomerAgreementProvider =
    AsyncNotifierProvider<AcceptCustomerAgreementNotifier, void>(
  AcceptCustomerAgreementNotifier.new,
);

/// The Client's own accepted-agreement history — Client Profile screen.
final customerAgreementHistoryProvider =
    FutureProvider.autoDispose<List<AcceptedCustomerAgreementEntity>>(
        (ref) async {
  final result =
      await ref.read(customerAgreementRepositoryProvider).getHistory();
  return result.fold((f) => throw f, (list) => list);
});

/// Downloads one accepted agreement's PDF bytes, for the history screen's
/// View/Download action.
class DownloadCustomerAgreementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<List<int>?> download(String acceptanceId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(customerAgreementRepositoryProvider)
        .downloadAgreementPdf(acceptanceId);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (bytes) {
        state = const AsyncData(null);
        return bytes;
      },
    );
  }
}

final downloadCustomerAgreementProvider =
    AsyncNotifierProvider<DownloadCustomerAgreementNotifier, void>(
  DownloadCustomerAgreementNotifier.new,
);
