import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ajout nécessaire pour le Stream
import 'main.dart';
import 'chat_page.dart';
import 'friend_profile_page.dart';

const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

// ----------------------------------------------------------------------
// WIDGET HEADER (AVEC NOTIF DEMANDES)
// ----------------------------------------------------------------------
class _CustomFriendsHeader extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final VoidCallback onBack;

  const _CustomFriendsHeader({
    required this.tabController,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(108.0);

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [darkBlue, mainBlue, lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Titre et Retour
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: -40, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                  Positioned(bottom: -30, left: 20, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(0.05))),
                  const Center(child: Text('Communauté', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
                ],
              ),
            ),

            const Spacer(),

            // --- TABBAR ---
            TabBar(
              controller: tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),

              tabs: [
                const Tab(text: 'AMIS'),
                const Tab(text: 'MESSAGES'),

                // --- ONGLET DEMANDES AVEC NOTIF ---
                Tab(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    // On écoute les demandes entrantes en temps réel (uniquement reçues pour la notif)
                      stream: (currentUserId != null)
                          ? Supabase.instance.client
                          .from('friend_requests')
                          .stream(primaryKey: ['id'])
                          .eq('receiver_id', currentUserId)
                          .order('created_at')
                          : const Stream.empty(),
                      builder: (context, snapshot) {
                        int count = 0;
                        if (snapshot.hasData && snapshot.data != null) {
                          // On filtre pour ne garder que les 'pending'
                          count = snapshot.data!.where((r) => r['status'] == 'pending').length;
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('DEMANDES'),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            ]
                          ],
                        );
                      }
                  ),
                ),

                const Tab(text: 'CHERCHER'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FriendsPage extends StatefulWidget {
  final int initialIndex;

  const FriendsPage({super.key, this.initialIndex = 0});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _pendingRequests = []; // Reçues
  List<Map<String, dynamic>> _sentRequests = [];    // Envoyées (Ajout)
  List<Map<String, dynamic>> _myFriends = [];

  bool _isLoading = false;
  String? _currentUserId;
  String _subscriptionTier = 'free';
  String? _userRole;

  final Color primaryColor = const Color(0xFF004AAD);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialIndex);
    _currentUserId = supabase.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadUserSubscription();
    await _loadPendingRequests(); // Charge Reçues ET Envoyées
    await _loadFriends();
  }

  Future<void> _loadUserSubscription() async {
    if (_currentUserId == null) return;
    try {
      final response = await supabase.from('users').select('subscription_tier, role').eq('user_id', _currentUserId!).single();
      if (mounted) {
        setState(() {
          _subscriptionTier = (response['subscription_tier'] ?? 'free').toString().toLowerCase();
          _userRole = response['role'];
        });
      }
    } catch (e) { debugPrint("Erreur abonnement: $e"); }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (_currentUserId == null) return;
    try {
      final response = await supabase.from('friend_requests').select().or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId').eq('status', 'accepted');
      List<Map<String, dynamic>> friendsList = [];
      Set<String> uniqueIds = {};

      for (var rel in response) {
        final String friendId = (rel['sender_id'] == _currentUserId) ? rel['receiver_id'] : rel['sender_id'];
        if (uniqueIds.contains(friendId)) continue;
        uniqueIds.add(friendId);
        try {
          final userRes = await supabase.from('users').select('name, username').eq('user_id', friendId).single();
          friendsList.add({'friend_id': friendId, 'name': userRes['name'] ?? 'Ami', 'username': userRes['username'] ?? '...'});
        } catch (_) {}
      }
      if (mounted) setState(() => _myFriends = friendsList);
    } catch (_) {}
  }

  // MODIFIÉ POUR CHARGER LES DEUX TYPES DE DEMANDES
  Future<void> _loadPendingRequests() async {
    if (_currentUserId == null) return;
    try {
      // 1. Demandes REÇUES (receiver_id = moi)
      final List<Map<String, dynamic>> rawReceived = await supabase.from('friend_requests').select('id, sender_id, status').eq('receiver_id', _currentUserId!).eq('status', 'pending');
      List<Map<String, dynamic>> receivedList = [];
      for (var request in rawReceived) {
        final String senderId = request['sender_id'];
        try {
          final userResponse = await supabase.from('users').select('name, username').eq('user_id', senderId).single();
          receivedList.add({'id': request['id'], 'status': request['status'], 'sender_name': userResponse['name'] ?? 'Utilisateur', 'sender_username': userResponse['username'] ?? '...'});
        } catch (_) {}
      }

      // 2. Demandes ENVOYÉES (sender_id = moi)
      final List<Map<String, dynamic>> rawSent = await supabase.from('friend_requests').select('id, receiver_id, status').eq('sender_id', _currentUserId!).eq('status', 'pending');
      List<Map<String, dynamic>> sentList = [];
      for (var request in rawSent) {
        final String receiverId = request['receiver_id'];
        try {
          final userResponse = await supabase.from('users').select('name, username').eq('user_id', receiverId).single();
          sentList.add({'id': request['id'], 'status': request['status'], 'receiver_name': userResponse['name'] ?? 'Utilisateur', 'receiver_username': userResponse['username'] ?? '...'});
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _pendingRequests = receivedList;
          _sentRequests = sentList;
        });
      }
    } catch (_) {}
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('users').select('user_id, name, username').or('username.ilike.%$query%,name.ilike.%$query%').neq('user_id', _currentUserId!).limit(10);
      if (mounted) setState(() { _searchResults = List<Map<String, dynamic>>.from(response); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _sendRequest(String targetUserId) async {
    try {
      final existing = await supabase.from('friend_requests').select().or('and(sender_id.eq.$_currentUserId,receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.$_currentUserId)').maybeSingle();
      if (existing != null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déjà liés ou en attente.'))); return; }
      await supabase.from('friend_requests').insert({'sender_id': _currentUserId, 'receiver_id': targetUserId, 'status': 'pending'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée !')));
        _searchController.clear();
        setState(() => _searchResults = []);
        await _loadPendingRequests(); // Recharger pour voir la demande envoyée
      }
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur envoi.'))); }
  }

  Future<void> _respondToRequest(dynamic requestId, String status) async {
    try {
      if (status == 'rejected') await supabase.from('friend_requests').delete().eq('id', requestId);
      else await supabase.from('friend_requests').update({'status': status}).eq('id', requestId);
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'accepted' ? 'Ami ajouté !' : 'Demande supprimée')));
    } catch (_) {}
  }

  // Annuler une demande qu'on a envoyée
  Future<void> _cancelRequest(dynamic requestId) async {
    try {
      await supabase.from('friend_requests').delete().eq('id', requestId);
      await _loadPendingRequests();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande annulée.')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _CustomFriendsHeader(tabController: _tabController, onBack: () => Navigator.pop(context)),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _MessagesTab(), // Widget Interne
          _buildRequestsList(), // Widget Modifié
          _buildSearchPage(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_myFriends.isEmpty) return const Center(child: Text("Vous n'avez pas encore d'amis.", style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myFriends.length,
      itemBuilder: (ctx, i) {
        final friend = _myFriends[i];
        return Card(
          elevation: 1, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendProfilePage(friendId: friend['friend_id']))),
            leading: CircleAvatar(backgroundColor: lightBlue, child: Text((friend['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
            title: Text(friend['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("@${friend['username']}"),
            trailing: IconButton(
                icon: const Icon(Icons.message, color: mainBlue),
                onPressed: () {
                  bool allowed = _userRole == 'admin' || _subscriptionTier.contains('inter') || _subscriptionTier.contains('elite');
                  if (allowed) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(friendId: friend['friend_id'], friendName: friend['name'])));
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Réservé Premium")));
                }
            ),
          ),
        );
      },
    );
  }

  // MODIFIÉ : Affiche les deux listes (Reçues et Envoyées)
  Widget _buildRequestsList() {
    if (_pendingRequests.isEmpty && _sentRequests.isEmpty) {
      return const Center(child: Text("Aucune demande en cours.", style: TextStyle(color: Colors.grey)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- SECTION REÇUES ---
        if (_pendingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("REÇUES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkBlue)),
          ),
          ..._pendingRequests.map((req) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.orange, child: Text((req['sender_name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                title: Text(req['sender_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Veut être votre ami"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _respondToRequest(req['id'], 'accepted')),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _respondToRequest(req['id'], 'rejected')),
                ]),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
        ],

        // --- SECTION ENVOYÉES ---
        if (_sentRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("ENVOYÉES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: mainBlue)),
          ),
          ..._sentRequests.map((req) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.outgoing_mail, color: Colors.grey, size: 30),
                title: Text(req['receiver_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("En attente...", style: TextStyle(color: Colors.grey)),
                trailing: TextButton(
                  onPressed: () => _cancelRequest(req['id']),
                  child: const Text("Annuler", style: TextStyle(color: Colors.red)),
                ),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildSearchPage() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16), color: Colors.white,
        child: TextField(
          controller: _searchController, decoration: InputDecoration(hintText: 'Pseudo ou nom...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.send, color: mainBlue), onPressed: () => _searchUsers(_searchController.text)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.grey[100]),
          onSubmitted: _searchUsers,
        ),
      ),
      Expanded(
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: _searchResults.length,
          itemBuilder: (ctx, i) {
            final user = _searchResults[i];
            return Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
              title: Text(user['name'] ?? 'User'), subtitle: Text("@${user['username']}"),
              trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: mainBlue, foregroundColor: Colors.white), onPressed: () => _sendRequest(user['user_id']), child: const Text("Ajouter")),
            ));
          },
        ),
      ),
    ]);
  }
}

// ----------------------------------------------------------------------
// WIDGET MESSAGERIE (Intégré)
// ----------------------------------------------------------------------
class _MessagesTab extends StatefulWidget {
  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  final String _myId = supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final response = await supabase.from('friend_requests').select().or('sender_id.eq.$_myId,receiver_id.eq.$_myId').eq('status', 'accepted');
      List<Map<String, dynamic>> temp = [];
      Set<String> processed = {};

      for (var rel in response) {
        final String otherId = (rel['sender_id'] == _myId) ? rel['receiver_id'] : rel['sender_id'];
        if (processed.contains(otherId)) continue;
        processed.add(otherId);

        final userRes = await supabase.from('users').select('name, username, role').eq('user_id', otherId).single();
        String lastMsg = "Nouvelle discussion";
        try {
          final msgRes = await supabase.from('messages').select('content').or('and(sender_id.eq.$_myId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$_myId)').order('created_at', ascending: false).limit(1).maybeSingle();
          if (msgRes != null) lastMsg = msgRes['content'];
        } catch (_) {}

        temp.add({'id': otherId, 'name': userRes['name'] ?? 'User', 'role': userRes['role'] ?? 'member', 'last_message': lastMsg});
      }
      if (mounted) setState(() { _conversations = temp; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: mainBlue));
    if (_conversations.isEmpty) return const Center(child: Text("Aucune conversation.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(10), itemCount: _conversations.length,
      itemBuilder: (ctx, i) {
        final conv = _conversations[i];
        final bool isCoach = conv['role'] == 'coach';
        return Card(
          elevation: 2, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(radius: 25, backgroundColor: isCoach ? Colors.orange.shade100 : Colors.blue.shade100, child: isCoach ? const Icon(Icons.sports_gymnastics, color: Colors.deepOrange) : Text((conv['name'] as String)[0].toUpperCase(), style: const TextStyle(color: mainBlue, fontWeight: FontWeight.bold))),
            title: Row(children: [Text(conv['name'], style: const TextStyle(fontWeight: FontWeight.bold)), if (isCoach) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: const Text("COACH", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]]),
            subtitle: Text(conv['last_message'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(friendId: conv['id'], friendName: conv['name']))).then((_) => _loadConversations()),
          ),
        );
      },
    );
  }
}