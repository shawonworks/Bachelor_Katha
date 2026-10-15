import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/session_controller.dart';

/// Premium animated splash: logo pop-in, glow + ripple rings, title reveal,
/// tagline fade and a slim progress line. Then routes to the right screen.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  static const String logoPath = 'assets/images/app_logo.jpeg';

  static const _appName = 'Bachelor Khata';
  static const _tagline = 'Shared expenses, simplified';

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  // Staged timings (0..1 over the whole animation).
  static const _logoScale = Interval(0.0, 0.45, curve: Curves.easeOutBack);
  static const _logoFade = Interval(0.0, 0.25, curve: Curves.easeOut);
  static const _ring1 = Interval(0.15, 0.80, curve: Curves.easeOutCubic);
  static const _ring2 = Interval(0.30, 0.95, curve: Curves.easeOutCubic);
  static const _title = Interval(0.40, 0.70, curve: Curves.easeOutCubic);
  static const _tag = Interval(0.55, 0.85, curve: Curves.easeOut);
  static const _bar = Interval(0.45, 1.0, curve: Curves.easeInOut);

  double _t(Interval i) => i.transform(_c.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (logoPath.isNotEmpty) {
      precacheImage(const AssetImage(logoPath), context).catchError((_) {});
    }
  }

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(_go);
  }

  void _go() {
    if (!mounted) return;
    final s = Get.find<SessionController>();
    final next = s.name.value.isEmpty
        ? Routes.onboarding
        : s.roomCode.value == null
            ? Routes.home
            : Routes.dashboard;
    Get.offAllNamed(next);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _logo() {
    const fallback = Icon(
      Icons.account_balance_wallet_rounded,
      size: 54,
      color: Color(0xFF4338CA),
    );
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: logoPath.isEmpty
            ? const Center(child: fallback)
            : Image.asset(
                logoPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: fallback),
              ),
      ),
    );
  }

  Widget _ring(double t) {
    final size = 120 + 260 * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: (1 - t) * 0.35),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final scale = 0.4 + 0.6 * _t(_logoScale);
            final fade = _t(_logoFade);
            final glow = 0.10 + 0.22 * fade;
            final title = _t(_title);
            final tag = _t(_tag);

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ripple rings
                    _ring(_t(_ring1)),
                    _ring(_t(_ring2)),
                    // Soft glow
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Colors.white.withValues(alpha: glow),
                          Colors.white.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                    // Logo + texts
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: fade,
                          child: Transform.scale(scale: scale, child: _logo()),
                        ),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: title,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - title)),
                            child: Text(
                              _appName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 5 - 4 * title,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: tag,
                          child: Text(
                            _tagline,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Progress line
                    Positioned(
                      bottom: 56,
                      child: Opacity(
                        opacity: tag,
                        child: SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _t(_bar),
                              minHeight: 3,
                              color: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
