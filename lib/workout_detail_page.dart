// workout_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart'; // Accès à Supabase

// -----------------------------------------------------------------------------
// COULEURS HARMONISÉES
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

// Définition du modèle
class Training {
  final int trainingId;
  final String title;
  final String description;
  final String level;
  final int duration;

  Training({
    required this.trainingId,
    required this.title,
    required this.description,
    required this.level,
    required this.duration,
  });
}

class WorkoutDetailPage extends StatefulWidget {
  final Training training;
  
  const WorkoutDetailPage({super.key, required this.training});

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;

  final List<String> _levels = ['Easy', 'Medium', 'Hard'];
  String? _selectedLevel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.training.title);
    _descriptionController = TextEditingController(text: widget.training.description);
    _durationController = TextEditingController(text: widget.training.duration.toString());
    
    String normalizedLevel = widget.training.level.toLowerCase();
    _selectedLevel = _levels.firstWhere(
      (level) => level.toLowerCase() == normalizedLevel,
      orElse: () => 'Medium',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // --- LOGIQUE MÉTIER (CONSERVÉE) ---

  int _getSimulatedUserId() {
    final user = supabase.auth.currentUser;
    if (user == null) return 0; 
    return int.tryParse(user.id.hashCode.toString().replaceAll('-', '').substring(0, 8)) ?? 1;
  }
  
  Future<void> _updateWorkout() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final int simulatedUserId = _getSimulatedUserId();
      if (simulatedUserId == 0) {
        _showSnackBar('Erreur: Utilisateur non connecté.');
        setState(() => _isLoading = false);
        return;
      }
      
      final String levelToInsert = _selectedLevel?.toLowerCase() ?? 'easy'; 

      try {
        await supabase.from('trainings')
            .update({
              'title': _titleController.text,
              'description': _descriptionController.text.isEmpty ? null : _descriptionController.text, 
              'level': levelToInsert,
              'duration': int.parse(_durationController.text),
            })
            .eq('training_id', widget.training.trainingId)
            .eq('user_id', simulatedUserId); 

        if (mounted) {
          _showSnackBar('Entraînement modifié avec succès !', isError: false);
          Navigator.of(context).pop(true); 
        }
      } catch (e) {
        _showSnackBar('Erreur lors de la modification: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet entraînement ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final int simulatedUserId = _getSimulatedUserId();

    try {
      await supabase.from('trainings')
          .delete()
          .eq('training_id', widget.training.trainingId)
          .eq('user_id', simulatedUserId); 

      if (mounted) {
        _showSnackBar('Entraînement supprimé avec succès !', isError: false);
        Navigator.of(context).pop(true); 
      }
    } catch (e) {
      _showSnackBar('Erreur lors de la suppression: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showSnackBar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER IMMERSIF
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            backgroundColor: Colors.grey[50],
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text("Modifier l'entraînement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                    Positioned(bottom: -30, left: 20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.05))),
                    Center(child: Icon(Icons.edit_note, size: 60, color: Colors.white.withOpacity(0.2))),
                  ],
                ),
              ),
            ),
          ),

          // 2. FORMULAIRE DANS UNE CARTE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("INFORMATIONS GÉNÉRALES"),
                          const SizedBox(height: 15),
                          
                          // Titre
                          _buildTextField(
                            controller: _titleController,
                            label: 'Titre',
                            hint: 'Ex: Full Body Blast',
                            icon: Icons.title,
                            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 20),

                          // Description
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Détails de la séance...',
                            icon: Icons.notes,
                            maxLines: 3,
                          ),
                          
                          const SizedBox(height: 30),
                          _buildSectionTitle("DÉTAILS TECHNIQUES"),
                          const SizedBox(height: 15),

                          // Durée
                          _buildTextField(
                            controller: _durationController,
                            label: 'Durée (min)',
                            hint: '45',
                            icon: Icons.timer_outlined,
                            isNumber: true,
                            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Invalide' : null,
                          ),
                          const SizedBox(height: 20),

                          // Niveau
                          _buildDropdownField(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // BOUTONS D'ACTION
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateWorkout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                              shadowColor: mainBlue.withOpacity(0.4),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("ENREGISTRER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isLoading ? null : _deleteWorkout,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text("Supprimer cet entraînement", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title, 
      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: mainBlue),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLevel,
      items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
      onChanged: (v) => setState(() => _selectedLevel = v),
      decoration: InputDecoration(
        labelText: 'Difficulté',
        prefixIcon: const Icon(Icons.bar_chart, color: mainBlue),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}