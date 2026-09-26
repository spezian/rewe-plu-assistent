import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'photo_plan_import.dart';

const maxPlanPhotoBytes = 4 * 1024 * 1024;

Future<PhotoPlanImport> recognizePlanPhoto({
  required SupabaseClient client,
  required String marketId,
  required Uint8List bytes,
}) async {
  if (bytes.isEmpty || bytes.length > maxPlanPhotoBytes) {
    throw const FormatException('Bitte ein Foto mit maximal 4 MB auswählen.');
  }
  final jpeg =
      bytes.length > 2 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final png =
      bytes.length > 8 && bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
  if (!jpeg && !png) {
    throw const FormatException('Bitte ein Foto als JPG oder PNG auswählen.');
  }
  try {
    final response = await client.functions
        .invoke(
          'parse-plan-photo',
          body: bytes,
          headers: {
            'Content-Type': jpeg ? 'image/jpeg' : 'image/png',
            'x-market-id': marketId,
          },
        )
        .timeout(const Duration(seconds: 100));
    if (response.data is! Map) {
      throw const FormatException(
        'Die Erkennung hat keine gültige Tabelle geliefert.',
      );
    }
    return parsePhotoPlanLayout(
      Map<String, dynamic>.from(response.data as Map),
    );
  } on FunctionException catch (error) {
    final details = error.details;
    final message = details is Map ? details['error'] : null;
    throw FormatException(
      message is String
          ? message
          : switch (error.status) {
              401 =>
                'Die Sitzung ist abgelaufen. Bitte den Markt erneut öffnen.',
              403 => 'Der Fotoimport ist nur mit Bearbeitungszugang möglich.',
              404 =>
                'Der Fotoimport ist auf dem Server noch nicht eingerichtet.',
              _ => 'Die Fotoerkennung ist derzeit nicht erreichbar. Bitte später erneut versuchen.',
            },
    );
  } on TimeoutException {
    throw const FormatException(
      'Die Fotoerkennung dauert zu lange. Bitte später erneut versuchen.',
    );
  }
}
