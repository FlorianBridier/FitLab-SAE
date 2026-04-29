import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart'; // Pour accéder à supabase

// -----------------------------------------------------------------------------
// COULEURS HARMONISÉES
// -----------------------------------------------------------------------------
const Color darkBlue = Color(0xFF103741);
const Color mainBlue = Color(0xFF004AAD);
const Color lightBlue = Color(0xFF4266D9);
const Color accentGreen = Color(0xFF00C853);
const Color backgroundGrey = Color(0xFFF8F9FA);

class WorkoutSessionPage extends StatefulWidget {
  final int trainingId;
  final String workoutTitle;

  const WorkoutSessionPage({
    super.key,
    required this.trainingId,
    required this.workoutTitle,
  });

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = true;
  bool _hasStarted = false;

  Timer? _timer;
  int _currentStepIndex = 0;
  bool _isResting = false;
  int _timeLeft = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final response = await supabase
          .from('workout_exercises')
          .select()
          .eq('training_id', widget.trainingId)
          .order('order', ascending: true);

      if (mounted) {
        setState(() {
          _exercises = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement exos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIQUE TIMER & NAVIGATION ---

  void _startWorkoutSequence() {
    if (_exercises.isEmpty) return;
    setState(() {
      _hasStarted = true;
    });
    _startStep(0);
  }

  void _startStep(int index) {
    if (index >= _exercises.length) {
      _finishWorkout();
      return;
    }

    final exercise = _exercises[index];
    setState(() {
      _currentStepIndex = index;
      _isResting = false;
      _timeLeft = exercise['duration_sec'];
      _isPaused = false;
    });
    _startTimer();
  }

  void _startRest() {
    final exercise = _exercises[_currentStepIndex];
    final int restTime = exercise['rest_sec'] ?? 0;

    if (restTime <= 0) {
      _startStep(_currentStepIndex + 1);
      return;
    }

    setState(() {
      _isResting = true;
      _timeLeft = restTime;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        if (_isResting) {
          _startStep(_currentStepIndex + 1);
        } else {
          _startRest();
        }
      }
    });
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  void _skip() {
    _timer?.cancel();
    if (_isResting) {
      _startStep(_currentStepIndex + 1);
    } else {
      _startRest();
    }
  }

  // --- SAUVEGARDE & CALCUL ---

  int _calculateCalories() {
    int totalSeconds = 0;
    for (var exo in _exercises) {
      totalSeconds += (exo['duration_sec'] as int);
    }
    double kcal = (totalSeconds / 60) * 8;
    return kcal < 5 ? 5 : kcal.round();
  }

  // 1. Mise à jour des stats globales (Pas/Calories du jour)
  Future<void> _saveSessionToDatabase() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final int caloriesBurned = _calculateCalories();

    try {
      final currentData = await supabase
          .from('user_daily_steps')
          .select('steps, calories, workouts')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      int currentSteps = 0;
      double currentCalories = 0;
      int currentWorkouts = 0;

      if (currentData != null) {
        currentSteps = currentData['steps'] ?? 0;
        currentCalories = (currentData['calories'] ?? 0).toDouble();
        currentWorkouts = currentData['workouts'] ?? 0;
      }

      await supabase.from('user_daily_steps').upsert({
        'user_id': userId,
        'date': today,
        'steps': currentSteps,
        'calories': currentCalories + caloriesBurned,
        'workouts': currentWorkouts + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, date');

    } catch (e) {
      debugPrint("❌ Erreur sauvegarde daily_steps : $e");
    }
  }

  // 2. Sauvegarde dans l'historique détaillé (assigned_workouts)
  Future<void> _saveHistoryLog() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase.from('assigned_workouts').insert({
        'athlete_id': userId,
        'training_id': widget.trainingId,
        'is_completed': true, // On marque comme terminé
        'assigned_at': DateTime.now().toIso8601String(),
        'coach_id': null, // Entraînement libre sans coach spécifique
      });
      debugPrint("✅ Historique détaillé sauvegardé !");
    } catch (e) {
      debugPrint("❌ Erreur sauvegarde assigned_workouts : $e");
    }
  }

  void _finishWorkout() async {
    _timer?.cancel();

    // Appel des deux sauvegardes en parallèle
    await Future.wait([
      _saveSessionToDatabase(),
      _saveHistoryLog()
    ]);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 60, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("SÉANCE TERMINÉE !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkBlue)),
            const SizedBox(height: 10),
            const Text("Félicitations, vous êtes allé jusqu'au bout !", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  Text("+${_calculateCalories()} kcal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.deepOrange)),
                  const Text("Ajouté à l'accueil", style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Retour à l'accueil", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UI START SCREEN ---
  Widget _buildStartScreen() {
    int totalDuration = 0;
    for (var exo in _exercises) {
      totalDuration += (exo['duration_sec'] as int) + (exo['rest_sec'] as int);
    }
    int minutes = (totalDuration / 60).ceil();

    return Scaffold(
      backgroundColor: backgroundGrey,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: backgroundGrey,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [darkBlue, mainBlue, lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: const Text("Aperçu de la séance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(top: -50, right: -50, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
                    Positioned(bottom: -30, left: 20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.05))),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          const Icon(Icons.fitness_center, size: 50, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(widget.workoutTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SummaryChip(icon: Icons.timer, label: "$minutes min"),
                      const SizedBox(width: 10),
                      _SummaryChip(icon: Icons.list, label: "${_exercises.length} exos"),
                      const SizedBox(width: 10),
                      _SummaryChip(icon: Icons.local_fire_department, label: "~${_calculateCalories()} kcal"),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("Programme", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                  const SizedBox(height: 15),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _exercises.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      final exo = _exercises[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  image: (exo['gif_url'] != null && exo['gif_url'].toString().isNotEmpty)
                                      ? DecorationImage(image: NetworkImage(exo['gif_url']), fit: BoxFit.cover)
                                      : null
                              ),
                              child: (exo['gif_url'] == null || exo['gif_url'].toString().isEmpty)
                                  ? Center(child: Text("${index + 1}", style: const TextStyle(color: mainBlue, fontWeight: FontWeight.bold, fontSize: 18)))
                                  : null,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(exo['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlue)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text("${exo['duration_sec']} sec", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      const SizedBox(width: 10),
                                      if(exo['rest_sec'] > 0) ...[
                                        Icon(Icons.snooze, size: 14, color: Colors.orange[300]),
                                        const SizedBox(width: 4),
                                        Text("Repos: ${exo['rest_sec']}s", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      ]
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ElevatedButton(
          onPressed: _startWorkoutSequence,
          style: ElevatedButton.styleFrom(
            backgroundColor: mainBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 5,
            shadowColor: mainBlue.withOpacity(0.4),
          ),
          child: const Text("COMMENCER LA SÉANCE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  // --- UI SESSION SCREEN ---
  Widget _buildSessionScreen() {
    final currentExo = _exercises[_currentStepIndex];
    final totalSteps = _exercises.length;
    final progress = (_currentStepIndex + 1) / totalSteps;
    final totalDuration = _isResting ? (currentExo['rest_sec'] ?? 10) : currentExo['duration_sec'];
    final progressValue = totalDuration > 0 ? _timeLeft / totalDuration : 0.0;

    final Color bgColor = _isResting ? accentGreen : Colors.white;
    final Color textColor = _isResting ? Colors.white : darkBlue;
    final Color subTextColor = _isResting ? Colors.white70 : Colors.grey;
    final Color timerColor = _isResting ? Colors.white : mainBlue;
    final Color trackColor = _isResting ? Colors.white24 : Colors.grey[100]!;

    String? imageUrl;
    if (!_isResting) {
      imageUrl = currentExo['gif_url'];
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, color: _isResting ? Colors.white : mainBlue, backgroundColor: trackColor, minHeight: 6),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isResting ? "TEMPS DE REPOS" : "EXERCICE ${_currentStepIndex + 1} / $totalSteps",
                        style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isResting ? "Respirez..." : currentExo['name'],
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ],
                  ),
                  IconButton(
                      icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _isResting ? Colors.white24 : Colors.grey[100], shape: BoxShape.circle),
                          child: Icon(Icons.close, color: textColor, size: 20)
                      ),
                      onPressed: () => Navigator.pop(context)
                  )
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!_isResting && imageUrl != null && imageUrl.isNotEmpty)
                    Container(
                      height: 220, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 25),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 10))]
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(25), child: Image.network(imageUrl, fit: BoxFit.cover)),
                    )
                  else
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if(_isResting) Positioned(top: 0, child: Icon(Icons.circle_outlined, size: 200, color: Colors.white.withOpacity(0.1))),
                        Icon(_isResting ? Icons.self_improvement : Icons.fitness_center, size: 100, color: _isResting ? Colors.white.withOpacity(0.9) : Colors.grey[200]),
                      ],
                    ),

                  if (_isResting && _exercises.length > _currentStepIndex + 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("À SUIVRE : ", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(_exercises[_currentStepIndex+1]['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                          width: 200, height: 200,
                          child: CircularProgressIndicator(value: progressValue, strokeWidth: 12, strokeCap: StrokeCap.round, color: timerColor, backgroundColor: trackColor)
                      ),
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("$_timeLeft", style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: textColor, height: 1)),
                        Text("secondes", style: TextStyle(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ),

                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(onTap: _togglePause, child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(color: _isResting ? Colors.white : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 35, color: _isResting ? accentGreen : darkBlue)
                    )),
                    const SizedBox(width: 40),
                    GestureDetector(onTap: _skip, child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(color: _isResting ? Colors.white24 : mainBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: const Icon(Icons.skip_next_rounded, size: 35, color: Colors.white)
                    )),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: mainBlue)));
    if (_exercises.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text("Cet entraînement est vide.")));

    if (!_hasStarted) {
      return _buildStartScreen();
    }
    return _buildSessionScreen();
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: mainBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: mainBlue),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: mainBlue, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}