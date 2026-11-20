import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'constants.dart';

/// يختار صورة ويضغطها إلى مربع صغير (JPEG) ويرجعها كـ data URI.
/// الحد الأقصى [AppConfig.maxPhotoBytes] (180KB) لتبقى بعيدة عن حد 1MiB لمستند Firestore.
Future<String?> pickProfilePhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 92,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final out = await compute(_compress, bytes);
  if (out == null) throw Exception('تعذر قراءة الصورة');
  return 'data:image/jpeg;base64,${base64Encode(out)}';
}

Uint8List? _compress(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  image = img.bakeOrientation(image);
  for (final size in [400, 320, 256, 192]) {
    final square = img.copyResizeCropSquare(image, size: size);
    for (var q = 85; q >= 40; q -= 15) {
      final jpg = Uint8List.fromList(img.encodeJpg(square, quality: q));
      if (jpg.length <= AppConfig.maxPhotoBytes) return jpg;
    }
  }
  return null;
}
