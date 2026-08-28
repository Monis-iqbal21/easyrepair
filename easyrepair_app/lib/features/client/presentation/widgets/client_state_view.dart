import 'package:flutter/material.dart';

import '../../../../core/theme/app_semantic_colors.dart';

enum ClientStateKind { loading, empty, error }

/// Consistent, responsive feedback for Client-only loading, empty and error
/// surfaces. Callers keep ownership of localized copy and existing refresh
/// methods; this widget contains no data or network logic.
class ClientStateView extends StatelessWidget {
  const ClientStateView.loading({super.key, this.message, this.compact = false})
    : kind = ClientStateKind.loading,
      icon = null,
      title = null,
      actionLabel = null,
      onAction = null;

  const ClientStateView.empty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  }) : kind = ClientStateKind.empty;

  const ClientStateView.error({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.compact = false,
    this.icon = Icons.error_outline_rounded,
  }) : kind = ClientStateKind.error;

  final ClientStateKind kind;
  final IconData? icon;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final horizontalPadding = compact ? 16.0 : 32.0;

    return ColoredBox(
      color: compact ? colors.surface : colors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: compact ? 20 : 28,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Semantics(
              container: true,
              liveRegion: kind != ClientStateKind.empty,
              label: _semanticLabel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kind == ClientStateKind.loading)
                    SizedBox.square(
                      dimension: compact ? 28 : 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.primary,
                      ),
                    )
                  else
                    Container(
                      width: compact ? 56 : 68,
                      height: compact ? 56 : 68,
                      decoration: BoxDecoration(
                        color: kind == ClientStateKind.error
                            ? colors.errorSoft
                            : colors.softTeal,
                        borderRadius: BorderRadius.circular(compact ? 16 : 18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 27 : 32,
                        color: kind == ClientStateKind.error
                            ? colors.error
                            : colors.primary,
                      ),
                    ),
                  if (title != null) ...[
                    SizedBox(height: compact ? 13 : 17),
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: compact ? 16 : 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (message != null) ...[
                    SizedBox(height: title == null ? 14 : 7),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: compact ? 13 : 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    SizedBox(height: compact ? 16 : 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 144,
                        minHeight: 48,
                      ),
                      child: kind == ClientStateKind.error
                          ? OutlinedButton.icon(
                              onPressed: onAction,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(actionLabel!),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.primary,
                                side: BorderSide(color: colors.controlBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : FilledButton(
                              onPressed: onAction,
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: colors.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(actionLabel!),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? get _semanticLabel {
    final parts = [
      title,
      message,
    ].whereType<String>().where((value) => value.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join('. ');
  }
}
