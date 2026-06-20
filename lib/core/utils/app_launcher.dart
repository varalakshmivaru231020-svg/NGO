import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchPhone(String phone, BuildContext context) async {
  final clean = phone.replaceAll(RegExp(r'\s|-'), '');
  final uri = Uri(scheme: 'tel', path: clean);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) _toast(context, 'Could not open dialer');
  }
}

Future<void> launchWhatsApp(String phone, BuildContext context, {String message = ''}) async {
  final clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  final uri = Uri.parse('https://wa.me/$clean${message.isNotEmpty ? '?text=${Uri.encodeComponent(message)}' : ''}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) _toast(context, 'WhatsApp not installed');
  }
}

Future<void> launchSms(String phone, BuildContext context, {String body = ''}) async {
  final clean = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  final uri = Uri(scheme: 'sms', path: clean, queryParameters: body.isNotEmpty ? {'body': body} : null);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) _toast(context, 'Could not open SMS');
  }
}

Future<void> launchEmail(String email, BuildContext context, {String subject = '', String body = ''}) async {
  final uri = Uri(scheme: 'mailto', path: email,
    queryParameters: {if (subject.isNotEmpty) 'subject': subject, if (body.isNotEmpty) 'body': body});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) _toast(context, 'Could not open email');
  }
}

Future<void> launchLink(String url, BuildContext context) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) _toast(context, 'Could not open link');
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  ));
}
