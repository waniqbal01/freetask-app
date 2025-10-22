import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';

import '../../models/user.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._profileService, this._storage)
      : super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileRefreshed>(_onRefreshed);
    on<ProfileSubmitted>(_onSubmitted);
    on<ProfileAvatarUploadRequested>(_onAvatarUploadRequested);
    on<ProfileMessageCleared>(_onMessageCleared);
  }

  final ProfileService _profileService;
  final StorageService _storage;

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    final cachedUser = event.initialUser ?? _storage.getUser();
    final currentUserId = _storage.getUser()?.id;
    final cachedUserId = cachedUser?.id;
    final isOwnProfile = event.forceReadOnly
        ? false
        : (cachedUserId == null || cachedUserId == currentUserId);
    emit(
      state.copyWith(
        user: cachedUser,
        isReadOnly: event.forceReadOnly || !isOwnProfile,
        isLoading: cachedUser == null,
        clearMessages: true,
      ),
    );

    if (state.isReadOnly) {
      return;
    }

    try {
      final user = await _profileService.fetchCurrentUser();
      emit(
        state.copyWith(
          user: user,
          isLoading: false,
          lastSyncedAt: DateTime.now(),
          clearMessages: true,
        ),
      );
    } on ProfileException catch (error, stackTrace) {
      AppLogger.e('Profile load failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error loading profile', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load your profile at the moment.',
        ),
      );
    }
  }

  Future<void> _onRefreshed(
    ProfileRefreshed event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isReadOnly) {
      return;
    }
    emit(state.copyWith(isRefreshing: true, clearMessages: true));
    try {
      final user = await _profileService.fetchCurrentUser();
      emit(
        state.copyWith(
          user: user,
          isRefreshing: false,
          lastSyncedAt: DateTime.now(),
          successMessage: event.silent
              ? null
              : 'Profile synced successfully.',
        ),
      );
    } on ProfileException catch (error, stackTrace) {
      AppLogger.e('Profile refresh failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isRefreshing: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error refreshing profile', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isRefreshing: false,
          errorMessage: 'Unable to refresh profile right now.',
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    ProfileSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isReadOnly || state.isSaving) {
      return;
    }
    emit(
      state.copyWith(
        isSaving: true,
        clearMessages: true,
      ),
    );
    try {
      final user = await _profileService.updateProfile(
        name: event.name,
        email: event.email,
        bio: event.bio,
        location: event.location,
        phoneNumber: event.phoneNumber,
      );
      emit(
        state.copyWith(
          user: user,
          isSaving: false,
          successMessage: 'Profile updated successfully!',
          lastSyncedAt: DateTime.now(),
        ),
      );
      add(const ProfileRefreshed(silent: true));
    } on ProfileException catch (error, stackTrace) {
      AppLogger.e('Profile update failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error updating profile', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Unable to update profile. Please try again later.',
        ),
      );
    }
  }

  Future<void> _onAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.isReadOnly || state.isUploadingAvatar) {
      return;
    }
    emit(
      state.copyWith(
        isUploadingAvatar: true,
        clearMessages: true,
      ),
    );
    try {
      final url = await _profileService.uploadAvatar(event.file);
      User? updatedUser = state.user;
      if (updatedUser != null && url != null) {
        updatedUser = updatedUser.copyWith(avatarUrl: url);
      }
      emit(
        state.copyWith(
          user: updatedUser,
          isUploadingAvatar: false,
          successMessage: 'Profile picture updated.',
          lastSyncedAt: DateTime.now(),
        ),
      );
      if (!event.skipRefresh) {
        add(const ProfileRefreshed(silent: true));
      }
    } on ProfileException catch (error, stackTrace) {
      AppLogger.e('Avatar upload failed', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isUploadingAvatar: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error uploading avatar', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isUploadingAvatar: false,
          errorMessage: 'Unable to upload avatar. Please try again.',
        ),
      );
    }
  }

  void _onMessageCleared(
    ProfileMessageCleared event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(clearMessages: true));
  }
}

