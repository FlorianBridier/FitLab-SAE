import 'package:flutter/material.dart';
import 'main.dart'; // Pour supabase

const Color mainBlue = Color(0xFF004AAD);
const Color darkBlue = Color(0xFF103741);

class CoachProfilePage extends StatefulWidget {
  final Map<String, dynamic> coach;

  const CoachProfilePage({super.key, required this.coach});

  @override
  State<CoachProfilePage> createState() => _CoachProfilePageState();
}

class _CoachProfilePageState extends State<CoachProfilePage> {
  bool _isLoading = false;

  Future<void> _selectCoach() async {
    setState(() => _isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // On assigne le coach
      await supabase.from('users').update({'coach_id': widget.coach['user_id']}).eq('user_id', userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Félicitations ! ${widget.coach['name']} est votre nouveau coach."), backgroundColor: Colors.green)
        );
        // On retourne 'true' pour dire à la page précédente que c'est fait
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coach = widget.coach;
    final specialties = (coach['specialties'] as String? ?? "Général").split(',');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: mainBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [darkBlue, mainBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        (coach['name'] ?? 'C')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: mainBlue),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(coach['name'] ?? 'Coach', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("@${coach['username'] ?? '...'}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
            ),
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spécialités
                  const Text("Spécialités", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: specialties.map((s) => Chip(
                      label: Text(s.trim()),
                      backgroundColor: Colors.orange.shade50,
                      labelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                      side: BorderSide.none,
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 25),

                  // Bio
                  const Text("À propos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Text(
                      coach['bio'] ?? "Aucune description disponible.",
                      style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Bouton Action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _selectCoach,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("CHOISIR CE COACH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}