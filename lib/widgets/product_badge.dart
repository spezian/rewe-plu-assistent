import 'package:flutter/material.dart';
import 'package:rewe_plu_assistent/core/app_constants.dart';

class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key,
    required this.label,
    required this.icon,
    required this.background,
  });

  ProductBadge.bio({super.key}) : label = 'BIO', icon = Icons.eco, background = Colors.green[900]!;
  const ProductBadge.sale({super.key}) : label = 'AKTION', icon = Icons.local_offer, background = reweRed;

  final String label;
  final IconData icon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}