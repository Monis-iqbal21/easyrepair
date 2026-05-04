import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/images/er-icon.png'),
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1D9E75)),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
