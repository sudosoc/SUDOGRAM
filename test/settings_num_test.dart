import 'package:flutter_test/flutter_test.dart';
import 'package:sudogram/domain/models.dart';

void main() {
  test('AuthState withError keeps step', () {
    const s = AuthState(AuthStep.waitCode);
    final e = s.withError('x');
    expect(e.step, AuthStep.waitCode);
    expect(e.error, 'x');
  });
}
