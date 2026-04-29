// register_page.dart (MODIFIÉ)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; 

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(); // NOUVEAU
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _isPasswordVisible = false; 

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose(); // DISPOSE DU NOUVEAU
    _emailController.dispose();
    _passwordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Date de Naissance',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0B5FA5), 
            colorScheme: const ColorScheme.light(primary: Color(0xFF0B5FA5)), 
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    if ((_heightController.text.isNotEmpty && double.tryParse(_heightController.text) == null) ||
        (_weightController.text.isNotEmpty && double.tryParse(_weightController.text) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer des nombres valides pour la taille et le poids.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Inscription Supabase Auth (Email/Mdp)
      final AuthResponse response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      final user = response.user;

      if (user != null) {
        // 2. Insertion du profil (y compris le pseudo) dans la table 'users'
        await supabase.from('users').insert({
          'user_id': user.id, 
          'name': _nameController.text.trim(),
          'username': _usernameController.text.trim(), // AJOUT DU PSEUDO
          'email': user.email,
          'gender': _selectedGender,
          'birth_date': _selectedBirthDate?.toIso8601String().substring(0, 10), 
          'height_cm': _heightController.text.isNotEmpty ? double.tryParse(_heightController.text.trim()) : null,
          'weight_kg': _weightController.text.isNotEmpty ? double.tryParse(_weightController.text.trim()) : null,
          'role': 'user', 
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription réussie ! Veuillez vérifier votre email pour confirmer votre compte.')),
        );
        await Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de l\'inscription. Un utilisateur avec cet email existe peut-être déjà.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur Supabase : ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      // Capture l'erreur d'unicité du pseudo (Postgres unique constraint failure)
      if (e.toString().contains('users_username_key')) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur : Ce pseudo est déjà utilisé. Veuillez en choisir un autre.')),
          );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une erreur inattendue est survenue : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B5FA5), 
      body: Stack(
        children: [
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
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FitLab',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B5FA5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Prêt à dépasser vos limites ?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Carte blanche principale
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Créez votre compte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B5FA5),
                            ),
                          ),
                          const SizedBox(height: 25),

                          // Champ Nom 
                          _buildTextField(_nameController, 'Nom Complet', Icons.person, keyboardType: TextInputType.name),
                          const SizedBox(height: 15),
                          
                          // NOUVEAU CHAMP PSEUDO
                          _buildTextField(_usernameController, 'Pseudo', Icons.alternate_email,
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Le pseudo est requis.';
                              }
                              if (value.length < 3) {
                                return 'Le pseudo doit contenir au moins 3 caractères.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          
                          // Champ Email
                          _buildTextField(
                              _emailController, 
                              'Email', 
                              Icons.email, 
                              keyboardType: TextInputType.emailAddress, 
                              validator: (value) { 
                                if (value == null || value.isEmpty || !value.contains('@')) {
                                  return 'Veuillez entrer un email valide.';
                                }
                                return null;
                              }),
                          const SizedBox(height: 15),

                          // Champ Mot de passe
                          _buildTextField(
                              _passwordController, 
                              'Mot de passe', 
                              Icons.lock, 
                              keyboardType: TextInputType.text, 
                              obscure: !_isPasswordVisible, 
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: const Color(0xFF0B5FA5).withOpacity(0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              validator: (value) { 
                                if (value == null || value.length < 6) {
                                  return 'Le mot de passe doit contenir au moins 6 caractères.';
                                }
                                return null;
                              }),
                          const SizedBox(height: 25),
                          
                          // Reste des champs (Profil Facultatif)
                          const Text(
                            'Informations de Profil (Facultatif)', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16, 
                              color: Color(0xFF0B5FA5)
                            )
                          ),
                          const SizedBox(height: 15),

                          _buildGenderDropdown(),
                          const SizedBox(height: 15),
                          _buildDateSelector(context),
                          const SizedBox(height: 15),

                          _buildTextField(
                              _heightController, 
                              'Taille (cm)', 
                              Icons.height, 
                              keyboardType: TextInputType.number, 
                              optional: true,
                              validator: (value) {
                                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                                  return 'Veuillez entrer un nombre valide.';
                                }
                                return null;
                              },
                          ),
                          const SizedBox(height: 15),

                          _buildTextField(
                              _weightController, 
                              'Poids (kg)', 
                              Icons.monitor_weight, 
                              keyboardType: TextInputType.number, 
                              optional: true,
                              validator: (value) {
                                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                                  return 'Veuillez entrer un nombre valide.';
                                }
                                return null;
                              },
                          ), 
                          const SizedBox(height: 30),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: const Color(0xFF0B5FA5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : const Text(
                                    'S\'inscrire',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                          const SizedBox(height: 15),

                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Déjà un compte ? Se connecter',
                              style: TextStyle(color: Color(0xFF0B5FA5), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "\"Le seul mauvais entraînement est celui qui n'a pas eu lieu\"",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper pour les champs de texte (inchangé)
  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {
    TextInputType? keyboardType, 
    bool obscure = false, 
    String? Function(String?)? validator, 
    bool optional = false,
    Widget? suffixIcon,
    }
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black87), 
      decoration: InputDecoration(
        labelText: optional ? '$label (optionnel)' : label,
        labelStyle: const TextStyle(color: Colors.black54), 
        filled: true,
        fillColor: Colors.grey[100], 
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none, 
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0), 
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFF0B5FA5), width: 2.0), 
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF0B5FA5).withOpacity(0.8)), 
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
      ),
      validator: optional
          ? null
          : validator ??
              (value) {
                if (value == null || value.isEmpty) {
                  return '$label est requis.';
                }
                return null;
              },
    );
  }

  // Widget helper pour le sélecteur de genre (inchangé)
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Sexe (optionnel)',
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFF0B5FA5), width: 2.0),
        ),
        prefixIcon: Icon(Icons.transgender, color: const Color(0xFF0B5FA5).withOpacity(0.8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
      ),
      initialValue: _selectedGender,
      hint: const Text('Sélectionnez votre sexe', style: TextStyle(color: Colors.black54)),
      dropdownColor: Colors.white, 
      items: const ['homme', 'femme', 'autre']
          .map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value.toUpperCase(), style: const TextStyle(color: Colors.black87)),
            );
          }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedGender = newValue;
        });
      },
    );
  }

  // Widget helper pour le sélecteur de date (inchangé)
  Widget _buildDateSelector(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date de Naissance (optionnel)',
          labelStyle: const TextStyle(color: Colors.black54),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Color(0xFF0B5FA5), width: 2.0),
          ),
          prefixIcon: Icon(Icons.calendar_today, color: const Color(0xFF0B5FA5).withOpacity(0.8)), 
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
        ),
        child: Text(
          _selectedBirthDate == null
              ? 'Sélectionner une date'
              : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}',
          style: const TextStyle(fontSize: 16, color: Colors.black87), 
        ),
      ),
    );
  }
}