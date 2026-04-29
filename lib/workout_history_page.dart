// workout_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Pour le formatage de date
import 'main.dart'; // Pour supabase
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';
import 'widgets/menu_button.dart';

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  List<Map<String, dynamic>> _workoutHistory = [];
  bool _isLoading = true;
  String _filterPeriod = 'Tous'; // Tous, 7j, 30j, 90j

  final Color primaryColor = const Color(0xFF0B5FA5);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadWorkoutHistory();
    });
  }

  // --- CHARGEMENT CORRECT DEPUIS ASSIGNED_WORKOUTS ---
  Future<void> _loadWorkoutHistory() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      DateTime dateLimit = DateTime(2000);
      final now = DateTime.now();
      if (_filterPeriod == '7j') {
        dateLimit = now.subtract(const Duration(days: 7));
      } else if (_filterPeriod == '30j') {
        dateLimit = now.subtract(const Duration(days: 30));
      } else if (_filterPeriod == '90j') {
        dateLimit = now.subtract(const Duration(days: 90));
      }

      final response = await supabase
          .from('assigned_workouts')
          .select('id, athlete_id, assigned_at, is_completed, coach_id, trainings(title, duration, level)')
          .eq('athlete_id', userId)
          .gte('assigned_at', dateLimit.toIso8601String())
          .order('assigned_at', ascending: false);

      if (mounted) {
        setState(() {
          _workoutHistory = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur historique: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SUPPRESSION ---
  Future<void> _deleteWorkoutEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('assigned_workouts').delete().eq('id', id);

      // Mise à jour locale pour éviter un rechargement réseau
      setState(() {
        _workoutHistory.removeWhere((item) => item['id'] == id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Séance supprimée')));
      }
    } catch (e) {
      debugPrint("Erreur suppression: $e");
    }
  }

  // --- BASCULER LE STATUT COMPLÉTÉ ---
  Future<void> _toggleCompletion(int id, bool currentStatus) async {
    try {
      // Optimistic UI : On change l'affichage tout de suite
      setState(() {
        final index = _workoutHistory.indexWhere((item) => item['id'] == id);
        if (index != -1) {
          _workoutHistory[index]['is_completed'] = !currentStatus;
        }
      });

      // Appel API
      await supabase
          .from('assigned_workouts')
          .update({'is_completed': !currentStatus})
          .eq('id', id);

    } catch (e) {
      debugPrint("Erreur update: $e");
      // Si erreur, on recharge pour remettre les bonnes données
      await _loadWorkoutHistory();
    }
  }

  // --- COULEURS SELON DIFFICULTÉ ---
  Color _getLevelColor(String? level) {
    if (level == null) return Colors.blue;
    final lower = level.toLowerCase();
    if (lower.contains('hard') || lower.contains('difficile')) return Colors.red;
    if (lower.contains('medium') || lower.contains('moyen')) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER
          const CustomSliverHeader(
            title: "Historique Sport",
            actions: [Padding(padding: EdgeInsets.only(right: 16), child: MenuButton())],
          ),

          // 2. FILTRES ET LISTE
          SliverToBoxAdapter(
            child: Column(
              children: [
                // BARRE DE FILTRES
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: ['Tous', '7j', '30j', '90j'].map((period) {
                      final isSelected = _filterPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(period),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _filterPeriod = period);
                            _loadWorkoutHistory();
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          checkmarkColor: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ÉTAT CHARGEMENT / VIDE
                if (_isLoading)
                  const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())
                else if (_workoutHistory.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("Aucune séance trouvée.", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                else
                // LISTE DES CARTES
                  ListView.builder(
                    shrinkWrap: true, // Important car dans un SliverToBoxAdapter
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _workoutHistory.length,
                    itemBuilder: (context, index) {
                      final item = _workoutHistory[index];
                      final training = item['trainings']; // Peut être null si supprimé

                      final id = item['id'] as int;
                      final isCompleted = item['is_completed'] ?? false;
                      final assignedAt = DateTime.parse(item['assigned_at']).toLocal();
                      final isCoachAssigned = item['coach_id'] != null;

                      // Données de l'entraînement (gestion sécurité null)
                      final title = training?['title'] ?? 'Entraînement supprimé';
                      final duration = training?['duration'] ?? 0;
                      final level = training?['level'] ?? 'N/A';
                      final levelColor = _getLevelColor(level);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.transparent,
                                width: 2
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LIGNE 1 : TITRE + DATE
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('EEEE d MMMM à HH:mm', 'fr_FR').format(assignedAt),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCoachAssigned)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(8)),
                                        child: const Text("COACH", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const Divider(height: 24),

                                // LIGNE 2 : STATS
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatItem(icon: Icons.timer, label: "$duration min", color: primaryColor),
                                    _StatItem(icon: Icons.local_fire_department, label: "${duration * 8} kcal", color: Colors.orange),
                                    _StatItem(icon: Icons.bar_chart, label: level, color: levelColor),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // LIGNE 3 : ACTIONS
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _toggleCompletion(id, isCompleted),
                                      icon: Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: isCompleted ? Colors.green : Colors.grey),
                                      label: Text(
                                        isCompleted ? "Terminé" : "Marquer fait",
                                        style: TextStyle(color: isCompleted ? Colors.green : Colors.grey[700], fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteWorkoutEntry(id),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Widget helper pour les stats
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}