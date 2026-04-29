import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Pour l'accès à Supabase

class FriendProfilePage extends StatefulWidget {
  final String friendId; // L'ID de l'ami à afficher

  const FriendProfilePage({super.key, required this.friendId});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  
  // Variables pour les stats
  int _workoutsCount = 0;
  int _badgesCount = 0;
  int _totalSteps = 0;
  int _totalCalories = 0;

  @override
  void initState() {
    super.initState();
    _loadFriendProfile();
  }

  Future<void> _loadFriendProfile() async {
    try {
      // 1. Récupérer les infos de base (table users)
      final userResponse = await supabase
          .from('users')
          .select()
          .eq('user_id', widget.friendId)
          .single();

      // 2. Récupérer le nombre de badges (user_goals terminés)
      final int badgesCount = await supabase
          .from('user_goals')
          .count(CountOption.exact)
          .eq('user_id', widget.friendId)
          .eq('status', 'completed');

      // 3. Récupérer l'historique complet pour calculer TOUTES les stats
      // On ajoute 'workouts' dans la sélection
      final dailyData = await supabase
          .from('user_daily_steps')
          .select('steps, calories, workouts') 
          .eq('user_id', widget.friendId);
      
      // Calcul des sommes via une boucle simple
      int sumSteps = 0;
      int sumCalories = 0;
      int sumWorkouts = 0; // Nouvelle variable pour la somme des séances
      
      for (var row in dailyData) {
        // On utilise 'num?' et 'toInt()' pour éviter les crashs si c'est null
        sumSteps += (row['steps'] as num? ?? 0).toInt();
        sumCalories += (row['calories'] as num? ?? 0).toInt();
        // ICI : On additionne la colonne workouts de la table user_daily_steps
        sumWorkouts += (row['workouts'] as num? ?? 0).toInt();
      }

      if (mounted) {
        setState(() {
          _profileData = userResponse;
          _workoutsCount = sumWorkouts; // On assigne le total calculé
          _badgesCount = badgesCount;
          _totalSteps = sumSteps;
          _totalCalories = sumCalories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement profil ami: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color mainBlue = Color(0xFF004AAD);
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: mainBlue)),
      );
    }

    if (_profileData == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Impossible de charger le profil.")),
      );
    }

    final name = _profileData!['name'] ?? 'Utilisateur';
    final username = _profileData!['username'] ?? 'Inconnu';
    final role = _profileData!['role'] ?? 'Sportif';
    
    // Gestion sécurisée de la date
    DateTime createdAt = DateTime.now();
    if (_profileData!['created_at'] != null) {
      createdAt = DateTime.parse(_profileData!['created_at']);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: mainBlue,
        elevation: 0,
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER PROFIL
            Container(
              padding: const EdgeInsets.only(bottom: 30),
              decoration: const BoxDecoration(
                color: mainBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, color: mainBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "@$username",
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // GRILLE DE STATS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Ligne 1 : Entraînements & Badges
                  Row(
                    children: [
                      _buildStatCard("Entraînements", "$_workoutsCount", Icons.fitness_center, Colors.orange),
                      const SizedBox(width: 15),
                      _buildStatCard("Badges", "$_badgesCount", Icons.emoji_events, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Ligne 2 : Pas & Calories
                  Row(
                    children: [
                      _buildStatCard("Pas Total", "$_totalSteps", Icons.directions_walk, const Color(0xFF10B981)),
                      const SizedBox(width: 15),
                      _buildStatCard("Kcal Total", "$_totalCalories", Icons.local_fire_department, const Color(0xFFEF4444)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // INFORMATIONS SUPPLÉMENTAIRES
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("À propos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainBlue)),
                  const SizedBox(height: 15),
                  _buildInfoRow(Icons.calendar_today, "Membre depuis", "${createdAt.day}/${createdAt.month}/${createdAt.year}"),
                  const Divider(),
                  _buildInfoRow(Icons.email, "Email", _profileData!['email'] ?? 'Non visible'),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}