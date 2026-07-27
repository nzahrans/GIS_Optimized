import 'package:flutter/material.dart';

class BantuanStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const BantuanStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData icon;
    String textDisplay = status;

    if (status == 'Sudah Menerima') {
      badgeColor = Colors.orange;
      icon = Icons.check_circle_outline;
      textDisplay = 'Sudah Cair';
    } else if (status == 'Dikonfirmasi Warga') {
      badgeColor = Colors.green;
      icon = Icons.verified;
      textDisplay = 'Dikonfirmasi';
    } else {
      badgeColor = Colors.red;
      icon = Icons.hourglass_empty;
      textDisplay = 'Belum Cair';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: badgeColor,
            size: fontSize + 2.0,
          ),
          const SizedBox(width: 4),
          Text(
            textDisplay,
            style: TextStyle(
              color: badgeColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
