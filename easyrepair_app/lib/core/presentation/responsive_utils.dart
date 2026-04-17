/// Scales [base] font size linearly with [width], clamped between [min] and [max].
/// [baseWidth] is the reference width (default 390 ≈ iPhone 14 Pro logical pixels).
///
/// Usage:
///   - Page-level text  → pass MediaQuery.sizeOf(context).width
///   - Card-level text  → pass LayoutBuilder constraints.maxWidth
double rFont(
  double width,
  double base, {
  double min = 10,
  double max = 28,
  double baseWidth = 390,
}) {
  return (base * width / baseWidth).clamp(min, max);
}
