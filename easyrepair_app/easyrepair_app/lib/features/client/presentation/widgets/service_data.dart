import 'package:flutter/material.dart';

class ServiceItem {
  final String title;
  final String emoji;
  final Color bg;
  final Color emojiBg;
  final String? imagePath;

  const ServiceItem({
    required this.title,
    required this.emoji,
    required this.bg,
    required this.emojiBg,
    this.imagePath,
  });
}

const kServices = [
  ServiceItem(
    title: 'AC Technician',
    emoji: '❄️',
    bg: Color(0xFFE8F4F8),
    emojiBg: Color(0xFFB2DFF0),
    imagePath: 'assets/images/ac.jpg',
  ),
  ServiceItem(
    title: 'Electrician',
    emoji: '⚡',
    bg: Color(0xFFFFF8E1),
    emojiBg: Color(0xFFFFECB3),
    imagePath: 'assets/images/electrician.jpg',
  ),
  ServiceItem(
    title: 'Plumber',
    emoji: '🔧',
    bg: Color(0xFFE8F5E9),
    emojiBg: Color(0xFFC8E6C9),
    imagePath: 'assets/images/plumber.jpg',
  ),
  ServiceItem(
    title: 'Handyman',
    emoji: '🔨',
    bg: Color(0xFFF3E5F5),
    emojiBg: Color(0xFFE1BEE7),
    imagePath: 'assets/images/handyman.jpg',
  ),
];
