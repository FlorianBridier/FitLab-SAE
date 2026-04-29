import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitlab/main.dart'; // Assurez-vous que l'import correspond à votre nom de projet
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Cette fonction s'exécute une seule fois avant tous les tests
  setUpAll(() async {
    // 1. On doit simuler SharedPreferences car Supabase l'utilise pour stocker la session
    SharedPreferences.setMockInitialValues({});

    // 2. On initialise Supabase avec de fausses URL/Clés pour que le test ne plante pas
    await Supabase.initialize(
      url: 'https://fake-url.supabase.co',
      anonKey: 'fake-anon-key',
    );
  });

  testWidgets('Homepage elements smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FitLabApp());

    // ATTENTION : Comme Supabase est initialisé avec de fausses données,
    // l'utilisateur ne sera pas connecté. L'application affichera probablement
    // la page de Login.

    // Vérifiez que le widget se construit sans erreur
    expect(find.byType(MaterialApp), findsOneWidget);

    // Si votre test cherchait du texte spécifique, vous devrez peut-être adapter
    // les lignes 'expect' ci-dessous en fonction de ce qui s'affiche sur la page de Login.
    // Par exemple :
    // expect(find.text('Connexion'), findsOneWidget);
  });
}