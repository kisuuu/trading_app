import 'package:flutter/scheduler.dart';

/// Schedules a callback to run at most once per rendered frame.
///
/// The market feed produces ticks on its own clock — potentially hundreds per
/// second. Pushing each one straight into the widget tree would ask Flutter to
/// rebuild far more often than the display can show. Instead, ticks accumulate
/// into a dirty set and are flushed through this scheduler, so the UI does at
/// most one coalesced update per frame no matter how fast the feed runs.
///
/// Abstracted behind an interface so tests can flush deterministically without
/// pumping a real frame pipeline.
abstract interface class FrameScheduler {
  /// Requests [callback] on the next frame. Repeated calls before that frame
  /// arrives collapse into a single invocation.
  void schedule(VoidCallback callback);

  void dispose();
}

class WidgetsFrameScheduler implements FrameScheduler {
  bool _scheduled = false;
  bool _disposed = false;

  @override
  void schedule(VoidCallback callback) {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      callback();
    });
    // The app may be idle with no frame pending (nothing animating). Ask for
    // one so the post-frame callback actually runs.
    binding.scheduleFrame();
  }

  @override
  void dispose() => _disposed = true;
}

/// Test double: records the pending callback and runs it on demand.
class ManualFrameScheduler implements FrameScheduler {
  VoidCallback? _pending;

  bool get hasPendingFlush => _pending != null;

  @override
  void schedule(VoidCallback callback) => _pending ??= callback;

  /// Runs the pending callback, mimicking one frame.
  void flush() {
    final callback = _pending;
    _pending = null;
    callback?.call();
  }

  @override
  void dispose() => _pending = null;
}
