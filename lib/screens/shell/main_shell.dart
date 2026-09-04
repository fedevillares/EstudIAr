import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/home_screen.dart';
import '../calendar/calendar_screen.dart';
import '../plan/study_plan_screen.dart';
import '../material/material_screen.dart';
import '../social/feed_screen.dart';
import '../messages/conversations_screen.dart';
import '../social/profile_screen.dart';
import '../../providers/social_providers.dart';
import '../../widgets/liquid_glass_nav_bar.dart';
import '../../core/auth/local_auth_service.dart';
import '../../features/auth/presentation/login_screen.dart';

/// Orden de navegación: Inicio queda en el CENTRO de la barra (posición
/// más natural para el pulgar y foco visual principal), flanqueado por
/// Comunidad y Mensajes (el corazón social), con Calendario y Material
/// en los extremos y Plan antes de Material.
///
/// Índices:
/// 0 Calendario | 1 Comunidad | 2 Inicio | 3 Mensajes | 4 Plan | 5 Material
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 2; // arranca en Inicio: ahora es el centro de la app.
  bool _navVisible = true;
  double _lastScrollOffset = 0;
  bool _loggingOut = false;

  // El admin puede deshabilitar/borrar la cuenta mientras el usuario ya
  // está logueado en su dispositivo; accountActiveProvider escucha el doc
  // de Firestore en vivo y esto fuerza el cierre de sesión al toque, sin
  // esperar a que reabra la app o intente loguearse de nuevo.
  Future<void> _forceLogout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    await LocalAuthService.logout();
    if (!mounted) return;
    ref.invalidate(currentUsernameProvider);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  final _screens = const [
    CalendarScreen(),
    FeedScreen(),
    HomeScreen(),
    ConversationsScreen(),
    StudyPlanScreen(),
    MaterialScreen(),
  ];

  void _onSelect(int i) {
    if (i == _index) return; // evita reconstruir/animar si tocan el mismo tab
    // Fusionamos en un solo setState para evitar dos rebuilds seguidos.
    setState(() {
      _index = i;
      _navVisible = true; // al cambiar de tab siempre mostramos la barra
    });
  }

  // Escucha el scroll burbujeante de CUALQUIER lista/scroll dentro de la
  // pantalla activa (ListView, GridView, etc. — no hace falta tocar cada
  // screen individualmente) y oculta/muestra la barra flotante según la
  // dirección: bajar = ocultar (más espacio para leer), subir = mostrar.
  bool _onScrollNotification(ScrollNotification notif) {
    if (notif.depth != 0) return false; // solo el scroll "principal" de la screen
    // Ignora scrolls horizontales (carruseles, o el swipe entre tabs de un
    // TabBarView/PageView, como en MaterialScreen) — solo nos interesa el
    // scroll vertical de listas, que es el que debe correr la barra.
    if (notif.metrics.axis != Axis.vertical) return false;
    final offset = notif.metrics.pixels;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    // Ignora micro-jitter y el rebote elástico en los extremos.
    if (delta.abs() < 6) return false;

    final shouldHide = delta > 0 && offset > 40;
    final shouldShow = delta < 0 || offset <= 40;

    if (shouldHide && _navVisible) {
      setState(() => _navVisible = false);
    } else if (shouldShow && !_navVisible) {
      setState(() => _navVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(accountActiveProvider, (previous, next) {
      if (next.value == false) _forceLogout();
    });

    // select() extrae solo el int de interés: la shell no se reconstruye
    // cuando el StreamProvider pasa de loading→data con el mismo conteo.
    final unread = ref.watch(
      totalUnreadProvider.select((async) => async.maybeWhen(
        data: (count) => count,
        orElse: () => 0,
      )),
    );
    final me = ref.watch(currentUsernameProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final displayName = profileAsync.maybeWhen(
      data: (u) => u?.displayName,
      orElse: () => null,
    );
    final brandSource = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (me ?? '');
    final brandLetter =
        brandSource.isNotEmpty ? brandSource[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0520),
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D0520),
                    Color(0xFF080D1C),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),
          ),
          // Padding inferior para que el contenido no quede tapado por la
          // barra flotante (altura 72 + separación 22 + safe area).
          //
          // El IndexedStack evita rebuilds completos al cambiar de tab (cada
          // screen se queda viva en memoria), pero el salto entre pantallas
          // se sentía "trabado" por ser un corte seco sin transición. Un
          // AnimatedSwitcher con fade corto (160ms) sobre el índice ya
          // resuelto por el IndexedStack da la sensación de deslizamiento
          // fluido sin pagar el costo de reconstruir widgets ni de animar
          // un PageView completo.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 110 + MediaQuery.of(context).padding.bottom,
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: IndexedStack(index: _index, children: _screens),
                  ),
                ),
              ),
            ),
          ),
          // Barra flotante "liquid glass" anclada abajo, sobre el contenido.
          // Se desliza fuera de pantalla (+ fade) al bajar en el scroll y
          // vuelve a aparecer al subir o al cambiar de tab, conservando el
          // mismo estilo liquid glass — solo se anima su posición/opacidad,
          // nunca su apariencia interna.
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _navVisible ? Offset.zero : const Offset(0, 1.4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _navVisible ? 1 : 0,
                child: LiquidGlassNavBar(
                  selectedIndex: _index,
                  onDestinationSelected: _onSelect,
                  onBrandTap: me == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(username: me),
                            ),
                          );
                        },
                  brandLetter: brandLetter,
                  destinations: [
                    const LiquidGlassDestination(
                      icon: Icons.calendar_month_outlined,
                      selectedIcon: Icons.calendar_month_rounded,
                      label: 'Calendario',
                    ),
                    const LiquidGlassDestination(
                      icon: Icons.groups_outlined,
                      selectedIcon: Icons.groups_rounded,
                      label: 'Comunidad',
                    ),
                    const LiquidGlassDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Inicio',
                    ),
                    LiquidGlassDestination(
                      icon: Icons.chat_bubble_outline,
                      selectedIcon: Icons.chat_bubble_rounded,
                      label: 'Mensajes',
                      badgeCount: unread,
                    ),
                    const LiquidGlassDestination(
                      icon: Icons.auto_awesome_outlined,
                      selectedIcon: Icons.auto_awesome,
                      label: 'Plan',
                    ),
                    const LiquidGlassDestination(
                      icon: Icons.menu_book_outlined,
                      selectedIcon: Icons.menu_book_rounded,
                      label: 'Material',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
