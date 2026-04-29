import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class NewsPage extends StatefulWidget {
  final String newsId; 
  final String newsTitle;

  const NewsPage({
    super.key,
    required this.newsId,
    required this.newsTitle,
  });

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  static const String detailsTable = 'news_details';
  
  List<Map<String, dynamic>> _details = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from(detailsTable)
          .select()
          .eq('news_id', widget.newsId)
          .order('news_detail_id', ascending: true);

      if (mounted) {
        setState(() {
          _details = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: CustomScrollView(
        slivers: [

          // --- 1. HEADER RÉUTILISABLE (CustomSliverHeader) ---
          CustomSliverHeader(
            // Le titre vient des arguments du widget
            title: widget.newsTitle,
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
            // Pas d'actions pour cette page
          ),
          // --- FIN DU REMPLACEMENT ---

          // 2. CONTENU DÉTAILLÉ
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: _isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: mainBlue)))
                : _details.isEmpty
                ? const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_outlined, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Le contenu arrive bientôt !", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = _details[index];
                  return ContentBlockCard(
                    imageUrl: item['image_url'],
                    description: item['long_description'],
                  );
                },
                childCount: _details.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// Widget pour afficher un bloc de contenu (Image optionnelle + Texte Long optionnel)
class ContentBlockCard extends StatelessWidget {
  final String? imageUrl;
  final String? description;

  const ContentBlockCard({super.key, this.imageUrl, this.description});

  @override
  Widget build(BuildContext context) {
    if ((imageUrl == null || imageUrl!.isEmpty) && (description == null || description!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE (Si présente)
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_,__,___) => const SizedBox.shrink(),
              ),
            ),
          
          // TEXTE LONG (Si présent)
          if (description != null && description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                description!,
                style: const TextStyle(
                  fontSize: 16, 
                  color: Color(0xFF333333), 
                  height: 1.6, 
                ),
              ),
            ),
        ],
      ),
    );
  }
}