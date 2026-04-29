import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Ajout pour le formatage de date
import 'main.dart';
import 'nutrition_page.dart';
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';
import 'widgets/menu_button.dart';

class MealHistoryPage extends StatefulWidget {
  const MealHistoryPage({super.key});

  @override
  State<MealHistoryPage> createState() => _MealHistoryPageState();
}

class _MealHistoryPageState extends State<MealHistoryPage> {
  List<Map<String, dynamic>> _mealHistory = [];
  bool _isLoading = true;
  String _filterPeriod = 'Tous'; // Tous, 7j, 30j, 90j

  final Color primaryColor = const Color(0xFF0B5FA5);
  final Color darkBlue = const Color(0xFF103741);

  @override
  void initState() {
    super.initState();
    // On initialise le formatage de date pour le français
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadMealHistory();
    });
  }

  Future<void> _loadMealHistory() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Déterminer la date limite selon le filtre
      DateTime dateLimit = DateTime(2000); // Par défaut, très loin dans le passé
      final now = DateTime.now();

      if (_filterPeriod == '7j') {
        dateLimit = now.subtract(const Duration(days: 7));
      } else if (_filterPeriod == '30j') {
        dateLimit = now.subtract(const Duration(days: 30));
      } else if (_filterPeriod == '90j') {
        dateLimit = now.subtract(const Duration(days: 90));
      }

      // --- NOUVELLE REQUÊTE AVEC JOINTURE ---
      // On récupère le plan assigné ET les détails de la recette liée
      final response = await supabase
          .from('assigned_meal_plans')
          .select('''
            id,
            assigned_at,
            meal_type,
            coach_id,
            recipes (
              recipe_id,
              title,
              calories_kcal,
              protein_g,
              carbs_g,
              fat_g,
              description,
              ingredients
            )
          ''')
          .eq('athlete_id', userId)
          .gte('assigned_at', dateLimit.toIso8601String())
          .order('assigned_at', ascending: false);

      if (mounted) {
        setState(() {
          _mealHistory = List<Map<String, dynamic>>.from(response).map((item) {
            final recipe = item['recipes'] ?? {};

            // Sécurisation des valeurs numériques (parfois int, parfois double)
            final calories = recipe['calories_kcal'] ?? 0;
            final protein = recipe['protein_g'] ?? 0;
            final carbs = recipe['carbs_g'] ?? 0;
            final fat = recipe['fat_g'] ?? 0;

            return {
              'id': item['id'], // ID du plan assigné
              'coach_id': item['coach_id'], // Pour savoir si c'est un coach
              'date': DateTime.parse(item['assigned_at'] as String).toLocal(),

              // Infos Recette
              'recipe_id': recipe['recipe_id'] ?? 0,
              'title': recipe['title'] ?? 'Recette inconnue',
              'calories': calories.toString(),
              'protein': protein.toString(),
              'carbs': carbs.toString(),
              'fat': fat.toString(),
              'description': recipe['description'] ?? '',
              'ingredients': recipe['ingredients'] ?? '',

              // Le type de repas est défini dans l'assignation, sinon dans la recette
              'mealType': item['meal_type'] ?? 'Snack',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'historique repas: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openRecipeDetails(Map<String, dynamic> meal) {
    final mealTypeColor = _getMealTypeColor(meal['mealType']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailPage(
          recipeId: meal['recipe_id'],
          creatorId: '', // Non nécessaire pour la consultation
          title: meal['title'],
          mealType: _translateMealType(meal['mealType']),
          calories: meal['calories'],
          protein: meal['protein'],
          carbs: meal['carbs'],
          fat: meal['fat'],
          description: meal['description'],
          ingredients: meal['ingredients'],
          color: mealTypeColor,
          showAddToPlanButton: false, // Historique = consultation seulement
          showAddButton: false,
        ),
      ),
    );
  }

  Color _getMealTypeColor(String? mealType) {
    if (mealType == null) return Colors.grey;
    final lowerType = mealType.toLowerCase();
    if (lowerType.contains('breakfast') || lowerType.contains('petit')) return const Color(0xFFFF9800);
    if (lowerType.contains('lunch') || lowerType.contains('déj')) return const Color(0xFF4CAF50);
    if (lowerType.contains('dinner') || lowerType.contains('dîner')) return const Color(0xFF9C27B0);
    return const Color(0xFFE91E63); // Snack
  }

  String _translateMealType(String? mealType) {
    if (mealType == null) return 'Repas';
    final lowerType = mealType.toLowerCase();
    if (lowerType == 'breakfast') return 'Petit-déjeuner';
    if (lowerType == 'lunch') return 'Déjeuner';
    if (lowerType == 'dinner') return 'Dîner';
    if (lowerType == 'snack') return 'Collation';
    return mealType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER DYNAMIQUE
          const CustomSliverHeader(
            title: 'Historique des repas',
            showBackButton: true,
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // 2. CONTENU PRINCIPAL
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Filtres de période
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: ['Tous', '7j', '30j', '90j'].map((period) {
                      final isSelected = _filterPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: FilterChip(
                          label: Text(period),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _filterPeriod = period);
                            _loadMealHistory();
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // État de chargement / vide / liste
                _isLoading
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                )
                    : _mealHistory.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.no_meals, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Aucun repas trouvé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Vos repas assignés ou enregistrés apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _mealHistory.length,
                  itemBuilder: (context, index) {
                    final meal = _mealHistory[index];
                    final date = meal['date'] as DateTime;
                    final mealTypeColor = _getMealTypeColor(meal['mealType']);
                    final isCoachAssigned = meal['coach_id'] != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          // 1. Bande latérale colorée
                          Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: mealTypeColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant_menu, color: Colors.white, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  _translateMealType(meal['mealType']).toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold
                                  ),
                                )
                              ],
                            ),
                          ),

                          // 2. Informations centrales
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Titre et Badge Coach
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          meal['title'],
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCoachAssigned)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(6)),
                                          child: const Text("COACH", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 4),
                                  // Date formatée
                                  Text(
                                    DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(date),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  ),

                                  const Spacer(),

                                  // Macros
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _CardMacro(label: "Cal", value: meal['calories']),
                                      _CardMacro(label: "Prot", value: '${double.parse(meal['protein']).toStringAsFixed(0)}g'),
                                      _CardMacro(label: "Gluc", value: '${double.parse(meal['carbs']).toStringAsFixed(0)}g'),
                                      _CardMacro(label: "Lip", value: '${double.parse(meal['fat']).toStringAsFixed(0)}g'),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),

                          // 3. Bouton d'action (Voir)
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: InkWell(
                              onTap: () => _openRecipeDetails(meal),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[300]!)
                                ),
                                child: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget pour afficher les macronutriments (inchangé mais inclus pour complétude)
class _CardMacro extends StatelessWidget {
  final String label;
  final String value;
  const _CardMacro({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      ],
    );
  }
}