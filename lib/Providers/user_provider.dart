import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dryvmobapp/Models/app_user.dart';
import 'package:dryvmobapp/Providers/auth_provider.dart';
import 'package:dryvmobapp/Services/user_service.dart';

class CurrentUserController extends AsyncNotifier<AppUser> {
  @override
  FutureOr<AppUser> build() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.trim().isEmpty) {
      throw const UserServiceException('Not authenticated.');
    }

    final service = UserService();
    return service.fetchCurrentUser(token: token);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await ref.read(authTokenProvider.future);
      if (token == null || token.trim().isEmpty) {
        throw const UserServiceException('Not authenticated.');
      }

      final service = UserService();
      return service.fetchCurrentUser(token: token);
    });
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserController, AppUser>(
  CurrentUserController.new,
);
