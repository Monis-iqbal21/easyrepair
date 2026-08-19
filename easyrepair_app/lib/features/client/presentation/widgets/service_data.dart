import 'package:flutter/material.dart';

class ServiceItem {
  final String title;
  final String backendName; // exact backend category.name used for booking submit
  final String emoji;
  final Color bg;
  final Color emojiBg;
  final String? imagePath;

  const ServiceItem({
    required this.title,
    required this.backendName,
    required this.emoji,
    required this.bg,
    required this.emojiBg,
    this.imagePath,
  });
}

class ServiceCategory {
  final String heading;
  final List<ServiceItem> items;

  const ServiceCategory({required this.heading, required this.items});
}

// Returns image asset path for a given backend category name (normalized).
String? imagePathForCategory(String backendName) {
  return switch (backendName.toLowerCase()) {
    'ac technician'             => 'assets/images/ac.jpg',
    'electrician'               => 'assets/images/electrician.jpg',
    'plumber'                   => 'assets/images/plumber.jpg',
    'handyman'                  => 'assets/images/handyman.jpg',
    // 'cleaner' is the migration-seeded backend name for the cleaning service
    'cleaner'                   => 'assets/images/cleaner.png',
    // 'cleaning' kept as fallback alias if root seed was run
    'cleaning'                  => 'assets/images/cleaner.png',
    'painter'                   => 'assets/images/painting.jpg',
    'carpenter'                 => 'assets/images/carpenter.jpg',
    'appliances repair'         => 'assets/images/appliance.png',
    'pest control'              => 'assets/images/pest.png',
    'car wash'                  => 'assets/images/carwash.png',
    'gardener'                  => 'assets/images/gardening.jpg',
    _                           => null,
  };
}

// Returns emoji for a given backend category name (normalized).
String emojiForCategory(String backendName) {
  return switch (backendName.toLowerCase()) {
    'ac technician'          => '❄️',
    'electrician'            => '⚡',
    'plumber'                => '🔧',
    'handyman'               => '🔨',
    'cleaner' || 'cleaning'  => '🧹',
    'painter'                => '🎨',
    'carpenter'              => '🪚',
    'appliances repair'      => '🧺',
    'pest control'           => '🐛',
    'car wash'               => '🚗',
    'gardener'               => '🌿',
    _                        => '🛠️',
  };
}

// Returns background color for a given backend category name.
Color bgColorForCategory(String backendName) {
  return switch (backendName.toLowerCase()) {
    'ac technician'          => const Color(0xFFE8F4F8),
    'electrician'            => const Color(0xFFFFF8E1),
    'plumber'                => const Color(0xFFE8F5E9),
    'handyman'               => const Color(0xFFF3E5F5),
    'cleaner' || 'cleaning'  => const Color(0xFFFFF3E0),
    'painter'                => const Color(0xFFFCE4EC),
    'carpenter'              => const Color(0xFFEFEBE9),
    'pest control'           => const Color(0xFFE8F5E9),
    'car wash'               => const Color(0xFFE3F2FD),
    'gardener'               => const Color(0xFFE8F5E9),
    _                        => const Color(0xFFF0F0F0),
  };
}

// Returns emoji background color for a given backend category name.
Color emojiBgForCategory(String backendName) {
  return switch (backendName.toLowerCase()) {
    'ac technician'          => const Color(0xFFB2DFF0),
    'electrician'            => const Color(0xFFFFECB3),
    'plumber'                => const Color(0xFFC8E6C9),
    'handyman'               => const Color(0xFFE1BEE7),
    'cleaner' || 'cleaning'  => const Color(0xFFFFE0B2),
    'painter'                => const Color(0xFFF8BBD0),
    'carpenter'              => const Color(0xFFD7CCC8),
    'pest control'           => const Color(0xFFC8E6C9),
    'car wash'               => const Color(0xFFBBDEFB),
    'gardener'               => const Color(0xFFA5D6A7),
    _                        => const Color(0xFFDDDDDD),
  };
}

// Section heading for a given backend category name.
// New backend categories not listed here fall into "More Services".
String sectionForCategory(String backendName) {
  return switch (backendName.toLowerCase()) {
    'ac technician'          => 'Beat the Karachi Heat',
    'pest control'           => 'Beat the Karachi Heat',
    'handyman'               => 'New Home Essentials',
    'cleaner' || 'cleaning'  => 'New Home Essentials',
    'painter'                => 'New Home Essentials',
    'plumber'                => 'Home Improvement Help',
    'electrician'            => 'Home Improvement Help',
    'carpenter'              => 'Home Improvement Help',
    'gardener'               => 'Keep Your Home Running',
    'car wash'               => 'Keep Your Home Running',
    _                        => 'More Services',
  };
}

// Ordered list of section headings for display order on homepage.
const kSectionOrder = [
  'Beat the Karachi Heat',
  'New Home Essentials',
  'Home Improvement Help',
  'Keep Your Home Running',
  'More Services',
];

// Legacy kServices kept for any remaining references.
const kServices = [
  ServiceItem(
    title: 'AC Technician',
    backendName: 'AC Technician',
    emoji: '❄️',
    bg: Color(0xFFE8F4F8),
    emojiBg: Color(0xFFB2DFF0),
    imagePath: 'assets/images/ac.jpg',
  ),
  ServiceItem(
    title: 'Electrician',
    backendName: 'Electrician',
    emoji: '⚡',
    bg: Color(0xFFFFF8E1),
    emojiBg: Color(0xFFFFECB3),
    imagePath: 'assets/images/electrician.jpg',
  ),
  ServiceItem(
    title: 'Plumber',
    backendName: 'Plumber',
    emoji: '🔧',
    bg: Color(0xFFE8F5E9),
    emojiBg: Color(0xFFC8E6C9),
    imagePath: 'assets/images/plumber.jpg',
  ),
  ServiceItem(
    title: 'Handyman',
    backendName: 'Handyman',
    emoji: '🔨',
    bg: Color(0xFFF3E5F5),
    emojiBg: Color(0xFFE1BEE7),
    imagePath: 'assets/images/handyman.jpg',
  ),
];

// Static fallback sections shown while backend categories are loading.
// backendName matches exact backend category.name for each item.
const kServiceCategories = [
  ServiceCategory(
    heading: 'Beat the Karachi Heat',
    items: [
      ServiceItem(
        title: 'AC Help',
        backendName: 'AC Technician',
        emoji: '❄️',
        bg: Color(0xFFE8F4F8),
        emojiBg: Color(0xFFB2DFF0),
        imagePath: 'assets/images/ac.jpg',
      ),
      ServiceItem(
        title: 'Pest Control',
        backendName: 'Pest Control',
        emoji: '🐛',
        bg: Color(0xFFE8F5E9),
        emojiBg: Color(0xFFC8E6C9),
        imagePath: 'assets/images/pest.png',
      ),
    ],
  ),
  ServiceCategory(
    heading: 'New Home Essentials',
    items: [
      ServiceItem(
        title: 'Handyman',
        backendName: 'Handyman',
        emoji: '🔨',
        bg: Color(0xFFF3E5F5),
        emojiBg: Color(0xFFE1BEE7),
        imagePath: 'assets/images/handyman.jpg',
      ),
      ServiceItem(
        title: 'Deep Cleaning',
        backendName: 'Cleaner',
        emoji: '🧹',
        bg: Color(0xFFFFF3E0),
        emojiBg: Color(0xFFFFE0B2),
        imagePath: 'assets/images/deepcleaning.png',
      ),
      ServiceItem(
        title: 'Paint / Painter',
        backendName: 'Painter',
        emoji: '🎨',
        bg: Color(0xFFFCE4EC),
        emojiBg: Color(0xFFF8BBD0),
        imagePath: 'assets/images/painting.jpg',
      ),
    ],
  ),
  ServiceCategory(
    heading: 'Home Improvement Help',
    items: [
      ServiceItem(
        title: 'Plumbing',
        backendName: 'Plumber',
        emoji: '🔧',
        bg: Color(0xFFE8F5E9),
        emojiBg: Color(0xFFC8E6C9),
        imagePath: 'assets/images/plumber.jpg',
      ),
      ServiceItem(
        title: 'Electrical',
        backendName: 'Electrician',
        emoji: '⚡',
        bg: Color(0xFFFFF8E1),
        emojiBg: Color(0xFFFFECB3),
        imagePath: 'assets/images/electrician.jpg',
      ),
      ServiceItem(
        title: 'Carpentry',
        backendName: 'Carpenter',
        emoji: '🪚',
        bg: Color(0xFFEFEBE9),
        emojiBg: Color(0xFFD7CCC8),
        imagePath: 'assets/images/carpenter.jpg',
      ),
    ],
  ),
  ServiceCategory(
    heading: 'Keep Your Home Running',
    items: [
      ServiceItem(
        title: 'Gardening',
        backendName: 'Gardener',
        emoji: '🌿',
        bg: Color(0xFFE8F5E9),
        emojiBg: Color(0xFFA5D6A7),
        imagePath: 'assets/images/gardening.jpg',
      ),
      ServiceItem(
        title: 'Car Wash',
        backendName: 'Car Wash',
        emoji: '🚗',
        bg: Color(0xFFE3F2FD),
        emojiBg: Color(0xFFBBDEFB),
        imagePath: 'assets/images/carwash.png',
      ),
    ],
  ),
];
