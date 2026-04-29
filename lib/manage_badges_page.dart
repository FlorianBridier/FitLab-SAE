// manage_badges_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';

// COULEURS FITLAB
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class ManageBadgesPage extends StatefulWidget {
  const ManageBadgesPage({super.key});

  @override
  State<ManageBadgesPage> createState() => _ManageBadgesPageState();
}

class _ManageBadgesPageState extends State<ManageBadgesPage> {
  // CONFIGURATION SUPABASE
  static const String badgesTable = 'badges';
  static const String storageBucket = 'badges'; // Le nom exact de ton bucket

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  XFile? _selectedImage;
  List<Map<String, dynamic>> _badges = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchBadges();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- LOGIQUE SUPABASE ---

  Future<void> _fetchBadges() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from(badgesTable)
          .select()
          .order('badge_id', ascending: false);

      if (mounted) {
        setState(() {
          _badges = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('Erreur chargement: $e', isError: true);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showSnackBar("Erreur sélection image");
    }
  }

  Future<String?> _uploadImage(XFile image) async {
    try {
      // Nom unique pour l'image
      final String fileName = 'badge_${DateTime.now().millisecondsSinceEpoch}.${image.name.split('.').last}';

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await Supabase.instance.client.storage.from(storageBucket).uploadBinary(fileName, bytes);
      } else {
        await Supabase.instance.client.storage.from(storageBucket).upload(fileName, File(image.path));
      }
      return Supabase.instance.client.storage.from(storageBucket).getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Erreur upload: $e");
      return null;
    }
  }

  Future<void> _createBadge() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showSnackBar('Une image est requise pour le badge.', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      // 1. Upload de l'image
      String? imageUrl = await _uploadImage(_selectedImage!);
      if (imageUrl == null) throw "L'upload de l'image a échoué.";

      // 2. Insertion dans la table badges
      await Supabase.instance.client.from(badgesTable).insert({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'image_url': imageUrl, // Assure-toi d'avoir créé cette colonne !
      });

      _showSnackBar('Badge créé avec succès !');
      _resetForm();
      await _fetchBadges();
    } catch (e) {
      _showSnackBar("Erreur création: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteBadge(int badgeId) async {
    try {
      await Supabase.instance.client.from(badgesTable).delete().eq('badge_id', badgeId);
      _showSnackBar('Badge supprimé.');
      await _fetchBadges();
    } catch (e) {
      _showSnackBar('Erreur suppression.', isError: true);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _descController.clear();
    setState(() => _selectedImage = null);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            backgroundColor: isError ? Colors.red : Colors.green
        )
    );
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER RÉUTILISABLE (CustomSliverHeader)
          const CustomSliverHeader(
            title: "Gérer les Badges",
            showBackButton: true,
          ),

          // CONTENU PRINCIPAL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- FORMULAIRE D'AJOUT ---
                  const Text("Nouveau Badge", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Zone Image
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[300]!),
                                image: _selectedImage != null
                                    ? DecorationImage(
                                    image: kIsWeb
                                        ? NetworkImage(_selectedImage!.path)
                                        : FileImage(File(_selectedImage!.path)) as ImageProvider,
                                    fit: BoxFit.cover
                                )
                                    : null,
                              ),
                              child: _selectedImage == null
                                  ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text("Appuyez pour ajouter l'icône", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 20),

                          // Champs Texte
                          _AdminTextField(controller: _nameController, label: "Nom du Badge", icon: Icons.emoji_events),
                          const SizedBox(height: 15),
                          _AdminTextField(controller: _descController, label: "Description (ex: Faire 10k pas)", icon: Icons.description, maxLines: 2),
                          const SizedBox(height: 20),

                          // Bouton
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCreating ? null : _createBadge,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: mainBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              child: _isCreating
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("Créer le Badge", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- LISTE DES BADGES ---
                  const Text("Badges existants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 15),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: mainBlue))
                  else if (_badges.isEmpty)
                    const Center(child: Text("Aucun badge créé.", style: TextStyle(color: Colors.grey)))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // 2 colonnes
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.85, // Ratio hauteur/largeur
                      ),
                      itemCount: _badges.length,
                      itemBuilder: (context, index) {
                        final badge = _badges[index];
                        return _BadgeCard(
                          name: badge['name'] ?? 'Sans nom',
                          description: badge['description'] ?? '',
                          imageUrl: badge['image_url'], // Utilise la nouvelle colonne
                          onDelete: () => _deleteBadge(badge['badge_id']),
                        );
                      },
                    ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS LOCAUX ---

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _AdminTextField({required this.controller, required this.label, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: mainBlue, size: 20),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
      ),
      validator: (v) => v!.isEmpty ? 'Requis' : null,
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String name;
  final String description;
  final String? imageUrl;
  final VoidCallback onDelete;

  const _BadgeCard({
    required this.name,
    required this.description,
    this.imageUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image du Badge
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[100],
                    image: imageUrl != null
                        ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageUrl == null
                      ? const Icon(Icons.emoji_events, size: 40, color: Colors.amber)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Bouton Supprimer
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
            ),
          )
        ],
      ),
    );
  }
}