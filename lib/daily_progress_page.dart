// DailyProgressPage.dart
import 'package:flutter/material.dart';
import 'nutrition_page.dart';
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9); // Nécessaire pour le dégradé du header

class DailyProgressPage extends StatelessWidget {
  final List<Map<String, dynamic>> addedMeals;

  const DailyProgressPage({super.key, required this.addedMeals});

  void _openMealDetail(BuildContext context, Map<String, dynamic> meal) {
    // 1. Définition de la couleur
    Color color;
    String type = (meal['displayType'] ?? meal['mealType'] ?? meal['meal_type'] ?? 'Snack').toString();

    if (type.contains('Breakfast') || type.contains('Petit')) color = Colors.orange;
    else if (type.contains('Lunch') || type.contains('Déjeuner')) color = Colors.green;
    else if (type.contains('Dinner') || type.contains('Dîner')) color = Colors.purple;
    else color = Colors.pink;

    // 2. Sécurisation des données
    final int safeId = int.tryParse(meal['id'].toString()) ?? int.tryParse(meal['recipe_id'].toString()) ?? 0;
    // C'est ici qu'il faut récupérer l'ID du créateur pour le passer à la page suivante
    final String safeCreatorId = (meal['creator_id'] ?? meal['user_id'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailPage(
          recipeId: safeId,
          creatorId: safeCreatorId, // <--- LA LIGNE QUI MANQUAIT
          title: (meal['title'] ?? 'Sans titre').toString(),
          mealType: type,
          calories: (meal['calories'] ?? meal['calories_kcal'] ?? 0).toString(),
          protein: (meal['protein'] ?? meal['protein_g'] ?? 0).toString(),
          carbs: (meal['carbs'] ?? meal['carbs_g'] ?? 0).toString(),
          fat: (meal['fat'] ?? meal['fat_g'] ?? 0).toString(),
          description: (meal['description'] ?? '').toString(),
          ingredients: (meal['ingredients'] ?? '').toString(),
          color: color,
          showAddButton: false, // Caché car déjà dans le plan
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Le contenu principal sera dans un SliverList ou SliverToBoxAdapter
    // car le CustomScrollView doit être l'enfant du Scaffold.

    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER DYNAMIQUE RÉUTILISABLE
          const CustomSliverHeader(
            title: "Journal du jour",
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // 2. CONTENU PRINCIPAL
          SliverToBoxAdapter(
            child: addedMeals.isEmpty
                ? const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text("Aucun repas ajouté aujourd'hui.", style: TextStyle(color: Colors.grey, fontSize: 16))
                )
            )
                : ListView.builder(
              // ListView doit être borné dans le SliverToBoxAdapter
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: addedMeals.length,
              itemBuilder: (context, index) {
                final meal = addedMeals[index];

                Color color;
                String type = (meal['displayType'] ?? meal['mealType'] ?? meal['meal_type'] ?? 'Snack').toString();

                if (type.contains('Breakfast') || type.contains('Petit')) color = Colors.orange;
                else if (type.contains('Lunch') || type.contains('Déjeuner')) color = Colors.green;
                else if (type.contains('Dinner') || type.contains('Dîner')) color = Colors.purple;
                else color = Colors.pink;

                final String calDisplay = (meal['calories'] ?? meal['calories_kcal'] ?? '0').toString();

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.restaurant, color: color),
                    ),
                    title: Text((meal['title'] ?? 'Repas').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("$calDisplay kcal", style: TextStyle(color: Colors.grey[600])),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => _openMealDetail(context, meal),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}