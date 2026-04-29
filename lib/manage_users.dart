// manage_users.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Assurez-vous que ce chemin est correct :
import 'widgets/custom_sliver_header.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);
const Color coachColor = Colors.orange; // Couleur pour le coach

// MODÈLE DE DONNÉES
class AppUser {
  final String userId;
  final String? name;
  final String? email;
  final String? role;
  final String? username;
  final String? avatarUrl;

  AppUser({
    required this.userId,
    this.name,
    this.email,
    this.role,
    this.username,
    this.avatarUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['user_id'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (username != null && username!.isNotEmpty) return username!;
    return email ?? 'Inconnu';
  }
}

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<AppUser> _allUsers = [];
  List<AppUser> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedFilter = "Tous"; // Tous, Admin, User, Coach

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> response = await Supabase.instance.client
          .from('users')
          .select('user_id, name, email, role, username, avatar_url');

      if (mounted) {
        setState(() {
          _allUsers = response.map((data) => AppUser.fromMap(data)).toList();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement users: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredUsers = _allUsers.where((user) {
      final matchesSearch = user.displayName.toLowerCase().contains(_searchQuery) ||
          (user.email?.toLowerCase().contains(_searchQuery) ?? false);

      if (_selectedFilter == "Tous") return matchesSearch;
      if (_selectedFilter == "Admin") return matchesSearch && user.role == 'admin';
      if (_selectedFilter == "Coach") return matchesSearch && user.role == 'coach'; // Filtre Coach
      if (_selectedFilter == "User") return matchesSearch && (user.role == 'user' || user.role == null);

      return matchesSearch;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 🚨 1. FONCTION DE MODIFICATION
  // ---------------------------------------------------------------------------
  Future<void> _showEditUserDialog(AppUser user) async {
    final nameController = TextEditingController(text: user.name ?? user.username ?? '');
    String selectedRole = user.role ?? 'user';
    
    // Si le rôle actuel n'est pas dans la liste standard, on le met par défaut à user
    if (!['user', 'admin', 'coach'].contains(selectedRole)) {
      selectedRole = 'user';
    }

    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Modifier l'utilisateur", style: TextStyle(color: darkBlue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Nom / Pseudo", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: "Rôle", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text("Utilisateur")),
                      DropdownMenuItem(value: 'coach', child: Text("Coach", style: TextStyle(color: coachColor, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'admin', child: Text("Administrateur", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selectedRole = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white),
                  onPressed: isUpdating ? null : () async {
                    setStateDialog(() => isUpdating = true);
                    try {
                      await Supabase.instance.client.from('users').update({
                        'name': nameController.text.trim(),
                        'role': selectedRole,
                      }).eq('user_id', user.userId);
                      if (!context.mounted) return;

                      Navigator.pop(context);
                      await _fetchUsers();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Utilisateur mis à jour"), backgroundColor: Colors.green)
                      );


                    } catch (e) {
                      setStateDialog(() => isUpdating = false);


                      if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erreur: $e"),
                                backgroundColor: Colors.red)
                        );
                      }
                    },
                  child: isUpdating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text("Enregistrer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 🚨 2. FONCTION DE SUPPRESSION
  // ---------------------------------------------------------------------------
  Future<void> _deleteUser(String userId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vous ne pouvez pas vous supprimer vous-même !"), backgroundColor: Colors.orange));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer cet utilisateur de la base de données ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('users').delete().eq('user_id', userId);
        await _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur supprimé."), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur suppression: $e"), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          const CustomSliverHeader(
            title: "Gérer les Utilisateurs",
            showBackButton: true,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Barre de recherche
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Rechercher un utilisateur...",
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filtres (Chips)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: "Tous", isSelected: _selectedFilter == "Tous", onTap: () => setState(() { _selectedFilter = "Tous"; _applyFilters(); })),
                        const SizedBox(width: 10),
                        _FilterChip(label: "Admin", isSelected: _selectedFilter == "Admin", onTap: () => setState(() { _selectedFilter = "Admin"; _applyFilters(); })),
                        const SizedBox(width: 10),
                        _FilterChip(label: "Coach", isSelected: _selectedFilter == "Coach", onTap: () => setState(() { _selectedFilter = "Coach"; _applyFilters(); })), // Chip Coach
                        const SizedBox(width: 10),
                        _FilterChip(label: "User", isSelected: _selectedFilter == "User", onTap: () => setState(() { _selectedFilter = "User"; _applyFilters(); })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Liste des utilisateurs
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: mainBlue))
                  else if (_filteredUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text("Aucun utilisateur trouvé.", style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _UserCard(
                          user: user,
                          onDelete: () => _deleteUser(user.userId),
                          onEdit: () => _showEditUserDialog(user),
                        );
                      },
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
// WIDGETS UI
// -----------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? mainBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? mainBlue : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _UserCard({required this.user, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = user.role == 'admin';
    final bool isCoach = user.role == 'coach';

    // Définition des couleurs selon le rôle
    Color badgeColor;
    Color badgeTextColor;
    String roleText;

    if (isAdmin) {
      badgeColor = Colors.red.withOpacity(0.1);
      badgeTextColor = Colors.red;
      roleText = 'ADMIN';
    } else if (isCoach) {
      badgeColor = Colors.orange.withOpacity(0.1);
      badgeTextColor = Colors.orange[800]!;
      roleText = 'COACH';
    } else {
      badgeColor = Colors.blue.withOpacity(0.1);
      badgeTextColor = Colors.blue;
      roleText = 'USER';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: badgeTextColor.withOpacity(0.1),
            backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) ? NetworkImage(user.avatarUrl!) : null,
            child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                ? Icon(Icons.person, color: badgeTextColor)
                : null,
          ),
          const SizedBox(width: 16),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue),
                ),
                Text(
                  user.email ?? 'Pas d\'email',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}