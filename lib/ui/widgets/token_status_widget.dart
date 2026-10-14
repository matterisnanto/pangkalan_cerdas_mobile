import 'package:flutter/material.dart';

class TokenStatusWidget extends StatelessWidget {
  final bool isTokenAvailable;

  const TokenStatusWidget({super.key, required this.isTokenAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: isTokenAvailable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTokenAvailable ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTokenAvailable ? Icons.check_circle : Icons.error,
            color: isTokenAvailable ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isTokenAvailable ? 'Token Terdeteksi' : 'Token Kadaluarsa / Belum Ada',
            style: TextStyle(
              color: isTokenAvailable ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
