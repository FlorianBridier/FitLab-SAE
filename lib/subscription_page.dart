// SubscriptionPage.dart
import 'package:flutter/material.dart';
import 'main.dart'; // Pour supabase
// --- IMPORTATION DU WIDGET SLIVER RÉUTILISABLE ---
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';        // Le menu latéral
import 'widgets/menu_button.dart';

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isLoading = true;
  String? _userRole;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadUserProfile();
    await _fetchSubscriptions();
  }

  Future<void> _loadUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await supabase.from('users').select('role').eq('user_id', userId).single();
      if (mounted) setState(() => _userRole = response['role'] as String?);
    } catch (e) { debugPrint('Erreur rôle: $e'); }
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final response = await supabase.from('subscriptions').select('*').order('price', ascending: true);
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  // --- ACTIVATION DE L'ABONNEMENT ---
  Future<void> _subscribe(String tierName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Normalisation du nom pour la base de données (ex: "Simple" -> "simple")
    String tierCode = tierName.toLowerCase();
    if (tierCode.contains('gratuit')) tierCode = 'free';

    try {
      // Mise à jour
      await supabase.from('users').update({'subscription_tier': tierCode}).eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Abonnement $tierName activé avec succès !"), backgroundColor: Colors.green));
        // On retourne à l'accueil pour recharger les droits
        await Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  // --- DIALOGUE ADMIN (Création/Modif) ---
  Future<void> _showEditDialog({Map<String, dynamic>? plan}) async {
    final isEditing = plan != null;
    final nameCtrl = TextEditingController(text: plan?['name'] ?? '');
    final priceCtrl = TextEditingController(text: plan?['price']?.toString() ?? '');
    final durationCtrl = TextEditingController(text: plan?['duration_days']?.toString() ?? '30');
    final descCtrl = TextEditingController(text: plan?['description'] ?? '');
    bool isPrimary = plan?['is_primary'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEditing ? 'Modifier' : 'Nouveau', style: const TextStyle(color: darkBlue)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix')),
                TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (jours)')),
                SwitchListTile(title: const Text("Mettre en avant"), value: isPrimary, onChanged: (v) => setStateDialog(() => isPrimary = v)),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameCtrl.text,
                  'price': double.tryParse(priceCtrl.text) ?? 0,
                  'duration_days': int.tryParse(durationCtrl.text) ?? 30,
                  'description': descCtrl.text,
                  'is_primary': isPrimary,
                };
                try {
                  if (isEditing) await supabase.from('subscriptions').update(data).eq('subscription_id', plan['subscription_id']);
                  else await supabase.from('subscriptions').insert(data);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _fetchSubscriptions();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePlan(int id) async {
    await supabase.from('subscriptions').delete().eq('subscription_id', id);
    await _fetchSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _userRole == 'admin';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(),
      floatingActionButton: isAdmin ? FloatingActionButton(onPressed: () => _showEditDialog(), backgroundColor: mainBlue, child: const Icon(Icons.add, color: Colors.white)) : null,
      body: CustomScrollView(
        slivers: [
          // 1. HEADER RÉUTILISABLE (CustomSliverHeader)
          const CustomSliverHeader(
            title: "Nos Offres",
            showBackButton: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // 2. CONTENU PRINCIPAL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                children: _plans.map((plan) => _PlanCard(
                  title: plan['name'],
                  price: "${plan['price']}€",
                  period: "/${plan['duration_days']}j",
                  features: (plan['description'] as String).split('\n'),
                  isPrimary: plan['is_primary'] ?? false,
                  onTap: () => _subscribe(plan['name']), // Activation
                  onEdit: isAdmin ? () => _showEditDialog(plan: plan) : null,
                  onDelete: isAdmin ? () => _deletePlan(plan['subscription_id']) : null,
                )).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title, price, period;
  final List<String> features;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback? onEdit, onDelete;

  const _PlanCard({required this.title, required this.price, required this.period, required this.features, required this.isPrimary, required this.onTap, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
          color: isPrimary ? mainBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
          border: isPrimary ? Border.all(color: Colors.blueAccent, width: 2) : null
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : darkBlue)),
          if (onEdit != null) Row(children: [IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: onEdit), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: onDelete)]),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(price, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : darkBlue)),
          Text(period, style: TextStyle(fontSize: 16, color: isPrimary ? Colors.white70 : Colors.grey)),
        ]),
        const SizedBox(height: 20),
        ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(Icons.check_circle, size: 18, color: isPrimary ? Colors.white : Colors.green), const SizedBox(width: 10), Expanded(child: Text(f, style: TextStyle(color: isPrimary ? Colors.white : Colors.black87)))]))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: isPrimary ? Colors.white : mainBlue, foregroundColor: isPrimary ? mainBlue : Colors.white), child: const Text("Choisir ce plan"))),
      ]),
    );
  }
}