import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/user_model.dart';

class UserRemoteDataSource {
  UserRemoteDataSource(this._client);
  final ApiClient _client;

  Future<UserModel> getMe() async {
    final response = await _client.get('/user/me');
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<UserModel> createProfile({
    required String email,
    required String name,
    File? profilePhoto,
  }) async {
    final formData = FormData.fromMap({
      'email': email,
      'name': name,
      if (profilePhoto != null)
        'profilePhoto': await MultipartFile.fromFile(
          profilePhoto.path,
          filename: profilePhoto.path.split('/').last,
        ),
    });
    final response = await _client.put('/user/me', data: formData);
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<UserModel> patchProfile(Map<String, dynamic> data) async {
    final response = await _client.patch('/user/me', data: data);
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<UserModel> uploadProfilePhoto(File file) async {
    final formData = FormData.fromMap({
      'profilePhoto': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final response = await _client.post('/user/me/profile-photo', data: formData);
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }
}
