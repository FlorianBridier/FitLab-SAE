import 'package:flutter/material.dart';
import 'main.dart';
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

class GoalsAndTargetsPage extends StatefulWidget {
  const GoalsAndTargetsPage({super.key});

  @override
  State<GoalsAndTargetsPage> createState() => _GoalsAndTargetsPageState();
}

class _GoalsAndTargetsPageState extends State<GoalsAndTargetsPage> {
  final Color primaryColor = const Color(0xFF0B5FA5);
  final Color darkBlue = const Color(0xFF103741);
  final Color successColor = const Color(0xFF4CAF50);
  final Color warningColor = const Color(0xFFFFC107);
  final Color dangerColor = const Color(0xFFFF5252);

  bool _isLoading = true;
  Map<String, dynamic>? _userGoals;

  // Contrôleurs pour l'édition
  late TextEditingController _calorieGoalController;
  late TextEditingController _proteinGoalController;
  late TextEditingController _carbsGoalController;
  late TextEditingController _fatGoalController;
  late TextEditingController _workoutGoalController;
  late TextEditingController _stepsGoalController;
  late TextEditingController _weightGoalController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserGoals();
  }

  void _initializeControllers() {
    _calorieGoalController = TextEditingController();
    _proteinGoalController = TextEditingController();
    _carbsGoalController = TextEditingController();
    _fatGoalController = TextEditingController();
    _workoutGoalController = TextEditingController();
    _stepsGoalController = TextEditingController();
    _weightGoalController = TextEditingController();
  }

  @override
  void dispose() {
    _calorieGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    _fatGoalController.dispose();
    _workoutGoalController.dispose();
    _stepsGoalController.dispose();
    _weightGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadUserGoals() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Récupère les objectifs depuis la table user_goals
      final response = await supabase
          .from('user_goals')
          .select('*')
          .eq('user_id', userId)
          .single();

      // Pré-remplir les contrôleurs
      setState(() {
        _userGoals = response;
        _calorieGoalController.text = (response['daily_calorie_goal'] ?? 2200).toString();
        _proteinGoalController.text = (response['daily_protein_goal'] ?? 150).toString();
        _carbsGoalController.text = (response['daily_carbs_goal'] ?? 250).toString();
        _fatGoalController.text = (response['daily_fat_goal'] ?? 70).toString();
        _workoutGoalController.text = (response['weekly_workout_goal'] ?? 4).toString();
        _stepsGoalController.text = (response['daily_steps_goal'] ?? 10000).toString();
        _weightGoalController.text = (response['target_weight_kg'] ?? '').toString();
      });
    } catch (e) {
      // Si la table n'existe pas ou l'utilisateur n'a pas d'objectifs, on crée des défauts
      print('Erreur chargement objectifs: $e');
      _setDefaultGoals();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setDefaultGoals() {
    setState(() {
      _calorieGoalController.text = '2200';
      _proteinGoalController.text = '150';
      _carbsGoalController.text = '250';
      _fatGoalController.text = '70';
      _workoutGoalController.text = '4';
      _stepsGoalController.text = '10000';
      _weightGoalController.text = '';
    });
  }

  Future<void> _saveGoals() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Erreur: Utilisateur non authentifié');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final goalsData = {
        'user_id': userId,
        'daily_calorie_goal': int.parse(_calorieGoalController.text),
        'daily_protein_goal': int.parse(_proteinGoalController.text),
        'daily_carbs_goal': int.parse(_carbsGoalController.text),
        'daily_fat_goal': int.parse(_fatGoalController.text),
        'weekly_workout_goal': int.parse(_workoutGoalController.text),
        'daily_steps_goal': int.parse(_stepsGoalController.text),
        'target_weight_kg': _weightGoalController.text.isNotEmpty
            ? double.parse(_weightGoalController.text)
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Essayer une mise à jour, sinon créer
      if (_userGoals != null) {
        await supabase
            .from('user_goals')
            .update(goalsData)
            .eq('user_id', userId);
      } else {
        await supabase.from('user_goals').insert(goalsData);
      }

      setState(() => _userGoals = goalsData);
      _showSnackBar('Objectifs sauvegardés avec succès !', isSuccess: true);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Erreur lors de la sauvegarde: $e');
      print('Erreur save goals: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? successColor : dangerColor,
        ),
      );
    }
  }

  // Calcul du pourcentage de progression

  // Déterminer la couleur basée sur la progression

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      // SUPPRESSION DE L'APPBAR CLASSIQUE
      // Remplacez tout le bloc "appBar: PreferredSize(...)" par la structure CustomScrollView

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : CustomScrollView( // <-- UTILISER CUSTOMSCROLLVIEW
        slivers: [
          // --- 1. HEADER DYNAMIQUE RÉUTILISABLE ---
          const CustomSliverHeader(
            title: 'Objectifs et Cibles',
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // --- 2. CONTENU PRINCIPAL DANS SLIVERTOBOXADAPTER ---
          SliverToBoxAdapter(
            child: SingleChildScrollView( // Conserver le SingleChildScrollView pour le padding et le Form
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Objectifs Nutritionnels
                    _buildSectionTitle('🎯 Objectifs Nutritionnels'),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildGoalInputField(
                            controller: _calorieGoalController,
                            label: 'Calories quotidiennes (kcal)',
                            icon: Icons.local_fire_department,
                            suffix: 'kcal',
                          ),
                          const SizedBox(height: 16),
                          _buildGoalInputField(
                            controller: _proteinGoalController,
                            label: 'Protéines quotidiennes (g)',
                            icon: Icons.fitness_center,
                            suffix: 'g',
                          ),
                          const SizedBox(height: 16),
                          _buildGoalInputField(
                            controller: _carbsGoalController,
                            label: 'Glucides quotidiens (g)',
                            icon: Icons.grain,
                            suffix: 'g',
                          ),
                          const SizedBox(height: 16),
                          _buildGoalInputField(
                            controller: _fatGoalController,
                            label: 'Lipides quotidiens (g)',
                            icon: Icons.water_drop,
                            suffix: 'g',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Objectifs d'Entraînement
                    _buildSectionTitle('💪 Objectifs d\'Entraînement'),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildGoalInputField(
                            controller: _workoutGoalController,
                            label: 'Entraînements par semaine',
                            icon: Icons.fitness_center,
                            suffix: '/semaine',
                          ),
                          const SizedBox(height: 16),
                          _buildGoalInputField(
                            controller: _stepsGoalController,
                            label: 'Pas quotidiens',
                            icon: Icons.directions_walk,
                            suffix: 'pas',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Objectifs de Poids
                    _buildSectionTitle('⚖️ Objectifs de Poids'),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildGoalInputField(
                        controller: _weightGoalController,
                        label: 'Poids cible (kg)',
                        icon: Icons.scale,
                        suffix: 'kg',
                        isOptional: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Conseils
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFD54F),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFD54F),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.info, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Conseils',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• Calories : En moyenne, 2200 kcal par jour\n'
                                '• Protéines : 1.6-2.2g par kg de poids corporel\n'
                                '• Glucides : 40-50% de vos calories totales\n'
                                '• Lipides : 25-35% de vos calories totales\n'
                                '• Entraînements : 3-5 par semaine pour progresser\n'
                                '• Pas : 10 000 pas pour une bonne santé',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF666666),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Bouton Sauvegarder
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveGoals,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Sauvegarder les Objectifs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bouton Réinitialiser
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _setDefaultGoals,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          'Réinitialiser aux Valeurs par Défaut',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkBlue,
      ),
    );
  }

  Widget _buildGoalInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: primaryColor),
        suffixText: suffix,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (!isOptional && (value == null || value.isEmpty)) {
          return 'Ce champ est requis';
        }
        if (value != null && value.isNotEmpty) {
          if (double.tryParse(value) == null) {
            return 'Veuillez entrer un nombre valide';
          }
          if (double.parse(value) <= 0) {
            return 'La valeur doit être supérieure à 0';
          }
        }
        return null;
      },
    );
  }
}