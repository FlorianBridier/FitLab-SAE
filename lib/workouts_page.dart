import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_workout_page.dart';
import 'workout_detail_page.dart';
import 'workout_session_page.dart';
import 'main.dart';
import 'subscription_page.dart';
import 'coach_selection_page.dart';

// --- WIDGETS DE NAVIGATION ---
import 'widgets/shared_drawer.dart';
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  String _selectedCategory = 'Tous';
  String? _userRole;
  String _subscriptionTier = 'free';
  String? _currentUserId;
  String _userGoal = 'forme';

  String? _myCoachId;
  String? _myCoachName;
  Map<String, dynamic>? _assignedWorkout;

  bool _isLoading = true;
  bool _isWorkoutsLoading = true;

  List<Map<String, dynamic>> _workouts = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  bool get _canCreateWorkout {
    return _userRole == 'coach' || _userRole == 'admin';
  }

  Future<void> _loadUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _currentUserId = userId;

    try {
      final response = await supabase
          .from('users')
          .select('name, role, subscription_tier, goal, coach_id')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userRole = response['role'] as String?;
          _subscriptionTier = (response['subscription_tier'] ?? 'free').toString().toLowerCase();
          _userGoal = (response['goal'] ?? 'forme').toString();
          _myCoachId = response['coach_id'] as String?;
        });

        if (_myCoachId != null) await _loadCoachName();
        if (_subscriptionTier.contains('inter') || _subscriptionTier.contains('elite')) await _loadAssignedWorkout();

        await _loadWorkouts();
      }
    } catch (e) {
      debugPrint('Erreur profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCoachName() async {
    try {
      final res = await supabase.from('users').select('name').eq('user_id', _myCoachId!).single();
      if (mounted) setState(() => _myCoachName = res['name']);
    } catch (_) {}
  }

  Future<void> _loadAssignedWorkout() async {
    try {
      final response = await supabase
          .from('assigned_workouts')
          .select('training_id, trainings(*)')
          .eq('athlete_id', _currentUserId!)
          .order('assigned_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['trainings'] != null) {
        final t = response['trainings'];
        if (mounted) {
          setState(() {
            _assignedWorkout = {
              'training_id': t['training_id'],
              'name': t['title'],
              'duration': t['duration'],
              'calories': (t['duration'] ?? 0) * 8,
            };
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur assignation: $e");
    }
  }

  Future<void> _loadWorkouts() async {
    if (mounted) setState(() => _isWorkoutsLoading = true);

    try {
      // 1. Charger les entraînements
      var query = supabase
          .from('trainings')
          .select('training_id, title, description, level, duration, user_id, is_official, target_goal');

      if (_userRole != 'admin' && (_subscriptionTier == 'free')) {
        query = query.eq('is_official', true);
      }

      final response = await query.order('created_at', ascending: false);

      // 2. Charger les favoris de l'utilisateur (NOUVEAU)
      final favResponse = await supabase
          .from('user_favorite_trainings')
          .select('training_id')
          .eq('user_id', _currentUserId!);

      // On crée un Set d'IDs pour vérifier rapidement si un training est favori
      final Set<int> favoriteIds = (favResponse as List)
          .map((e) => e['training_id'] as int)
          .toSet();

      final List<Map<String, dynamic>> loadedWorkouts = List<Map<String, dynamic>>.from(response).map((training) {
        final String rawLevel = (training['level'] as String?)?.toLowerCase() ?? 'easy';
        final int tId = training['training_id'] as int;

        String category = 'Cardio';
        String difficultyLabel = 'Débutant';
        Color color = const Color(0xFFE3F2FD);
        Color iconColor = const Color(0xFF42A5F5);
        IconData materialIcon = Icons.directions_run;

        if (rawLevel.contains('hard')) {
          category = 'Musculation'; difficultyLabel = 'Avancé'; color = const Color(0xFFFFEBEE); iconColor = const Color(0xFFEF5350); materialIcon = Icons.fitness_center;
        } else if (rawLevel.contains('medium')) {
          category = 'Cardio'; difficultyLabel = 'Intermédiaire'; color = const Color(0xFFFFF3E0); iconColor = const Color(0xFFFF9800); materialIcon = Icons.directions_run;
        } else {
          category = 'Souplesse'; difficultyLabel = 'Débutant'; color = const Color(0xFFE8F5E9); iconColor = const Color(0xFF66BB6A); materialIcon = Icons.self_improvement;
        }

        return {
          'training_id': tId,
          'creator_id': training['user_id'] as String,
          'name': training['title'] ?? 'Sans titre',
          'description': training['description'] ?? '',
          'duration': training['duration'] ?? 0,
          'difficulty': difficultyLabel,
          'calories': (training['duration'] ?? 0) * 8,
          'target_goal': training['target_goal'] ?? 'forme',
          'materialIcon': materialIcon,
          'color': color,
          'iconColor': iconColor,
          'category': category,
          'isFavorite': favoriteIds.contains(tId), // Vérification réelle ici
        };
      }).toList();

      if (mounted) {
        setState(() {
          _workouts = loadedWorkouts;
          _isWorkoutsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur load workouts: $e");
      if (mounted) setState(() => _isWorkoutsLoading = false);
    }
  }

  void _assignWorkoutToStudent(int trainingId, String trainingName) async {
    try {
      final studentsRes = await supabase.from('users').select('user_id, name, email').eq('coach_id', _currentUserId!);

      if (studentsRes.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vous n'avez pas encore d'élèves.")));
        return;
      }

      if (!mounted) return;
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Assigner : $trainingName"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: studentsRes.length,
                  itemBuilder: (ctx, i) {
                    final s = studentsRes[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(s['name'] ?? 'Élève'),
                      subtitle: Text(s['email'] ?? ''),
                      trailing: const Icon(Icons.send, color: mainBlue),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await supabase.from('assigned_workouts').insert({
                          'coach_id': _currentUserId,
                          'athlete_id': s['user_id'],
                          'training_id': trainingId,
                          'assigned_at': DateTime.now().toIso8601String()
                        });
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Programme envoyé à ${s['name']} !"), backgroundColor: Colors.green));
                      },
                    );
                  }
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler"))],
          )
      );
    } catch (e) {
      debugPrint("Erreur assignation: $e");
    }
  }

  void _onCoachCardTap() async {
    if (_userRole == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mode Admin : Simulation Coach")));
      return;
    }
    bool hasAccess = _subscriptionTier.contains('inter') || _subscriptionTier.contains('elite');

    if (!hasAccess) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Accès Restreint"), content: const Text("L'accès au Coach est réservé aux membres Intermédiaire et Elite."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")), ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPage())); }, child: const Text("Voir offres"))]));
      return;
    }

    if (_myCoachId == null) {
      final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CoachSelectionPage()));
      if (res == true) await _loadUserProfile();
    } else {
      if (_assignedWorkout != null) _startWorkout(_assignedWorkout!);
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Votre coach ne vous a pas encore assigné de programme.")));
    }
  }

  // GESTION DU COACH (SUPPRIMER/CHANGER)
  Future<void> _removeCoach() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Arrêter le coaching ?"),
        content: const Text("Vous ne recevrez plus de programmes personnalisés."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirmer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('users').update({'coach_id': null}).eq('user_id', _currentUserId!);

        if (!mounted) return;

        setState(() {
          _myCoachId = null;
          _myCoachName = null;
          _assignedWorkout = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vous n'avez plus de coach.")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  void _changeUserGoal() {
    if (_subscriptionTier == 'free') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passez au plan Simple pour cibler un objectif !")));
      return;
    }
    showDialog(context: context, builder: (ctx) => SimpleDialog(title: const Text("Choisir mon objectif"), children: [_buildGoalOption(ctx, "Perte de poids", "perte_poids", Icons.local_fire_department), _buildGoalOption(ctx, "Prise de muscle", "muscle", Icons.fitness_center), _buildGoalOption(ctx, "Remise en forme", "forme", Icons.favorite), _buildGoalOption(ctx, "Souplesse", "souplesse", Icons.self_improvement)]));
  }

  Widget _buildGoalOption(BuildContext ctx, String label, String code, IconData icon) {
    return SimpleDialogOption(onPressed: () async { Navigator.pop(ctx); await supabase.from('users').update({'goal': code}).eq('user_id', _currentUserId!); setState(() => _userGoal = code); }, child: Row(children: [Icon(icon, color: mainBlue), const SizedBox(width: 10), Text(label)]));
  }

  Future<bool> _checkDailyLimit() async {
    if (_userRole == 'admin' || _subscriptionTier != 'free') return true;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    try {
      final count = await supabase
          .from('daily_usage')
          .count(CountOption.exact)
          .eq('user_id', _currentUserId!)
          .eq('action_type', 'workout_done')
          .gte('created_at', todayStart);

      if (!mounted) return false;

      if (count >= 1) {
        await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                title: const Text("Limite atteinte"),
                content: const Text("1 séance max en gratuit."),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("OK")
                  )
                ]
            )
        );
        return false;
      }
      return true;
    } catch (e) { return true; }
  }

  Future<void> _logWorkoutStart() async {
    if (_userRole != 'admin' && _subscriptionTier == 'free') await supabase.from('daily_usage').insert({'user_id': _currentUserId, 'action_type': 'workout_done'});
  }

  void _goToCreateWorkout() async {
    final bool? shouldRefresh = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateWorkoutPage()));
    if (shouldRefresh == true) await _loadWorkouts();
  }

  void _goToWorkoutDetails(Map<String, dynamic> workoutData) {
    final training = Training(trainingId: workoutData['training_id'], title: workoutData['name'], description: workoutData['description'], level: workoutData['difficulty'], duration: workoutData['duration']);
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => WorkoutDetailPage(training: training)));
  }

  void _startWorkout(Map<String, dynamic> workout) async {
    if (!await _checkDailyLimit()) return;
    await _logWorkoutStart();
    if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutSessionPage(trainingId: workout['training_id'], workoutTitle: workout['name'])));
  }

  // --- FONCTION CORRIGÉE ---
  Future<void> _toggleWorkoutFavorite(int trainingId, bool isCurrentlyFavorite) async {
    // 1. Sécurité : Si pas d'utilisateur connecté, on arrête tout
    if (_currentUserId == null) return;

    // 2. Optimistic Update (Mise à jour visuelle immédiate)
    setState(() {
      final index = _workouts.indexWhere((w) => w['training_id'] == trainingId);
      if (index != -1) {
        _workouts[index]['isFavorite'] = !isCurrentlyFavorite;
      }
    });

    try {
      if (isCurrentlyFavorite) {
        // Suppression
        await supabase.from('user_favorite_trainings').delete().match({
          'user_id': _currentUserId!, // <--- AJOUT DU POINT D'EXCLAMATION ICI
          'training_id': trainingId,
        });
      } else {
        // Ajout
        await supabase.from('user_favorite_trainings').insert({
          'user_id': _currentUserId!, // <--- ET ICI
          'training_id': trainingId,
        });
      }
    } catch (e) {
      debugPrint("Erreur favoris: $e");
      // Annulation en cas d'erreur API
      setState(() {
        final index = _workouts.indexWhere((w) => w['training_id'] == trainingId);
        if (index != -1) {
          _workouts[index]['isFavorite'] = isCurrentlyFavorite;
        }
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de connexion")));
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: mainBlue)));

    final recommendedWorkouts = _workouts.where((w) => w['target_goal'] == _userGoal).toList();

    // --- FILTRAGE ---
    List<Map<String, dynamic>> displayedWorkouts;
    if (_selectedCategory == 'Tous') {
      displayedWorkouts = _workouts;
    } else if (_selectedCategory == 'Favoris') {
      displayedWorkouts = _workouts.where((w) => w['isFavorite'] == true).toList();
    } else {
      displayedWorkouts = _workouts.where((w) => w['category'] == _selectedCategory).toList();
    }

    // --- LOGIQUE D'AFFICHAGE DU COACH ---
    String coachTitle = "Programme du Coach";
    String coachSub = "Chargement...";
    IconData coachIcon = Icons.lock;

    bool isSubscriber = _subscriptionTier.contains('inter') || _subscriptionTier.contains('elite') || _userRole == 'admin';
    bool isElite = _subscriptionTier.contains('elite') || _userRole == 'admin';

    if (isSubscriber) {
      if (_myCoachId == null) { coachTitle = "Choisir un Coach"; coachSub = "Sélectionnez votre mentor"; coachIcon = Icons.person_add; }
      else if (_assignedWorkout != null) {
        coachTitle = isElite ? "Programme Sur-Mesure" : "Votre Séance du Jour";
        coachSub = "${_assignedWorkout!['name']} (${_assignedWorkout!['duration']} min)";
        coachIcon = isElite ? Icons.verified_user : Icons.play_circle_fill;
      }
      else { coachTitle = "En attente du Coach"; coachSub = "Aucun programme assigné"; coachIcon = Icons.hourglass_empty; }
    } else { coachSub = "Réservé aux membres Intermédiaire"; }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(), // --- AJOUT : MENU LATÉRAL ---
      floatingActionButton: _canCreateWorkout ? FloatingActionButton(onPressed: _goToCreateWorkout, backgroundColor: mainBlue, child: const Icon(Icons.add, color: Colors.white)) : null,

      body: CustomScrollView(
        slivers: [
          // --- HEADER AVEC DESIGN CERCLES & BURGER ---
          SliverAppBar(
            expandedHeight: 140.0,
            backgroundColor: Colors.grey[50],
            pinned: true,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context)
            ),
            // --- AJOUT DU BOUTON MENU À DROITE ---
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                  "Entraînement",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkBlue, mainBlue, lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                // --- LES CERCLES DÉCORATIFS ---
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CARTE COACH
                  GestureDetector(
                    onTap: _onCoachCardTap,
                    child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFEA580C)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.local_fire_department, color: Colors.white, size: 28)),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(coachTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    // BOUTON PARAMÈTRES COACH
                                    if (_myCoachId != null && isSubscriber)
                                      GestureDetector(
                                        onTap: () {},
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
                                          onSelected: (val) {
                                            if (val == 'change') Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachSelectionPage())).then((_) => _loadUserProfile());
                                            if (val == 'remove') _removeCoach();
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 'change', child: Text("Changer de coach")),
                                            const PopupMenuItem(value: 'remove', child: Text("Arrêter le coaching", style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(coachSub, style: const TextStyle(color: Colors.white70, fontSize: 13))
                              ])),
                              if (_myCoachId == null) Icon(coachIcon, color: Colors.white70, size: 24)
                            ]
                        )
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_subscriptionTier != 'free') Container(margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade800, mainBlue]), borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("MON OBJECTIF", style: TextStyle(color: Colors.white70, fontSize: 12)), Text(_userGoal.toUpperCase().replaceAll('_', ' '), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]), ElevatedButton(onPressed: _changeUserGoal, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: mainBlue), child: const Text("Modifier"))])),

                  if (_subscriptionTier != 'free' && recommendedWorkouts.isNotEmpty) ...[
                    const Text("Recommandé pour vous", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                    const SizedBox(height: 16),
                    SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: recommendedWorkouts.length, itemBuilder: (ctx, i) {
                      final w = recommendedWorkouts[i];
                      return GestureDetector(onTap: () => _startWorkout(w), child: Container(width: 160, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(w['materialIcon'], color: w['iconColor'], size: 40), const SizedBox(height: 10), Text(w['name'], textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text("${w['duration']} min", style: const TextStyle(color: Colors.grey, fontSize: 12))])));
                    })),
                    const SizedBox(height: 24),
                  ],

                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          children: [
                            _FilterChip(label: 'Tous', isSelected: _selectedCategory == 'Tous', onTap: () => setState(() => _selectedCategory = 'Tous')),
                            const SizedBox(width: 10),
                            // --- NOUVEAU CHIP FAVORIS ---
                            _FilterChip(label: 'Favoris', isSelected: _selectedCategory == 'Favoris', onTap: () => setState(() => _selectedCategory = 'Favoris')),
                            const SizedBox(width: 10),
                            // ----------------------------
                            _FilterChip(label: 'Musculation', isSelected: _selectedCategory == 'Musculation', onTap: () => setState(() => _selectedCategory = 'Musculation')),
                            const SizedBox(width: 10),
                            _FilterChip(label: 'Cardio', isSelected: _selectedCategory == 'Cardio', onTap: () => setState(() => _selectedCategory = 'Cardio')),
                            const SizedBox(width: 10),
                            _FilterChip(label: 'Souplesse', isSelected: _selectedCategory == 'Souplesse', onTap: () => setState(() => _selectedCategory = 'Souplesse'))
                          ]
                      )
                  ),
                  const SizedBox(height: 24),
                  const Text("Tous les programmes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 16),

                  if (_isWorkoutsLoading) const Center(child: CircularProgressIndicator(color: mainBlue))
                  else if (displayedWorkouts.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text("Aucun entraînement trouvé.", style: TextStyle(color: Colors.grey))))
                  else ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: displayedWorkouts.length, separatorBuilder: (_, __) => const SizedBox(height: 16), itemBuilder: (context, index) {
                      final workout = displayedWorkouts[index];
                      final bool isOwner = workout['creator_id'] == _currentUserId;
                      return _WorkoutCard(
                        workout: workout,
                        isOwner: isOwner,
                        isCoach: _userRole == 'coach' || _userRole == 'admin',
                        onTap: () => isOwner ? _goToWorkoutDetails(workout) : _startWorkout(workout),
                        onFavoriteToggle: () => _toggleWorkoutFavorite(workout['training_id'], workout['isFavorite']), // <-- Appel de la vraie fonction
                        onAssign: () => _assignWorkoutToStudent(workout['training_id'], workout['name']),
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS UI ---
class _FilterChip extends StatelessWidget {
  final String label; final bool isSelected; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: isSelected ? mainBlue : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? mainBlue : Colors.grey.shade300), boxShadow: isSelected ? [BoxShadow(color: mainBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : []), child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold))));
  }
}

class _WorkoutCard extends StatelessWidget {
  final Map<String, dynamic> workout; final bool isOwner; final bool isCoach;
  final VoidCallback onTap; final VoidCallback onFavoriteToggle; final VoidCallback? onAssign;

  const _WorkoutCard({required this.workout, required this.isOwner, required this.isCoach, required this.onTap, required this.onFavoriteToggle, this.onAssign});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(color: (workout['color'] as Color).withOpacity(0.5), borderRadius: BorderRadius.circular(15)), child: Icon(workout['materialIcon'], color: workout['iconColor'], size: 30)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(workout['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text("${workout['duration']} min • ${workout['difficulty']}", style: TextStyle(fontSize: 12, color: Colors.grey[600]))])),
      Column(children: [
        GestureDetector(onTap: onFavoriteToggle, child: Icon(workout['isFavorite'] ? Icons.favorite : Icons.favorite_border, color: workout['isFavorite'] ? Colors.red : Colors.grey[400], size: 22)),
        const SizedBox(height: 10),
        if (isCoach && onAssign != null)
          GestureDetector(onTap: onAssign, child: const Icon(Icons.send, size: 24, color: Colors.orange))
        else if (isOwner)
          const Icon(Icons.edit, size: 18, color: mainBlue)
        else
          const Icon(Icons.play_circle_fill, size: 28, color: mainBlue)
      ])
    ])));
  }
}