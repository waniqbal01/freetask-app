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
    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
    checkNow();
  }

  final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _subscription;

  Future<void> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    _emitFromResult(result);
  }

  void _onChanged(ConnectivityResult result) {
    _emitFromResult(result);
  }

  void _emitFromResult(ConnectivityResult result) {
    final isOffline = result == ConnectivityResult.none;
    if (state.isOffline != isOffline) {
      emit(state.copyWith(isOffline: isOffline));
    }
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
