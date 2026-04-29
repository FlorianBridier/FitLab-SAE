// contact_us_page.dart

import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB (Mêmes que ton fichier)
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulation d'envoi (Ici tu connecteras Supabase plus tard)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message envoyé avec succès ! 🚀'),
          backgroundColor: Colors.green,
        ),
      );
      _subjectController.clear();
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER IDENTIQUE À LA NUTRITION PAGE
          SliverAppBar(
            expandedHeight: 140.0,
            pinned: true,
            backgroundColor: Colors.grey[50],
            elevation: 0,
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
                  "Contactez-nous",
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intro
                    const Text(
                      "Une question ou une suggestion ?",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkBlue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Notre équipe est là pour vous aider à atteindre vos objectifs.",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),

                    // CARTES D'INFORMATION (Style _MealCard simplifié)
                    const _ContactInfoCard(
                      icon: Icons.email_outlined,
                      title: "Email",
                      subtitle: "support@fitlab.com",
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const _ContactInfoCard(
                      icon: Icons.phone_outlined,
                      title: "Téléphone",
                      subtitle: "+33 1 23 45 67 89",
                      color: Colors.green,
                    ),
                    const SizedBox(height: 32),

                    // FORMULAIRE
                    const Text(
                      "Envoyez-nous un message",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkBlue),
                    ),
                    const SizedBox(height: 16),

                    // Champ Sujet
                    _CustomTextField(
                      controller: _subjectController,
                      label: "Sujet",
                      icon: Icons.title,
                    ),
                    const SizedBox(height: 16),

                    // Champ Message
                    _CustomTextField(
                      controller: _messageController,
                      label: "Votre message",
                      icon: Icons.message_outlined,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 40),

                    // BOUTON ENVOYER (Style identique au bouton "Ajouter à mon plan")
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Envoyer le message',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS UI (Basés sur ton design system)
// -----------------------------------------------------------------------------

class _ContactInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ContactInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkBlue)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  const _CustomTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (value) =>
            value == null || value.isEmpty ? 'Ce champ est requis' : null,
        style: const TextStyle(color: darkBlue),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon:
              Icon(icon, color: mainBlue.withOpacity(0.6)), // Icône colorée
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none, // Pas de bordure visible par défaut
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}