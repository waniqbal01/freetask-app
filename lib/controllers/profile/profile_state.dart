part of 'profile_bloc.dart';

const _sentinel = Object();

class ProfileState extends Equatable {
  const ProfileState({
    this.user,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isSaving = false,
    this.isUploadingAvatar = false,
    this.isReadOnly = false,
    this.errorMessage,
    this.successMessage,
    this.lastSyncedAt,
  });

  final User? user;
  final bool isLoading;
  final bool isRefreshing;
  final bool isSaving;
  final bool isUploadingAvatar;
  final bool isReadOnly;
  final String? errorMessage;
  final String? successMessage;
  final DateTime? lastSyncedAt;

  ProfileState copyWith({
    User? user,
    bool? isLoading,
    bool? isRefreshing,
    bool? isSaving,
    bool? isUploadingAvatar,
    bool? isReadOnly,
    Object? errorMessage = _sentinel,
    Object? successMessage = _sentinel,
    DateTime? lastSyncedAt,
    bool clearMessages = false,
  }) {
    return ProfileState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      errorMessage: clearMessages
          ? null
          : errorMessage == _sentinel
              ? this.errorMessage
              : errorMessage as String?,
      successMessage: clearMessages
          ? null
          : successMessage == _sentinel
              ? this.successMessage
              : successMessage as String?,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [
        user,
        isLoading,
        isRefreshing,
        isSaving,
        isUploadingAvatar,
        isReadOnly,
        errorMessage,
        successMessage,
        lastSyncedAt,
      ];
}
