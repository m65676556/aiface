import 'package:flutter/material.dart';

class AppUtils {
  static String parseExpression(String text) {
    final regex = RegExp(r'\[EXPRESSION:(\w+)\]');
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'neutral';
  }

  static String removeExpressionTags(String text) {
    return text.replaceAll(RegExp(r'\[EXPRESSION:\w+\]\s*'), '').trim();
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
