import 'package:flutter/material.dart';

const _kSkeletonBase = Color(0x14FFFFFF);
const _kSkeletonHighlight = Color(0x33FFFFFF);

/// Shimmer hand-rolado (sin agregar dependencias): un [ShaderMask] con un
/// gradiente que se desliza en loop sobre bloques placeholder opacos,
/// tiñéndolos con `BlendMode.srcATop` (conserva la forma del hijo, la
/// reemplaza por los colores del gradiente animado).
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: const [_kSkeletonBase, _kSkeletonHighlight, _kSkeletonBase],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Bloque rectangular placeholder de esquinas redondeadas.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Placeholder con la forma de un post del feed: avatar + líneas de texto +
/// fila de acciones. Reemplaza el `CircularProgressIndicator` genérico para
/// que la carga se sienta como parte del layout, no como una espera vacía.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 120, height: 12),
                      SizedBox(height: 6),
                      SkeletonBox(width: 70, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.4,
              child: SkeletonBox(width: double.infinity, height: 12),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                SkeletonBox(
                  width: 50,
                  height: 20,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                SizedBox(width: 16),
                SkeletonBox(
                  width: 50,
                  height: 20,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de [count] tarjetas placeholder, para reemplazar el loader del feed.
class PostCardSkeletonList extends StatelessWidget {
  final int count;
  const PostCardSkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => const PostCardSkeleton(),
    );
  }
}

/// Placeholder con la forma de un `ListTile` de conversación: avatar
/// circular + dos líneas de texto + hora a la derecha.
class ConversationTileSkeleton extends StatelessWidget {
  const ConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SkeletonBox(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 100, height: 13),
                  SizedBox(height: 8),
                  SkeletonBox(width: 160, height: 11),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonBox(width: 30, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Lista de [count] tiles placeholder, para reemplazar el loader de la
/// pantalla de conversaciones.
class ConversationSkeletonList extends StatelessWidget {
  final int count;
  const ConversationSkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => const ConversationTileSkeleton(),
    );
  }
}
