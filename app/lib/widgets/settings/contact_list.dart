import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ContactList extends StatelessWidget {
  const ContactList({super.key});

  static const _whatsapp = '+923001234567';
  static const _phone = '+923001234567';
  static const _email = 'support@travelloai.pk';
  static const _address = 'Blue Area, Islamabad, Pakistan';
  static const _instagram = 'https://instagram.com/travelloai';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header info ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TravelloTheme.primaryMain.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.headset_mic_outlined,
                  color: TravelloTheme.primaryMain, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Need help? Reach our support team through any of the channels below. Available Mon–Sat, 9am–7pm PKT.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.75),
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Contact cards ──────────────────────────────────────────────
        _ContactCard(
          icon: FontAwesomeIcons.whatsapp,
          iconColor: const Color(0xFF25D366),
          iconBg: const Color(0xFFE8FBF0),
          title: _whatsapp,
          subtitle: 'WhatsApp — Fastest Response',
          onTap: () => _launch(
              'https://wa.me/${_whatsapp.replaceAll('+', '')}?text=Hello%20Travello%20AI%20Support'),
        ),
        _ContactCard(
          icon: Icons.phone_rounded,
          iconColor: Colors.blue.shade600,
          iconBg: Colors.blue.shade50,
          title: _phone,
          subtitle: 'Phone Call',
          onTap: () => _launch('tel:$_phone'),
        ),
        _ContactCard(
          icon: Icons.email_rounded,
          iconColor: Colors.teal.shade600,
          iconBg: Colors.teal.shade50,
          title: _email,
          subtitle: 'Email Support',
          onTap: () => _launch('mailto:$_email?subject=Support%20Request'),
        ),
        _ContactCard(
          icon: Icons.location_on_rounded,
          iconColor: Colors.red.shade500,
          iconBg: Colors.red.shade50,
          title: _address,
          subtitle: 'Headquarters',
          onTap: () => _launch(
              'https://maps.google.com/?q=Blue+Area+Islamabad+Pakistan'),
        ),
        _ContactCard(
          icon: FontAwesomeIcons.instagram,
          iconColor: Colors.purple.shade500,
          iconBg: Colors.purple.shade50,
          title: '@travelloai',
          subtitle: 'Instagram',
          onTap: () => _launch(_instagram),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
