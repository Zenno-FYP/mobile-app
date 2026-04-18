import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/user_model.dart';
import '../data/auth_repository.dart';
import '../data/user_remote_ds.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onForceLogout: () => ref.read(authRepositoryProvider).signOut(),
  );
});

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource(ref.watch(apiClientProvider));
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = StateProvider<UserModel?>((ref) => null);

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;
  AuthRepository get _auth => _ref.read(authRepositoryProvider);
  UserRemoteDataSource get _userDs => _ref.read(userRemoteDataSourceProvider);

  Future<bool> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _auth.signInWithEmail(email, password);
      final user = await _userDs.getMe();
      _ref.read(currentUserProvider.notifier).state = user;
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(_mapFirebaseError(e), st);
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    File? profilePhoto,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _auth.signUpWithEmail(email, password);
      await _userDs.createProfile(
        email: email,
        name: name,
        profilePhoto: profilePhoto,
      );
      await _auth.sendVerificationEmail();
      await _auth.signOut();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(_mapFirebaseError(e), st);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.signInWithGoogle();
      final firebaseUser = credential.user!;
      await _userDs.createProfile(
        email: firebaseUser.email!,
        name: firebaseUser.displayName ?? firebaseUser.email!.split('@').first,
      );
      final user = await _userDs.getMe();
      _ref.read(currentUserProvider.notifier).state = user;
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(_mapFirebaseError(e), st);
      return false;
    }
  }

  Future<bool> signInWithGitHub() async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.signInWithGitHub();
      final firebaseUser = credential.user!;
      await _userDs.createProfile(
        email: firebaseUser.email ?? '${firebaseUser.uid}@github.user',
        name: firebaseUser.displayName ?? 'GitHub User',
      );
      final user = await _userDs.getMe();
      _ref.read(currentUserProvider.notifier).state = user;
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(_mapFirebaseError(e), st);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncValue.loading();
    try {
      await _auth.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(_mapFirebaseError(e), st);
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    await _auth.sendVerificationEmail();
  }

  Future<bool> checkEmailVerified() async {
    await _auth.reloadUser();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    _ref.read(currentUserProvider.notifier).state = null;
    await _auth.signOut();
  }

  Future<void> fetchCurrentUser() async {
    try {
      final user = await _userDs.getMe();
      _ref.read(currentUserProvider.notifier).state = user;
    } catch (_) {}
  }

  String _mapFirebaseError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password.',
        'email-already-in-use' => 'An account with this email already exists.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password must be at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'user-disabled' => 'This account has been disabled.',
        'operation-not-allowed' => 'This sign-in method is not enabled.',
        'invalid-credential' => 'Invalid email or password.',
        _ => e.message ?? 'Authentication failed.',
      };
    }
    return e.toString();
  }
}
