// manage_news_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_news_photos_page.dart';
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';

// COULEURS FITLAB
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class ManageNewsPage extends StatefulWidget {
  const ManageNewsPage({super.key});

  @override
  State<ManageNewsPage> createState() => _ManageNewsPageState();
}

class _ManageNewsPageState extends State<ManageNewsPage> {
  static const String newsTable = 'news';
  static const String storageBucket = 'news_images';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _shortDescController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  XFile? _selectedImage;
  List<Map<String, dynamic>> _allNews = [];
  List<Map<String, dynamic>> _filteredNews = [];
  bool _isLoadingNews = true;
  bool _isCreatingNews = false;

  @override
  void initState() {
    super.initState();
    _fetchNews();
    _searchController.addListener(_filterNews);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIQUE SUPABASE ---

  Future<void> _fetchNews() async {
    setState(() => _isLoadingNews = true);
    try {
      final List<Map<String, dynamic>> response = await Supabase.instance.client
          .from(newsTable)
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allNews = response;
          _filterNews();
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNews = false);
      _showSnackBar('Erreur chargement: $e', isError: true);
    }
  }

  void _filterNews() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNews = _allNews.where((news) {
        final title = (news['title'] as String? ?? '').toLowerCase();
        return title.contains(query);
      }).toList();
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showSnackBar("Erreur image");
    }
  }

  Future<String?> _uploadImage(XFile image) async {
    try {
      String fileName = 'main_${DateTime.now().millisecondsSinceEpoch}.${image.name.split('.').last}';
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await Supabase.instance.client.storage.from(storageBucket).uploadBinary(fileName, bytes);
      } else {
        await Supabase.instance.client.storage.from(storageBucket).upload(fileName, File(image.path));
      }
      return Supabase.instance.client.storage.from(storageBucket).getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<void> _createNews() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showSnackBar('Image principale requise.', isError: true);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isCreatingNews = true);

    try {
      String? imageUrl = await _uploadImage(_selectedImage!);
      if (imageUrl == null) throw "Upload échoué";

      await Supabase.instance.client.from(newsTable).insert({
        'title': _titleController.text.trim(),
        'short_description': _shortDescController.text.trim(),
        'main_image_url': imageUrl,
        'author_id': userId,
        'archive': false,
      });

      _showSnackBar('Publié avec succès !');
      _resetForm();
      await _fetchNews();
    } catch (e) {
      _showSnackBar("Erreur création: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isCreatingNews = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _selectedImage = null;
      _titleController.clear();
      _shortDescController.clear();
    });
  }

  Future<void> _showEditNewsDialog(Map<String, dynamic> news) async {
    final editTitle = TextEditingController(text: news['title']);
    final editShort = TextEditingController(text: news['short_description']);
    final editKey = GlobalKey<FormState>();
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Modifier l'actualité", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: editKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: editTitle,
                        decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: editShort,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Description courte', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requis' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white),
                  onPressed: isUpdating ? null : () async {
                    if (editKey.currentState!.validate()) {
                      setStateDialog(() => isUpdating = true);
                      try {
                        await Supabase.instance.client.from(newsTable).update({
                          'title': editTitle.text.trim(),
                          'short_description': editShort.text.trim(),
                        }).eq('news_id', news['news_id']);

                        Navigator.pop(context);
                        _showSnackBar("Modification enregistrée");
                        await _fetchNews();
                      } catch (e) {
                        setStateDialog(() => isUpdating = false);
                      }
                    }
                  },
                  child: isUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text("Enregistrer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteNews(dynamic newsId) async {
    try {
      await Supabase.instance.client.from(newsTable).delete().eq('news_id', newsId);
      _showSnackBar('Actualité supprimée.');
      await _fetchNews();
    } catch (e) {
      _showSnackBar('Erreur suppression.', isError: true);
    }
  }

  Future<void> _archiveNews(dynamic newsId, bool currentStatus) async {
    try {
      await Supabase.instance.client.from(newsTable).update({'archive': !currentStatus}).eq('news_id', newsId);
      await _fetchNews();
    } catch (_) {}
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER RÉUTILISABLE (CustomSliverHeader)
          const CustomSliverHeader(
            title: "Gérer les Actualités",
            showBackButton: true,
          ),

          // 2. CONTENU
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nouvelle publication", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                                image: _selectedImage != null ? DecorationImage(image: kIsWeb ? NetworkImage(_selectedImage!.path) : FileImage(File(_selectedImage!.path)) as ImageProvider, fit: BoxFit.cover) : null,
                              ),
                              child: _selectedImage == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey), Text("Image Principale", style: TextStyle(color: Colors.grey))]) : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _AdminTextField(controller: _titleController, label: "Titre", icon: Icons.title),
                          const SizedBox(height: 15),
                          _AdminTextField(controller: _shortDescController, label: "Description courte (Aperçu)", icon: Icons.short_text, maxLines: 2),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCreatingNews ? null : _createNews,
                              style: ElevatedButton.styleFrom(backgroundColor: mainBlue, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: _isCreatingNews ? const CircularProgressIndicator(color: Colors.white) : const Text("Publier", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text("Articles existants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(hintText: "Rechercher...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingNews) const Center(child: CircularProgressIndicator(color: mainBlue))
                  else if (_filteredNews.isEmpty) const Center(child: Text("Aucun article.", style: TextStyle(color: Colors.grey)))
                  else ..._filteredNews.map((news) {
                      final isArchived = news['archive'] ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                        child: Column(
                          children: [
                            ListTile(
                              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: news['main_image_url'] != null ? Image.network(news['main_image_url'], width: 50, height: 50, fit: BoxFit.cover) : const Icon(Icons.image, size: 50)),
                              title: Text(news['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(isArchived ? 'Archivé' : 'En ligne', style: TextStyle(color: isArchived ? Colors.orange : Colors.green, fontSize: 12)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(onPressed: () => _archiveNews(news['news_id'], isArchived), icon: Icon(isArchived ? Icons.unarchive : Icons.archive, color: Colors.orange), tooltip: "Archiver"),
                                  IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageNewsPhotosPage(newsId: news['news_id'].toString(), newsTitle: news['title']))), icon: const Icon(Icons.photo_library, color: mainBlue), tooltip: "Ajouter Détails/Photos"),
                                  IconButton(onPressed: () => _showEditNewsDialog(news), icon: const Icon(Icons.edit, color: Colors.grey), tooltip: "Modifier"),
                                  IconButton(onPressed: () => _deleteNews(news['news_id']), icon: const Icon(Icons.delete, color: Colors.red), tooltip: "Supprimer"),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    }),
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
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: mainBlue, size: 20), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      validator: (v) => v!.isEmpty ? 'Requis' : null,
    );
  }
}