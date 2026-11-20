import 'dart:convert';
import 'package:crypto/crypto.dart';

/// تطبيع أرقام الهواتف وتحويلها إلى معرّف دخول داخلي.
///
/// رقم الهاتف هنا "معرّف دخول" فقط ولم يتم إثبات ملكيته (لا يوجد SMS).
class PhoneUtils {
  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  static String _latinDigits(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = _arabicIndic.indexOf(ch);
      final j = _persian.indexOf(ch);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
    }
    return b.toString();
  }

  static final _egMobileLocal = RegExp(r'^01[0125]\d{8}$');
  static final _egMobileIntl = RegExp(r'^1[0125]\d{8}$');

  /// يرجع الرقم بصيغة E.164 (مثل +201012345678) أو null إن كان غير صالح.
  static String? normalize(String input) {
    var s = _latinDigits(input.trim());
    var intl = s.startsWith('+');
    s = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('00')) {
      s = s.substring(2);
      intl = true;
    }
    if (!intl) {
      if (_egMobileLocal.hasMatch(s)) return '+20${s.substring(1)}';
      if (s.length == 12 && s.startsWith('20') && _egMobileIntl.hasMatch(s.substring(2))) {
        return '+$s';
      }
      return null;
    }
    if (s.startsWith('20')) {
      return _egMobileIntl.hasMatch(s.substring(2)) ? '+$s' : null;
    }
    if (s.length >= 8 && s.length <= 15 && !s.startsWith('0')) return '+$s';
    return null;
  }

  /// عرض الرقم بصيغة محلية للمصريين.
  static String display(String e164) =>
      e164.startsWith('+20') ? '0${e164.substring(3)}' : e164;

  /// البريد الداخلي المشتق: لا يُعرض للمستخدم ولا يحتوي الرقم صراحةً.
  static String internalEmail(String e164) {
    final h = sha256.convert(utf8.encode('khedmet-osra|$e164')).toString();
    return 'u${h.substring(0, 40)}@users.khedmet-osra.app';
  }
}
