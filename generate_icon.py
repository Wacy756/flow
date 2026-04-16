#!/usr/bin/env python3
"""Generate Flow app icons matching the FlowLogo widget exactly."""

from PIL import Image, ImageDraw
import os

def cubic_bezier_points(p0, p1, p2, p3, steps=300):
    points = []
    for i in range(steps + 1):
        t = i / steps
        x = (1-t)**3*p0[0] + 3*(1-t)**2*t*p1[0] + 3*(1-t)*t**2*p2[0] + t**3*p3[0]
        y = (1-t)**3*p0[1] + 3*(1-t)**2*t*p1[1] + 3*(1-t)*t**2*p2[1] + t**3*p3[1]
        points.append((x, y))
    return points

def draw_flow_icon(final_size):
    scale = 4
    size = final_size * scale

    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rect background #2D6A2D
    radius = size * 0.22
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=(45, 106, 45, 255))

    s = size / 48.0
    stroke = max(2, size * 0.052)

    # Exact curves from FlowLogo widget in flow_logo.dart
    # Wave 1: arch from (14s,26s) up to peak (24s,20s) back down to (34s,26s)
    w1 = (
        cubic_bezier_points((14*s, 26*s), (14*s, 26*s), (17*s, 20*s), (24*s, 20*s)) +
        cubic_bezier_points((24*s, 20*s), (31*s, 20*s), (34*s, 26*s), (34*s, 26*s))
    )

    # Wave 2: same arch shifted down 6 units, 50% opacity
    w2 = (
        cubic_bezier_points((14*s, 32*s), (14*s, 32*s), (17*s, 26*s), (24*s, 26*s)) +
        cubic_bezier_points((24*s, 26*s), (31*s, 26*s), (34*s, 32*s), (34*s, 32*s))
    )

    draw.line(w1, fill=(255, 255, 255, 255), width=int(stroke), joint='curve')
    draw.line(w2, fill=(255, 255, 255, 128), width=int(stroke), joint='curve')

    # Downsample with LANCZOS for smooth anti-aliasing
    result = img.resize((final_size, final_size), Image.LANCZOS)

    # Flatten to RGB (iOS requires no alpha for app icons)
    final = Image.new('RGB', (final_size, final_size), (45, 106, 45))
    final.paste(result, mask=result.split()[3])
    return final

icons = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

output_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
os.makedirs(output_dir, exist_ok=True)

for filename, size in icons.items():
    img = draw_flow_icon(size)
    img.save(os.path.join(output_dir, filename), 'PNG')
    print(f"Generated {filename} ({size}x{size})")

print("\nAll icons generated!")
