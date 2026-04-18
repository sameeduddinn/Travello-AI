import 'package:flutter/material.dart';

class EmailStatusBanner extends StatelessWidget {
  final String message;
  final bool isWarning;
  final Animation<double>? fadeAnimation;

  const EmailStatusBanner({
    super.key,
    required this.message,
    required this.isWarning,
    this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isWarning ? const Color(0xFFFFF7E8) : const Color(0xFFEAF8F0);
    final border =
        isWarning ? const Color(0xFFF4C97A) : const Color(0xFF7BC79A);
    final iconColor =
        isWarning ? const Color(0xFF9A6700) : const Color(0xFF1E7A45);

    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.info_outline : Icons.mark_email_read_outlined,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (fadeAnimation != null) {
      return FadeTransition(opacity: fadeAnimation!, child: child);
    }

    return child;
  }
}
