// image_upload_helper.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Assurez-vous d'importer votre client Supabase

class ImageUploadHelper {
  // Le bucket où vous stockerez les avatars dans Supabase Storage
  static const String _avatarBucket = 'avatars'; 

  // Assurez-vous que ce bucket existe et est configuré dans Supabase Storage

  Future<String?> uploadAvatar(File imageFile, String userId) async {
    final fileExtension = imageFile.path.split('.').last;
    final fileName = '$userId.$fileExtension';
    final filePath = 'public/$fileName';

    try {
      // 1. Upload du fichier vers le bucket 'avatars'
      await supabase.storage.from(_avatarBucket).upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              // Définit la politique de remplacement si le fichier existe déjà
              upsert: true, 
            ),
          );

      // 2. Récupère l'URL publique de l'image pour la stocker dans la table 'users'
      final publicUrl = supabase.storage.from(_avatarBucket).getPublicUrl(filePath);
      
      return publicUrl;
      
    } on StorageException catch (e) {
      print('Erreur Supabase Storage lors de l\'upload: ${e.message}');
      return null;
    } catch (e) {
      print('Erreur inconnue lors de l\'upload: $e');
      return null;
    }
  }
}