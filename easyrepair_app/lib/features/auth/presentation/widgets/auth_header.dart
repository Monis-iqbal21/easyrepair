import 'package:flutter/material.dart';

import 'auth_primary_button.dart';

/// Shared logo + title + subtitle header, reused across every auth screen —
/// consolidates the near-identical private `_AuthHeader` copy-pasted per
/// page. Sizes down on small screens (`isSmall`) instead of using a fixed
/// height, so it never overflows on small Android phones.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSmall;
  final bool showBackButton;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSmall,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(
                Icons.arrow_back_rounded,
                color: kAuthDark,
                size: 24,
              ),
            ),
          ),
          SizedBox(height: isSmall ? 12 : 18),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo-green.png',
              width: isSmall ? 36 : 44,
              height: isSmall ? 36 : 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Handygo',
              style: TextStyle(
                fontSize: isSmall ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: kAuthAccent,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmall ? 16 : 24),
        Text(
          title,
          style: TextStyle(
            fontSize: isSmall ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: kAuthDark,
            height: 1.2,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: kAuthGray,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
