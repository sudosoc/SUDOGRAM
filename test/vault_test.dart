import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/data/vault/vault_store.dart';

void main() {
  test('real and decoy passcodes open different data; wrong one opens nothing',
      () {
    final dir = Directory.systemTemp.createTempSync('vault').path;
    final v = VaultService(dir, 'salt');
    expect(v.isSetUp, isFalse);
    v.setUp('1111', '2222', decoyItems: [('Shopping', 'milk')]);
    expect(v.isSetUp, isTrue);

    final real = v.unlock('1111')!;
    real.add('Secret', 'x');
    expect(real.items().single.title, 'Secret');
    real.close();

    final decoy = v.unlock('2222')!;
    expect(decoy.items().single.title, 'Shopping');
    decoy.close();

    expect(v.unlock('9999'), isNull);
    // Persisted: reopening the real one still has the secret.
    final again = v.unlock('1111')!;
    expect(again.items().single.title, 'Secret');
    again.close();
    Directory(dir).deleteSync(recursive: true);
  });

  test('identical passcodes are rejected', () {
    final dir = Directory.systemTemp.createTempSync('vault2').path;
    expect(() => VaultService(dir, 's').setUp('1', '1'), throwsArgumentError);
    Directory(dir).deleteSync(recursive: true);
  });
}
