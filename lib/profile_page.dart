// profile_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_panel_page.dart';
import 'edit_profile.dart';
import 'meal_history_page.dart';
import 'workout_history_page.dart';
import 'goals_and_targets_page.dart';
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);
const Color accentGreen = Color(0xFF10B981);
const Color accentOrange = Color(0xFFFF6B35);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _recentSuccesses = []; // Liste des défis terminés (badges)
  Map<String, dynamic>? _activeGoal; // Le défi en cours
  bool _isLoading = true;

  // Variables pour les totaux
  int _totalSteps = 0;
  int _totalCalories = 0;
  int _totalWorkouts = 0;
  int _totalBadges = 0;

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  Future<void> _loadAllProfileData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Infos User (J'ai ajouté avatar_url ici)
      final userResp = await Supabase.instance.client
          .from('users')
          .select('name, role, weight_kg, height_cm, bmi, avatar_url')
          .eq('user_id', userId)
          .single();

      // 2. Succès récents (Badges via user_goals Completed pour l'affichage liste)
      final completedResp = await Supabase.instance.client
          .from('user_goals')
          .select('completed_at, goals(title, badges(name, image_url))')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(4);

      // 3. Défi en cours
      final activeResp = await Supabase.instance.client
          .from('user_goals')
          .select('current_value, goals(title, target_value, goal_type, badges(image_url))')
          .eq('user_id', userId)
          .eq('status', 'in_progress')
          .maybeSingle();

      // 4. Calcul des Totaux (Pas, Kcal, Entraînements) via user_daily_steps
      final dailyStats = await Supabase.instance.client
          .from('user_daily_steps')
          .select('steps, calories, workouts')
          .eq('user_id', userId);

      int sumSteps = 0;
      int sumCalories = 0;
      int sumWorkouts = 0;

      for (var row in dailyStats) {
        sumSteps += (row['steps'] as num? ?? 0).toInt();
        sumCalories += (row['calories'] as num? ?? 0).toInt();
        sumWorkouts += (row['workouts'] as num? ?? 0).toInt();
      }

      // 5. Compte TOTAL des Badges (Défis terminés)
      final int badgesCount = await Supabase.instance.client
          .from('user_goals')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('status', 'completed');

      if (mounted) {
        setState(() {
          _userData = userResp;
          _recentSuccesses = List<Map<String, dynamic>>.from(completedResp);
          _activeGoal = activeResp;

          // Assignation des totaux
          _totalSteps = sumSteps;
          _totalCalories = sumCalories;
          _totalWorkouts = sumWorkouts;
          _totalBadges = badgesCount;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement profil: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AdminPanelPage()),
    );
  }

  void _editProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    ).then((value) {
      // Si on revient de la modif avec un succès (true), on recharge les données pour afficher le nouvel avatar
      if (value == true) _loadAllProfileData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = _userData?['name'] ?? 'Sportif';
    final role = (_userData?['role'] ?? 'user').toString();
    final isAdmin = role.toLowerCase() == 'admin';

    final weight = _userData?['weight_kg']?.toString() ?? '--';
    final height = _userData?['height_cm']?.toString() ?? '--';
    final bmi = _userData?['bmi']?.toString() ?? '--';

    // Récupération de l'URL de l'avatar
    final avatarUrl = _userData?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mainBlue))
          : CustomScrollView(
        slivers: [
          // --- 1. HEADER ---
          const CustomSliverHeader(
            title: "Mon Profil",
            showBackButton: true,
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // --- 2. CONTENU ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // CARTE INFO UTILISATEUR
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // --- AVATAR ICI ---
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: mainBlue, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.grey[200],
                                // Si on a une URL, on l'affiche, sinon null
                                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                // Si pas d'image, on affiche l'icône
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: darkBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: mainBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAdmin ? "Administrateur" : "Membre FitLab",
                                      style: const TextStyle(
                                        color: mainBlue,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _editProfile,
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.edit, color: mainBlue, size: 20),
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 20),

                        // Stats Corporelles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _PhysicalStatItem(label: "Poids", value: "$weight kg"),
                            _PhysicalStatItem(label: "Taille", value: "$height cm"),
                            _PhysicalStatItem(label: "IMC", value: bmi, isHighlight: true),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // BOUTON PANEL ADMIN
                  if (isAdmin) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToAdminPanel,
                        icon: const Icon(Icons.security, color: Colors.white),
                        label: const Text('Accéder au Panel Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),

                  // --- NOUVELLE SECTION : STATISTIQUES GLOBALES ---
                  // (Pas total, Kcal total, Entraînements, Badges)
                  Row(
                    children: [
                      _buildStatCard("Entraînements", "$_totalWorkouts", Icons.fitness_center, Colors.orange),
                      const SizedBox(width: 15),
                      _buildStatCard("Badges", "$_totalBadges", Icons.emoji_events, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _buildStatCard("Pas Total", "$_totalSteps", Icons.directions_walk, accentGreen),
                      const SizedBox(width: 15),
                      _buildStatCard("Kcal Total", "$_totalCalories", Icons.local_fire_department, Colors.redAccent),
                    ],
                  ),
                  // ------------------------------------------------

                  const SizedBox(height: 25),

                  // --- SUCCÈS RÉCENTS ---
                  const _SectionTitle(title: "Succès récents"),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: _recentSuccesses.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text("Termine un défi pour gagner un badge !", style: TextStyle(color: Colors.grey))),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _recentSuccesses.map((item) {
                        final goalData = item['goals'] as Map<String, dynamic>?;
                        final badgeData = goalData?['badges'] as Map<String, dynamic>?;

                        final imageUrl = badgeData?['image_url'];
                        final label = badgeData?['name'] ?? goalData?['title'] ?? 'Badge';

                        return Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: _AchievementBadge(
                            imageUrl: imageUrl,
                            label: label,
                            color1: const Color(0xFFFBBF24),
                            color2: const Color(0xFFD97706),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // --- OBJECTIF EN COURS ---
                  const _SectionTitle(title: "Objectif en cours"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: _activeGoal == null
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Column(
                          children: const [
                            Icon(Icons.flag_outlined, color: Colors.grey, size: 30),
                            SizedBox(height: 8),
                            Text("Aucun défi actif pour le moment", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                        : _ActiveGoalWidget(activeGoalData: _activeGoal!),
                  ),

                  const SizedBox(height: 25),

                  // PARAMÈTRES & HISTORIQUE
                  const _SectionTitle(title: "Paramètres & Historique"),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.fitness_center,
                    title: "Historique d'entraînement",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const WorkoutHistoryPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.restaurant_menu,
                    title: "Historique de repas",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const MealHistoryPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.track_changes,
                    title: "Modifier mes objectifs",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const GoalsAndTargetsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER POUR LES CARTES DE STATS ---
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
}

// -----------------------------------------------------------------------------
// WIDGETS UI EXISTANTS
// -----------------------------------------------------------------------------

class _PhysicalStatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _PhysicalStatItem({required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHighlight ? mainBlue : darkBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final Color color1;
  final Color color2;

  const _AchievementBadge({this.imageUrl, required this.label, required this.color1, required this.color2});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: imageUrl == null
                ? LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imageUrl != null
                ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, color: Colors.amber))
                : const Icon(Icons.emoji_events, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

class _ActiveGoalWidget extends StatelessWidget {
  final Map<String, dynamic> activeGoalData;

  const _ActiveGoalWidget({required this.activeGoalData});

  @override
  Widget build(BuildContext context) {
    final goalInfo = activeGoalData['goals'] ?? {};

    final String title = goalInfo['title'] ?? 'Défi';
    final String type = goalInfo['goal_type'] ?? 'steps';
    final int target = goalInfo['target_value'] ?? 100;
    final int current = activeGoalData['current_value'] ?? 0;

    Color color;
    String unit;
    IconData icon;

    if (type == 'workouts') {
      color = mainBlue;
      unit = 'séances';
      icon = Icons.fitness_center;
    } else if (type == 'calories') {
      color = accentOrange;
      unit = 'kcal';
      icon = Icons.local_fire_department;
    } else {
      color = accentGreen;
      unit = 'pas';
      icon = Icons.directions_walk;
    }

    final double progress = (current / target).clamp(0.0, 1.0);
    final int remaining = (target - current) > 0 ? (target - current) : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                    const SizedBox(height: 2),
                    Text(
                        remaining == 0 ? "Objectif atteint !" : 'Reste: $remaining $unit',
                        style: TextStyle(color: remaining == 0 ? accentGreen : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ],
            ),
            Text("${(progress * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[100],
              color: color,
              minHeight: 10
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text("$current / $target $unit", style: const TextStyle(fontSize: 11, color: Colors.grey)),
        )
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: lightBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: lightBlue, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlue))),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}