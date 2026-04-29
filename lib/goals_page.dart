// goals_page.dart
// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _staticGoalDefinitions = [];
  
  // Stream pour écouter les changements en direct
  late Stream<List<Map<String, dynamic>>> _userGoalsStream;
  
  // Pour éviter de lancer l'animation en boucle
  final Set<String> _celebratedIds = {};
  
  // Variable pour savoir si c'est le tout premier chargement
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. On charge les définitions des défis (pour avoir le goal_type)
      final goalsResponse = await Supabase.instance.client
          .from('goals')
          .select('*, badges(*)');
      
      if (mounted) {
        setState(() {
          _staticGoalDefinitions = List<Map<String, dynamic>>.from(goalsResponse);
          _isLoading = false;
        });
      }

      // 2. On lance une synchronisation initiale pour mettre à jour les progrès
      // (Au cas où l'utilisateur a marché/fait du sport depuis la dernière ouverture)
      await _syncAllActiveGoals(userId);

      // 3. Initialisation du Stream
      _refreshUserGoalsStream(userId);

    } catch (e) {
      debugPrint("Erreur chargement: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refreshUserGoalsStream(String userId) {
    setState(() {
      _userGoalsStream = Supabase.instance.client
          .from('user_goals')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('started_at');
    });
  }

  // --- LOGIQUE DE CALCUL ET SYNCHRONISATION ---

  /// Cette fonction parcourt les défis en cours et recalcule le progrès réel
  /// en se basant sur la table user_daily_steps et le goal_type.
  Future<void> _syncAllActiveGoals(String userId) async {
    try {
      // On récupère les défis "in_progress" de cet utilisateur
      final activeGoals = await Supabase.instance.client
          .from('user_goals')
          .select()
          .eq('user_id', userId)
          .eq('status', 'in_progress');

      for (var ug in activeGoals) {
        await _calculateAndUpdateProgress(ug);
      }
    } catch (e) {
      debugPrint("Erreur sync globale: $e");
    }
  }

  Future<void> _calculateAndUpdateProgress(Map<String, dynamic> userGoal) async {
    final String goalId = userGoal['goal_id'];
    final String userGoalId = userGoal['id'];
    final String startedAt = userGoal['started_at'];
    final String userId = userGoal['user_id'];

    // 1. Trouver la définition pour connaître le TYPE (workouts, calories ou steps)
    final def = _staticGoalDefinitions.firstWhere(
      (element) => element['id'] == goalId, 
      orElse: () => {}
    );
    if (def.isEmpty) return;

    final String type = def['goal_type'] ?? 'steps';

    try {
      // 2. Récupérer l'activité quotidienne depuis le début du défi
      // On prend juste la date YYYY-MM-DD pour être sûr
      final dateOnly = startedAt.substring(0, 10);

      // On récupère aussi la colonne 'calories'
      final activities = await Supabase.instance.client
          .from('user_daily_steps')
          .select('steps, workouts, calories, date') 
          .eq('user_id', userId)
          .gte('date', dateOnly);

      // 3. Calculer le total selon le TYPE
      int totalCalculated = 0;
      
      for (var day in activities) {
        if (type == 'workouts') {
          // Compte les séances
          totalCalculated += (day['workouts'] as num? ?? 0).toInt();
        } else if (type == 'calories') {
          // Compte les calories (arrondi à l'entier)
          totalCalculated += (day['calories'] as num? ?? 0).toInt();
        } else {
          // Par défaut (steps), on compte les pas
          totalCalculated += (day['steps'] as num? ?? 0).toInt();
        }
      }

      // 4. Mettre à jour user_goals seulement si la valeur a changé
      final int currentDbValue = userGoal['current_value'] ?? 0;
      
      if (totalCalculated != currentDbValue) {
        debugPrint("Mise à jour du défi $type : $currentDbValue -> $totalCalculated");
        await Supabase.instance.client
            .from('user_goals')
            .update({'current_value': totalCalculated})
            .eq('id', userGoalId);
            
        // Le Stream s'occupera de rafraîchir l'interface automatiquement après l'update
      }

    } catch (e) {
      debugPrint("Erreur calcul progrès pour $userGoalId: $e");
    }
  }

  // --- ACTIONS ---

  Future<void> _joinChallenge(String goalId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client.from('user_goals').insert({
        'user_id': userId,
        'goal_id': goalId,
        'status': 'in_progress',
        'current_value': 0,
        'started_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      // Mise à jour immédiate (calcul initial)
      await _calculateAndUpdateProgress(res);
      // Le stream se mettra à jour automatiquement, pas besoin de refresh manuel ici
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Défi accepté ! 🚀"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // CORRECTION ICI : "Soft Delete" -> on change le statut en 'abandoned'
  Future<void> _abandonChallenge(String userGoalId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('user_goals')
          .update({
            'status': 'abandoned', // On passe en abandonné au lieu de supprimer
            'completed_at': DateTime.now().toIso8601String(), // Optionnel : date d'abandon
          })
          .eq('id', userGoalId);
      
      // Pas besoin de supprimer les badges ou autre, car le défi n'est plus "in_progress"
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Défi abandonné."), backgroundColor: Colors.orange));
      }
    } catch (e) { 
      debugPrint("Erreur abandon: $e"); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'abandonner le défi."), backgroundColor: Colors.red));
      }
    }
  }

  // --- LOGIQUE DE VALIDATION & BADGES ---

  void _checkCompletionAndBadges(Map<String, dynamic> userGoal, Map<String, dynamic> definition) {
    final int current = userGoal['current_value'] ?? 0;
    final int target = definition['target_value'] ?? 999999;
    final String status = userGoal['status'];
    final String userGoalId = userGoal['id'];
    final String title = definition['title'];
    final String? badgeImage = definition['badges']?['image_url'];
    final int? badgeId = definition['badge_id'];

    // CAS 1 : Détection locale (C'est fini mais BDD "in_progress")
    if (current >= target && status == 'in_progress') {
      debugPrint("Victoire détectée ! Validation...");
      
      // 1. Update status
      Supabase.instance.client.from('user_goals').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', userGoalId).then((_) {
        // 2. Donner le badge
        if (badgeId != null) _awardBadge(badgeId, userGoalId);
      });
      
      // 3. Animation (si pas vu)
      if (!_celebratedIds.contains(userGoalId)) {
        _celebratedIds.add(userGoalId);
        WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebrationDialog(title, badgeImage));
      }
    }
    // CAS 2 : C'est déjà "completed" en BDD
    else if (status == 'completed') {
        // Vérifie TOUJOURS si le badge a bien été donné
        if (badgeId != null) {
           _awardBadge(badgeId, userGoalId); 
        }

        // Gestion de l'animation (popup unique)
        if (_isInitialLoad) {
           _celebratedIds.add(userGoalId);
        } else if (!_celebratedIds.contains(userGoalId)) {
           _celebratedIds.add(userGoalId);
           WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebrationDialog(title, badgeImage));
        }
    }
  }

  // Fonction sécurisée pour insérer dans user_badges sans doublon
  Future<void> _awardBadge(int badgeId, String sourceGoalId) async {
     final userId = Supabase.instance.client.auth.currentUser?.id;
     if (userId == null) return;
     
     try {
       final existing = await Supabase.instance.client
           .from('user_badges')
           .select()
           .eq('badge_id', badgeId)
           .eq('user_id', userId)
           .maybeSingle();
           
       if (existing == null) {
         debugPrint("Ajout du badge $badgeId dans la table...");
         await Supabase.instance.client.from('user_badges').insert({
           'user_id': userId, 
           'badge_id': badgeId, 
           'earned_at': DateTime.now().toIso8601String(), 
           'source_goal_id': sourceGoalId
         });
       }
     } catch (e) {
       // On ignore les erreurs de doublons
     }
  }

  void _showCelebrationDialog(String title, String? badgeImage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeImage != null)
               CircleAvatar(backgroundImage: NetworkImage(badgeImage), radius: 40, backgroundColor: Colors.transparent)
            else
               const Icon(Icons.emoji_events, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("FÉLICITATIONS ! 🏆", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 10),
            const Text("Objectif atteint :", style: TextStyle(color: Colors.grey)),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainBlue), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white, shape: const StadiumBorder()),
              child: const Text("Récupérer mon badge"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER
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
                title: const Text("Défis & Récompenses", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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

          // 2. CONTENU STREAM
          if (_isLoading)
             const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: mainBlue)))
          else
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _userGoalsStream,
              builder: (context, snapshot) {
                final userGoals = snapshot.data ?? [];

                Map<String, dynamic>? activeUserGoal;
                Map<String, dynamic>? activeGoalDetails;
                List<Map<String, dynamic>> completedGoalsList = [];
                // Set des IDs de défis déjà finis pour bloquer le "refaire"
                Set<String> completedGoalDefIds = {}; 

                for (var ug in userGoals) {
                  final details = _staticGoalDefinitions.firstWhere((d) => d['id'] == ug['goal_id'], orElse: () => {});
                  if (details.isEmpty) continue;

                  // Vérif badge + statut
                  _checkCompletionAndBadges(ug, details);

                  // Si le statut est 'abandoned', il est ignoré ici car pas de "else" final
                  if (ug['status'] == 'in_progress') {
                    activeUserGoal = ug;
                    activeGoalDetails = details;
                  } else if (ug['status'] == 'completed') {
                    final completeItem = Map<String, dynamic>.from(ug);
                    completeItem['details'] = details;
                    completedGoalsList.add(completeItem);
                    completedGoalDefIds.add(ug['goal_id']);
                  }
                }

                if (_isInitialLoad && snapshot.hasData) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _isInitialLoad = false);
                    });
                }

                final bool hasActiveChallenge = activeUserGoal != null;

                return SliverPadding(
                  padding: const EdgeInsets.all(20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      
                      // --- SECTION 1 : DÉFI ACTIF ---
                      if (hasActiveChallenge) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0, bottom: 10.0),
                          child: Text("🔥 TON DÉFI EN COURS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                        ),
                        _ActiveChallengeCard(
                          userGoal: activeUserGoal,
                          goalDetails: activeGoalDetails!,
                          onAbandon: () => _abandonChallenge(activeUserGoal!['id']),
                        ),
                        const SizedBox(height: 30),
                      ] else ...[
                        _EmptyStateCard(),
                      ],

                      // --- SECTION 2 : EXPLORER ---
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("EXPLORER", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 18)),
                            if (hasActiveChallenge)
                              const Text("🔒 Termine ton défi d'abord", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),

                      // Liste des défis disponibles
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _staticGoalDefinitions.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 15),
                        itemBuilder: (context, index) {
                          final goal = _staticGoalDefinitions[index];
                          
                          if (hasActiveChallenge && goal['id'] == activeGoalDetails?['id']) return const SizedBox.shrink();
                          
                          final bool isAlreadyDone = completedGoalDefIds.contains(goal['id']);

                          return _GoalCard(
                            goal: goal,
                            isLocked: hasActiveChallenge || isAlreadyDone,
                            isDone: isAlreadyDone,
                            onJoin: () => _joinChallenge(goal['id']),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // --- SECTION 3 : MES TROPHÉES ---
                      if (completedGoalsList.isNotEmpty) ...[
                          const Padding(
                          padding: EdgeInsets.only(left: 8.0, bottom: 10.0),
                          child: Text("🏆 MES TROPHÉES", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: completedGoalsList.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                             final item = completedGoalsList[index];
                             return _CompletedGoalCard(
                               goalDetails: item['details'], 
                               completedAt: item['completed_at']
                             );
                          },
                        ),
                        const SizedBox(height: 50),
                      ],
                    ]),
                  ),
                );
              }
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS UI
// -----------------------------------------------------------------------------

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: const [
          Icon(Icons.emoji_events_outlined, color: mainBlue, size: 50),
          SizedBox(height: 15),
          Text("Prêt à te dépasser ?", style: TextStyle(color: darkBlue, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text("Choisis un défi ci-dessous pour gagner des badges !", style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ActiveChallengeCard extends StatelessWidget {
  final Map<String, dynamic> userGoal;
  final Map<String, dynamic> goalDetails;
  final VoidCallback onAbandon;

  const _ActiveChallengeCard({required this.userGoal, required this.goalDetails, required this.onAbandon});

  @override
  Widget build(BuildContext context) {
    final int current = userGoal['current_value'] ?? 0;
    final int target = goalDetails['target_value'] ?? 1;
    final double percent = (current / target).clamp(0.0, 1.0);
    final badge = goalDetails['badges'];
    final String? badgeImage = badge != null ? badge['image_url'] : null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: mainBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 60, width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        image: badgeImage != null ? DecorationImage(image: NetworkImage(badgeImage), fit: BoxFit.cover) : null,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: badgeImage == null ? const Icon(Icons.emoji_events, color: Colors.orange, size: 30) : null,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goalDetails['title'] ?? "Défi", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text("Progression : ${(percent * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onAbandon,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.black.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)), 
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("$current / $target", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final bool isLocked;
  final bool isDone;
  final VoidCallback onJoin;

  const _GoalCard({required this.goal, required this.isLocked, this.isDone = false, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final badge = goal['badges'];
    final String? badgeImage = badge != null ? badge['image_url'] : null;
    final String type = goal['goal_type'] ?? 'steps';
    
    // Config de l'icône selon le type
    IconData typeIcon = Icons.directions_walk;
    Color typeColor = const Color(0xFF10B981);
    
    if (type == 'workouts') { 
      typeIcon = Icons.fitness_center; 
      typeColor = const Color(0xFFFBBF24); 
    }
    else if (type == 'calories') { 
      typeIcon = Icons.local_fire_department; 
      typeColor = const Color(0xFFEF4444); 
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked ? null : onJoin,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)),
                      const SizedBox(height: 4),
                      Text(goal['description'], style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (badge != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          if (badgeImage != null) ...[CircleAvatar(backgroundImage: NetworkImage(badgeImage), radius: 8, backgroundColor: Colors.transparent), const SizedBox(width: 6)] else const Icon(Icons.emoji_events, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(isDone ? "Badge obtenu" : "Gagne: ${badge['name']}", style: TextStyle(color: isDone ? Colors.green : Colors.orange[800], fontSize: 11, fontWeight: FontWeight.bold)),
                        ])
                      ]
                    ],
                  ),
                ),
                
                // Icône Action
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green.withOpacity(0.1) : (isLocked ? Colors.grey[100] : mainBlue.withOpacity(0.1)), 
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    isDone ? Icons.check : (isLocked ? Icons.lock_outline : Icons.play_arrow_rounded), 
                    size: 20, 
                    color: isDone ? Colors.green : (isLocked ? Colors.grey : mainBlue)
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedGoalCard extends StatelessWidget {
  final Map<String, dynamic> goalDetails;
  final String? completedAt;

  const _CompletedGoalCard({required this.goalDetails, this.completedAt});

  @override
  Widget build(BuildContext context) {
    String dateStr = "";
    if (completedAt != null) {
      final date = DateTime.parse(completedAt!).toLocal();
      dateStr = "${date.day}/${date.month}/${date.year}";
    }
    final badge = goalDetails['badges'];
    final badgeImage = badge?['image_url'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
             height: 50, width: 50,
             decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
             child: badgeImage != null 
                 ? Padding(padding: const EdgeInsets.all(5), child: CircleAvatar(backgroundImage: NetworkImage(badgeImage), backgroundColor: Colors.transparent))
                 : const Icon(Icons.check, color: Colors.green),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goalDetails['title'] ?? "Défi terminé", style: const TextStyle(fontWeight: FontWeight.bold, color: darkBlue)),
                Text("Terminé le $dateStr", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.emoji_events, color: Colors.amber),
        ],
      ),
    );
  }
}