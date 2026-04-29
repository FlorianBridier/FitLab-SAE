// coach_selection_page.dart
import 'package:flutter/material.dart';
import 'main.dart'; // Assure-toi que 'supabase' est bien déclaré ici
import 'coach_profile_page.dart'; 

// -----------------------------------------------------------------------------
// COULEURS (Harmonisées)
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class CoachSelectionPage extends StatefulWidget {
  const CoachSelectionPage({super.key});

  @override
  State<CoachSelectionPage> createState() => _CoachSelectionPageState();
}

class _CoachSelectionPageState extends State<CoachSelectionPage> {
  List<Map<String, dynamic>> _coaches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoaches();
  }

  Future<void> _loadCoaches() async {
    try {
      final response = await supabase
          .from('users')
          .select('user_id, name, username, email, bio, specialties')
          .eq('role', 'coach');

      if (mounted) {
        setState(() {
          _coaches = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement coachs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIQUE DE SÉLECTION (CONSERVÉE) ---
  Future<void> _chooseCoach(String coachId, String coachName) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // 1. Définir le coach
      await supabase.from('users').update({'coach_id': coachId}).eq('user_id', myId);
      
      // 2. Créer l'amitié
      final existing = await supabase.from('friend_requests')
          .select()
          .or('and(sender_id.eq.$myId,receiver_id.eq.$coachId),and(sender_id.eq.$coachId,receiver_id.eq.$myId)')
          .maybeSingle();

      if (existing == null) {
        await supabase.from('friend_requests').insert({
          'sender_id': myId,
          'receiver_id': coachId,
          'status': 'accepted'
        });
      } else {
        await supabase.from('friend_requests').update({'status': 'accepted'}).eq('id', existing['id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Félicitations ! $coachName est votre coach et ami."), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _goToProfile(Map<String, dynamic> coach) async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => CoachProfilePage(coach: coach))
    );

    if (result == true) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 1. HEADER IMMERSIF
          SliverAppBar(
            expandedHeight: 140.0,
            pinned: true,
            backgroundColor: Colors.grey[50],
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text("Choisir un Coach", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                    Positioned(bottom: -30, left: 20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.05))),
                  ],
                ),
              ),
            ),
          ),

          // 2. CONTENU
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: mainBlue)))
          else if (_coaches.isEmpty)
            const SliverFillRemaining(child: Center(child: Text("Aucun coach disponible.", style: TextStyle(color: Colors.grey))))
          else
            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final coach = _coaches[index];
                    String firstSpecialty = (coach['specialties'] as String?)?.split(',').first ?? 'Coach';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _goToProfile(coach),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // AVATAR
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.orange.withOpacity(0.1),
                                  child: Text(
                                    (coach['name'] ?? 'C')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                
                                // INFO COACH
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(coach['name'] ?? 'Coach', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                                      const SizedBox(height: 4),
                                      Text("@${coach['username']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: mainBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(firstSpecialty.trim(), style: const TextStyle(color: mainBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                ),

                                // BOUTON CHOISIR
                                ElevatedButton(
                                  onPressed: () => _chooseCoach(coach['user_id'], coach['name']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mainBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    elevation: 0,
                                  ),
                                  child: const Text("Choisir", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _coaches.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}