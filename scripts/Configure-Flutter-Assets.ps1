# ============================================
# FLUTTER ASSETS CONFIGURATION SCRIPT
# ============================================

Write-Host "⚙️  Configuration des assets Flutter pour UUMO" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# Vérifier si pubspec.yaml existe
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ pubspec.yaml non trouvé!" -ForegroundColor Red
    Write-Host "📁 Exécutez ce script depuis la racine du projet Flutter" -ForegroundColor Yellow
    exit 1
}

# Lire le contenu actuel
$pubspecContent = Get-Content -Path "pubspec.yaml" -Raw

# Section assets à ajouter
$assetsSection = @"

  # UUMO Assets
  assets:
    - assets/logos/svg/
    - assets/logos/variants/
    
    # Icons
    - assets/icons/ios/
    - assets/icons/android/
    - assets/icons/adaptive/
    
    # Splash
    - assets/splash/
    - assets/splash/ios/
    - assets/splash/android/
    
    # Fonts (optionnel)
    - assets/fonts/
"@

# Vérifier si la section flutter existe déjà
if ($pubspecContent -match "flutter:") {
    # Ajouter les assets après la section flutter
    $updatedContent = $pubspecContent -replace "(flutter:)", "`$1`n$assetsSection"
}
else {
    # Ajouter la section flutter complète
    $updatedContent = $pubspecContent + @"

flutter:
$assetsSection
"@
}

# Écrire le nouveau contenu
$updatedContent | Out-File -FilePath "pubspec.yaml" -Encoding UTF8

Write-Host "✅ pubspec.yaml mis à jour avec les assets UUMO" -ForegroundColor Green

# --------------------------------------------------
# CRÉER LE FICHIER DE THÈME
# --------------------------------------------------
$themeDir = "lib/src/core/theme"
if (-not (Test-Path $themeDir)) {
    New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
}

# Fichier theme.dart
$themeContent = @"
// UUMO Theme Configuration
// Generated on $(Get-Date -Format "yyyy-MM-dd")

import 'package:flutter/material.dart';

class UUMOColors {
  // Variants
  static const Color rider = Color(0xFFFF6B35);
  static const Color driver = Color(0xFF34C759);
  static const Color eat = Color(0xFFFF3B30);
  static const Color merchant = Color(0xFF007AFF);
  
  // Backgrounds
  static const Color backgroundDark = Color(0xFF0F1A2B);
  static const Color backgroundLight = Color(0xFF1C2B3E);
  static const Color cardBackground = Color(0xFF253447);
  
  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFEBEBF5);
  static const Color textTertiary = Color(0xFF8E8E93);
  
  // Functional
  static const Color success = Color(0xFF32D74B);
  static const Color warning = Color(0xFFFFD60A);
  static const Color error = Color(0xFFFF453A);
  static const Color disabled = Color(0xFF8E8E93);
}

class UUMOTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: UUMOColors.rider,
      scaffoldBackgroundColor: UUMOColors.backgroundDark,
      cardColor: UUMOColors.cardBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: UUMOColors.backgroundDark,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: UUMOColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: UUMOColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: UUMOColors.textSecondary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: UUMOColors.textTertiary,
          fontSize: 14,
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: UUMOColors.rider,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: UUMOColors.rider,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }
  
  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      primaryColor: UUMOColors.rider,
      scaffoldBackgroundColor: Colors.white,
      cardColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
  
  // Helper pour obtenir la couleur par variante
  static Color getVariantColor(String variant) {
    switch (variant.toLowerCase()) {
      case 'rider':
        return UUMOColors.rider;
      case 'driver':
        return UUMOColors.driver;
      case 'eat':
        return UUMOColors.eat;
      case 'merchant':
        return UUMOColors.merchant;
      default:
        return UUMOColors.rider;
    }
  }
}
"@

$themePath = Join-Path $themeDir "uumo_theme.dart"
$themeContent | Out-File -FilePath $themePath -Encoding UTF8

Write-Host "✅ Thème Flutter généré: lib/src/core/theme/uumo_theme.dart" -ForegroundColor Green

# --------------------------------------------------
# CRÉER LE WIDGET LOGO
# --------------------------------------------------
$widgetsDir = "lib/src/core/widgets"
if (-not (Test-Path $widgetsDir)) {
    New-Item -ItemType Directory -Force -Path $widgetsDir | Out-Null
}

$logoWidgetContent = @"
// UUMO Logo Widget
// Generated on $(Get-Date -Format "yyyy-MM-dd")

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UUMOLogo extends StatelessWidget {
  final String variant; // 'rider', 'driver', 'eat', 'merchant'
  final double? width;
  final double? height;
  final Color? color;
  final bool animated;
  
  const UUMOLogo({
    Key? key,
    this.variant = 'rider',
    this.width = 200,
    this.height = 80,
    this.color,
    this.animated = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/logos/svg/uumo_\$variant.svg';
    
    return AnimatedContainer(
      duration: animated ? Duration(milliseconds: 300) : Duration.zero,
      curve: Curves.easeInOut,
      child: SvgPicture.asset(
        assetPath,
        width: width,
        height: height,
        color: color,
        fit: BoxFit.contain,
      ),
    );
  }
}

class UUMOLogoIcon extends StatelessWidget {
  final String variant;
  final double size;
  final Color? color;
  
  const UUMOLogoIcon({
    Key? key,
    this.variant = 'rider',
    this.size = 40,
    this.color,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/logos/svg/uumo_\${variant}_icon.svg';
    
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      color: color,
    );
  }
}

class UUMOLogoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String variant;
  final bool showBackButton;
  final List<Widget>? actions;
  
  const UUMOLogoAppBar({
    Key? key,
    this.variant = 'rider',
    this.showBackButton = true,
    this.actions,
  }) : super(key: key);
  
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: UUMOLogo(
        variant: variant,
        width: 120,
        height: 40,
      ),
      centerTitle: true,
      actions: actions,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }
}
"@

$logoWidgetPath = Join-Path $widgetsDir "uumo_logo_widget.dart"
$logoWidgetContent | Out-File -FilePath $logoWidgetPath -Encoding UTF8

Write-Host "✅ Widget Logo généré: lib/src/core/widgets/uumo_logo_widget.dart" -ForegroundColor Green

# --------------------------------------------------
# CRÉER LE SPLASH SCREEN
# --------------------------------------------------
$splashWidgetContent = @"
// UUMO Splash Screen
// Generated on $(Get-Date -Format "yyyy-MM-dd")

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class UUMOSplashScreen extends StatefulWidget {
  final String variant;
  final Duration duration;
  final VoidCallback? onComplete;
  
  const UUMOSplashScreen({
    Key? key,
    this.variant = 'rider',
    this.duration = const Duration(seconds: 2),
    this.onComplete,
  }) : super(key: key);
  
  @override
  _UUMOSplashScreenState createState() => _UUMOSplashScreenState();
}

class _UUMOSplashScreenState extends State<UUMOSplashScreen> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );
    
    _controller.forward();
    
    // Naviguer après la durée spécifiée
    Future.delayed(widget.duration, () {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1A2B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animé
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/splash/splash_logo_\${widget.variant}.svg',
                width: 200,
                height: 100,
              ),
            ),
            
            SizedBox(height: 40),
            
            // Nom de l'app
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'UUMO',
                style: TextStyle(
                  color: _getVariantColor(),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            
            SizedBox(height: 10),
            
            // Sous-titre
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Universal Urban Mobility',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ),
            
            SizedBox(height: 60),
            
            // Loader
            _buildLoader(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoader() {
    return SizedBox(
      width: 200,
      height: 3,
      child: LinearProgressIndicator(
        backgroundColor: Colors.white12,
        valueColor: AlwaysStoppedAnimation<Color>(_getVariantColor()),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
  
  Color _getVariantColor() {
    switch (widget.variant) {
      case 'rider':
        return Color(0xFFFF6B35);
      case 'driver':
        return Color(0xFF34C759);
      case 'eat':
        return Color(0xFFFF3B30);
      case 'merchant':
        return Color(0xFF007AFF);
      default:
        return Color(0xFFFF6B35);
    }
  }
}

// Version simplifiée pour les apps séparées
class UUMOSplashScreenSimple extends StatelessWidget {
  final String variant;
  
  const UUMOSplashScreenSimple({
    Key? key,
    required this.variant,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F1A2B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/splash/splash_logo_\$variant.svg',
              width: 150,
              height: 75,
            ),
            SizedBox(height: 30),
            Text(
              'UUMO',
              style: TextStyle(
                color: _getVariantColor(),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getVariantColor() {
    switch (variant) {
      case 'rider':
        return Color(0xFFFF6B35);
      case 'driver':
        return Color(0xFF34C759);
      case 'eat':
        return Color(0xFFFF3B30);
      case 'merchant':
        return Color(0xFF007AFF);
      default:
        return Color(0xFFFF6B35);
    }
  }
}
"@

$splashWidgetPath = Join-Path $widgetsDir "uumo_splash_screen.dart"
$splashWidgetContent | Out-File -FilePath $splashWidgetPath -Encoding UTF8

Write-Host "✅ Splash Screen généré: lib/src/core/widgets/uumo_splash_screen.dart" -ForegroundColor Green

# --------------------------------------------------
# CRÉER UN FICHIER D'EXPORT
# --------------------------------------------------
$exportContent = @"
// UUMO Assets Export
// Generated on $(Get-Date -Format "yyyy-MM-dd")

export 'uumo_theme.dart';
export 'uumo_logo_widget.dart';
export 'uumo_splash_screen.dart';
"@

$exportPath = Join-Path $themeDir "exports.dart"
$exportContent | Out-File -FilePath $exportPath -Encoding UTF8

Write-Host "`n" -NoNewline
Write-Host "✅ " -ForegroundColor Green -NoNewline
Write-Host "Configuration Flutter terminée !" -ForegroundColor Cyan
Write-Host "📦 Assets configurés dans pubspec.yaml" -ForegroundColor Yellow
Write-Host "🎨 Thème disponible: lib/src/core/theme/uumo_theme.dart" -ForegroundColor Yellow
Write-Host "🖼️  Widgets disponibles: lib/src/core/widgets/" -ForegroundColor Yellow
Write-Host "`n🚀 Pour utiliser les logos:" -ForegroundColor Cyan
Write-Host "   import 'package:your_app/src/core/theme/exports.dart';" -ForegroundColor Gray
Write-Host "   UUMOLogo(variant: 'rider')" -ForegroundColor Gray