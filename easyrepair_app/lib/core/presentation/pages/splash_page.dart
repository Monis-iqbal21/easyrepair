import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.44).clamp(112.0, 208.0);

    return Scaffold(
      backgroundColor: const Color(0xFF1D9E75),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo-white.png',
              width: logoWidth,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
