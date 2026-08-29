// Returns image asset path for a given backend category name (normalized).
String? imagePathForCategory(String backendName) {
  return switch (backendName.toLowerCase()) {
    'ac technician' => 'assets/images/ac.jpg',
    'electrician' => 'assets/images/electrician.jpg',
    'plumber' => 'assets/images/plumber.jpg',
    'handyman' => 'assets/images/handyman.jpg',
    // 'cleaner' is the migration-seeded backend name for the cleaning service
    'cleaner' => 'assets/images/cleaner.png',
    // 'cleaning' kept as fallback alias if root seed was run
    'cleaning' => 'assets/images/cleaner.png',
    'painter' => 'assets/images/painting.jpg',
    'carpenter' => 'assets/images/carpenter.jpg',
    'appliances repair' => 'assets/images/appliance.png',
    'pest control' => 'assets/images/pest.png',
    'car wash' => 'assets/images/carwash.png',
    'gardener' => 'assets/images/gardening.jpg',
    _ => null,
  };
}
