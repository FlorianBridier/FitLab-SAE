import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class StepService {
  // Instance singleton (pour qu'on utilise toujours le même service partout)
  static final StepService _instance = StepService._internal();
  factory StepService() => _instance;
  StepService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  late Stream<StepCount> _stepCountStream;
  
  // Clés de stockage local
  static const String _keyLastDate = 'step_last_date';
  static const String _keyStepsAtMidnight = 'step_anchor_midnight';

  /// Initialise le service : demande la permission et lance l'écoute
  Future<void> initService() async {
    // 1. Demander la permission d'activité physique
    var status = await Permission.activityRecognition.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      print("Permission refusée pour le podomètre");
      return;
    }

    // 2. Lancer l'écoute du flux
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(_onStepCount).onError(_onStepError);
  }

  /// Fonction appelée à chaque fois que le téléphone détecte un pas
  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    int systemSteps = event.steps; // Nombre total de pas depuis le dernier reboot
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Récupération des données sauvegardées
    String? savedDate = prefs.getString(_keyLastDate);
    int? stepsAtMidnight = prefs.getInt(_keyStepsAtMidnight);

    // --- LOGIQUE DE CALCUL ---

    // Cas 1 : Changement de jour (C'est un nouveau jour !)
    if (savedDate != today) {
      // On définit le "zéro" d'aujourd'hui comme étant le total actuel
      stepsAtMidnight = systemSteps;
      await prefs.setString(_keyLastDate, today);
      await prefs.setInt(_keyStepsAtMidnight, systemSteps);
    }

    // Cas 2 : Le téléphone a redémarré (System steps est revenu à 0)
    // Si le total système est inférieur à notre référence, le téléphone a rebooté.
    if (stepsAtMidnight != null && systemSteps < stepsAtMidnight) {
      stepsAtMidnight = 0; 
      await prefs.setInt(_keyStepsAtMidnight, 0);
    }

    // Calcul final des pas du jour
    int dailySteps = systemSteps - (stepsAtMidnight ?? 0);
    if (dailySteps < 0) dailySteps = 0;

    print("--- DEBUG PAS ---");
    print("Total Système: $systemSteps");
    print("Référence Minuit: $stepsAtMidnight");
    print("Pas du jour calculés: $dailySteps");

    // --- SAUVEGARDE SUR SUPABASE ---
    await _saveToSupabase(user.id, today, dailySteps);
  }

  Future<void> _saveToSupabase(String userId, String date, int steps) async {
    try {
      await _supabase.from('user_daily_steps').upsert(
        {
          'user_id': userId,
          'date': date,
          'steps': steps,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, date', // Utilise la contrainte UNIQUE qu'on a créée
      );
    } catch (e) {
      print("Erreur Sync Supabase: $e");
    }
  }

  void _onStepError(error) {
    print('Erreur Pedometer: $error');
  }

  /// Récupère les pas du jour depuis Supabase (pour l'affichage au démarrage)
  Future<int> getTodaySteps() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final response = await _supabase
          .from('user_daily_steps')
          .select('steps')
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      if (response != null) {
        return response['steps'] as int;
      }
    } catch (e) {
      print("Erreur récupération steps: $e");
    }
    return 0;
  }
}