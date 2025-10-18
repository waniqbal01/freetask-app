import 'package:bloc/bloc.dart';

import '../../models/app_theme_mode.dart';
import '../../services/storage_service.dart';

class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit(this._storage, {AppThemeMode? initialMode})
      : super(initialMode ?? AppThemeMode.system);

  final StorageService _storage;

  Future<void> updateTheme(AppThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _storage.saveThemeMode(mode);
  }
}
