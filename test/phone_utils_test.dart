import 'package:flutter_test/flutter_test.dart';
import 'package:khedmet_osret_thanawy/core/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize', () {
    test('محلي مصري', () => expect(PhoneUtils.normalize('01012345678'), '+201012345678'));
    test('مع مسافات وشرطات', () => expect(PhoneUtils.normalize('010 1234-5678'), '+201012345678'));
    test('أرقام عربية', () => expect(PhoneUtils.normalize('٠١٠١٢٣٤٥٦٧٨'), '+201012345678'));
    test('+20', () => expect(PhoneUtils.normalize('+20 10 1234 5678'), '+201012345678'));
    test('0020', () => expect(PhoneUtils.normalize('00201012345678'), '+201012345678'));
    test('20 بدون +', () => expect(PhoneUtils.normalize('201012345678'), '+201012345678'));
    test('دولي غير مصري', () => expect(PhoneUtils.normalize('+14155550123'), '+14155550123'));
    test('رقم قصير مرفوض', () => expect(PhoneUtils.normalize('0101234'), isNull));
    test('شبكة غير مصرية مرفوضة', () => expect(PhoneUtils.normalize('01312345678'), isNull));
    test('نص فارغ', () => expect(PhoneUtils.normalize('  '), isNull));
  });

  test('نفس الرقم بصيغ مختلفة = نفس البريد الداخلي', () {
    final a = PhoneUtils.internalEmail(PhoneUtils.normalize('01012345678')!);
    final b = PhoneUtils.internalEmail(PhoneUtils.normalize('+20 101 234 5678')!);
    expect(a, b);
    expect(a.contains('1012345678'), isFalse);
  });

  test('عرض محلي', () => expect(PhoneUtils.display('+201012345678'), '01012345678'));
}
