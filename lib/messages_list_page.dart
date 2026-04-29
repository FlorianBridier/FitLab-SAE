import 'package:flutter/material.dart';
import 'main.dart'; // Pour accéder à ta variable globale 'supabase'
import 'chat_page.dart';

// --- WIDGETS PERSONNALISÉS (Comme dans NewsPage) ---
import 'widgets/custom_sliver_header.dart';
import 'widgets/shared_drawer.dart';
import 'widgets/menu_button.dart';

// -----------------------------------------------------------------------------
// COULEURS FITLAB
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);

class MessagesListPage extends StatefulWidget {
  const MessagesListPage({super.key});

  @override
  State<MessagesListPage> createState() => _MessagesListPageState();
}

class _MessagesListPageState extends State<MessagesListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  
  // On récupère l'ID courant. 
  // Note: Assure-toi que l'utilisateur est bien connecté avant d'arriver ici.
  final String _myId = supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final response = await supabase
          .from('friend_requests')
          .select()
          .or('sender_id.eq.$_myId,receiver_id.eq.$_myId')
          .eq('status', 'accepted');

      List<Map<String, dynamic>> tempConversations = [];
      Set<String> processedIds = {};

      for (var rel in response) {
        final String otherId = (rel['sender_id'] == _myId) ? rel['receiver_id'] : rel['sender_id'];
        if (processedIds.contains(otherId)) continue;
        processedIds.add(otherId);

        final userRes = await supabase.from('users').select('name, username, role').eq('user_id', otherId).single();
        
        String lastMsg = "Nouvelle discussion";
        bool isUnread = false;

        try {
          final msgRes = await supabase
              .from('messages')
              .select('content, created_at, is_read, sender_id')
              .or('and(sender_id.eq.$_myId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$_myId)')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          if (msgRes != null) {
             lastMsg = msgRes['content'];
             if (msgRes['sender_id'] == otherId && msgRes['is_read'] == false) {
               isUnread = true;
             }
          }
        } catch (_) {}

        tempConversations.add({
          'id': otherId,
          'name': userRes['name'] ?? 'Utilisateur',
          'role': userRes['role'] ?? 'member',
          'last_message': lastMsg,
          'is_unread': isUnread
        });
      }

      if (mounted) {
        setState(() {
          _conversations = tempConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTION : MARQUER COMME LU ---
  Future<void> _markAsRead(String friendId) async {
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('sender_id', friendId)
        .eq('receiver_id', _myId)
        .eq('is_read', false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      endDrawer: const SharedDrawer(), // Ajout du menu latéral
      body: CustomScrollView(
        slivers: [
          // --- 1. HEADER PERSONNALISÉ ---
          const CustomSliverHeader(
            title: "Messagerie",
            showBackButton: true, // Ou false si c'est une page racine
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: MenuButton(),
              ),
            ],
          ),

          // --- 2. GESTION DU CONTENU (Loading / Empty / List) ---
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: mainBlue)),
            )
          else if (_conversations.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text("Aucune conversation pour le moment.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conv = _conversations[index];
                    return _buildConversationCard(conv);
                  },
                  childCount: _conversations.length,
                ),
              ),
            ),
            
          // Petit espace en bas
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // --- WIDGET HELPER POUR LE DESIGN DE LA CARTE ---
  Widget _buildConversationCard(Map<String, dynamic> conv) {
    final bool isCoach = conv['role'] == 'coach';
    final bool isUnread = conv['is_unread'] ?? false;
    final String name = conv['name'];
    final String lastMessage = conv['last_message'];
    final String friendId = conv['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // 1. Marquer comme lu
            await _markAsRead(friendId);

            if (!mounted) return;
            
            // 2. Navigation
            await Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => ChatPage(friendId: friendId, friendName: name)
              )
            );
            
            // 3. Rechargement au retour
            if (mounted) {
              await _loadConversations();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // AVATAR
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isCoach ? Colors.orange.shade100 : Colors.blue.shade50,
                  child: isCoach 
                    ? const Icon(Icons.sports_gymnastics, color: Colors.deepOrange, size: 28) 
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?', 
                        style: const TextStyle(color: mainBlue, fontWeight: FontWeight.bold, fontSize: 20)
                      ),
                ),
                const SizedBox(width: 16),
                
                // INFO TEXTE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                color: darkBlue
                              ),
                            ),
                          ),
                          if (isCoach) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6)
                              ),
                              child: const Text(
                                "COACH", 
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                              )
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.grey[600],
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14
                        ),
                      ),
                    ],
                  ),
                ),

                // ICONE / INDICATEUR
                const SizedBox(width: 8),
                if (isUnread)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}