import 'package:flutter/material.dart';
import 'main.dart'; // Accès à Supabase

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class CreateWorkoutPage extends StatefulWidget {
  const CreateWorkoutPage({super.key});

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // Options
  final List<String> _levels = ['Easy', 'Medium', 'Hard'];
  final List<String> _categories = ['Cardio', 'Strength', 'Flexibility']; 

  // État
  String _selectedLevel = 'Medium';
  String _selectedCategory = 'Cardio';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }
  
  Future<void> _insertWorkout() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: Utilisateur non connecté.'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Simulation ID int4 (à adapter selon ta logique réelle)
      final int simulatedUserId = int.tryParse(user.id.hashCode.toString().replaceAll('-', '').substring(0, 8)) ?? 1;
      final String levelToInsert = _selectedLevel.toLowerCase(); 

      try {
        await supabase.from('trainings').insert({
          'user_id': simulatedUserId, 
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(), 
          'level': levelToInsert, 
          'duration': int.parse(_durationController.text),
          // Tu pourrais aussi stocker la 'category' si ta BDD a une colonne pour ça
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entraînement ajouté avec succès !'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'ajout: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // -----------------------------------------------------------------------------
  // BUILD UI
  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fond moderne
      body: CustomScrollView(
        slivers: [
          // 1. HEADER FITLAB
          SliverAppBar(
            expandedHeight: 120.0,
            backgroundColor: Colors.grey[50],
            pinned: true,
            elevation: 0,
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
                  "Créer un Entraînement",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                  ],
                ),
              ),
            ),
          ),

          // 2. FORMULAIRE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // CARTE BLANCHE
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Détails"),
                          const SizedBox(height: 15),
                          
                          _buildModernTextField(
                            controller: _titleController,
                            label: "Titre de l'entraînement",
                            hint: "Ex: Cardio intense 30min",
                            icon: Icons.fitness_center,
                            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 15),
                          
                          _buildModernTextField(
                            controller: _descriptionController,
                            label: "Description",
                            hint: "Objectifs, matériel nécessaire...",
                            icon: Icons.description,
                            maxLines: 3,
                            inputType: TextInputType.multiline,
                          ),
                          const SizedBox(height: 15),

                          _buildModernTextField(
                            controller: _durationController,
                            label: "Durée (minutes)",
                            hint: "45",
                            icon: Icons.timer,
                            inputType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requis';
                              if (int.tryParse(v) == null) return 'Nombre valide requis';
                              return null;
                            },
                          ),

                          const SizedBox(height: 25),
                          const Divider(),
                          const SizedBox(height: 25),

                          // SÉLECTEUR NIVEAU (CHIPS)
                          _buildSectionTitle("Difficulté"),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children: _levels.map((level) {
                              final isSelected = _selectedLevel == level;
                              return ChoiceChip(
                                label: Text(level),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedLevel = level);
                                },
                                selectedColor: mainBlue,
                                backgroundColor: Colors.grey[100],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 25),

                          // SÉLECTEUR CATÉGORIE (CHIPS)
                          _buildSectionTitle("Catégorie"),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) setState(() => _selectedCategory = cat);
                                },
                                selectedColor: lightBlue,
                                backgroundColor: Colors.grey[100],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // BOUTON VALIDER
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _insertWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 5,
                          shadowColor: mainBlue.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('Créer l\'entraînement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  // --- WIDGETS HELPER ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(icon, color: mainBlue, size: 22),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainBlue, width: 1.5)),
      ),
    );
  }
}