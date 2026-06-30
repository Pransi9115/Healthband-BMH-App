import 'package:flutter/material.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../shared/widgets/bmh_screen.dart';
import '../../../shared/widgets/bmh_global_nav.dart';
import 'ble_scan_screen.dart';

class BleIntroScreen extends StatelessWidget {
  final bool isScale;
  const BleIntroScreen({super.key, this.isScale = false});

  @override
  Widget build(BuildContext context) {
    final color = isScale ? BMHColors.sGut : BMHColors.sCardio;
    final title = isScale ? 'BioScale' : 'Health Band';
    final icon  = isScale ? Icons.monitor_weight_outlined : Icons.watch_outlined;
    final desc  = isScale
        ? 'Your BioScale measures weight, body fat, muscle mass, water percentage, BMI and more.'
        : 'Your Health Band continuously monitors heart rate, SpO2, HRV, temperature, sleep and activity.';

    return BMHScreenBackground(
      glowColor: color,
      glowAlignment: Alignment.topLeft,
      bottomNavigationBar: const BMHGlobalNav(),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              BMHIconButton(
                onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: BMHColors.ink, size: 16),
              ),
              const SizedBox(height: 32),
              Center(
                child: Stack(alignment: Alignment.center, children: [
                  Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.10), width: 1))),
                  Container(width: 116, height: 116,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.18), width: 1))),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.35), width: 1.5),
                      boxShadow: BMHShadows.glow(color),
                    ),
                    child: Icon(icon, color: color, size: 34),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              BMHEyebrow('Device setup', showDot: true),
              const SizedBox(height: 10),
              Text.rich(TextSpan(
                style: BMHText.displayMd.copyWith(fontSize: 32, height: 1.2),
                children: [
                  const TextSpan(text: 'Connect your\n'),
                  TextSpan(text: title, style: TextStyle(
                    fontStyle: FontStyle.italic, color: color, fontWeight: FontWeight.w400)),
                ],
              )),
              const SizedBox(height: 10),
              Text(desc, style: BMHText.italic),
              const SizedBox(height: 28),
              _Step(num: '1',
                title: 'Power on your device',
                desc: isScale ? 'Step on the scale briefly to wake it' : 'Hold the button on your band for 3 seconds',
                color: color),
              _Step(num: '2',
                title: 'Enable Bluetooth',
                desc: 'Make sure Bluetooth is on in your phone settings',
                color: color),
              _Step(num: '3',
                title: 'Stay close',
                desc: 'Keep your phone within 30 cm of the device',
                color: color),
              const SizedBox(height: 32),
              BMHButton(
                label: 'Scan for $title',
                color: color,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BleScanScreen(isScale: isScale))),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String num, title, desc;
  final Color color;
  const _Step({required this.num, required this.title, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Center(child: Text(num,
            style: BMHText.monoMd.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: BMHText.labelLg),
          const SizedBox(height: 3),
          Text(desc, style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
        ])),
      ]),
    );
  }
}
