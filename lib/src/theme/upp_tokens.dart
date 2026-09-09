import 'package:flutter/widgets.dart';

/// Tokens del sistema de diseño UPONPENGUIN ("Telón de Acero Digital"),
/// traducidos 1:1 de `colors_and_type.css` del proyecto de diseño "SOMI
/// Voz". Es la única fuente de color/medida del sistema: ningún widget
/// debe llevar un `Color(0x...)` suelto fuera de este archivo, igual que
/// el CSS original ("never use hex codes directly in components").
class UppTokens {
  UppTokens._();

  // ─────────────────── PALETA BASE ───────────────────
  static const cian = Color(0xFF00F0FF); // Cian Reactor — neón, CTA, acento
  static const negro = Color(0xFF0D0F12); // Negro KGB — canvas base
  static const hormigon = Color(0xFF5A6B75); // estructura, divisores
  static const rojo = Color(0xFFD62828); // error, crítico
  static const fosforo = Color(0xFFE0FBFC); // tinta principal

  // Escalas
  static const cian80 = Color(0xFF33F3FF);
  static const cian60 = Color(0xFF00B8C2);
  static const cian40 = Color(0xFF007A82);
  static const cian20 = Color(0xFF003D41);

  static const kgb80 = Color(0xFF13171C); // panel
  static const kgb60 = Color(0xFF1A1F24); // card
  static const kgb40 = Color(0xFF22282E); // seam / divider
  static const kgb20 = Color(0xFF2B333A);

  static const horm80 = Color(0xFF8497A1); // texto claro sobre fondo oscuro
  static const horm60 = Color(0xFF3A464E);
  static const horm40 = Color(0xFF283036);
  static const horm20 = Color(0xFF1B2024);

  static const rojo80 = Color(0xFFE45757);
  static const rojo60 = Color(0xFF8E1B1B);
  static const rojo40 = Color(0xFF5C1212);

  static const fos80 = Color(0xFF8FA8AC); // texto atenuado

  // ─────────────────── TOKENS SEMÁNTICOS ───────────────────
  static const bgBase = negro;
  static const bgPanel = kgb80;
  static const bgCard = kgb60;
  static const bgElevated = kgb40;
  static const bgInverse = fosforo;

  static const fg1 = fosforo; // texto principal
  static const fg2 = fos80; // cuerpo atenuado / secundario
  static const fg3 = horm80; // meta, rótulos
  static const fgMuted = hormigon; // deshabilitado / estructural
  static const fgOnAccent = negro; // texto sobre botón cian

  static const border1 = horm60; // regla por defecto
  static const border2 = horm40; // costura fina
  static const borderActive = cian; // foco / hover

  static const accent = cian;
  static const accentSoft = cian60;
  static const danger = rojo;
  static const dangerSoft = rojo60;

  // ─────────────────── MÉTRICAS ───────────────────
  /// El sistema nunca redondea esquinas.
  static const double radius = 0;
  static const double rule = 1;
  static const double ruleHeavy = 2;

  /// Sombra dura, desplazada, sin blur — el gesto característico del
  /// sistema (`box-shadow: 6px 6px 0 var(--upp-hormigon)`).
  static const Offset shadowHardOffset = Offset(6, 6);
  static const Offset shadowHardOffsetPressed = Offset(2, 2);

  static List<BoxShadow> shadowHard({Offset offset = shadowHardOffset}) => [
        BoxShadow(color: hormigon, offset: offset, blurRadius: 0),
      ];

  // ─────────────────── TIPOGRAFÍA ───────────────────
  static const String fontDisplay = 'ClashDisplay';

  /// Menlo en iOS, Roboto Mono en Android/Linux: no se empaqueta ninguna
  /// mono propia, se resuelve por fallback de plataforma.
  static const List<String> fontMonoFallback = ['Menlo', 'Roboto Mono', 'monospace'];

  /// Tracking amplio para rótulos mono en mayúsculas — aparece en casi
  /// cada bloque del diseño (`letter-spacing: 0.22em`).
  static const double trackingWidest = 0.22;
  static const double trackingWide = 0.08;
  static const double trackingCaps = 0.04;
}
