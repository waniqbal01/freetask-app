part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileStarted extends ProfileEvent {
  const ProfileStarted({this.initialUser, this.forceReadOnly = false});

  final User? initialUser;
  final bool forceReadOnly;

  @override
  List<Object?> get props => [initialUser, forceReadOnly];
}

class ProfileRefreshed extends ProfileEvent {
  const ProfileRefreshed({this.silent = false});

  final bool silent;

  @override
  List<Object?> get props => [silent];
}

class ProfileSubmitted extends ProfileEvent {
  const ProfileSubmitted({
    required this.name,
    required this.email,
    this.bio,
    this.location,
    this.phoneNumber,
  });

  final String name;
  final String email;
  final String? bio;
  final String? location;
  final String? phoneNumber;

  @override
  List<Object?> get props => [name, email, bio, location, phoneNumber];
}

class ProfileAvatarUploadRequested extends ProfileEvent {
  const ProfileAvatarUploadRequested({
    required this.file,
    this.skipRefresh = false,
  });

  final File file;
  final bool skipRefresh;

  @override
  List<Object?> get props => [file.path, skipRefresh];
}

class ProfileMessageCleared extends ProfileEvent {
  const ProfileMessageCleared();
}
