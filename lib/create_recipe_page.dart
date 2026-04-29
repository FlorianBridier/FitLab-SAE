// create_recipe_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart'; // Pour l'accès à Supabase
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS HARMONISÉES
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class CreateRecipePage extends StatefulWidget {
  const CreateRecipePage({super.key});

  @override
  State<CreateRecipePage> createState() => _CreateRecipePageState();
}

class _CreateRecipePageState extends State<CreateRecipePage> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  String _selectedMealType = 'Lunch';

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _insertRecipe() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final user = supabase.auth.currentUser;
      if (user == null) {
        _showSnackBar('Erreur: Utilisateur non connecté.', isError: true);
        setState(() { _isLoading = false; });
        return;
      }

      try {
        await supabase.from('recipes').insert({
          'user_id': user.id,
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
          'ingredients': _ingredientsController.text.isEmpty ? null : _ingredientsController.text.trim(),
          'meal_type': _selectedMealType,
          // --- CONFLIT RÉSOLU : Garde double.tryParse (Autres modifications) ---
          'calories_kcal': double.tryParse(_caloriesController.text.trim()) ?? 0,
          'protein_g': double.tryParse(_proteinController.text.trim()) ?? 0,
          'carbs_g': double.tryParse(_carbsController.text.trim()) ?? 0,
          'fat_g': double.tryParse(_fatController.text.trim()) ?? 0,
          // -------------------------------------------------------------------
        });

        if (mounted) {
          _showSnackBar('Recette ajoutée avec succès !');
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        _showSnackBar('Erreur lors de l\'ajout: $e', isError: true);
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      // --- CONFLIT RÉSOLU : Garde le SnackBar stylisé (Autre modification) ---
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          )
      );
      // ----------------------------------------------------------------------
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: CustomScrollView(
        slivers: [
          // --- CONFLIT RÉSOLU : Garde le CustomSliverHeader (Ma modification) ---
          const CustomSliverHeader(
            title: 'Créer une Recette',
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),
          // -------------------------------------------------------------------

          // 2. FORMULAIRE DANS UNE CARTE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    // SECTION GÉNÉRALE (TITRE & TYPE)
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
                          _buildSectionTitle("INFORMATIONS"),
                          const SizedBox(height: 15),

                          // Titre
                          _buildModernTextField(
                            controller: _titleController,
                            label: 'Nom de la recette',
                            icon: Icons.title,
                            hint: 'Ex: Poulet Curry Coco',
                            validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 20),

                          // Type de repas (Chips)
                          const Text("Type de repas", style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 14)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _mealTypes.map((type) {
                              final isSelected = _selectedMealType == type;
                              return ChoiceChip(
                                label: Text(type),
                                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                selected: isSelected,
                                selectedColor: mainBlue,
                                backgroundColor: Colors.grey[100],
                                onSelected: (bool selected) { if (selected) setState(() => _selectedMealType = type); },
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SECTION NUTRITION
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
                          _buildSectionTitle("NUTRITION"),
                          const SizedBox(height: 15),

                          _buildNumericRow(_caloriesController, 'Calories', 'kcal', Icons.local_fire_department, Colors.orange),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),

                          Row(
                            children: [
                              Expanded(child: _buildNumericCompact(_proteinController, 'Protéines', 'g', Colors.red)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildNumericCompact(_carbsController, 'Glucides', 'g', Colors.blue)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildNumericCompact(_fatController, 'Lipides', 'g', Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SECTION DÉTAILS
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
                          _buildSectionTitle("DÉTAILS"),
                          const SizedBox(height: 15),

                          _buildModernTextField(
                            controller: _ingredientsController,
                            label: 'Ingrédients',
                            icon: Icons.shopping_basket_outlined,
                            hint: 'Liste des ingrédients...',
                            maxLines: 4,
                            inputType: TextInputType.multiline,
                            validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 15),

                          _buildModernTextField(
                            controller: _descriptionController,
                            label: 'Instructions',
                            icon: Icons.format_list_numbered,
                            hint: 'Étapes de préparation...',
                            maxLines: 6,
                            inputType: TextInputType.multiline,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // BOUTON AJOUTER
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _insertRecipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: mainBlue.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('ENREGISTRER LA RECETTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  // --- WIDGETS HELPERS ---

  Widget _buildSectionTitle(String title) {
    // --- CONFLIT RÉSOLU : Utilise le style plus compact et moderne (Autre modification) ---
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
    );
    // --------------------------------------------------------------------------------------
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 0), child: Icon(icon, color: mainBlue, size: 22)),
        // Alignement de l'icone en haut si multiline
        prefixIconConstraints: const BoxConstraints(minWidth: 50), // Garde le padding gauche
        filled: true,
        fillColor: Colors.white, // Conserve le fond blanc des champs
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        // Rétablit les bordures du champ, plus modernes que celles de l'autre commit
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainBlue, width: 1.5)),
      ),
    );
  }

  // Ligne spéciale pour les Calories (plus large)
  Widget _buildNumericRow(TextEditingController controller, String label, String unit, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
        ),
        SizedBox(
          width: 100,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: unit,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: mainBlue)),
            ),
            validator: (v) => (v == null || v.isEmpty) ? '!' : null,
          ),
        ),
      ],
    );
  }

  // Champ compact pour les autres macros (Prot/Glu/Lip)
  Widget _buildNumericCompact(TextEditingController controller, String label, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: unit,
            suffixStyle: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
            filled: true,
            fillColor: color.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            // Conserve la suppression de la bordure et l'effet de couleur
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}