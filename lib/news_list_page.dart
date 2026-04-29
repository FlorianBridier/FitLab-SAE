import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'news_page.dart'; // On importe la page de DÉTAIL pour la navigation

// --- IMPORT DES WIDGETS RÉUTILISABLES ---
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

final supabase = Supabase.instance.client;

class NewsListPage extends StatelessWidget {
  const NewsListPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchAllNews() async {
    final response = await supabase
        .from('news')
        .select('news_id, title, short_description, main_image_url, created_at')
        .eq('archive', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    initializeDateFormatting('fr_FR', null);

    return Scaffold(
      backgroundColor: Colors.grey[50],

      // 1. AJOUT DU MENU LATÉRAL
      endDrawer: const SharedDrawer(),

      body: CustomScrollView(
        slivers: [
          // 2. REMPLACEMENT DU HEADER MANUEL PAR LE WIDGET PERSONNALISÉ
          CustomSliverHeader(
            title: "Actualités FitLab",
            showBackButton: true, // Affiche la flèche retour
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(), // Affiche le bouton menu à droite
              ),
            ],
          ),

          // 3. LISTE DES ACTUALITÉS (Inchangée)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            sliver: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchAllNews(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: mainBlue)),
                  );
                } else if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(
                        "Erreur de chargement",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  );
                } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final newsList = snapshot.data!;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final news = newsList[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: NewsHighlightCard(
                            // On passe l'ID pour la navigation vers le détail
                            newsId: news['news_id'].toString(),
                            imagePath: news['main_image_url'] ?? '',
                            title: news['title'] ?? 'Sans titre',
                            subtitle: news['short_description'] ?? '',
                            date: news['created_at'],
                          ),
                        );
                      },
                      childCount: newsList.length,
                    ),
                  );
                } else {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(
                        "Aucune actualité.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// CARTE NEWS (DANS LA LISTE) - STRICTEMENT IDENTIQUE À AVANT
class NewsHighlightCard extends StatefulWidget {
  final String newsId;
  final String imagePath;
  final String title;
  final String subtitle;
  final String? date;

  const NewsHighlightCard({
    super.key,
    required this.newsId,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    this.date,
  });

  @override
  State<NewsHighlightCard> createState() => _NewsHighlightCardState();
}

class _NewsHighlightCardState extends State<NewsHighlightCard> {
  bool _isPressed = false;

  void _navigateToDetail() {
    // Redirection vers NewsPage (le détail)
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
    } catch (_) {
      formattedDate = '';
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _navigateToDetail,

      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: widget.imagePath.startsWith('http')
                      ? Image.network(
                    widget.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                      : Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  ),
                ),
              ),

              // CONTENU TEXTE
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formattedDate.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: lightBlue),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: lightBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: darkBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // BOUTON LIRE LA SUITE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Lire la suite",
                          style: TextStyle(
                            color: mainBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: mainBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: mainBlue,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 50),
      ),
    );
  }
}