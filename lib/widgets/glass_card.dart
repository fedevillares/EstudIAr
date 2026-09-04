import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double opacity;
  // Cambiamos el nombre para que coincida con lo que piden tus pantallas
  final BorderRadius? borderRadius; 
  final Color? color; 
  final EdgeInsetsGeometry? padding;
  final bool showBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.opacity = 0.1,
    this.borderRadius, // Ahora tus pantallas viejas lo encontrarán
    this.color,        // Ahora tus pantallas viejas lo encontrarán
    this.padding,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    // Si no pasas un radius, usamos el de por defecto (20)
    final finalRadius = borderRadius ?? BorderRadius.circular(20);

    return ClipRRect(
      borderRadius: finalRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            // Priorizamos el color manual si viene (para tus alertas), si no, blanco traslúcido
            color: color ?? Colors.white.withValues(alpha: opacity),
            borderRadius: finalRadius,
            border: showBorder
                ? Border.all(color: Colors.white.withValues(alpha: 0.12))
                : null,
          ),
          child: Stack(
            children: [
              // Highlight especular sutil arriba, mismo lenguaje visual
              // que la nav bar liquid glass — da sensación de superficie
              // de vidrio real en vez de un panel plano semitransparente.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: finalRadius.topLeft,
                      topRight: finalRadius.topRight,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ],
          ),
        ),
      ),
    );
  }
}