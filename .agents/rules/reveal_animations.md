# Guide: Animating Reveals in Flutter

Creating smooth, high-quality reveal animations in Flutter requires a combination of structural layout animations and visual state transitions. The combination of Flutter's built-in `AnimatedSize` and the `flutter_animate` package provides an excellent pattern for achieving this.

## 1. The structural change: `AnimatedSize`

When a widget suddenly appears or disappears in a layout (like a `Column` or `ListView`), the surrounding widgets typically snap to their new positions. To make this structural change smooth, wrap the conditionally rendered widget in an `AnimatedSize`.

`AnimatedSize` watches its child's size and interpolates changes over a given duration.

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
  alignment: Alignment.topCenter, // Determines the pivot point of the expansion
  child: showContent 
    ? MyContentWidget() 
    : const SizedBox.shrink(),
)
```
> [!TIP]
> `Curves.easeOutCubic` is excellent for reveals because it starts fast (feeling highly responsive) and gently settles into its final size, mimicking physical movement.

## 2. The visual transition: `flutter_animate`

While `AnimatedSize` handles the surrounding layout, the content *inside* the layout will still abruptly pop in or out. To make the entrance of the content itself graceful, we use the `flutter_animate` package to animate its opacity and scale.

```dart
import 'package:flutter_animate/flutter_animate.dart';

// ...

child: showContent 
  ? Column(
      children: [
        Text("Item 1"),
        Text("Item 2"),
        Text("Item 3"),
      ]
      // Apply the animation to the list of children!
      .animate(interval: 40.ms)
      .fade(duration: 250.ms, curve: Curves.easeOutCubic)
      .scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
    )
  : const SizedBox.shrink(),
```

### Breaking down the `.animate()` chain:

- `.animate(interval: 40.ms)`: By calling this on a `List<Widget>`, `flutter_animate` applies a staggered delay to each item. Item 2 starts 40ms after Item 1, Item 3 starts 40ms after Item 2. This creates a beautiful "waterfall" reveal effect.
- `.fade(...)`: Animates the opacity from 0.0 to 1.0.
- `.scale(begin: const Offset(0.95, 0.95), ...)`: Animates the scale from 95% to 100%. Starting at 95% instead of 0% prevents a dramatic "pop" and instead gives a subtle, premium "swell" effect as the content fades in.

## 3. The Complete Pattern

Combining both gives you a buttery-smooth section reveal that pushes surrounding content away gently while the new content fades and scales in with a staggered effect.

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
  alignment: Alignment.topCenter,
  child: isExpanded
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFirstSection(),
            const Gap(12),
            _buildSecondSection(),
            const Gap(12),
            _buildThirdSection(),
          ]
          .animate(interval: 40.ms)
          .fade(duration: 250.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.95, 0.95), 
            duration: 250.ms, 
            curve: Curves.easeOutCubic,
          ),
        )
      : const SizedBox.shrink(),
)
```

## Summary Checklist
1. **Always handle the layout shift**: Use `AnimatedSize` (or `AnimatedSwitcher`) for any conditionally rendered block in a list or column.
2. **Combine Fade and Scale**: A pure fade looks basic; a subtle scale-up (e.g. `0.95 -> 1.0`) adds depth.
3. **Stagger lists**: Use `interval` on `.animate()` to stagger multiple elements appearing at once.
4. **Use ease-out curves**: `Curves.easeOutCubic` or `Curves.easeOutQuart` are standard for entrances, ensuring the animation decelerates as it finishes.
