Ok, voici ce qu'il y a dans mon api_client (coté Docker) :
import 'dart:convert';
import 'package:http/http.dart' as http;

/// true  -> utilise la VM (192.168.101.128)
/// false -> utilise ta machine locale (localhost)
const bool useVmBackend = false;

String get apiBaseUrl {
  if (useVmBackend) {
    // 🔹 BACKEND SUR LA VM
    return 'http://192.168.101.128:8080/api';
  } else {
    // 🔹 BACKEND DOCKER EN LOCAL
    return 'http://localhost:8080/api';
  }
}

// Exemple d'appel
Future<http.Response> getLatestNews() {
  final uri = Uri.parse('$apiBaseUrl/news/latest');
  return http.get(uri);
}




Voici l'api_client qui marche pour flutter :



voici ce qu'il y a dans mon home_page (coté Docker) :
import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

// --- TES PAGES ---
import 'profile_page.dart';
import 'news_list_page.dart';
import 'nutrition_page.dart';
import 'workouts_page.dart';
import 'friends_page.dart';
import 'subscription_page.dart';
import 'messages_list_page.dart';
import 'goals_page.dart';
import 'coach_dashboard_page.dart';
import 'elite_checkin_page.dart';
import 'services/step_service.dart';
import 'widgets/shared_drawer.dart'; 
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
final supabase = Supabase.instance.client;

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _userName = 'Sportif';
  
  // Données dynamiques
  int _steps = 0; 
  int _dbCalories = 0; // Correspondra uniquement aux calories "Sport"
  int _workouts = 0; 
  
  String _subscriptionTier = 'free';
  String? _userRole;
  
  StreamSubscription<StepCount>? _stepSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDailyActivity(); 
    _initPedometer();     
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }

  // --- 1. CHARGER L'ACTIVITÉ BDD (CORRIGÉ : SOUSTRACTION) ---
  Future<void> _loadDailyActivity() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final response = await supabase
          .from('user_daily_steps')
          .select('calories, workouts, steps') // On récupère aussi les steps enregistrés
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (response != null && mounted) {
        // CORRECTION ICI : On isole les calories du sport
        double totalCalInDb = (response['calories'] ?? 0).toDouble();
        int stepsInDb = (response['steps'] ?? 0).toInt();
        
        // On retire la part "marche" qui est déjà dans la BDD pour ne pas la compter deux fois
        // Car le build() va rajouter (steps * 0.04)
        double workoutCaloriesOnly = totalCalInDb - (stepsInDb * 0.04);
        if (workoutCaloriesOnly < 0) workoutCaloriesOnly = 0;

        setState(() {
          _dbCalories = workoutCaloriesOnly.toInt();
          _workouts = (response['workouts'] ?? 0).toInt();
        });
        _updateGoalsProgress(_steps);
      }
    } catch (e) {
      debugPrint("Erreur load activity: $e");
    }
  }

  // --- 2. LOGIQUE PODOMETRE + SAUVEGARDE ---
  Future<void> _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      try {
        await StepService().initService();
        int savedSteps = await StepService().getTodaySteps();
        
        if (mounted) {
          setState(() => _steps = savedSteps);
          _updateGoalsProgress(savedSteps);
        }

        _stepSubscription = Pedometer.stepCountStream.listen((event) async {
          final prefs = await SharedPreferences.getInstance();
          int? stepsAtMidnight = prefs.getInt('step_anchor_midnight');
          
          if (stepsAtMidnight == null) {
             stepsAtMidnight = event.steps;
             await prefs.setInt('step_anchor_midnight', stepsAtMidnight);
          }
          
          int dailySteps = event.steps - stepsAtMidnight;
          
          if (dailySteps < 0) { 
            dailySteps = 0; 
            await prefs.setInt('step_anchor_midnight', event.steps); 
          }
          
          if (mounted) {
             setState(() => _steps = dailySteps);
             _updateGoalsProgress(dailySteps);
             _saveWalkingData(dailySteps);
          }
        }, onError: (error) {
          debugPrint("Erreur Podomètre Stream: $error");
        });
      } catch (e) {
        debugPrint("Erreur Service Pas: $e");
      }
    }
  }

  // SAUVEGARDE INTELLIGENTE (Déjà en place, je la garde)
  Future<void> _saveWalkingData(int currentSteps) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final currentData = await supabase.from('user_daily_steps').select('calories, steps, workouts').eq('user_id', userId).eq('date', today).maybeSingle();

      double totalCaloriesInDb = 0.0;
      int stepsInDb = 0;
      int workoutsInDb = 0;

      if (currentData != null) {
        totalCaloriesInDb = (currentData['calories'] as num?)?.toDouble() ?? 0.0;
        stepsInDb = (currentData['steps'] as int?) ?? 0;
        workoutsInDb = (currentData['workouts'] as int?) ?? 0;
      }

      double workoutCalories = totalCaloriesInDb - (stepsInDb * 0.04);
      if (workoutCalories < 0) workoutCalories = 0;

      double newTotalCalories = workoutCalories + (currentSteps * 0.04);

      await supabase.from('user_daily_steps').upsert({
        'user_id': userId,
        'date': today,
        'steps': currentSteps,
        'calories': newTotalCalories,
        'workouts': workoutsInDb,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, date');

    } catch (e) { debugPrint("Erreur sauvegarde pas: $e"); }
  }

  // --- 3. PROFIL USER ---
  Future<void> _loadUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase.from('users').select('name, subscription_tier, role').eq('user_id', userId).maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _userName = response['name'] ?? 'Sportif';
          _subscriptionTier = (response['subscription_tier'] ?? 'free').toString().toLowerCase();
          _userRole = response['role'];
        });
      }
    } catch (e) { debugPrint('Erreur profil: $e'); }
  }

  Future<void> _updateGoalsProgress(int currentSteps) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase.from('user_goals').update({'current_value': currentSteps}).eq('user_id', userId).eq('status', 'in_progress');
    } catch (e) { debugPrint("Erreur update goals: $e"); }
  }

  // --- NAVIGATION ---
  void _navigateToPage(String pageCode) async {
    Widget page;
    switch (pageCode) {
      case 'PROFILE': page = const ProfilePage(); break;
      case 'NEWS': page = const NewsListPage(); break;
      case 'NUTRITION': page = const NutritionPage(); break;
      case 'WORKOUTS': page = const WorkoutsPage(); break;
      case 'COACH_DASHBOARD': page = const CoachDashboardPage(); break;
      default: return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
    _loadDailyActivity(); 
  }

  void _navigateToFriends() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FriendsPage()));
  void _navigateToSubscription() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SubscriptionPage()));
  void _navigateToGoals() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GoalsPage()));

  void _navigateToMessages() {
    if (_userRole == 'admin' || _userRole == 'coach') {
       Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MessagesListPage()));
       return;
    }

    final hasAccess = _subscriptionTier != 'free' && _subscriptionTier != 'simple'; 

    if (hasAccess) {
       Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MessagesListPage()));
    } else {
      String messageContent = "La messagerie avec les coachs est réservée aux membres Intermédiaire et Elite.";
      if (_subscriptionTier == 'simple') {
         messageContent = "Votre abonnement Simple ne comprend pas la messagerie. Passez à l'offre Intermédiaire pour discuter avec un coach !";
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: const [Icon(Icons.lock, color: Colors.orange), SizedBox(width: 10), Text("Messagerie")]),
          content: Text(messageContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")),
            ElevatedButton(onPressed: () { Navigator.pop(ctx); _navigateToSubscription(); }, style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white), child: const Text("Voir les offres")),
          ],
        ),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    int totalCalories = _dbCalories + (_steps * 0.04).toInt();
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      key: _scaffoldKey, 
      backgroundColor: Colors.grey[50],
      
      // BOUTON FLOTTANT AVEC NOTIF (Design ajusté)
      floatingActionButton: StreamBuilder<List<Map<String, dynamic>>>(
        stream: (currentUserId != null) 
            ? supabase
                .from('messages')
                .stream(primaryKey: ['id'])
                .eq('receiver_id', currentUserId)
                .order('created_at')
            : const Stream.empty(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData && snapshot.data != null) {
             try {
                unreadCount = snapshot.data!.where((m) => m['is_read'] == false).length;
             } catch (_) {}
          }

          return FloatingActionButton(
            onPressed: _navigateToMessages,
            backgroundColor: mainBlue,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 2, offset: const Offset(0,1))
                        ]
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      ),

      endDrawer: const SharedDrawer(),

      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: 340,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                  Positioned(bottom: -20, left: 20, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(0.05))),
                ],
              ),
            ),
            
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [Image.asset('assets/images/logo.png', height: 32, errorBuilder: (_,__,___) => const Icon(Icons.fitness_center, color: Colors.white)), const SizedBox(width: 10), const Text('FitLab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))]),
                            Row(children: [
                                GestureDetector(onTap: _navigateToFriends, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20))),
                                const SizedBox(width: 10),
                                const MenuButton(),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 25),
                        const Text('Bonjour,', style: TextStyle(color: Colors.white70, fontSize: 18)),
                        Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 25),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _StatItem(value: '$_steps', label: 'Pas', icon: Icons.directions_walk), 
                            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)), 
                            _StatItem(value: '$totalCalories', label: 'Kcal', icon: Icons.local_fire_department_rounded), 
                            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)), 
                            _StatItem(value: '$_workouts', label: 'Séances', icon: Icons.fitness_center)
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(top: 30, left: 20, right: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Accès Rapide", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
                      const SizedBox(height: 15),
                      
                      GridView.count(
                        shrinkWrap: true, 
                        physics: const NeverScrollableScrollPhysics(), 
                        crossAxisCount: 2, 
                        crossAxisSpacing: 15, 
                        mainAxisSpacing: 15, 
                        childAspectRatio: 1.3, 
                        children: [
                          _MenuCard(title: 'Actualités', subtitle: 'Nouveautés', iconAsset: 'assets/icons/news.png', iconFallback: Icons.newspaper, color1: const Color(0xFF4266D9), color2: const Color(0xFF004AAD), onTap: () => _navigateToPage('NEWS')),
                          _MenuCard(title: 'Nutrition', subtitle: 'Mes repas', iconAsset: 'assets/icons/nutrition.png', iconFallback: Icons.restaurant_menu, color1: const Color(0xFF34D399), color2: const Color(0xFF059669), onTap: () => _navigateToPage('NUTRITION')),
                          
                          if (_userRole == 'coach')
                             _MenuCard(title: 'Espace Coach', subtitle: 'Gérer mes élèves', iconAsset: 'assets/icons/coach.png', iconFallback: Icons.sports_gymnastics, color1: Colors.orange, color2: Colors.deepOrange, onTap: () => _navigateToPage('COACH_DASHBOARD'))
                          else
                             _MenuCard(title: 'Entraînement', subtitle: 'Programmes', iconAsset: 'assets/icons/dumbbell.png', iconFallback: Icons.fitness_center, color1: const Color(0xFFFBBF24), color2: const Color(0xFFD97706), onTap: () => _navigateToPage('WORKOUTS')),
                          
                          _MenuCard(title: 'Profil', subtitle: 'Mes progrès', iconAsset: 'assets/icons/profile.png', iconFallback: Icons.person, color1: const Color(0xFFA78BFA), color2: const Color(0xFF7C3AED), onTap: () => _navigateToPage('PROFILE')),

                          if (_subscriptionTier.contains('elite') || _userRole == 'admin')
                            _MenuCard(title: 'Bilan Elite', subtitle: 'Envoyer rapport', iconAsset: 'assets/icons/chart.png', iconFallback: Icons.insights, color1: Colors.black87, color2: Colors.black, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const EliteCheckinPage()));
                            }),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      const Text("Challenges & Récompenses", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkBlue)),
                      const SizedBox(height: 15),
                      
                      _ActionCard(
                        title: "Défis à relever", 
                        subtitle: "Gagne des badges en relevant des challenges !", 
                        icon: Icons.emoji_events, 
                        color: Colors.orange, 
                        onTap: _navigateToGoals, 
                      ),

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS UI ---
class _StatItem extends StatelessWidget {
  final String value, label; final IconData icon;
  const _StatItem({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Colors.white, size: 24),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500))
    ]);
  }
}

class _MenuCard extends StatelessWidget {
  final String title, subtitle, iconAsset; final IconData iconFallback; final Color color1, color2; final VoidCallback onTap;
  const _MenuCard({required this.title, required this.subtitle, required this.iconAsset, required this.iconFallback, required this.color1, required this.color2, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color2.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Stack(children: [
          Positioned(right: -15, bottom: -15, child: CircleAvatar(radius: 40, backgroundColor: Colors.white.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.all(8), 
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), 
                child: (iconAsset.isNotEmpty) 
                    ? Image.asset(iconAsset, height: 22, width: 22, color: Colors.white, errorBuilder: (_, __, ___) => Icon(iconFallback, color: Colors.white, size: 22))
                    : Icon(iconFallback, color: Colors.white, size: 22)
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11))])
            ]),
          )
        ]),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title, 
    required this.subtitle, 
    required this.icon, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), 
            child: Icon(icon, color: color, size: 30)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlue)), 
                const SizedBox(height: 4), 
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12))
              ]
            )
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
        ]),
      ),
    );
  }
}

Voici l'home_page qui marche pour flutter :