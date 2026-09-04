import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Barra de navegación flotante con estética "liquid glass" (vidrio
/// líquido, estilo Apple Tahoe): blur fuerte, highlight especular en el
/// borde superior, sombra profunda que la separa claramente del fondo,
/// un brillo diagonal que recorre el vidrio en loop lento (la barra
/// "respira"), y una "píldora" de selección que se desliza con animación
/// elástica entre destinos.
///
/// Diseño label-siempre-visible-debajo-del-ícono (como una bottom nav
/// clásica), NO icon-only: cada destino reserva un ancho IGUAL vía
/// `Expanded`, así el layout nunca puede hacer overflow sin importar
/// cuántos destinos haya ni qué tan largo sea el label — a diferencia de
/// depender de que un texto "entre" en un ancho máximo fijo.
///
/// Se usa flotando sobre el contenido (dentro de un `Stack`, NO como
/// `bottomNavigationBar` del `Scaffold`) para que se vea como un objeto
/// de vidrio suspendido, no como una barra pegada al borde.
class LiquidGlassNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<LiquidGlassDestination> destinations;
  final VoidCallback? onBrandTap;
  final String brandLetter;

  const LiquidGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.onBrandTap,
    this.brandLetter = '?',
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  // Un único AnimationController en loop maneja TODAS las animaciones
  // "vivas" del vidrio (brillo diagonal + respiración del borde) — un
  // solo Ticker para toda la barra en vez de uno por efecto, así el
  // costo de la animación continua no se multiplica.
  late final AnimationController _liveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _liveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const radius = 34.0;
    const barHeight = 74.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset + 22),
      // IMPORTANTE: la sombra va en un contenedor SIN clip, separado del
      // que recorta+difumina. Si la sombra estuviera dentro del mismo
      // ClipRRect que el blur, el clip la corta y queda "desubicada"
      // (proyectada en formas raras en vez de un halo limpio alrededor).
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedBuilder(
              animation: _liveCtrl,
              builder: (context, child) {
                // "Respiración" del vidrio: el borde y el degradé de fondo
                // laten muy sutilmente entre dos intensidades — da la
                // sensación de una superficie líquida viva, no un panel
                // estático, sin ser una distracción.
                final breathe = 0.5 + 0.5 * (1 - (2 * _liveCtrl.value - 1).abs());
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: Colors.white.withValues(alpha: 0.07 + 0.02 * breathe),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22 + 0.10 * breathe),
                      width: 1.2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.20 + 0.06 * breathe),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: child,
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Highlight especular superior: línea de luz fija.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(radius),
                          topRight: Radius.circular(radius),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Brillo diagonal que recorre todo el ancho de la barra
                  // en loop lento — el efecto "liquid glass" en movimiento
                  // que pedía Fernando, no solo un panel de vidrio quieto.
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: AnimatedBuilder(
                        animation: _liveCtrl,
                        builder: (context, _) {
                          final t = _liveCtrl.value;
                          return Align(
                            alignment: Alignment(-3 + 6 * t, 0),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Container(
                                width: 46,
                                height: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.10),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      _BrandMark(
                        onTap: widget.onBrandTap,
                        pulse: _liveCtrl,
                        letter: widget.brandLetter,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      // Expanded (no Flexible+ConstrainedBox como antes)
                      // garantiza matemáticamente que la fila de destinos
                      // ocupa exactamente el ancho restante, repartido en
                      // partes iguales — no puede overflowear sin importar
                      // el largo del label, porque cada ítem ya sabe su
                      // ancho exacto antes de dibujar el texto.
                      Expanded(
                        child: Row(
                          children: List.generate(widget.destinations.length, (i) {
                            final dest = widget.destinations[i];
                            final selected = i == widget.selectedIndex;
                            return Expanded(
                              child: _NavItem(
                                key: ValueKey('navitem_$i'),
                                destination: dest,
                                selected: selected,
                                onTap: () {
                                  if (!selected) HapticFeedback.selectionClick();
                                  widget.onDestinationSelected(i);
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final LiquidGlassDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
              border: selected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.38),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            // Column en vez de Row: el label vive ABAJO del ícono, no al
            // costado — así el ancho de cada ítem depende solo de repartir
            // el espacio disponible entre destinos (vía Expanded arriba),
            // nunca del ancho intrínseco del texto del label.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.elasticOut,
                      scale: selected ? 1.08 : 1.0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          selected ? destination.selectedIcon : destination.icon,
                          key: ValueKey(selected),
                          color: fg,
                          size: 21,
                        ),
                      ),
                    ),
                    if (destination.badgeCount != null && destination.badgeCount! > 0)
                      Positioned(
                        top: -6,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.25)),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '${destination.badgeCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar del usuario fijo a la izquierda de la barra: muestra la inicial
/// de su nombre (a modo de foto de perfil placeholder, mismo patrón que
/// un avatar clásico) sobre una cápsula con degradé púrpura→cian. Es
/// también la entrada al perfil propio: tocarlo abre `ProfileScreen` del
/// usuario logueado (ver `onBrandTap`/`brandLetter` en `MainShell`).
class _BrandMark extends StatelessWidget {
  final VoidCallback? onTap;
  final Animation<double> pulse;
  final String letter;
  const _BrandMark({required this.onTap, required this.pulse, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.2),
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final glow = 0.35 + 0.20 * (1 - (2 * pulse.value - 1).abs());
            return Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA855F7), Color(0xFF06B6D4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withValues(alpha: glow),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? badgeCount;

  const LiquidGlassDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
  });
}
