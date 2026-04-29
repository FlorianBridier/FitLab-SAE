// manage_news_photos_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // IMPÉRATIF POUR LE WEB
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// COULEURS FITLAB
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class ManageNewsPhotosPage extends StatefulWidget {
  final String newsId;
  final String newsTitle;

  const ManageNewsPhotosPage({
    super.key,
    required this.newsId,
    required this.newsTitle,
  });

  @override
  State<ManageNewsPhotosPage> createState() => _ManageNewsPhotosPageState();
}

class _ManageNewsPhotosPageState extends State<ManageNewsPhotosPage> {
  static const String detailsTable = 'news_details';
  static const String storageBucket = 'news_images';

  List<Map<String, dynamic>> _details = [];
  bool _isLoading = true;
  bool _isUploading = false;
  late final int _newsIdInt;

  @override
  void initState() {
    super.initState();
    _newsIdInt = int.tryParse(widget.newsId) ?? 0;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (_newsIdInt == 0) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from(detailsTable)
          .select()
          .eq('news_id', _newsIdInt)
          .order('news_detail_id', ascending: true);

      if (mounted) setState(() => _details = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _showSnackBar('Erreur chargement: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- CORRECTION DU BUG UPLOAD (WEB COMPATIBLE) ---
  Future<String?> _uploadImage(XFile image) async {
    try {
      final fileName = '${widget.newsId}_detail_${DateTime.now().millisecondsSinceEpoch}.${image.name.split('.').last}';
      
      if (kIsWeb) {
        // SUR LE WEB : On lit les bytes
        final bytes = await image.readAsBytes();
        await Supabase.instance.client.storage.from(storageBucket).uploadBinary(fileName, bytes);
      } else {
        // SUR MOBILE : On utilise File
        await Supabase.instance.client.storage.from(storageBucket).upload(fileName, File(image.path));
      }
      
      return Supabase.instance.client.storage.from(storageBucket).getPublicUrl(fileName);
    } catch (e) {
      print("Erreur upload: $e");
      return null;
    }
  }

  // Fonction pour ajouter un détail (Photo + Longue Description)
  Future<void> _addDetail() async {
    final ImagePicker picker = ImagePicker();
    // On sélectionne UNE image pour pouvoir lui attacher UNE description précise
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (image == null) return;

    // Dialogue pour saisir la description longue
    String? description = await _showDescriptionDialog();

    // Si l'utilisateur annule le dialogue (retour null), on annule tout ? 
    // Non, on peut considérer que la description est vide.
    // Ici je considère description = "" si null.

    setState(() => _isUploading = true);

    try {
      // 1. Upload Image
      final imageUrl = await _uploadImage(image);
      if (imageUrl == null) throw "Upload échoué";

      // 2. Insert DB dans news_details
      await Supabase.instance.client.from(detailsTable).insert({
        'news_id': _newsIdInt,
        'image_url': imageUrl,
        'long_description': description ?? "", // Insère la description ici
      });

      _showSnackBar("Détail ajouté !");
      await _fetchDetails();
    } catch (e) {
      _showSnackBar("Erreur ajout: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _showDescriptionDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Ajouter une description ?", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Contenu détaillé de ce paragraphe...",
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null), 
            child: const Text("Pas de texte", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white),
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDetail(int id, String? url) async {
    try {
      if (url != null) {
        final fileName = Uri.parse(url).pathSegments.last;
        await Supabase.instance.client.storage.from(storageBucket).remove([fileName]);
      }
      await Supabase.instance.client.from(detailsTable).delete().eq('news_detail_id', id);
      _showSnackBar("Supprimé.");
      await _fetchDetails();
    } catch (e) {
      _showSnackBar("Erreur suppression", isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            backgroundColor: Colors.grey[50],
            pinned: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text("Détails & Contenu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Édition pour : ${widget.newsTitle}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: mainBlue))
                  else if (_details.isEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: const [
                            Icon(Icons.post_add, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("Aucun contenu détaillé.", style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 5),
                            Text("Ajoutez des paragraphes avec images.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._details.map((detail) => Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          if (detail['image_url'] != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: Image.network(detail['image_url'], height: 200, width: double.infinity, fit: BoxFit.cover),
                            ),
                          
                          // Description & Actions
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (detail['long_description'] != null && detail['long_description'].isNotEmpty)
                                  Text(detail['long_description'], style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5))
                                else
                                  const Text("Sans texte", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                                
                                const SizedBox(height: 15),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    onPressed: () => _deleteDetail(detail['news_detail_id'], detail['image_url']),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: "Supprimer ce bloc",
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _addDetail,
        backgroundColor: mainBlue,
        icon: _isUploading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Icon(Icons.add, color: Colors.white),
        label: Text(_isUploading ? "Envoi..." : "Ajouter Détail", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}