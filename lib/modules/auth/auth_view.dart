import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/app_widgets.dart';
import 'auth_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                28, MediaQuery.of(context).padding.top + 56, 28, 48),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(height: 22),
                const Text('Bachelor Khata',
                    style: TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Track shared expenses with your roommates in real time. Know exactly who owes whom.',
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("What's your name?",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Your friends will see this name.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: controller.nameC,
                    label: 'Your name',
                    icon: Icons.person_rounded,
                    maxLength: 24,
                    capitalization: TextCapitalization.words,
                    action: TextInputAction.done,
                    onSubmitted: (_) => controller.submit(),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Get started',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: controller.submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
