import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import 'auth_widgets.dart';
import 'login_page.dart';
import 'sign_up_page.dart';

/// First page of the app: logo, Sign Up, Log In and the language switch.
/// Put the logo image at assets/images/rasd_logo.png.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return PalmScaffold(
      body: Stack(
        children: [
          // Palm photo at the top, fading into the page background.
          SizedBox(
            height: height * 0.55,
            width: double.infinity,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0, 0.6, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/palm_background.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/rasd_logo.png',
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 84,
                        height: 84,
                        child: Center(
                          child: PalmIcon(size: 60, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RASD',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Healthy Palms, Stronger Farms',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(flex: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignUpPage()),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text('Log In'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const LanguageToggle(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
