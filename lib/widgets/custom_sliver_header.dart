import 'package:flutter/material.dart';

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class CustomSliverHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions; // <--- 1. NOUVELLE PROPRIÉTÉ

  const CustomSliverHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions, // <--- 2. AJOUT AU CONSTRUCTEUR
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100.0,
      backgroundColor: Colors.grey[50],
      elevation: 0,
      pinned: true,

      // 3. ON PASSE LES ACTIONS AU SLIVERAPPBAR
      actions: actions,

      // Bouton Retour
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      )
          : null,

      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [darkBlue, mainBlue, lightBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        child: FlexibleSpaceBar(
          centerTitle: true,
          titlePadding: const EdgeInsets.only(bottom: 16),
          title: Text(
            title,
            style: const TextStyle(
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
                child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1)),
              ),
              Positioned(
                bottom: -20,
                left: 20,
                child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(0.05)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}