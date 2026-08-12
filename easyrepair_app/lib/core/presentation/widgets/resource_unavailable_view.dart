import 'package:flutter/material.dart';

import '../../errors/failures.dart';

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
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_off_rounded,
                size: 30,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDB6234),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
