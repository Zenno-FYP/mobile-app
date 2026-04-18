import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/presentation/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _githubController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _twitterController;
  File? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.description ?? '');
    _githubController = TextEditingController(text: user?.githubUrl ?? '');
    _linkedinController = TextEditingController(text: user?.linkedinUrl ?? '');
    _twitterController = TextEditingController(text: user?.twitterUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image != null) setState(() { _newPhoto = File(image.path); _removePhoto = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ds = ref.read(userRemoteDataSourceProvider);

      // Upload new photo if selected
      if (_newPhoto != null) {
        await ds.uploadProfilePhoto(_newPhoto!);
      }

      // Patch profile
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _bioController.text.trim(),
        'github_url': _githubController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'twitter_url': _twitterController.text.trim(),
        if (_removePhoto) 'remove_profile_photo': true,
      };
      await ds.patchProfile(data);

      // Refresh user
      await ref.read(authControllerProvider.notifier).fetchCurrentUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Photo
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  if (_newPhoto != null)
                    CircleAvatar(radius: 48, backgroundImage: FileImage(_newPhoto!))
                  else if (!_removePhoto)
                    AppAvatar(imageUrl: user?.profilePhoto, name: user?.name, size: 96)
                  else
                    AppAvatar(name: user?.name, size: 96),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? AppColors.darkBg : Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty && _newPhoto == null && !_removePhoto)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _removePhoto = true),
                child: const Text('Remove photo', style: TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            ),

          const SizedBox(height: 20),

          GlassCard(
            child: Column(
              children: [
                _field('Name', _nameController),
                const SizedBox(height: 12),
                _field('Bio', _bioController, maxLines: 3),
                const SizedBox(height: 12),
                _field('GitHub URL', _githubController, inputType: TextInputType.url),
                const SizedBox(height: 12),
                _field('LinkedIn URL', _linkedinController, inputType: TextInputType.url),
                const SizedBox(height: 12),
                _field('Twitter URL', _twitterController, inputType: TextInputType.url),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Email: ${user?.email ?? ''}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String hint, TextEditingController controller, {int maxLines = 1, TextInputType? inputType}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
