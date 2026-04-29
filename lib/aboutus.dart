// about_us_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: <Widget>[
          // 1. HEADER (Design identique à NutritionPage / ContactUsPage)
          SliverAppBar(
            expandedHeight: 140.0,
            pinned: true,
            backgroundColor: Colors.grey[50],
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[darkBlue, mainBlue, lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text(
                  "À propos de nous",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Décoration subtile en arrière-plan
                    Positioned(
                        top: -50,
                        right: -50,
                        child: CircleAvatar(
                            radius: 80,
                            backgroundColor: Colors.white.withOpacity(0.1))),
                    Positioned(
                        bottom: -30,
                        left: 20,
                        child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white.withOpacity(0.05))),
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
                children: <Widget>[
                  
                  // SECTION 1 : QUI SOMMES-NOUS (Who We Are)
                  _ContentCard(
                    icon: Icons.groups_rounded,
                    title: "Qui sommes-nous ?",
                    child: Text(
                      "FitLab est votre compagnon fitness ultime, conçu pour vous aider à atteindre vos objectifs de santé et de bien-être.\n\nNous croyons que le fitness doit être accessible, agréable et durable pour tous, quel que soit votre niveau actuel ou votre expérience.",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.6, // Meilleure lisibilité
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2 : CE QUE NOUS OFFRONS (What We Offer)
                  _ContentCard(
                    icon: Icons.fitness_center_rounded,
                    title: "Ce que nous offrons",
                    child: Column(
                      children: const <Widget>[
                        _FeatureItem(
                          text: "Plans d'entraînement personnalisés et adaptés à vos objectifs.",
                          dotColor: mainBlue,
                        ),
                        _FeatureItem(
                          text: "Bibliothèque d'exercices complète avec démonstrations vidéo.",
                          dotColor: Colors.green,
                        ),
                        _FeatureItem(
                          text: "Suivi des progrès et analyses détaillées de vos performances.",
                          dotColor: Colors.orange,
                        ),
                        _FeatureItem(
                          text: "Conseils nutritionnels et outils de planification des repas.",
                          dotColor: mainBlue,
                        ),
                        _FeatureItem(
                          text: "Soutien de la communauté et défis motivants.",
                          dotColor: Colors.green,
                        ),
                        _FeatureItem(
                          text: "Conseils d'experts par des professionnels certifiés du fitness.",
                          dotColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // FOOTER LOGO
                  Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mainBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt, color: mainBlue, size: 30),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "FitLab",
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold, 
                          color: darkBlue
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Votre aventure commence ici.",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
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
}

// -----------------------------------------------------------------------------
// WIDGETS DE DESIGN (Reusable)
// -----------------------------------------------------------------------------

class _ContentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _ContentCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // On déclare la propriété 'title' pour le débogueur
    properties.add(StringProperty('title', title));
    // On déclare la propriété 'icon' (type générique car pas de IconDataProperty natif simple)
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
  }

  @override
  Widget build(final BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Arrondi style Nutrition
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la carte avec Icône et Titre
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: mainBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: mainBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Contenu de la carte
          child,
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;
  final Color dotColor;

  const _FeatureItem({
    required this.text,
    required this.dotColor,
  });

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text));
    properties.add(ColorProperty('dotColor', dotColor));
  }

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Point coloré (Bullet point)
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          // Texte
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}