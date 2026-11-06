import 'dart:async';

/// A value holder whose [stream] replays the current value to every new
/// listener and then follows later changes.
class LiveValue<T> {
  LiveValue(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast();

  T get value => _value;

  set value(T next) {
    _value = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  Stream<T> get stream => Stream<T>.multi((controller) {
        controller.add(_value);
        final sub = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  Future<void> close() => _changes.close();
}
