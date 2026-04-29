// admin_panel_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORTS DE VOS PAGES DE GESTION ---
import 'manage_users.dart';
import 'manage_news_page.dart';
import 'manage_goals.dart';
import 'manage_badges_page.dart'; // 🚨 Indispensable pour la redirection

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  // Variables d'état pour les compteurs
  int _userCount = 0;
  int _newsCount = 0;
  int _goalsCount = 0;
  int _badgesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // Récupération des statistiques en parallèle (Optimisé)
  Future<void> _fetchStats() async {
    try {
      final client = Supabase.instance.client;
      
      // On lance les 4 requêtes en même temps pour gagner du temps
      final results = await Future.wait([
        client.from('users').count(CountOption.exact),
        client.from('news').count(CountOption.exact).eq('archive', false),
        client.from('goals').count(CountOption.exact),
        client.from('badges').count(CountOption.exact),
      ]);

      if (mounted) {
        setState(() {
          _userCount = results[0];
          _newsCount = results[1];
          _goalsCount = results[2];
          _badgesCount = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur stats admin: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER (Style FitLab)
          SliverAppBar(
            expandedHeight: 120.0,
            backgroundColor: Colors.grey[50],
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkBlue, mainBlue, lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text(
                  "Panel Admin",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. CONTENU
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Vue d'ensemble",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue),
                  ),
                  const SizedBox(height: 15),

                  // --- STATS EN LIGNES (Plus stable que GridView ici) ---
                  
                  // LIGNE 1 : Utilisateurs & Articles
                  Row(
                    children: [
                      _SimpleStatCard(
                        label: "Utilisateurs",
                        value: _isLoading ? "..." : "$_userCount",
                        icon: Icons.group,
                        color: const Color(0xFF10B981), // Vert
                      ),
                      const SizedBox(width: 15),
                      _SimpleStatCard(
                        label: "Articles",
                        value: _isLoading ? "..." : "$_newsCount",
                        icon: Icons.article,
                        color: const Color(0xFFFF6B35), // Orange
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // LIGNE 2 : Défis & Badges
                  Row(
                    children: [
                      _SimpleStatCard(
                        label: "Défis Actifs",
                        value: _isLoading ? "..." : "$_goalsCount",
                        icon: Icons.emoji_events,
                        color: const Color(0xFF8B5CF6), // Violet
                      ),
                      const SizedBox(width: 15),
                      _SimpleStatCard(
                        label: "Badges",
                        value: _isLoading ? "..." : "$_badgesCount",
                        icon: Icons.verified,
                        color: const Color(0xFFEC4899), // Rose
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Gestion",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue),
                  ),
                  const SizedBox(height: 15),

                  // --- ACTIONS DE GESTION ---
                  
                  // 1. Utilisateurs
                  _AdminActionCard(
                    title: "Utilisateurs",
                    subtitle: "Gérer les rôles et accès",
                    icon: Icons.people_alt,
                    color1: const Color(0xFF2563EB),
                    color2: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersPage())),
                  ),
                  const SizedBox(height: 15),

                  // 2. Actualités
                  _AdminActionCard(
                    title: "Actualités",
                    subtitle: "Publier des articles",
                    icon: Icons.newspaper,
                    color1: const Color(0xFFEA580C),
                    color2: const Color(0xFFF97316),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageNewsPage())),
                  ),
                  const SizedBox(height: 15),

                  // 3. Défis
                  _AdminActionCard(
                    title: "Défis & Objectifs",
                    subtitle: "Créer des challenges quotidiens",
                    icon: Icons.emoji_events,
                    color1: const Color(0xFF7C3AED),
                    color2: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageGoalsPage())),
                  ),
                  const SizedBox(height: 15),

                  // 4. Badges (NOUVEAU)
                  _AdminActionCard(
                    title: "Badges & Récompenses",
                    subtitle: "Ajouter et gérer les badges",
                    icon: Icons.verified,
                    color1: const Color(0xFFDB2777),
                    color2: const Color(0xFFEC4899),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageBadgesPage())),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS UI
// -----------------------------------------------------------------------------

class _SimpleStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SimpleStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            
            // FittedBox empêche le texte de déborder si le chiffre est grand
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: darkBlue),
              ),
            ),
            
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color1,
    required this.color2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Icône avec dégradé
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color1, color2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: color1.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            
            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Flèche
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}