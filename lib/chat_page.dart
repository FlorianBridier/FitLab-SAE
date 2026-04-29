import 'package:flutter/material.dart';
import 'main.dart'; // Pour l'accès à la variable 'supabase'

// COULEURS FITLAB (Définies ici pour le style)
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);


class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  // Assurez-vous que l'utilisateur est connecté pour que cela ne soit pas null
  final String _myUserId = supabase.auth.currentUser!.id;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Fonction utilitaire pour formater la date
  String _formatDate(String timestamp) {
    final DateTime date = DateTime.parse(timestamp).toLocal();
    final DateTime now = DateTime.now();

    // Si c'est aujourd'hui : on affiche l'heure (ex: 14:30)
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    // Sinon on affiche la date (ex: 24/11)
    else {
      return "${date.day}/${date.month}";
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await supabase.from('messages').insert({
        'sender_id': _myUserId,
        'receiver_id': widget.friendId,
        'content': text,
      });

      // Petit scroll vers le bas après envoi
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 50,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi : $e")),
        );
      }
    }
  }

  // Stream de messages (filtré côté client par précaution)
  Stream<List<Map<String, dynamic>>> _getMessagesStream() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((maps) {
      // On filtre en Dart pour être sûr à 100% de n'avoir que cette conversation
      return maps.where((m) {
        final s = m['sender_id'];
        final r = m['receiver_id'];
        return (s == _myUserId && r == widget.friendId) ||
            (s == widget.friendId && r == _myUserId);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // --- APPBAR STYLISÉE ---
      appBar: AppBar(
        title: Text(
          widget.friendName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            // Dégradé à 3 couleurs
            gradient: LinearGradient(
              colors: [darkBlue, mainBlue, lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            // Coin arrondi (visible uniquement si l'AppBar n'est pas pinned/scrolled)
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bulles décoratives
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

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // --- FIN APPBAR STYLISÉE ---

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getMessagesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        const Text("Dites bonjour ! 👋", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Logique de scroll automatique
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    // Scroll vers le bas si un nouveau message arrive
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController, // On attache le contrôleur
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myUserId;
                    final timeString = _formatDate(msg['created_at']);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF004AAD) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              msg['content'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          // Affichage de l'heure
                          Padding(
                            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                            child: Text(
                              timeString,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Votre message...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF004AAD),
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}