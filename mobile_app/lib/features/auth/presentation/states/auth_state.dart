import '../../domain/entities/user_entity.dart';

class AuthState {
  final UserEntity? user;

  const AuthState({this.user});

  const AuthState.initial() : user = null;

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserEntity? user, bool clearUser = false}) {
    return AuthState(user: clearUser ? null : user ?? this.user);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthState && other.user == user;

  @override
  int get hashCode => user.hashCode;
}
