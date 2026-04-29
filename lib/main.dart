import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'register_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'admin_panel_page.dart';
import 'manage_users.dart';
import 'manage_news_page.dart';
import 'news_page.dart';

// --- IMPORTS POUR LES NOUVELLES PAGES ---
import 'aboutus.dart';
import 'contactus.dart';

// -----------------------------------------------------------------------------
// CONFIGURATION SUPABASE (FRONT)
// -----------------------------------------------------------------------------
const supabaseUrl = 'https://iznmorxlsylczvrnfmum.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml6bm1vcnhsc3lsY3p2cm5mbXVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NTg0NjUsImV4cCI6MjA3NTMzNDQ2NX0.oqNT8IRV57OSrJ24mFFJwC3kNUnemJB1lixmfhZ3nPE';

final supabase = Supabase.instance.client;

// Couleurs globales
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

// -----------------------------------------------------------------------------
// MAIN
// -----------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // Initialisation de Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const FitLabApp());
}

class FitLabApp extends StatelessWidget {
  const FitLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: mainBlue,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mainBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/admin_panel': (context) => const AdminPanelPage(),
        '/manage_users': (context) => const ManageUsersPage(),
        '/manage_news': (context) => const ManageNewsPage(),
        '/about': (context) => const AboutUsPage(),
        '/contact': (context) => const ContactUsPage(),
      },
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH GATE
// -----------------------------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // Si pas connecté -> page d'accueil marketing
        if (session == null) {
          return const FitLabWelcomePage();
        }

        // Si connecté -> HomePage
        return const HomePage();
      },
    );
  }
}

// -----------------------------------------------------------------------------
// PAGE D'ACCUEIL (FITLAB WELCOME PAGE)
// -----------------------------------------------------------------------------
class FitLabWelcomePage extends StatelessWidget {
  final String footerLogo = 'assets/images/logo.png';

  const FitLabWelcomePage({super.key});

  // --- CORRECTION ICI : Récupération directe via Supabase ---
  Future<List<Map<String, dynamic>>> _fetchLatestNews() async {
    try {
      // On interroge la table 'news' directement
      final response = await supabase
          .from('news')
          .select()
      // Optionnel : Filtrer pour ne pas afficher les archives si la colonne existe et est true
      // .eq('archive', false)
          .order('created_at', ascending: false) // Les plus récentes en premier
          .limit(3); // On en prend seulement 3

      // Conversion du résultat en liste de Map
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erreur Supabase: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- HERO SECTION ---
              SizedBox(
                width: double.infinity,
                height: 520,
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [darkBlue, mainBlue, lightBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -100,
                      left: -100,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -120,
                      right: -120,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                footerLogo,
                                width: 42,
                                height: 42,
                                errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "FitLab",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 50),
                          const Text(
                            "Améliore ton corps,",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Libère ton potentiel.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Rejoins la plateforme fitness complète : entraînements, nutrition et suivi des progrès.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/login'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: mainBlue,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 6,
                                  ),
                                  child: const Text(
                                    "Se connecter",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/register'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    Colors.white.withOpacity(0.12),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 1.2,
                                      ),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: const Text(
                                    "Créer un compte",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- SECTION ACTUALITÉS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  children: const [
                    Text(
                      'Dernières actualités',
                      style: TextStyle(
                        color: mainBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchLatestNews(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: mainBlue),
                    );
                  } else if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Erreur de chargement des actualités.'),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        children: snapshot.data!
                            .map(
                              (news) => Padding(
                            padding:
                            const EdgeInsets.only(bottom: 14.0),
                            child: _HighlightCard(
                              // Adaptation aux noms des colonnes Supabase (voir image fournie)
                              newsId: news['news_id'].toString(),
                              imagePath: news['main_image_url'] ??
                                  'assets/images/placeholder.jpg',
                              title: news['title'] ?? 'Sans titre',
                              subtitle: news['short_description'] ?? '',
                              date: news['created_at'],
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    );
                  } else {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune actualité disponible.'),
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // --- SECTION A PROPOS & CONTACT ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "En savoir plus sur FitLab",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Découvrez notre équipe et contactez-nous pour toute question.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        // BOUTON A PROPOS
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/about');
                            },
                            icon: const Icon(Icons.info_outline, size: 20),
                            label: const Text("À propos"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mainBlue,
                              side: const BorderSide(color: mainBlue, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // BOUTON CONTACT
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/contact');
                            },
                            icon: const Icon(Icons.mail_outline, size: 20),
                            label: const Text("Contact"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- FOOTER ---
              Container(
                color: darkBlue,
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          footerLogo,
                          width: 34,
                          height: 34,
                          errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'FitLab',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ton compagnon fitness depuis 2025.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '© 2025 FitLab. Tous droits réservés.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Carte d'une news
// -----------------------------------------------------------------------------
class _HighlightCard extends StatefulWidget {
  final String newsId;
  final String imagePath;
  final String title;
  final String subtitle;
  final String? date;

  const _HighlightCard({
    required this.newsId,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    this.date,
  });

  @override
  State<_HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<_HighlightCard> {
  bool _hover = false;

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsPage(
          newsId: widget.newsId,
          newsTitle: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = '';
    try {
      if (widget.date != null) {
        final dt = DateTime.parse(widget.date!);
        formattedDate = DateFormat('dd MMM yyyy', 'fr_FR').format(dt);
      }
    } catch (_) {}

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _navigateToDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (_hover)
                BoxShadow(
                  color: lightBlue.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Transform.scale(
            scale: _hover ? 1.01 : 1.0,
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: widget.imagePath.startsWith('http')
                        ? Image.network(
                      widget.imagePath,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    )
                        : Image.asset(
                      widget.imagePath,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Texte
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        if (formattedDate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: lightBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _navigateToDetail,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    "Lire la suite",
                                    style: TextStyle(
                                      color: mainBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: mainBlue,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}