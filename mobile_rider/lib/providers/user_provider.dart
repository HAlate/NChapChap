import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider pour l'utilisateur connecté actuel
final currentUserProvider = StreamProvider<User?>((ref) {
  final supabase = Supabase.instance.client;
  return supabase.auth.onAuthStateChange.map((data) => data.session?.user);
});

// Provider pour les données complètes de l'utilisateur depuis la table users
final userDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authUser = await ref.watch(currentUserProvider.future);

  if (authUser == null) return null;

  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('users')
        .select('id, full_name, phone, email, profile_photo_url')
        .eq('id', authUser.id)
        .maybeSingle();

    return response;
  } catch (e) {
    print('Error fetching user data: $e');
    return null;
  }
});

// Provider pour le nom de l'utilisateur (raccourci pratique)
final userNameProvider = Provider<String>((ref) {
  final userData = ref.watch(userDataProvider);

  return userData.when(
    data: (data) => data?['full_name'] as String? ?? 'Utilisateur',
    loading: () => 'Utilisateur',
    error: (_, __) => 'Utilisateur',
  );
});
