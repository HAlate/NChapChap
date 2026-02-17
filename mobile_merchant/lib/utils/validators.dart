class Validators {
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Numéro requis';
    if (value.length < 8) return 'Numéro trop court';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis';
    if (value.length < 6) return 'Mot de passe trop court';
    return null;
  }
}
