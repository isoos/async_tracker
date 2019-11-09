import 'dart:async';

/// Tracks async callbacks (e.g. microtask, [Future], [Stream], [Timer]) and
/// indicates when any of these has completed their executions.
/// It can be used to track and react on async event chains.
///
/// Clients of the [AsyncTracker] either listen on the [stream] or they can
/// add or remove listeners that receive these events.
class AsyncTracker {
  final Duration _duration;
  Zone _parent;
  Zone _tracked;

  bool _scheduled = false;
  Timer _timer;

  final _callbacks = <Function>[];
  final _controller = StreamController.broadcast();

  int _microtaskCount = 0;
  int _runningCount = 0;

  /// When [duration] is specified, the tracking event is schedule via a [Timer]
  /// in the original [zone], otherwise it is scheduled via a microtask.
  AsyncTracker({Zone zone, Duration duration}) : _duration = duration {
    _parent = zone ?? Zone.current;
    _tracked = _parent.fork(
      specification: ZoneSpecification(
        scheduleMicrotask: _scheduleMicrotask,
        run: _run,
        runUnary: _runUnary,
        runBinary: _runBinary,
        createTimer: _createTimer,
      ),
    );
  }

  Zone get parentZone => _parent;
  Zone get trackedZone => _tracked;

  Stream get stream => _controller.stream;

  /// Runs [fn] in the tracked zone.
  R run<R>(R fn()) => trackedZone.run(fn);

  /// Add event listener that will get called when the tracker emits an event.
  void addListener(Function callback) {
    if (_controller.isClosed) {
      throw StateError('Closed.');
    }
    _callbacks.add(callback);
  }

  /// Remove previously added event listener.
  void removeListener(Function callback) {
    _callbacks.remove(callback);
  }

  /// Closes the tracker and doesn't accept new listeners.
  Future close() async {
    _callbacks.clear();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  /// Whether currently it has a running or scheduled code that will be executed
  /// in the current turn.
  bool get isActive => _runningCount > 0 || _microtaskCount > 0;

  bool get _hasListener => _callbacks.isNotEmpty || _controller.hasListener;

  void _scheduleMicrotask(Zone self, ZoneDelegate parent, Zone zone, void f()) {
    _microtaskCount++;
    final task = () {
      try {
        f();
      } finally {
        _microtaskCount--;
        _trigger();
      }
    };
    parent.scheduleMicrotask(zone, task);
  }

  R _run<R>(Zone self, ZoneDelegate parent, Zone zone, R fn()) {
    try {
      _runningCount++;
      return parent.run(zone, fn);
    } finally {
      _runningCount--;
      _trigger();
    }
  }

  R _runUnary<R, T>(
      Zone self, ZoneDelegate parent, Zone zone, R fn(T arg), T arg) {
    try {
      _runningCount++;
      return parent.runUnary(zone, fn, arg);
    } finally {
      _runningCount--;
      _trigger();
    }
  }

  R _runBinary<R, T1, T2>(Zone self, ZoneDelegate parent, Zone zone,
      R fn(T1 arg1, T2 arg2), T1 arg1, T2 arg2) {
    try {
      _runningCount++;
      return parent.runBinary(zone, fn, arg1, arg2);
    } finally {
      _runningCount--;
      _trigger();
    }
  }

  Timer _createTimer(
      Zone self, ZoneDelegate parent, Zone zone, Duration duration, fn()) {
    final wrappedFn = () {
      try {
        _runningCount++;
        fn();
      } finally {
        _runningCount--;
        _trigger();
      }
    };
    return parent.createTimer(zone, duration, wrappedFn);
  }

  void _trigger() {
    if (isActive || !_hasListener || _scheduled) return;
    if (_duration == null) {
      _scheduled = true;
      _parent.scheduleMicrotask(_publishEvent);
    } else if (_timer == null) {
      _scheduled = true;
      _timer = Timer(_duration, _publishEvent);
    }
  }

  void _publishEvent() {
    _scheduled = false;
    _timer = null;
    if (isActive || !_hasListener) return;
    if (!_controller.isClosed && _controller.hasListener) {
      _controller.add(null);
    }
    _callbacks.forEach((fn) => fn());
  }
}
