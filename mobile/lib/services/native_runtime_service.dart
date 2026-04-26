import 'dart:async';
import 'dart:math';

import '../models/geo_point.dart';

enum NativeRuntimeMode { standard, robust }

enum NativeSyncState { idle, syncing, retrying, paused }

class NativeRuntimeSnapshot {
  const NativeRuntimeSnapshot({
    required this.mode,
    required this.state,
    required this.isForeground,
    required this.hasSessionToken,
    required this.pendingSync,
    required this.retryAttempt,
    this.lastError,
  });

  factory NativeRuntimeSnapshot.initial({
    NativeRuntimeMode mode = NativeRuntimeMode.robust,
  }) {
    return NativeRuntimeSnapshot(
      mode: mode,
      state: NativeSyncState.idle,
      isForeground: true,
      hasSessionToken: false,
      pendingSync: false,
      retryAttempt: 0,
    );
  }

  final NativeRuntimeMode mode;
  final NativeSyncState state;
  final bool isForeground;
  final bool hasSessionToken;
  final bool pendingSync;
  final int retryAttempt;
  final String? lastError;

  String get modeLabel => switch (mode) {
    NativeRuntimeMode.standard => 'Padrão',
    NativeRuntimeMode.robust => 'Nativo robusto',
  };

  String get stateLabel => switch (state) {
    NativeSyncState.idle => 'Em espera',
    NativeSyncState.syncing => 'A sincronizar',
    NativeSyncState.retrying => 'Em retentativa',
    NativeSyncState.paused => 'Pausado em segundo plano',
  };
}

/// Coordena sincronizações críticas para um comportamento mais próximo de apps
/// nativas: fila coalescida, retentativas com backoff e pausa em background.
class NativeRuntimeService {
  NativeRuntimeService({
    NativeRuntimeMode mode = NativeRuntimeMode.robust,
    this.maxRetryAttempts = 6,
    this.retryBaseDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(seconds: 45),
  }) : _mode = mode,
       _snapshot = NativeRuntimeSnapshot.initial(mode: mode);

  final int maxRetryAttempts;
  final Duration retryBaseDelay;
  final Duration maxRetryDelay;

  NativeRuntimeMode _mode;
  NativeRuntimeSnapshot _snapshot;
  bool _isForeground = true;
  bool _isSyncing = false;
  int _retryAttempt = 0;
  String? _sessionToken;
  String? _lastError;
  GeoPoint? _pendingPoint;
  Timer? _retryTimer;
  Future<void> Function(GeoPoint point)? _sender;

  final StreamController<NativeRuntimeSnapshot> _snapshotController =
      StreamController<NativeRuntimeSnapshot>.broadcast();

  Stream<NativeRuntimeSnapshot> get snapshotStream =>
      _snapshotController.stream;
  NativeRuntimeSnapshot get snapshot => _snapshot;
  bool get isRobustMode => _mode == NativeRuntimeMode.robust;

  void setMode(NativeRuntimeMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    if (mode == NativeRuntimeMode.standard) {
      _cancelRetryTimer();
      _retryAttempt = 0;
    }

    _emitSnapshot(_resolveState());
    _drainQueue();
  }

  void setSessionToken(String? token) {
    final normalizedToken = (token ?? '').trim();
    _sessionToken = normalizedToken.isEmpty ? null : normalizedToken;

    if (_sessionToken == null) {
      _cancelRetryTimer();
      _pendingPoint = null;
      _retryAttempt = 0;
      _lastError = null;
    }

    _emitSnapshot(_resolveState());
    _drainQueue();
  }

  void updateForegroundState(bool isForeground) {
    if (_isForeground == isForeground) {
      return;
    }

    _isForeground = isForeground;
    _emitSnapshot(_resolveState());

    if (_isForeground) {
      _drainQueue();
    }
  }

  void scheduleLocationSync(
    GeoPoint point, {
    required Future<void> Function(GeoPoint point) sender,
  }) {
    _sender = sender;
    _pendingPoint = point;
    _emitSnapshot(_resolveState());
    _drainQueue();
  }

  void dispose() {
    _cancelRetryTimer();
    _snapshotController.close();
  }

  void _drainQueue() {
    if (_isSyncing || !_isForeground) {
      _emitSnapshot(_resolveState());
      return;
    }

    final token = _sessionToken;
    final point = _pendingPoint;
    final sender = _sender;

    if (token == null || point == null || sender == null) {
      _emitSnapshot(_resolveState());
      return;
    }

    _pendingPoint = null;
    _isSyncing = true;
    _emitSnapshot(NativeSyncState.syncing);
    unawaited(_syncPoint(point, sender));
  }

  Future<void> _syncPoint(
    GeoPoint point,
    Future<void> Function(GeoPoint point) sender,
  ) async {
    try {
      await sender(point);
      _lastError = null;
      _retryAttempt = 0;
    } catch (error) {
      _lastError = error.toString();
      _pendingPoint ??= point;

      if (_mode == NativeRuntimeMode.robust && _sessionToken != null) {
        _scheduleRetry();
      } else {
        _retryAttempt = 0;
      }
    } finally {
      _isSyncing = false;
      _emitSnapshot(_resolveState());
      if (_pendingPoint != null && _retryTimer == null) {
        _drainQueue();
      }
    }
  }

  void _scheduleRetry() {
    if (_retryAttempt >= maxRetryAttempts) {
      _lastError =
          'Falha de sincronização após $maxRetryAttempts tentativas consecutivas.';
      _retryAttempt = 0;
      _emitSnapshot(_resolveState());
      return;
    }

    _retryAttempt += 1;
    _cancelRetryTimer();

    final multiplier = pow(2, max(0, _retryAttempt - 1)).toInt();
    final delayInMilliseconds = min(
      retryBaseDelay.inMilliseconds * multiplier,
      maxRetryDelay.inMilliseconds,
    );

    _retryTimer = Timer(Duration(milliseconds: delayInMilliseconds), () {
      _retryTimer = null;
      _drainQueue();
    });

    _emitSnapshot(NativeSyncState.retrying);
  }

  NativeSyncState _resolveState() {
    if (_isSyncing) {
      return NativeSyncState.syncing;
    }

    if (_retryTimer != null && _pendingPoint != null) {
      return NativeSyncState.retrying;
    }

    if (!_isForeground && _pendingPoint != null) {
      return NativeSyncState.paused;
    }

    return NativeSyncState.idle;
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _emitSnapshot(NativeSyncState state) {
    _snapshot = NativeRuntimeSnapshot(
      mode: _mode,
      state: state,
      isForeground: _isForeground,
      hasSessionToken: _sessionToken != null,
      pendingSync: _pendingPoint != null,
      retryAttempt: _retryAttempt,
      lastError: _lastError,
    );

    if (!_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
  }
}
