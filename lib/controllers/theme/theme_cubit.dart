import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/storage_service.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._storage, {ThemeMode? initialMode})
      : super(initialMode ?? ThemeMode.system);

  final StorageService _storage;

  Future<void> updateTheme(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _storage.saveThemeMode(mode);
  }
}
