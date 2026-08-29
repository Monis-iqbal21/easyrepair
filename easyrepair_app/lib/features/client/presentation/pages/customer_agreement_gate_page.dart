import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/customer_agreement_entity.dart';
import '../providers/customer_agreement_providers.dart';
import '../widgets/client_state_view.dart';
import 'customer_agreement_viewer_page.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Mandatory, non-dismissible full-screen gate: every CLIENT must accept
/// Customer Terms Version 1.0 before using the app.
///
/// Enforcement lives in `app_router.dart`'s redirect guard — EVERY
/// authenticated CLIENT route (not just the splash/login dispatch) redirects
/// here whenever [requiredCustomerAgreementProvider] reports acceptance is
/// required or could not be confirmed, so a notification, deep link or
/// bottom-nav tap can never navigate around it. This page itself is
/// unreachable to a WORKER — the redirect guard only ever activates it for
/// `!user.isWorker`.
///
/// Genuinely non-dismissible:
///  * `PopScope(canPop: false)` swallows Android/system back.
///  * No AppBar, no close (X) button.
///  * Nothing here is a dialog/sheet, so there is no "outside" to tap.
///  * The only way out is a confirmed, backend-acknowledged acceptance.
///
/// Never marks acceptance locally before the backend confirms success: the
/// checkbox is local UI state only, [AcceptCustomerAgreementNotifier] never
/// writes anywhere durable, and the gate only ever closes because
/// [requiredCustomerAgreementProvider] re-resolves to `acceptanceRequired:
/// false` after a real 200 from the accept endpoint.
class CustomerAgreementGatePage extends ConsumerStatefulWidget {
  const CustomerAgreementGatePage({super.key});

  @override
  ConsumerState<CustomerAgreementGatePage> createState() =>
      _CustomerAgreementGatePageState();
}

class _CustomerAgreementGatePageState
    extends ConsumerState<CustomerAgreementGatePage> {
  bool _checked = false;

  Future<void> _viewAgreement(CustomerAgreementEntity agreement) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerAgreementViewerPage(agreement: agreement),
      ),
    );
  }

  Future<void> _submit() async {
    // Re-entry guard: a second tap that raced past the disabled button
    // (isLoading only updates on the next rebuild) must never fire a
    // duplicate acceptance request.
    if (ref.read(acceptCustomerAgreementProvider).isLoading) return;
    // Fire-and-forget from the widget's perspective: success closes the gate
    // via the invalidated requiredCustomerAgreementProvider triggering the
    // router redirect; failure surfaces through acceptCustomerAgreementProvider's
    // AsyncError state, rendered inline below, and the gate simply stays open.
    await ref.read(acceptCustomerAgreementProvider.notifier).accept();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final statusAsync = ref.watch(requiredCustomerAgreementProvider);
    final acceptState = ref.watch(acceptCustomerAgreementProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: statusAsync.when(
            loading: () => ClientStateView.loading(
              message: context.l10n.clientStateLoading,
            ),
            error: (err, _) => ClientStateView.error(
              title: context.l10n.clientStateErrorTitle,
              message: failureMessage(
                context.l10n,
                err,
                fallback: context.l10n.agreementLoadFailed,
              ),
              actionLabel: context.l10n.commonRetry,
              onAction: () => ref.invalidate(requiredCustomerAgreementProvider),
            ),
            data: (status) {
              if (status == null || !status.acceptanceRequired) {
                // The router redirect is about to navigate away; avoid a
                // flash of the form during that single frame.
                return ClientStateView.loading(
                  message: context.l10n.clientStateLoading,
                );
              }
              return _GateBody(
                agreement: status.agreement,
                checked: _checked,
                onCheckedChanged: (v) => setState(() => _checked = v),
                onViewAgreement: () => _viewAgreement(status.agreement),
                isSubmitting: acceptState.isLoading,
                errorMessage: acceptState.hasError
                    ? failureMessage(
                        context.l10n,
                        acceptState.error,
                        fallback: context.l10n.customerAgreementSaveFailed,
                      )
                    : null,
                onAgree: _checked && !acceptState.isLoading ? _submit : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GateBody extends StatelessWidget {
  final CustomerAgreementEntity agreement;
  final bool checked;
  final ValueChanged<bool> onCheckedChanged;
  final VoidCallback onViewAgreement;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback? onAgree;

  const _GateBody({
    required this.agreement,
    required this.checked,
    required this.onCheckedChanged,
    required this.onViewAgreement,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onAgree,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final l10n = context.l10n;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HandyGo branding ────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'H',
                        style: TextStyle(
                          color: c.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'HandyGo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Title + version + effective date ────────────────────
                Text(
                  l10n.customerAgreementTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      label: l10n.workerAgreementVersion(agreement.version),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.customerAgreementEffectiveDateNote,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // ── View/Download PDF ───────────────────────────────────
                OutlinedButton.icon(
                  onPressed: onViewAgreement,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(l10n.customerAgreementViewDownloadPdf),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primaryPressed,
                    side: BorderSide(color: c.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Scrollable agreement content ────────────────────────
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        // The complete approved legal body, verbatim.
                        agreement.contentText,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Checkbox — initially unchecked, never pre-selected ──
                InkWell(
                  onTap: () => onCheckedChanged(!checked),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: checked ? c.softTeal : c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: checked ? c.primary : c.border,
                        width: checked ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: checked,
                          activeColor: c.primary,
                          onChanged: (v) => onCheckedChanged(v ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              l10n.customerAgreementCheckboxLabel,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: c.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.errorSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: c.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.error,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── I Agree ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            boxShadow: [
              BoxShadow(
                color: c.scrim.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAgree,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                disabledBackgroundColor: c.primary.withValues(alpha: 0.4),
                foregroundColor: c.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.onPrimary,
                      ),
                    )
                  : Text(
                      context.l10n.customerAgreementIAgree,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: c.textSecondary,
        ),
      ),
    );
  }
}
