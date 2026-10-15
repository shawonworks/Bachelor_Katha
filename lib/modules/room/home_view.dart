import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../widgets/app_widgets.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bachelor Khata'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: controller.session.toggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Obx(() => Text('Hi, ${controller.session.name.value}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800))),
          const SizedBox(height: 4),
          Text('Create a room for your flat, or join one with a code.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(Icons.add_home_rounded, 'Create a room'),
                const SizedBox(height: 14),
                AppTextField(
                  controller: controller.roomNameC,
                  label: 'Room name',
                  hint: 'e.g. Mess 304',
                  icon: Icons.home_rounded,
                  maxLength: 30,
                  capitalization: TextCapitalization.words,
                  action: TextInputAction.done,
                  onSubmitted: (_) => controller.create(),
                ),
                const SizedBox(height: 14),
                Obx(() => AppButton(
                      label: 'Create room',
                      loading: controller.creating.value,
                      onPressed: controller.create,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(Icons.login_rounded, 'Join with a code'),
                const SizedBox(height: 14),
                AppTextField(
                  controller: controller.codeC,
                  label: '6-digit code',
                  icon: Icons.pin_rounded,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  action: TextInputAction.done,
                  onSubmitted: (_) => controller.join(),
                ),
                const SizedBox(height: 14),
                Obx(() => AppButton(
                      label: 'Join room',
                      tonal: true,
                      loading: controller.joining.value,
                      onPressed: controller.join,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader(this.icon, this.title);
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
      ),
      const SizedBox(width: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    ]);
  }
}
