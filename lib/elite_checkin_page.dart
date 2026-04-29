// elite_checkin_page.dart
import 'package:flutter/material.dart';
import 'main.dart';
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS HARMONISÉES
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class EliteCheckinPage extends StatefulWidget {
  const EliteCheckinPage({super.key});

  @override
  State<EliteCheckinPage> createState() => _EliteCheckinPageState();
}

class _EliteCheckinPageState extends State<EliteCheckinPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _feelingCtrl = TextEditingController();
  double _energy = 5.0;
  bool _isLoading = false;

  Future<void> _submitCheckin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Récupérer l'ID du coach
      final userRes = await supabase.from('users').select('coach_id').eq('user_id', userId).maybeSingle();
      final coachId = userRes?['coach_id'];


      // 2. Envoyer le bilan
      await supabase.from('checkins').insert({
        'user_id': userId,
        'coach_id': coachId, 
        'weight': double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
        'waist': double.tryParse(_waistCtrl.text.replaceAll(',', '.')),
        'energy': _energy.toInt(),
        'feeling': _feelingCtrl.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bilan envoyé à votre coach ! 🚀"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
        }
      } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      body: CustomScrollView(
        slivers: [
          // 1. HEADER DYNAMIQUE RÉUTILISABLE
          const CustomSliverHeader(
            title: "Bilan Hebdo (Elite)",
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // 2. CONTENU DU FORMULAIRE (dans SliverToBoxAdapter)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              // Suppression du Padding ici car il est inclus dans le Padding de la page.
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // SECTION MESURES
                    const Padding(
                      padding: EdgeInsets.only(left: 10, bottom: 10),
                      child: Text("MESURES PHYSIQUES", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          // POIDS
                          TextFormField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Poids (kg)",
                              hintText: "Ex: 75.5",
                              prefixIcon: const Icon(Icons.monitor_weight_outlined, color: mainBlue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) => v!.isEmpty ? "Requis" : null,
                          ),
                          const SizedBox(height: 20),
                          // TAILLE
                          TextFormField(
                            controller: _waistCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Tour de taille (cm) - Optionnel",
                              hintText: "Ex: 80",
                              prefixIcon: const Icon(Icons.straighten, color: mainBlue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // SECTION ÉNERGIE
                    const Padding(
                      padding: EdgeInsets.only(left: 10, bottom: 10),
                      child: Text("FORME & ÉNERGIE", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Niveau d'énergie", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: _getEnergyColor(_energy).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text("${_energy.toInt()}/10", style: TextStyle(color: _getEnergyColor(_energy), fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          const SizedBox(height: 10),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _getEnergyColor(_energy),
                              inactiveTrackColor: Colors.grey[200],
                              thumbColor: _getEnergyColor(_energy),
                              overlayColor: _getEnergyColor(_energy).withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _energy,
                              min: 1, max: 10, divisions: 9,
                              onChanged: (v) => setState(() => _energy = v),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("Fatigué", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text("En forme !", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // SECTION RESSENTI
                    const Padding(
                      padding: EdgeInsets.only(left: 10, bottom: 10),
                      child: Text("RESSENTI & NOTES", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: TextFormField(
                        controller: _feelingCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Comment s'est passée la semaine ? Difficultés ? Réussites ?",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (v) => v!.isEmpty ? "Dites au moins un mot :)" : null,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // BOUTON ENVOYER
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitCheckin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: mainBlue.withOpacity(0.4),
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text("ENVOYER MON BILAN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                SizedBox(width: 10),
                                Icon(Icons.send_rounded, size: 20)
                              ],
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

  // Petite fonction pour changer la couleur du slider selon la valeur
  Color _getEnergyColor(double value) {
    if (value < 4) return Colors.red;
    if (value < 7) return Colors.orange;
    return Colors.green;
  }
}