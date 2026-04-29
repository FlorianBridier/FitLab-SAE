import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  final Color iconColor;
  final bool isTransparent;

  const MenuButton({
    super.key,
    this.iconColor = Colors.white,
    this.isTransparent = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Ouvre le menu de droite (EndDrawer)
        Scaffold.of(context).openEndDrawer();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isTransparent
              ? Colors.white.withOpacity(0.2)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.menu, color: iconColor, size: 20),
      ),
    );
  }
}