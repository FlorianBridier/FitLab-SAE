// edit_profile.dart
import 'dart:io'; // Pour gérer le fichier image local
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Pour choisir la photo

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de texte
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;

  // États de chargement et erreur
  bool _isLoading = true;
  String? _errorMessage;

  // Variables pour la gestion de l'avatar
  File? _imageFile; // Image stockée localement après sélection
  String? _avatarUrl; // URL de l'avatar venant de Supabase
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// Charge les données du profil existant + l'avatar
  Future<void> _loadUserProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final userEmail = Supabase.instance.client.auth.currentUser?.email;

    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('name, weight_kg, height_cm, avatar_url') // On récupère aussi l'avatar
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _nameController.text = response['name'] ?? '';
          _emailController.text = userEmail ?? '';
          _weightController.text = (response['weight_kg'] ?? '').toString();
          _heightController.text = (response['height_cm'] ?? '').toString();
          _avatarUrl = response['avatar_url']; // Stockage de l'URL actuelle
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur de chargement : $e";
          _isLoading = false;
        });
      }
    }
  }

  /// Ouvre la galerie pour choisir une image
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Compression légère pour optimiser l'upload
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Erreur image picker: $e");
    }
  }

  /// Upload l'image et met à jour le profil utilisateur
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? newAvatarUrl = _avatarUrl;

      // 1. SI UNE NOUVELLE IMAGE EST CHOISIE, ON L'UPLOAD
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        // Nom de fichier unique pour éviter les conflits de cache
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = fileName;

        // Upload vers le bucket "avatars"
        await Supabase.instance.client.storage
            .from('avatars')
            .upload(filePath, _imageFile!, fileOptions: const FileOptions(upsert: true));

        // Récupération de l'URL publique
        newAvatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(filePath);
      }

      // 2. PRÉPARATION DES DONNÉES À METTRE À JOUR
      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'weight_kg': double.tryParse(_weightController.text),
        'height_cm': double.tryParse(_heightController.text),
        'avatar_url': newAvatarUrl, // Mise à jour de l'URL
        // J'ai supprimé 'updated_at' ici pour corriger ton erreur
      };

      // Recalcul du BMI
      final double? weight = updates['weight_kg'];
      final double? height = updates['height_cm'];

      if (weight != null && height != null && height > 0) {
        final double heightInMeters = height / 100.0;
        updates['bmi'] = weight / (heightInMeters * heightInMeters);
      } else {
        updates['bmi'] = null;
      }

      // 3. ENVOI A SUPABASE
      await Supabase.instance.client
          .from('users')
          .update(updates)
          .eq('user_id', userId);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(true); // Retour avec succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil mis à jour avec succès !"),
            backgroundColor: mainBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur lors de la mise à jour : $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logique d'affichage de l'image (Locale > Réseau > Placeholder)
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_avatarUrl!);
    } else {
      imageProvider = const AssetImage('assets/images/logo.png');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mainBlue))
          : CustomScrollView(
        slivers: [
          // --- 1. HEADER MODERNE ---
          SliverAppBar(
            expandedHeight: 120.0,
            backgroundColor: Colors.grey[50],
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkBlue, mainBlue, lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text(
                  "Modifier le Profil",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                background: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- 2. FORMULAIRE DANS UNE CARTE ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- AVATAR MODIFIABLE ---
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage, // Action au clic
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: mainBlue, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                backgroundImage: imageProvider,
                                child: (imageProvider is AssetImage && _avatarUrl == null)
                                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: mainBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- CARTE DES CHAMPS ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Informations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                          const SizedBox(height: 15),

                          _ModernTextField(
                            controller: _nameController,
                            label: "Nom complet",
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 15),

                          _ModernTextField(
                            controller: _emailController,
                            label: "Adresse email",
                            icon: Icons.email_outlined,
                            isReadOnly: true, // Email verrouillé
                          ),

                          const SizedBox(height: 25),
                          const Divider(),
                          const SizedBox(height: 25),

                          const Text("Mesures", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                          const SizedBox(height: 15),

                          // Poids et Taille côte à côte
                          Row(
                            children: [
                              Expanded(
                                child: _ModernTextField(
                                  controller: _weightController,
                                  label: "Poids (kg)",
                                  icon: Icons.monitor_weight_outlined,
                                  inputType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _ModernTextField(
                                  controller: _heightController,
                                  label: "Taille (cm)",
                                  icon: Icons.height,
                                  inputType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Message d'erreur
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),

                    const SizedBox(height: 40),

                    // Bouton Enregistrer
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: mainBlue.withOpacity(0.4),
                        ),
                        child: const Text("Enregistrer les modifications", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET CHAMP DE TEXTE DESIGN (Custom)
// -----------------------------------------------------------------------------
class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType inputType;
  final bool isReadOnly;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.inputType = TextInputType.text,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      readOnly: isReadOnly,
      style: TextStyle(
        color: isReadOnly ? Colors.grey[600] : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : mainBlue, size: 22),
        filled: true,
        fillColor: isReadOnly ? Colors.grey[100] : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mainBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      validator: (value) {
        if (!isReadOnly && (value == null || value.isEmpty)) {
          return 'Champ requis';
        }
        return null;
      },
    );
  }
}