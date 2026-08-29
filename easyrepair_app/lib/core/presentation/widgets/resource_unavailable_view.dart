import 'package:flutter/material.dart';

import '../../errors/failures.dart';
import '../../theme/app_semantic_colors.dart';

/// Full-state view for a specific "this resource is gone" business state —
/// a booking/job/conversation that was deleted, withdrawn, or is otherwise
/// no longer accessible to this account (a 404/403 from the API, mapped to
/// [NotFoundFailure]/[ForbiddenFailure] by dio_failure_mapper.dart).
///
/// Deliberately never offers Retry — re-fetching the same id cannot turn a
/// gone resource into a present one — only a safe navigation action away
/// from the dead end.
class ResourceUnavailableView extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const ResourceUnavailableView({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_off_rounded,
                size: 30,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// True for the [Failure] shapes that mean "this specific resource is gone",
/// as opposed to a transient network/server problem —
/// [NotFoundFailure]/[ForbiddenFailure] (404/403 from the API).
bool isResourceUnavailableFailure(Object? error) =>
    error is NotFoundFailure || error is ForbiddenFailure;
