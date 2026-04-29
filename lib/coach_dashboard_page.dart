// coach_dashboard_page.dart
import 'package:flutter/material.dart';
import 'main.dart'; // Assure-toi que 'supabase' est bien déclaré ici
import 'chat_page.dart'; 

// -----------------------------------------------------------------------------
// COULEURS (Mêmes que GoalsPage)
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class CoachDashboardPage extends StatefulWidget {
  const CoachDashboardPage({super.key});

  @override
  State<CoachDashboardPage> createState() => _CoachDashboardPageState();
}

class _CoachDashboardPageState extends State<CoachDashboardPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allTrainings = [];
  List<Map<String, dynamic>> _allRecipes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // 1. Charger mes élèves
      final studentsRes = await supabase
          .from('users')
          .select('user_id, name, email, subscription_tier, goal')
          .eq('coach_id', myId);

      // 2. Charger tous les entrainements
      final trainingRes = await supabase
          .from('trainings')
          .select('training_id, title, duration, target_goal');
      
      // 3. Charger toutes les recettes
      final recipeRes = await supabase
          .from('recipes')
          .select('recipe_id, title, calories_kcal, meal_type');

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(studentsRes);
          _allTrainings = List<Map<String, dynamic>>.from(trainingRes);
          _allRecipes = List<Map<String, dynamic>>.from(recipeRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS (LOGIQUE CONSERVÉE) ---

  void _openChat(String studentId, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(friendId: studentId, friendName: name)));
  }

  void _showAssignDialog(String studentId, String studentName, String studentGoal) {
    final recommended = _allTrainings.where((t) => t['target_goal'] == studentGoal).toList();
    final others = _allTrainings.where((t) => t['target_goal'] != studentGoal).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Sport pour $studentName", style: const TextStyle(fontWeight: FontWeight.bold, color: darkBlue)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommended.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.all(8.0), child: Text("Recommandé ⭐", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                  ...recommended.map((t) => _SimpleListTile(title: t['title'], subtitle: "${t['duration']} min", icon: Icons.fitness_center, color: Colors.orange, onTap: () => _confirmAssignWorkout(ctx, studentId, studentName, t))),
                  const Divider(),
                ],
                const Padding(padding: EdgeInsets.all(8.0), child: Text("Catalogue", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                ...others.map((t) => _SimpleListTile(title: t['title'], subtitle: "${t['duration']} min", icon: Icons.fitness_center, color: Colors.grey, onTap: () => _confirmAssignWorkout(ctx, studentId, studentName, t))),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler"))],
      ),
    );
  }

  void _confirmAssignWorkout(BuildContext ctx, String sId, String sName, Map<String, dynamic> t) async {
    Navigator.pop(ctx);
    await supabase.from('assigned_workouts').insert({
      'coach_id': supabase.auth.currentUser!.id,
      'athlete_id': sId,
      'training_id': t['training_id'],
      'assigned_at': DateTime.now().toIso8601String()
    });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entraînement envoyé !"), backgroundColor: Colors.green));
  }

  void _showAssignMealDialog(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Nutrition pour $studentName", style: const TextStyle(fontWeight: FontWeight.bold, color: darkBlue)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  labelColor: mainBlue,
                  indicatorColor: mainBlue,
                  tabs: [Tab(text: "Matin"), Tab(text: "Midi"), Tab(text: "Soir")]
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildRecipeList(studentId, "Breakfast"),
                      _buildRecipeList(studentId, "Lunch"),
                      _buildRecipeList(studentId, "Dinner"),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer"))],
      ),
    );
  }

  Widget _buildRecipeList(String studentId, String type) {
    return ListView.builder(
      itemCount: _allRecipes.length,
      itemBuilder: (ctx, i) {
        final r = _allRecipes[i];
        return ListTile(
          title: Text(r['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("${r['calories_kcal']} kcal"),
          trailing: const Icon(Icons.add_circle, color: mainBlue),
          onTap: () async {
            Navigator.pop(context);
            await supabase.from('assigned_meal_plans').insert({
              'coach_id': supabase.auth.currentUser!.id,
              'athlete_id': studentId,
              'recipe_id': r['recipe_id'],
              'meal_type': type
            });
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Repas ($type) assigné !"), backgroundColor: Colors.green));
          },
        );
      },
    );
  }

  void _showCheckins(String studentId, String name) async {
    final checkins = await supabase
        .from('checkins')
        .select()
        .eq('user_id', studentId)
        .order('created_at', ascending: false)
        .limit(5);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Derniers Bilans de $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 20),
            if (checkins.isEmpty) 
              const Center(child: Text("Aucun bilan reçu pour le moment.", style: TextStyle(color: Colors.grey)))
            else 
              Expanded(
                child: ListView.builder(
                  itemCount: checkins.length,
                  itemBuilder: (ctx, i) {
                    final c = checkins[i];
                    final date = DateTime.parse(c['created_at']).toLocal().toString().split(' ')[0];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text("📅 $date", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)), child: Text("Energie: ${c['energy']}/10", style: TextStyle(color: Colors.deepOrange[800], fontWeight: FontWeight.bold, fontSize: 12)))
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            const Icon(Icons.monitor_weight, size: 16, color: Colors.grey), const SizedBox(width: 5), Text("${c['weight']} kg"),
                            const SizedBox(width: 20),
                            const Icon(Icons.straighten, size: 16, color: Colors.grey), const SizedBox(width: 5), Text("${c['waist'] ?? '-'} cm"),
                          ]),
                          if (c['feeling'] != null) ...[
                             const SizedBox(height: 8),
                             Text("📝 \"${c['feeling']}\"", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          ]
                        ],
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      )
    );
  }

  // --- UI PRINCIPALE ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER IMMERSIF (Style GoalsPage)
          SliverAppBar(
            expandedHeight: 140.0,
            pinned: true,
            backgroundColor: Colors.grey[50],
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text("Espace Coach", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                    Positioned(bottom: -30, left: 20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.05))),
                  ],
                ),
              ),
            ),
          ),

          // 2. CONTENU
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: mainBlue)))
          else if (_students.isEmpty)
            const SliverFillRemaining(child: Center(child: Text("Aucun élève assigné.", style: TextStyle(color: Colors.grey))))
          else
            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final student = _students[index];
                    return _StudentCard(
                      student: student,
                      onChat: () => _openChat(student['user_id'], student['name']),
                      onSport: () => _showAssignDialog(student['user_id'], student['name'], student['goal'] ?? 'forme'),
                      onFood: () => _showAssignMealDialog(student['user_id'], student['name']),
                      onStats: () => _showCheckins(student['user_id'], student['name']),
                    );
                  },
                  childCount: _students.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS UI (Design GoalsPage appliqué aux élèves)
// -----------------------------------------------------------------------------

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onChat;
  final VoidCallback onSport;
  final VoidCallback onFood;
  final VoidCallback onStats;

  const _StudentCard({
    required this.student, 
    required this.onChat, 
    required this.onSport, 
    required this.onFood, 
    required this.onStats
  });

  @override
  Widget build(BuildContext context) {
    String tier = (student['subscription_tier'] ?? 'free').toString().toUpperCase();
    Color tierColor = tier.contains('ELITE') ? Colors.orange : (tier.contains('PRO') ? mainBlue : Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // HEADER CARTE
            Row(
              children: [
                CircleAvatar(
                  radius: 25, 
                  backgroundColor: darkBlue.withOpacity(0.1), 
                  child: Text((student['name']??'E')[0].toUpperCase(), style: const TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 18))
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: tierColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text("Obj: ${student['goal']} • $tier", style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),

            // ACTIONS BAR (Style épuré)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CoachActionBtn(icon: Icons.chat_bubble_outline, color: mainBlue, label: "Chat", onTap: onChat),
                _CoachActionBtn(icon: Icons.fitness_center, color: Colors.orange, label: "Sport", onTap: onSport),
                _CoachActionBtn(icon: Icons.restaurant_menu, color: Colors.green, label: "Repas", onTap: onFood),
                _CoachActionBtn(icon: Icons.bar_chart, color: Colors.purple, label: "Bilan", onTap: onStats),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _CoachActionBtn extends StatelessWidget {
  final IconData icon; final Color color; final String label; final VoidCallback onTap;
  const _CoachActionBtn({required this.icon, required this.color, required this.label, required this.onTap});
  
  @override 
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }
}

class _SimpleListTile extends StatelessWidget {
  final String title, subtitle; final IconData icon; final Color color; final VoidCallback onTap;
  const _SimpleListTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), 
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)), 
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey), 
      onTap: onTap
    );
  }
}