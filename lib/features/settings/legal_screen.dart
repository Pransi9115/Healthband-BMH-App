import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';

/// ─────────────────────────────────────────────────────────
///  LEGAL — Privacy Policy & Terms of Service
///
///  NOTE FOR THE TEAM: this content is a solid starting
///  template tailored to a health-band app, but health-data
///  privacy has real legal requirements that vary by region.
///  Have a qualified lawyer review before public release.
/// ─────────────────────────────────────────────────────────

enum LegalKind { privacy, terms }

class LegalScreen extends StatelessWidget {
  final LegalKind kind;
  const LegalScreen({super.key, required this.kind});

  bool get _isPrivacy => kind == LegalKind.privacy;

  @override
  Widget build(BuildContext context) {
    final sections = _isPrivacy ? _privacySections : _termsSections;
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 3),
      body: SafeArea(bottom: false, child: Column(children: [
        // ── HEADER with back button ───────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH, vertical: 8),
          child: Row(children: [
            BMHIconButton(onTap: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                color: BMHColors.ink, size: 16)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BMHEyebrow('Bio Medical Healthcare'),
                Text(_isPrivacy ? 'Privacy Policy' : 'Terms of Service',
                  style: BMHText.heading1.copyWith(fontSize: 24)),
              ])),
          ])),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Last updated: July 2026',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute)),
              const SizedBox(height: 16),
              ...sections.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(s.$1, style: BMHText.heading2.copyWith(
                    fontSize: 15, color: BMHColors.cyan)),
                  const SizedBox(height: 8),
                  Text(s.$2, style: BMHText.bodySm.copyWith(
                    color: BMHColors.ink2, height: 1.65)),
                ]))),
              const SizedBox(height: 120),
            ]))),
      ])),
    );
  }
}

// ── PRIVACY POLICY ────────────────────────────────────────
const List<(String, String)> _privacySections = [
  ('1. Introduction',
   'Bio Medical Healthcare ("BMH", "we", "our") is committed to '
   'protecting your privacy. This policy explains what information '
   'the BMH app collects, how it is used, and the choices you have. '
   'By using the app you agree to the practices described here.'),
  ('2. Information We Collect',
   'Account information: your name and email address, provided when '
   'you create an account.\n\n'
   'Health and sensor data: measurements collected from your '
   'connected health band and BioScale, including heart rate, heart '
   'rate variability, blood oxygen (SpO₂), skin temperature, blood '
   'pressure estimates, stress score, sleep data, steps, calories, '
   'distance, and body-composition metrics.\n\n'
   'Manually entered data: readings you type in yourself, such as '
   'manual blood glucose entries and daily check-ins.\n\n'
   'Device information: the Bluetooth identifier, name and battery '
   'level of your paired devices, used solely to maintain your '
   'connection.'),
  ('3. How Your Data Is Used',
   'Your data is used to display your health measurements and '
   'trends, calculate wellness scores and insights, keep your '
   'devices connected and synced, and personalize your experience '
   '(for example, greeting you by name). We do not sell your '
   'personal or health data to third parties, and we do not use '
   'your health data for advertising.'),
  ('4. Where Your Data Is Stored',
   'Your health measurements and preferences are stored locally on '
   'your device. Login credentials are protected using the '
   'platform\'s secure storage (iOS Keychain / Android Keystore). '
   'If you enable Apple Health or Google Health Connect sync, the '
   'data you authorize is shared with those services under their '
   'own privacy policies and your device permission settings.'),
  ('5. Apple Health & Google Health Connect',
   'Syncing with Apple Health or Google Health Connect is entirely '
   'optional and controlled by you. You choose which data types to '
   'share, and you can revoke access at any time in your device '
   'settings. Data received from these services is used only to '
   'display and enrich your health insights inside the app.'),
  ('6. Bluetooth & Location',
   'The app uses Bluetooth to communicate with your health band and '
   'BioScale. On some Android versions, the operating system '
   'requires location permission to scan for Bluetooth devices; we '
   'do not track or store your geographic location.'),
  ('7. Data Retention & Deletion',
   'Health history is retained on your device for up to 90 days for '
   'trend charts. You can delete your data at any time by removing '
   'the app or using the sign-out and device-forget options. '
   'Contact us to request deletion of any account information.'),
  ('8. Children\'s Privacy',
   'The BMH app is not directed at children under 13 (or the '
   'applicable minimum age in your region), and we do not knowingly '
   'collect data from them.'),
  ('9. Not a Medical Device',
   'BMH readings are for general wellness purposes and are not '
   'intended to diagnose, treat, cure or prevent any disease. '
   'Always consult a qualified healthcare professional about '
   'medical concerns.'),
  ('10. Changes & Contact',
   'We may update this policy from time to time; material changes '
   'will be communicated in the app. For privacy questions or '
   'requests, contact the Bio Medical Healthcare support team '
   'through the app or our website.'),
];

// ── TERMS OF SERVICE ──────────────────────────────────────
const List<(String, String)> _termsSections = [
  ('1. Acceptance of Terms',
   'By creating an account or using the Bio Medical Healthcare '
   '("BMH") app, you agree to these Terms of Service. If you do '
   'not agree, please do not use the app.'),
  ('2. The Service',
   'BMH provides tools to view, track and understand health '
   'measurements collected from compatible wearable devices and '
   'smart scales, alongside wellness content such as breathing '
   'programs and exercise guidance.'),
  ('3. Not Medical Advice',
   'The app, its measurements, scores and content are provided for '
   'general wellness and informational purposes only. They are not '
   'medical advice, and the app is not a medical device. Never '
   'disregard professional medical advice or delay seeking it '
   'because of something you read or measured in the app. If you '
   'believe you are experiencing a medical emergency, contact '
   'emergency services immediately.'),
  ('4. Your Account',
   'You are responsible for keeping your login credentials secure '
   'and for all activity under your account. Provide accurate '
   'information and keep it up to date. You may sign out or stop '
   'using the service at any time.'),
  ('5. Acceptable Use',
   'You agree not to misuse the service — including attempting to '
   'access it by unauthorized means, interfering with its '
   'operation, reverse-engineering the app, or using it in any '
   'unlawful way.'),
  ('6. Devices & Measurement Accuracy',
   'Measurements depend on correct device wear, skin contact, '
   'device condition and other factors. Readings from consumer '
   'wearables are estimates and may differ from clinical-grade '
   'equipment. Exercise programs are followed at your own risk — '
   'consult your doctor before beginning a new exercise routine, '
   'particularly the Senior Biocare programs if you have existing '
   'health conditions.'),
  ('7. Intellectual Property',
   'The app, its design, content and trademarks (including '
   'Women\'s Biocare™ and Senior Biocare™) belong to Bio Medical '
   'Healthcare or its licensors. You receive a personal, '
   'non-transferable licence to use the app; no other rights are '
   'granted.'),
  ('8. Limitation of Liability',
   'To the maximum extent permitted by law, BMH is provided "as '
   'is" without warranties of any kind, and Bio Medical Healthcare '
   'is not liable for indirect, incidental or consequential damages '
   'arising from your use of the app or reliance on its readings.'),
  ('9. Changes to the Service or Terms',
   'We may update the app and these terms over time. Continued use '
   'after changes take effect constitutes acceptance of the updated '
   'terms. Material changes will be communicated in the app.'),
  ('10. Contact',
   'Questions about these terms can be sent to the Bio Medical '
   'Healthcare support team through the app or our website.'),
];
