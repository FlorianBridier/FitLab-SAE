import 'package:flutter/material.dart';
import '../main.dart'; // Pour accéder à la variable 'supabase'

// Imports de vos pages
import '../profile_page.dart';
import '../friends_page.dart';
import '../subscription_page.dart';
import '../admin_panel_page.dart';
import '../coach_dashboard_page.dart';

// Couleurs FitLab
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);

class SharedDrawer extends StatefulWidget {
  const SharedDrawer({super.key});

  @override
  State<SharedDrawer> createState() => _SharedDrawerState();
}

class _SharedDrawerState extends State<SharedDrawer> {
  String _userName = 'Chargement...';
  String _subscriptionTier = 'free';
  String _userRole = 'user'; // 'admin', 'coach', 'user'

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('users')
          .select('name, subscription_tier, role')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _userName = response['name'] ?? 'Sportif';
          _subscriptionTier = (response['subscription_tier'] ?? 'free').toString().toLowerCase();
          _userRole = (response['role'] ?? 'user').toString().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement drawer: $e');
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _navigateTo(Widget page) {
    Navigator.pop(context); // Ferme le menu d'abord
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    bool isPremium = _subscriptionTier != 'free';

    return Drawer(
      child: Column(
        children: [
          // EN-TÊTE
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [darkBlue, mainBlue]),
            ),
            accountName: Text(
              _userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Row(
              children: [
                if (_userRole == 'admin')
                  const Text("ADMINISTRATEUR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                else if (_userRole == 'coach')
                  const Text("COACH", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))
                else
                  Text(
                    isPremium ? "Membre $_subscriptionTier".toUpperCase() : "Membre Gratuit",
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                _userRole == 'admin' ? Icons.security : Icons.person,
                size: 40,
                color: mainBlue,
              ),
            ),
          ),

          // LISTE DES LIENS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text("Accueil"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Mon Profil"),
                  onTap: () => _navigateTo(const ProfilePage()),
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text("Mes Amis"),
                  onTap: () => _navigateTo(const FriendsPage()),
                ),

                // SECTION ADMIN
                if (_userRole == 'admin') ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text("ADMINISTRATION", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dashboard, color: darkBlue),
                    title: const Text("Panel Admin"),
                    onTap: () => _navigateTo(const AdminPanelPage()),
                  ),
                ],

                // SECTION COACH
                if (_userRole == 'coach') ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.sports_gymnastics, color: Colors.orange),
                    title: const Text("Espace Coach"),
                    onTap: () => _navigateTo(const CoachDashboardPage()),
                  ),
                ],

                const Divider(),

                // BOUTON PREMIUM
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.diamond, color: Colors.orange),
                      title: const Text(
                        "Abonnements",
                        style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("Passez au niveau supérieur", style: TextStyle(fontSize: 12)),
                      onTap: () => _navigateTo(const SubscriptionPage()),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // DECONNEXION (En bas)
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Déconnexion", style: TextStyle(color: Colors.red)),
            onTap: () => _signOut(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}