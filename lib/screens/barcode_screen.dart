import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/product.dart';

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({
    required this.product,
    required this.code,
    this.isObsolete = false,
    super.key,
  });

  final Product product;
  final ProductCode code;
  final bool isObsolete;

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.product.name),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              if (widget.isObsolete)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Achtung: Dieser Code ist als veraltet markiert.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                widget.code.type.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.code.displayValue,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 190,
                width: double.infinity,
                child: BarcodeWidget(
                  barcode: _barcodeFor(widget.code),
                  data: widget.code.value,
                  drawText: false,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  errorBuilder: (context, error) => Center(
                    child: Text(
                      'Barcode kann nicht erzeugt werden:\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Scanner mittig auf den Barcode richten',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Schließen'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Barcode _barcodeFor(ProductCode code) {
    if (code.type == ProductCodeType.barcode) {
      if (RegExp(r'^\d{13}$').hasMatch(code.value)) return Barcode.ean13();
      if (RegExp(r'^\d{8}$').hasMatch(code.value)) return Barcode.ean8();
      if (RegExp(r'^\d{12}$').hasMatch(code.value)) return Barcode.upcA();
    }
    return Barcode.code128();
  }
}
