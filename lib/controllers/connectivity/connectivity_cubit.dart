import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tracks network reachability and exposes a simple `isOffline` flag that the
/// UI can react to. The cubit subscribes to the `connectivity_plus` stream and
/// debounces duplicate events so that we avoid unnecessary rebuilds.
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit(this._connectivity)
      : super(const ConnectivityState(isOffline: false)) {
    _subscription =
        _connectivity.onConnectivityChanged.listen(_onChanged);
    checkNow();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> checkNow() async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    final effective = _effectiveResult(results);
    _emitFromResult(effective);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final effective = _effectiveResult(results);
    _emitFromResult(effective);
  }

  void _emitFromResult(ConnectivityResult result) {
    final isOffline = result == ConnectivityResult.none;
    if (state.isOffline != isOffline) {
      emit(state.copyWith(isOffline: isOffline));
    }
  }

  ConnectivityResult _effectiveResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;

    const priorityOrder = <ConnectivityResult>[
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
      ConnectivityResult.bluetooth,
      ConnectivityResult.other,
      ConnectivityResult.none,
    ];

    for (final type in priorityOrder) {
      if (results.contains(type)) {
        return type;
      }
    }

    return ConnectivityResult.none;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class ConnectivityState extends Equatable {
  const ConnectivityState({required this.isOffline});

  final bool isOffline;

  ConnectivityState copyWith({bool? isOffline}) {
    return ConnectivityState(isOffline: isOffline ?? this.isOffline);
  }

  @override
  List<Object?> get props => [isOffline];
}
