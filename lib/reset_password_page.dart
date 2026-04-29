// reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart'; // Pour la navigation retour si besoin

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false; // Pour basculer entre l'écran Email et l'écran Code
  bool _isPasswordVisible = false;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIQUE SUPABASE (Reprise de ton ancienne app) ---

  Future<void> _sendResetCode() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'request-password-reset',
        body: {'email': _emailController.text.trim()},
      );

      if (!mounted) return;

      if (response.status == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Un email avec votre code a été envoyé.'), backgroundColor: Colors.green),
        );
        setState(() {
          _resetToken = response.data['token'];
          _codeSent = true; // On passe à l'étape suivante
        });
      } else {
        throw response.data['error'] ?? 'Une erreur est survenue';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCodeAndResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'confirm-password-reset',
        body: {
          'token': _resetToken,
          'code': _codeController.text.trim(),
          'newPassword': _passwordController.text.trim(),
        },
      );
      
      if (!mounted) return;

      if (response.status == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour avec succès !'), backgroundColor: Colors.green),
        );
        // Retour au login en nettoyant la navigation
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        throw response.data['error'] ?? 'Une erreur est survenue';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI (Design FitLab) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B5FA5),
      body: Stack(
        children: [
          // Décoration Cercle Haut Gauche
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Décoration Cercle Bas Droite
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Bouton Retour en haut à gauche
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Contenu Principal
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                   // Logo / Titre App (Optionnel, pour rester cohérent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FitLab',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B5FA5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Carte Blanche Principale
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _codeSent ? _buildResetForm() : _buildEmailForm(),
                      ),
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

  // ÉTAPE 1 : Formulaire Email
  Widget _buildEmailForm() {
    return Column(
      key: const ValueKey('emailForm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Réinitialisation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B5FA5),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Entrez votre email pour recevoir un code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 25),
        _buildTextField(
          _emailController,
          'Email',
          Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) => value!.isEmpty || !value.contains('@') ? 'Email invalide' : null,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendResetCode,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: const Color(0xFF0B5FA5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Envoyer le code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ÉTAPE 2 : Formulaire Code + Nouveau MDP
  Widget _buildResetForm() {
    return Column(
      key: const ValueKey('resetForm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nouveau mot de passe',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B5FA5),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Vérifiez vos emails et entrez le code reçu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
        const SizedBox(height: 25),
        _buildTextField(
          _codeController,
          'Code à 6 chiffres',
          Icons.pin,
          keyboardType: TextInputType.number,
          validator: (value) => value!.length != 6 ? 'Le code doit faire 6 chiffres' : null,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          _passwordController,
          'Nouveau mot de passe',
          Icons.lock,
          obscure: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF0B5FA5).withOpacity(0.6)),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          validator: (value) => value!.length < 6 ? 'Minimum 6 caractères' : null,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyCodeAndResetPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: const Color(0xFF0B5FA5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Réinitialiser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Helper Widget identique à Login Page
  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {
    TextInputType? keyboardType, 
    bool obscure = false, 
    String? Function(String?)? validator, 
    Widget? suffixIcon,
    }
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black87), 
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54), 
        filled: true,
        fillColor: Colors.grey[100], 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: Color(0xFF0B5FA5), width: 2.0)),
        prefixIcon: Icon(icon, color: const Color(0xFF0B5FA5).withOpacity(0.8)), 
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
      ),
      validator: validator,
    );
  }
}