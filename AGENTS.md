# EstudIAr (EstudIApp) — Contexto para Codex

App Flutter/Dart de gestión de evaluaciones escolares con IA, para estudiantes
secundarios/universitarios. Incluye una red social interna y mensajería
directa. Dueño del proyecto: Fernando (Federico Villares). Respondé siempre
en español rioplatense (Argentina), tono directo y conciso.

## Stack y arquitectura

- Flutter/Dart, SDK `>=3.2.0`, Flutter `>=3.16.0`. Package name: `EstudIAr`
  (ojo: con mayúsculas así en `pubspec.yaml`, no `estudiar` — esto rompe
  `test/widget_test.dart` que importa `package:estudiar/main.dart`, error
  preexistente y no resuelto, no es algo que rompiste vos).
- State management: **Riverpod 2.x** (`ConsumerWidget`, `ConsumerStatefulWidget`,
  `AsyncNotifier`/`Notifier`).
- Persistencia local: **Hive** (evaluaciones, settings, consentimiento legal).
- Backend social/mensajería: **Firebase — solo Cloud Firestore**. No hay
  Firebase Auth (auth es custom, ver abajo) ni Firebase Storage configurado.
- IA: **Groq API** (`llama-3.3-70b-versatile` para texto, modelo de visión
  para imágenes), key hardcodeada en `lib/services/ai_service.dart` —
  pendiente histórico: migrar a servidor intermediario.
- Navegación: `Navigator` nativo + `MainShell` con `IndexedStack` (no usa
  `go_router` activamente pese a estar en `pubspec.yaml`).

## Autenticación (IMPORTANTE: no es Firebase Auth)

Auth completamente custom en `lib/core/auth/local_auth_service.dart`:
usuario/contraseña hasheada, guardado como documento en la colección
`users` de Firestore (doc ID = username normalizado a minúsculas vía
`_normalize()`). Hay un usuario admin especial (`admin`). El username
logueado se persiste en una Hive box (`logged_in_username`), no en
`FirebaseAuth.currentUser`. Si algo no carga datos del usuario actual,
revisar `currentUsernameProvider` en `lib/providers/social_providers.dart`,
no `FirebaseAuth.instance`.

## Red social (feature grande, agregada después de la app base)

- Modelos en `lib/models/social/`: `post.dart`, `comment.dart`,
  `message.dart`, `report.dart`. `AppUser` (perfil) en `lib/models/app_user.dart`
  con campos `displayName`, `bio`, `avatarUrl` (String? nullable).
- Repos: `lib/core/repositories/social_repository.dart` (posts, follows,
  bloqueos, reportes) y `messaging_repository.dart` (conversaciones/DMs).
- Moderación de contenido: `lib/core/security/content_moderation_service.dart`
  + excepciones en `moderation_exceptions.dart` (`BlockedUserException`,
  `ContentRejectedException`).
- Pantallas en `lib/screens/social/`: `feed_screen.dart`, `profile_screen.dart`,
  `edit_profile_screen.dart`, `comments_screen.dart`, `new_post_screen.dart`,
  `follow_list_screen.dart`.
- Mensajería directa en `lib/screens/messages/`: `conversations_screen.dart`,
  `chat_screen.dart`, `new_conversation_screen.dart`.
- Denormalización: `Post`/`Comment` guardan `authorAvatarUrl` copiado del
  perfil AL MOMENTO de crear el post/comentario, no en vivo. Si alguien
  cambia su avatar, los posts/comentarios viejos quedan con el avatar
  anterior — comportamiento aceptado, no es bug.

### Avatares: Base64 en Firestore, NO Firebase Storage

No hay `firebase_storage` ni `cached_network_image` en `pubspec.yaml`.
Decisión de diseño: el avatar se sube con `image_picker` (ya en
dependencias), se redimensiona a ~480px/calidad 70, se codifica a Base64 y
se guarda como data URI (`data:image/jpeg;base64,...`) directo en el campo
`avatarUrl` del doc de Firestore. Límite duro: si el Base64 pesa más de
~900KB se rechaza (límite de doc de Firestore es 1MB).

**Siempre** renderizar avatares con el helper `lib/utils/avatar_image.dart`
→ `avatarImageProvider(String? avatarUrl)`. Resuelve `MemoryImage` si es
data URI, `NetworkImage` si es una URL http(s) normal (por si en el futuro
se migra a Storage), o `null` si no hay avatar (mostrar iniciales como
fallback). No usar `NetworkImage(avatarUrl)` directo en ningún lugar nuevo.

### Búsqueda de usuarios por prefijo en Firestore

Patrón usado en `new_conversation_screen.dart` para buscar usuarios por
nombre: `orderBy('username').startAt([trimmed]).endAt(['$trimmed' + chr(0xF8FF)])`.
El carácter `0xF8FF` (punto más alto del BMP de Unicode) es obligatorio en
el `endAt` — sin él, el rango colapsa a coincidencia exacta y la búsqueda
por prefijo no devuelve nada. Si se agregan más búsquedas por texto en
Firestore, replicar este patrón.

## UI / Design system

- Fondo: gradiente oscuro `0xFF0D0520 → 0xFF080D1C → negro`, sin modo claro.
- Colores: púrpura `_kPurple = 0xFFA855F7`, cyan `_kCyan = 0xFF06B6D4`,
  peligro `_kDanger = 0xFFEF4444`.
- `GlassCard` (`lib/widgets/glass_card.dart`): card frosted-glass con
  `BackdropFilter`, usado en casi todas las pantallas.
- Orbes decorativos (`RadialGradient`) en las esquinas de cada screen.
- **`LiquidGlassNavBar`** (`lib/widgets/liquid_glass_nav_bar.dart`): barra de
  navegación inferior flotante, estilo "liquid glass" (blur fuerte +
  highlight especular + sombra profunda), NO es un `bottomNavigationBar`
  del `Scaffold` — vive dentro de un `Stack` en `MainShell`, flotando sobre
  el contenido. Diseño icon-only: el label de cada destino solo aparece
  (con fade + expansión animada) cuando ese ítem está seleccionado. Tiene
  un `ConstrainedBox(maxWidth: 78)` en el label y `Flexible` por ítem —
  esto es deliberado para evitar overflow horizontal con 6 destinos + logo
  en pantallas angostas; no quitarlo sin pensar en ese caso.
  Auto-hide en scroll: se oculta (slide + fade) al bajar y reaparece al
  subir o cambiar de tab, vía un único `NotificationListener<ScrollNotification>`
  en `MainShell` (no hace falta instrumentar cada pantalla individualmente).
  Filtra `notif.depth != 0` y ejes no verticales para no reaccionar a
  swipes horizontales (p.ej. el `TabBarView` interno de `MaterialScreen`).
- `MainShell` (`lib/screens/shell/main_shell.dart`): `IndexedStack` con 6
  tabs envuelto en `AnimatedSwitcher` (fade 160ms) para que el cambio de
  tab no se sienta como un corte seco. Orden de tabs:
  `0 Inicio | 1 Calendario | 2 Comunidad | 3 Mensajes | 4 Plan | 5 Material`
  (Comunidad/Mensajes están al centro a propósito, son el "corazón social").

## Restricciones del entorno de quien te asiste (Codex/sandbox)

- No hay Flutter/Dart SDK instalado en el sandbox de ejecución de comandos.
  No se puede correr `flutter analyze`, `flutter build`, ni `dart format`.
  Verificación de cambios: lectura completa del archivo + conteo de
  balance de llaves/paréntesis/corchetes (con cuidado: comentarios en
  español con paréntesis sueltos dan falsos positivos en scripts simples
  de conteo — si el conteo da desbalance, releer el archivo entero antes
  de asumir que el código está roto).
- Fernando corre `flutter analyze` en su máquina y pega el resultado. La
  mayoría del ruido histórico (300+ issues) es `info`-level
  `deprecated_member_use` (sobre todo `withOpacity` → debería migrarse a
  `.withValues()` en algún momento, no urgente) más errores preexistentes
  no relacionados en `firebase_options.dart` y `test/widget_test.dart`
  (mismatch de nombre de paquete, ver arriba).

## Convenciones de comunicación con Fernando

- Español, tono directo, sin verborragia innecesaria.
- Fernando reporta bugs de forma informal y a veces ambigua ("no me deja
  entrar", "dice overflowed") — vale la pena preguntar specifics (¿dónde
  exactamente? ¿qué intentaste?) antes de adivinar el archivo, sobre todo
  si hay varias pantallas candidatas.
- Cuando se reporta un "overflowed by X pixels" de Flutter, es un error en
  tiempo de ejecución real (texto/widget sin constraints en un `Row`/`Column`),
  no algo que aparezca como warning estático en el código — hay que
  rastrear el widget exacto, generalmente un `Text` sin `Expanded`/`Flexible`
  ni `overflow: TextOverflow.ellipsis`.

## Pendientes conocidos (no urgentes, no pedidos explícitamente)

- Migrar `withOpacity()` → `.withValues()` en todo el código (deprecation).
- `firebase_options.dart` parece tener contenido corrupto/mal generado.
- `test/widget_test.dart` referencia `package:estudiar/main.dart` en vez de
  `package:EstudIAr/main.dart`.
- API key de Groq hardcodeada en `ai_service.dart` — riesgo de seguridad
  conocido y aceptado por ahora, hay un pendiente histórico de moverla a
  un backend intermediario.
