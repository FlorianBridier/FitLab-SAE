import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_page.dart';
import 'reset_password_page.dart';

// --- ACCÈS GLOBAL SUPABASE ---
final supabase = Supabase.instance.client;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour l'email/mot de passe classique
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1. LOGIQUE CONNEXION CLASSIQUE (EMAIL/PSEUDO)
  // ---------------------------------------------------------------------------
  bool _isEmail(String input) {
    return RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(input);
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    final loginValue = _loginController.text.trim();
    String emailToUse;

    try {
      // Gestion pseudo ou email
      if (_isEmail(loginValue)) {
        emailToUse = loginValue;
      } else {
        final response = await supabase
            .from('users')
            .select('email')
            .eq('username', loginValue)
            .maybeSingle();

        if (response == null) {
          throw 'Pseudo non trouvé';
        }
        emailToUse = response['email'] as String;
      }

      await supabase.auth.signInWithPassword(
        email: emailToUse,
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) {
        String msg = e.toString().contains('Pseudo non trouvé')
            ? 'Ce pseudo n\'existe pas.'
            : "Erreur de connexion : $e";
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. LOGIQUE CONNEXION GOOGLE (NOUVEAU)
  // ---------------------------------------------------------------------------
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // A. Configuration et lancement du flux Google
      // IMPORTANT : Remplace par ton ID Client Web (celui qui finit par .apps.googleusercontent.com)
      // Tu le trouves sur Google Cloud Console > Identifiants > ID Client OAuth 2.0 > Web client
      const webClientId = '916629589661-afo8rq9v13inuapf53ikedfus1uf5bdh.apps.googleusercontent.com'; // <-- TON ID ICI (J'ai mis celui de ta capture)

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();

      // Si l'utilisateur annule le panneau de connexion
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Pas d\'ID Token trouvé Google.';
      }

      // B. Authentification auprès de Supabase
      final authResponse = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // C. Création/Vérification du profil dans ta table 'public.users'
      // C'est CRUCIAL car ton app utilise cette table pour le profil
      final user = authResponse.user;
      if (user != null) {
        await _ensureUserProfileExists(user);
      }

      // D. Redirection
      if (mounted) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }

    } catch (e) {
      debugPrint("Erreur Google Sign In: $e");
      if (mounted) _showError("Erreur connexion Google: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Vérifie si l'utilisateur existe dans ta table 'users', sinon le crée
  Future<void> _ensureUserProfileExists(User user) async {
    final userId = user.id;

    // On vérifie si la ligne existe
    final existingData = await supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existingData == null) {
      // Création du profil par défaut
      // On génère un pseudo unique à partir de l'email (ex: jean.dupont_a1b2)
      final baseUsername = user.email?.split('@')[0] ?? 'user';
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final uniqueUsername = '${baseUsername}_$uniqueSuffix';

      await supabase.from('users').insert({
        'user_id': userId,
        'email': user.email ?? '',
        'name': user.userMetadata?['full_name'] ?? 'Utilisateur Google',
        'avatar_url': user.userMetadata?['avatar_url'], // Photo Google
        'role': 'user',
        'subscription_tier': 'free',
        'goal': 'forme',
        'username': uniqueUsername, // Champ unique requis
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. INTERFACE UTILISATEUR
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B5FA5),
      body: Stack(
        children: [
          // Cercles décoratifs
          Positioned(top: -100, left: -100, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle))),
          Positioned(bottom: -150, right: -150, child: Container(width: 300, height: 300, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo et Titre
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Text('FitLab', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0B5FA5))),
                    ),
                    const SizedBox(height: 10),
                    const Text('Bienvenue, c\'est l\'heure de s\'entraîner !', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 40),

                    // Formulaire
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text("Se Connecter", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B5FA5))),
                            const SizedBox(height: 25),

                            // Email / Pseudo
                            _buildTextField(_loginController, "Email ou Pseudo", Icons.person, validator: (v) => (v == null || v.isEmpty) ? "Requis" : null),
                            const SizedBox(height: 15),

                            // Mot de passe
                            _buildTextField(
                              _passwordController,
                              "Mot de passe",
                              Icons.lock,
                              obscure: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF0B5FA5).withOpacity(0.6)),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? "Min 6 caractères" : null,
                            ),

                            // Mot de passe oublié
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage())),
                                child: const Text("Mot de passe oublié ?", style: TextStyle(color: Color(0xFF0B5FA5), fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Bouton Se connecter
                            ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B5FA5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                  : const Text("Se Connecter", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),

                            const SizedBox(height: 20),

                            // --- BOUTON GOOGLE ---
                            Row(children: const [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OU", style: TextStyle(color: Colors.grey))), Expanded(child: Divider())]),
                            const SizedBox(height: 20),

                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _googleSignIn,
                              // ON UTILISE UNE ICONE NATIVE POUR ÉVITER LE BUG D'IMAGE
                              icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                              label: const Text(
                                  "Continuer avec Google",
                                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            // ----------------------

                            const SizedBox(height: 15),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushNamed('/register'),
                              child: const Text('Pas encore de compte ? S\'inscrire', style: TextStyle(color: Color(0xFF0B5FA5), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text("\"Le seul mauvais entraînement est celui qui n'a pas eu lieu\"", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, Widget? suffixIcon, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFF0B5FA5).withOpacity(0.8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFF0B5FA5), width: 2.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
      ),
      validator: validator,
    );
  }
}