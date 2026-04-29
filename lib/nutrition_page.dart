import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_recipe_page.dart';
import 'daily_progress_page.dart';
import 'subscription_page.dart';
import 'main.dart';
import 'widgets/custom_sliver_header.dart'; // <-- Importation du header réutilisable
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

// -----------------------------------------------------------------------------
// 1. PAGE DE DÉTAIL (RECIPE DETAIL)
// -----------------------------------------------------------------------------
class RecipeDetailPage extends StatefulWidget {
  final int recipeId;
  final String title;
  final String mealType;
  final String calories;
  final String protein;
  final String carbs;
  final String fat;
  final String description;
  final String ingredients;
  final Color color;
  final bool showAddToPlanButton;
  final bool showAddButton;
  final String creatorId;

  const RecipeDetailPage({
    super.key,
    required this.recipeId,
    required this.title,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.description,
    required this.ingredients,
    required this.color,
    this.showAddToPlanButton = true,
    required this.creatorId,
    this.showAddButton = true,
  });

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await supabase.from('user_favorites')
          .select()
          .eq('user_id', userId)
          .eq('recipe_id', widget.recipeId)
          .maybeSingle();
      if (mounted) setState(() => isFavorite = response != null);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => isFavorite = !isFavorite);
    try {
      if (isFavorite) {
        await supabase.from('user_favorites').insert({'user_id': userId, 'recipe_id': widget.recipeId});
      } else {
        await supabase.from('user_favorites').delete().eq('user_id', userId).eq('recipe_id', widget.recipeId);
      }
    } catch (_) {
      if (mounted) setState(() => isFavorite = !isFavorite);
    }
  }

  List<Widget> _buildIngredientsList() {
    if (widget.ingredients.isEmpty) return [const Text("Aucun ingrédient.")];
    return widget.ingredients.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        const Icon(Icons.circle, size: 6, color: mainBlue),
        const SizedBox(width: 8),
        Expanded(child: Text(line.trim(), style: const TextStyle(fontSize: 14))),
      ]),
    ))
        .toList();
  }

  Widget _buildPreparationSection() {
    if (widget.showAddButton) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 40, color: Colors.grey[500]),
            const SizedBox(height: 10),
            Text(
              "Ajoutez cette recette à votre plan pour voir les étapes de préparation.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    if (widget.description.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Text("Aucune instruction disponible."),
      );
    }

    final List<String> steps = widget.description.split('\n').where((s) => s.trim().isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((entry) {
          int idx = entry.key + 1;
          String step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: widget.color.withOpacity(0.2), shape: BoxShape.circle),
                  child: Text("$idx", style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step, style: const TextStyle(fontSize: 15, height: 1.4))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0, pinned: true, backgroundColor: Colors.grey[50],
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.white), onPressed: _toggleFavorite),
            ],
            flexibleSpace: Container(
              decoration: BoxDecoration(color: widget.color, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30))),
              child: FlexibleSpaceBar(background: Center(child: Icon(Icons.restaurant_menu, size: 100, color: Colors.white.withOpacity(0.8)))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(widget.mealType, style: TextStyle(color: widget.color, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkBlue)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _DetailColumn(icon: Icons.local_fire_department, label: 'Kcal', value: widget.calories, color: Colors.orange),
                    _DetailColumn(icon: Icons.fitness_center, label: 'Prot', value: widget.protein, color: Colors.red),
                    _DetailColumn(icon: Icons.grain, label: 'Gluc', value: widget.carbs, color: Colors.blue),
                    _DetailColumn(icon: Icons.water_drop, label: 'Lip', value: widget.fat, color: Colors.green),
                  ]),
                ),
                const SizedBox(height: 24),
                const Text('Ingrédients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
                const SizedBox(height: 12),
                Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildIngredientsList())),

                const SizedBox(height: 24),
                const Text('Préparation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
                const SizedBox(height: 12),

                _buildPreparationSection(),

                const SizedBox(height: 40),
                if (widget.showAddButton)
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Ajouter à mon plan')
                      )
                  ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _DetailColumn({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Icon(icon, color: color), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
}

// -----------------------------------------------------------------------------
// 2. PAGE PRINCIPALE NUTRITION
// -----------------------------------------------------------------------------
class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});
  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  bool _isLoading = true;
  String _selectedTab = 'Tous';
  String _errorMessage = '';

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _addedMealsToday = [];
  List<int> _favoriteRecipeIds = [];

  // VARIABLES POUR LE MENU DU JOUR
  Map<String, dynamic>? _dailyBreakfast;
  Map<String, dynamic>? _dailyLunch;
  Map<String, dynamic>? _dailyDinner;

  String _subscriptionTier = 'free';
  String? _currentUserId;
  String? _userRole;

  int _dailyCalories = 0;
  double _dailyProtein = 0, _dailyCarbs = 0, _dailyFat = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        _currentUserId = user.id;
        final userRes = await supabase.from('users').select('subscription_tier, role').eq('user_id', user.id).maybeSingle();
        if (userRes != null) {
          _subscriptionTier = (userRes['subscription_tier'] ?? 'free').toString().toLowerCase();
          _userRole = userRes['role'];
        }
        final favRes = await supabase.from('user_favorites').select('recipe_id').eq('user_id', user.id);
        _favoriteRecipeIds = (favRes as List).map((e) => e['recipe_id'] as int).toList();
      }

      final response = await supabase.from('recipes').select().order('created_at', ascending: false);

      final List<Map<String, dynamic>> loadedData = List<Map<String, dynamic>>.from(response).map((r) {
        Color color = Colors.pink;
        String type = (r['meal_type'] ?? 'Snack').toString();

        // DÉTECTION LARGE
        if (type.toLowerCase().contains('break') || type.toLowerCase().contains('petit')) color = Colors.orange;
        else if (type.toLowerCase().contains('lunch') || type.toLowerCase().contains('déj')) color = Colors.green;
        else if (type.toLowerCase().contains('dinner') || type.toLowerCase().contains('dîner')) color = Colors.purple;

        return {
          'id': r['recipe_id'],
          'creator_id': r['user_id'],
          'title': (r['title'] ?? 'Sans titre').toString(),
          'calories': (r['calories_kcal'] ?? 0).toString(),
          'protein': (r['protein_g'] ?? 0).toString(),
          'carbs': (r['carbs_g'] ?? 0).toString(),
          'fat': (r['fat_g'] ?? 0).toString(),
          'mealType': type,
          'description': (r['description'] ?? '').toString(),
          'ingredients': (r['ingredients'] ?? '').toString(),
          'color': color,
        };
      }).toList();

      // GÉNÉRATION ROBUSTE DU MENU DU JOUR
      if (loadedData.isNotEmpty) {
        try { _dailyBreakfast = loadedData.firstWhere((r) => r['color'] == Colors.orange, orElse: () => loadedData[0]); } catch (_) { _dailyBreakfast = loadedData[0]; }
        try { _dailyLunch = loadedData.firstWhere((r) => r['color'] == Colors.green && r != _dailyBreakfast, orElse: () => loadedData.length > 1 ? loadedData[1] : loadedData[0]); } catch (_) { _dailyLunch = loadedData[0]; }
        try { _dailyDinner = loadedData.firstWhere((r) => r['color'] == Colors.purple && r != _dailyLunch && r != _dailyBreakfast, orElse: () => loadedData.length > 2 ? loadedData[2] : loadedData[0]); } catch (_) { _dailyDinner = loadedData[0]; }
      }

      // Charger le plan du jour
      if (_currentUserId != null) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final planRes = await supabase.from('daily_plans').select('recipe_id').eq('user_id', _currentUserId!).eq('date', today);
        final List<int> planIds = (planRes as List).map((e) => e['recipe_id'] as int).toList();
        _addedMealsToday = loadedData.where((r) => planIds.contains(r['id'])).toList();
        _recalculateMacros();
      }

      if (mounted) setState(() { _recipes = loadedData; _isLoading = false; _errorMessage = ''; });
    } catch (e) {
      debugPrint("ERREUR LOAD DATA: $e");
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  void _recalculateMacros() {
    int c = 0; double p = 0, cb = 0, f = 0;
    for (var meal in _addedMealsToday) {
      c += int.tryParse(meal['calories'].split('.')[0]) ?? 0;
      p += double.tryParse(meal['protein']) ?? 0;
      cb += double.tryParse(meal['carbs']) ?? 0;
      f += double.tryParse(meal['fat']) ?? 0;
    }
    setState(() { _dailyCalories = c; _dailyProtein = p; _dailyCarbs = cb; _dailyFat = f; });
  }

  // --- MODIFICATION ICI : REMPLACEMENT TABLE PLATE PAR ASSIGNED_MEAL_PLANS ---
  void _addToPlan(Map<String, dynamic> meal) async {
    setState(() { _addedMealsToday.add(meal); _recalculateMacros(); });

    if (_currentUserId == null) return;

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // 1. EXISTANT : daily_plans (Pour l'onglet "Mon Plan" du jour)
      await supabase.from('daily_plans').insert({'user_id': _currentUserId, 'recipe_id': meal['id'], 'date': todayStr});

      // 2. NOUVEAU : assigned_meal_plans (Historique relationnel)
      // On insère l'ID de la recette et le type de repas. La jointure fera le reste.
      await supabase.from('assigned_meal_plans').insert({
        'athlete_id': _currentUserId, // L'utilisateur connecté
        'recipe_id': meal['id'],      // La référence vers la recette
        'meal_type': meal['mealType'], // Breakfast, Lunch, etc.
        'assigned_at': DateTime.now().toIso8601String(),
        'coach_id': null // Null car c'est un ajout personnel
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté au plan et à l\'historique !'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Erreur plan: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _addAllDailyMenu() {
    if (!(_subscriptionTier.contains('inter') || _subscriptionTier.contains('elite') || _userRole == 'admin')) { _showLimitPopup(1); return; }
    if (_dailyBreakfast != null) _addToPlan(_dailyBreakfast!);
    if (_dailyLunch != null) _addToPlan(_dailyLunch!);
    if (_dailyDinner != null) _addToPlan(_dailyDinner!);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menu complet ajouté au planning !"), backgroundColor: Colors.green));
  }

  // --- FEATURE ELITE : LISTE DE COURSES ---
  void _showShoppingList() {
    String ingredients = "";
    if (_dailyBreakfast != null) ingredients += "MATIN:\n${_dailyBreakfast!['ingredients']}\n\n";
    if (_dailyLunch != null) ingredients += "MIDI:\n${_dailyLunch!['ingredients']}\n\n";
    if (_dailyDinner != null) ingredients += "SOIR:\n${_dailyDinner!['ingredients']}";

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Liste de Courses 🛒"),
      content: SingleChildScrollView(child: Text(ingredients.isEmpty ? "Aucun ingrédient trouvé." : ingredients)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")), ElevatedButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liste copiée ! (Simulation)"))); }, child: const Text("Copier"))],
    ));
  }

  Future<bool> _checkRecipeLimit() async {
    if (_userRole == 'admin') return true;
    if (_subscriptionTier.contains('inter') || _subscriptionTier.contains('elite')) return true;
    int limit = (_subscriptionTier == 'simple') ? 3 : 1;
    final start = DateTime.now().toIso8601String().substring(0, 10);
    final count = await supabase.from('daily_usage').count(CountOption.exact).eq('user_id', _currentUserId!).eq('action_type', 'recipe_viewed').gte('created_at', start);
    if (count >= limit) { _showLimitPopup(limit); return false; }
    await supabase.from('daily_usage').insert({'user_id': _currentUserId, 'action_type': 'recipe_viewed'});
    return true;
  }

  void _showLimitPopup(int limit) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Limite atteinte"), content: Text("Vous avez atteint votre limite de $limit recettes par jour.\nPassez au niveau supérieur !"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Non")), ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPage())); }, child: const Text("Voir offres"))]));
  }

  void _onCardTap(Map<String, dynamic> meal) async {
    bool added = _addedMealsToday.any((element) => element['id'] == meal['id']);
    if (!added) { if (!await _checkRecipeLimit()) return; }
    if (mounted) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: meal['id'], creatorId: (meal['creator_id'] ?? '').toString(), title: meal['title'], mealType: meal['mealType'], calories: meal['calories'], protein: meal['protein'], carbs: meal['carbs'], fat: meal['fat'], description: meal['description'], ingredients: meal['ingredients'], color: meal['color'], showAddButton: !added)));

      await _loadData();

      if (result == true) _addToPlan(meal);
    }
  }

  void _handlePlusButton(Map<String, dynamic> meal) async {
    bool added = _addedMealsToday.any((element) => element['id'] == meal['id']);
    if (added) return;
    if (!await _checkRecipeLimit()) return;
    _addToPlan(meal);
  }

  void _goToCreateRecipe() async {
    final bool? shouldRefresh = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateRecipePage()));
    if (shouldRefresh == true) await _loadData();
  }

  List<Map<String, dynamic>> get _filteredRecipes {
    if (_selectedTab == 'Favoris') return _recipes.where((r) => _favoriteRecipeIds.contains(r['id'])).toList();
    if (_selectedTab == 'Mon Plan') return _addedMealsToday;
    return _recipes;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    bool isInterOrElite = (_subscriptionTier.contains('inter') || _subscriptionTier.contains('elite') || _userRole == 'admin');
    bool isElite = (_subscriptionTier.contains('elite') || _userRole == 'admin');
    bool hasDailyMenu = _dailyBreakfast != null;

    String menuTitle = "🍽️ Menu Équilibré du Jour";
    String badgeText = "PREMIUM";
    Color badgeColor = Colors.orange;

    if (isElite) {
      menuTitle = "🍏 Votre Nutrition Personnalisée";
      badgeText = "ELITE";
      badgeColor = Colors.black;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      floatingActionButton: (_userRole == 'coach' || _userRole == 'admin') ? FloatingActionButton(onPressed: _goToCreateRecipe, backgroundColor: mainBlue, child: const Icon(Icons.add, color: Colors.white)) : null,
      body: CustomScrollView(
        slivers: [
          const CustomSliverHeader(
            title: "Nutrition",
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyProgressPage(addedMeals: _addedMealsToday))), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [darkBlue, mainBlue]), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Progrès du jour", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 5), Text("$_dailyCalories / 2200 kcal", style: const TextStyle(color: Colors.white70))]), Stack(alignment: Alignment.center, children: [SizedBox(width: 60, height: 60, child: CircularProgressIndicator(value: (_dailyCalories/2200).clamp(0.0, 1.0), color: Colors.white, backgroundColor: Colors.white24)), Text("${((_dailyCalories/2200)*100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])]))),
                  const SizedBox(height: 20),

                  if (isInterOrElite && hasDailyMenu && _selectedTab == 'Tous') ...[
                    Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.shade200), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                menuTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)), child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                          ]
                      ),
                      const SizedBox(height: 10),
                      if (_dailyBreakfast != null) _TinyMealRow(meal: _dailyBreakfast!),
                      if (_dailyLunch != null) _TinyMealRow(meal: _dailyLunch!),
                      if (_dailyDinner != null) _TinyMealRow(meal: _dailyDinner!),
                      const SizedBox(height: 15),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _addAllDailyMenu, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white), child: const Text("Tout ajouter au plan"))),

                      if (isElite) ...[
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _showShoppingList, icon: const Icon(Icons.shopping_cart), label: const Text("Générer ma liste de courses"), style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange, side: const BorderSide(color: Colors.deepOrange))))
                      ]
                    ])),
                    const SizedBox(height: 20),
                  ],

                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildTab("Tous"), const SizedBox(width: 10), _buildTab("Mon Plan"), const SizedBox(width: 10), _buildTab("Favoris")])),
                  const SizedBox(height: 20),
                  if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.all(10), child: Text("Erreur: $_errorMessage", style: const TextStyle(color: Colors.red))),
                  if (_filteredRecipes.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Text(_selectedTab == 'Mon Plan' ? "Aucun repas ajouté au plan." : "Aucune recette ici.", style: const TextStyle(color: Colors.grey))) else ..._filteredRecipes.map((meal) { bool isAdded = _addedMealsToday.any((m) => m['id'] == meal['id']); return _MealCard(title: meal['title'], mealType: meal['mealType'], calories: meal['calories'], protein: meal['protein'], carbs: meal['carbs'], fat: meal['fat'], color: meal['color'], isAdded: isAdded, onTap: () => _onCardTap(meal), onAdd: () => _handlePlusButton(meal)); }).toList()
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTab(String label) {
    bool isSelected = _selectedTab == label;
    return GestureDetector(onTap: () => setState(() => _selectedTab = label), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: isSelected ? mainBlue : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? mainBlue : Colors.grey.shade300)), child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold))));
  }
}

class _TinyMealRow extends StatelessWidget { final Map<String, dynamic> meal; const _TinyMealRow({required this.meal}); @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(Icons.circle, size: 8, color: meal['color']), const SizedBox(width: 8), Expanded(child: Text(meal['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: darkBlue))), Text("${meal['calories']} kcal", style: const TextStyle(fontSize: 12, color: Colors.grey))])); } }
class _MealCard extends StatelessWidget { final String title, mealType, calories, protein, carbs, fat; final Color color; final bool isAdded; final VoidCallback onTap, onAdd; const _MealCard({required this.title, required this.mealType, required this.calories, required this.protein, required this.carbs, required this.fat, required this.color, required this.isAdded, required this.onTap, required this.onAdd}); @override Widget build(BuildContext context) { return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(children: [Container(width: 100, height: 110, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20))), child: const Icon(Icons.restaurant, color: Colors.white, size: 40)), Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis), Text(mealType, style: TextStyle(fontSize: 12, color: Colors.grey[500])), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_MicroMacro(label: "Cal", value: calories), _MicroMacro(label: "Prot", value: protein), _MicroMacro(label: "Carbs", value: carbs), _MicroMacro(label: "Fat", value: fat)])]))), Padding(padding: const EdgeInsets.only(right: 16), child: GestureDetector(onTap: onAdd, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: isAdded ? Colors.green : mainBlue, shape: BoxShape.circle), child: Icon(isAdded ? Icons.check : Icons.add, color: Colors.white, size: 20))))]))); } }
class _MicroMacro extends StatelessWidget { final String label, value; const _MicroMacro({required this.label, required this.value}); @override Widget build(BuildContext context) { return Column(children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkBlue))]); } }