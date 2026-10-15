import 'package:flutter/material.dart';

// Message d'erreur avec un bouton pour recommencer le chargement.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Impossible de charger les données.'),
          TextButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
