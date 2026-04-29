// manage_goals.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';

// COULEURS FITLAB
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class ManageGoalsPage extends StatefulWidget {
  const ManageGoalsPage({super.key});

  @override
  State<ManageGoalsPage> createState() => _ManageGoalsPageState();
}

class _ManageGoalsPageState extends State<ManageGoalsPage> {
  // Noms des tables
  static const String goalsTable = 'goals';
  static const String trainingsTable = 'trainings';
  static const String badgesTable = 'badges';

  final _formKey = GlobalKey<FormState>();

  // Contrôleurs
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();

  // État du formulaire
  String _selectedGoalType = 'steps'; // steps, workouts, calories, specific_training
  int? _selectedTrainingId;
  int? _selectedBadgeId; // Badge optionnel à gagner
  bool _isCreating = false;
  bool _isLoading = true;

  // Données
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _availableTrainings = [];
  List<Map<String, dynamic>> _availableBadges = [];

  // Options pour le type de défi
  final Map<String, String> _goalTypesDisplay = {
    'steps': 'Objectif de Pas',
    'workouts': 'Nombre de Séances',
    'calories': 'Objectif Calories (Kcal)',
    'specific_training': 'Entraînement Précis',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  // --- LOGIQUE SUPABASE ---

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      // 1. Récupérer les défis existants
      final goalsData = await client
          .from(goalsTable)
          .select()
          .order('created_at', ascending: false);

      // 2. Récupérer les entraînements (pour la liste déroulante)
      final trainingsData = await client
          .from(trainingsTable)
          .select('training_id, title')
          .order('title');

      // 3. Récupérer les badges (pour la récompense)
      final badgesData = await client
          .from(badgesTable)
          .select('badge_id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _goals = List<Map<String, dynamic>>.from(goalsData);
          _availableTrainings = List<Map<String, dynamic>>.from(trainingsData);
          _availableBadges = List<Map<String, dynamic>>.from(badgesData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('Erreur chargement: $e', isError: true);
    }
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation spécifique pour l'entraînement
    if (_selectedGoalType == 'specific_training' && _selectedTrainingId == null) {
      _showSnackBar('Veuillez sélectionner un entraînement.', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      // 1. Préparation des données de base
      // NOTE IMPORTANTE : On ne met PAS la clé 'id' ici.
      // La base de données va générer l'UUID automatiquement.
      final Map<String, dynamic> newGoal = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'goal_type': _selectedGoalType,
        'badge_id': _selectedBadgeId, // Peut être null, c'est autorisé
      };

      // 2. Ajout des cibles selon le type choisi
      if (_selectedGoalType == 'specific_training') {
        newGoal['target_training_id'] = _selectedTrainingId;
        newGoal['target_value'] = null;
      } else {
        // Pour Steps, Workouts ou Calories
        newGoal['target_training_id'] = null;
        newGoal['target_value'] = int.parse(_targetValueController.text.trim());
      }

      // 3. Envoi à Supabase
      await Supabase.instance.client.from(goalsTable).insert(newGoal);

      _showSnackBar('Défi créé avec succès !');
      _resetForm();
      await _fetchData();
    } catch (e) {
      _showSnackBar("Erreur création: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    try {
      await Supabase.instance.client.from(goalsTable).delete().eq('id', goalId);
      _showSnackBar('Défi supprimé.');
      await _fetchData(); // Rafraîchir la liste
    } catch (e) {
      _showSnackBar('Erreur suppression: $e', isError: true);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _titleController.clear();
    _descController.clear();
    _targetValueController.clear();
    setState(() {
      _selectedGoalType = 'steps';
      _selectedTrainingId = null;
      _selectedBadgeId = null;
    });
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

  // --- FONCTIONS UTILITAIRES ---

  String _getLabelForTargetValue() {
    switch (_selectedGoalType) {
      case 'steps': return "Nombre de pas cible";
      case 'workouts': return "Nombre de séances cible";
      case 'calories': return "Calories cibles (Kcal)";
      default: return "Valeur cible";
    }
  }

  IconData _getIconForTargetValue() {
    switch (_selectedGoalType) {
      case 'steps': return Icons.directions_walk;
      case 'workouts': return Icons.fitness_center;
      case 'calories': return Icons.local_fire_department;
      default: return Icons.onetwothree;
    }
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
            title: "Gérer les Défis",
            showBackButton: true,
          ),

          // CONTENU
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- FORMULAIRE DE CRÉATION ---
                  const Text("Nouveau Défi (24h)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AdminTextField(controller: _titleController, label: "Titre du Défi", icon: Icons.emoji_events),
                          const SizedBox(height: 15),
                          _AdminTextField(controller: _descController, label: "Description", icon: Icons.description, maxLines: 2),
                          const SizedBox(height: 20),

                          // SÉLECTION DU TYPE
                          const Text("Type d'objectif", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGoalType,
                            decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.category, color: mainBlue)
                            ),
                            items: _goalTypesDisplay.entries.map((e) {
                              return DropdownMenuItem(value: e.key, child: Text(e.value));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGoalType = val);
                            },
                          ),
                          const SizedBox(height: 20),

                          // CHAMPS DYNAMIQUES
                          if (_selectedGoalType == 'steps' || _selectedGoalType == 'workouts' || _selectedGoalType == 'calories') ...[
                            TextFormField(
                              controller: _targetValueController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: _getLabelForTargetValue(), // Label dynamique
                                  prefixIcon: Icon(_getIconForTargetValue(), color: mainBlue),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                              ),
                              validator: (v) => v!.isEmpty ? 'Valeur requise' : null,
                            ),
                          ] else if (_selectedGoalType == 'specific_training') ...[
                            // Liste déroulante des entraînements
                            DropdownButtonFormField<int>(
                              initialValue: _selectedTrainingId,
                              isExpanded: true,
                              hint: const Text("Choisir l'entraînement"),
                              decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  prefixIcon: const Icon(Icons.fitness_center, color: mainBlue)
                              ),
                              items: _availableTrainings.map((t) {
                                return DropdownMenuItem<int>(
                                  value: t['training_id'] as int,
                                  child: Text(t['title'] ?? 'Sans titre', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedTrainingId = val),
                              validator: (v) => v == null ? 'Requis' : null,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // SÉLECTION DU BADGE (OPTIONNEL)
                          const Text("Récompense (Optionnel)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedBadgeId,
                            isExpanded: true,
                            hint: const Text("Badge à gagner"),
                            decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.verified, color: Colors.orange)
                            ),
                            items: [
                              const DropdownMenuItem<int>(value: null, child: Text("Aucun badge")),
                              ..._availableBadges.map((b) {
                                return DropdownMenuItem<int>(
                                  value: b['badge_id'] as int,
                                  child: Text(b['name'] ?? 'Inconnu'),
                                );
                              }),
                            ],
                            onChanged: (val) => setState(() => _selectedBadgeId = val),
                          ),

                          const SizedBox(height: 25),

                          // BOUTON CRÉER
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCreating ? null : _createGoal,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: mainBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              child: _isCreating
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Publier le Défi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- LISTE DES DÉFIS ---
                  const Text("Défis actifs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 15),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: mainBlue))
                  else if (_goals.isEmpty)
                    const Center(child: Text("Aucun défi créé pour le moment.", style: TextStyle(color: Colors.grey)))
                  else
                    ..._goals.map((goal) {
                      // Récupération des infos pour l'affichage
                      final type = goal['goal_type'];
                      final targetVal = goal['target_value'];
                      final trainingId = goal['target_training_id'];
                      final badgeId = goal['badge_id'];

                      // Trouver le nom de l'entraînement si nécessaire
                      String trainingTitle = "ID: $trainingId";
                      if (trainingId != null && _availableTrainings.isNotEmpty) {
                        final t = _availableTrainings.firstWhere((element) => element['training_id'] == trainingId, orElse: () => {});
                        if (t.isNotEmpty) trainingTitle = t['title'];
                      }

                      // Trouver le nom du badge
                      String badgeName = "";
                      if (badgeId != null && _availableBadges.isNotEmpty) {
                        final b = _availableBadges.firstWhere((element) => element['badge_id'] == badgeId, orElse: () => {});
                        if (b.isNotEmpty) badgeName = b['name'];
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                      goal['title'] ?? 'Sans titre',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  // NOTE: Assurez-vous que la colonne 'id' dans votre table goals est bien un String/UUID si vous utilisez .eq('id', goal['id'])
                                  onPressed: () => _deleteGoal(goal['id'].toString()),
                                  tooltip: "Supprimer ce défi",
                                )
                              ],
                            ),
                            Text(goal['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const Divider(height: 20),
                            Row(
                              children: [
                                // Badge Type
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: lightBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(_goalTypesDisplay[type] ?? type, style: const TextStyle(color: mainBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                // Détail
                                Expanded(
                                  child: Text(
                                    type == 'specific_training'
                                        ? "🏋️ $trainingTitle"
                                        : "🎯 Objectif: $targetVal",
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (badgeName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events, size: 16, color: Colors.orange),
                                  const SizedBox(width: 5),
                                  Text("Gagne: $badgeName", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              )
                            ]
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

// Widget utilitaire pour les champs de texte simples
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