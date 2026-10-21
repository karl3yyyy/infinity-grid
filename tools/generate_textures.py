"""Generates the game's medieval textures procedurally (no third-party art).

Run:  python tools/generate_textures.py
Needs numpy, scipy and Pillow. Output goes to assets/textures/.

Every tiling texture is built from FFT ("spectral") noise with integer
wavenumbers, so it repeats seamlessly. Normal maps use the OpenGL convention
(green = +Y) that Godot expects.
"""

from __future__ import annotations

import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)


# --- noise helpers ------------------------------------------------------------

def spectral(h: int, w: int, beta: float = 2.0, stretch_x: float = 1.0, stretch_y: float = 1.0,
             seed: int = 0, low_cut: float = 1.0) -> np.ndarray:
    """Seamless 1/f^beta noise in [0,1]. stretch_x > 1 elongates features along x."""
    rng = np.random.default_rng(seed)
    ky = np.fft.fftfreq(h)[:, None] * h
    kx = np.fft.fftfreq(w)[None, :] * w
    k = np.sqrt((kx * stretch_x) ** 2 + (ky * stretch_y) ** 2)
    k[0, 0] = 1.0
    amp = 1.0 / np.maximum(k, low_cut) ** (beta * 0.5)
    amp[0, 0] = 0.0
    phase = rng.normal(size=(h, w)) + 1j * rng.normal(size=(h, w))
    field = np.real(np.fft.ifft2(amp * phase))
    field -= field.min()
    return field / max(field.max(), 1e-9)


def lerp_palette(t: np.ndarray, colors: list[tuple[int, int, int]]) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0) * (len(colors) - 1)
    i = np.minimum(t.astype(int), len(colors) - 2)
    f = (t - i)[..., None]
    c = np.array(colors, dtype=np.float32)
    return c[i] * (1 - f) + c[i + 1] * f


def normal_from_height(height: np.ndarray, strength: float, wrap: bool = True) -> np.ndarray:
    mode = "wrap" if wrap else "nearest"
    dx = ndimage.sobel(height, axis=1, mode=mode)
    dy = ndimage.sobel(height, axis=0, mode=mode)
    n = np.stack([-dx * strength, dy * strength, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5) * 255.0


def wrapped_distance(h: int, w: int, cy: float, cx: float, wrap: bool = True) -> tuple[np.ndarray, np.ndarray]:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dy = yy - cy
    dx = xx - cx
    if wrap:
        dy = (dy + h / 2) % h - h / 2
        dx = (dx + w / 2) % w - w / 2
    return dy, dx


def save(name: str, rgb: np.ndarray, alpha: np.ndarray | None = None) -> None:
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is not None:
        a = np.clip(alpha, 0, 255).astype(np.uint8)
        Image.fromarray(np.dstack([rgb, a]), "RGBA").save(os.path.join(OUT, name), optimize=True)
    else:
        # Opaque maps ship as JPEG to keep the web download small.
        name = name.replace(".png", ".jpg")
        Image.fromarray(rgb, "RGB").save(os.path.join(OUT, name), quality=90, optimize=True)
    print("wrote", name)


def gray(value: np.ndarray) -> np.ndarray:
    v = np.clip(value * 255.0, 0, 255)
    return np.dstack([v, v, v])


# --- wood -----------------------------------------------------------------------

def wood_grain(h: int, w: int, rings: int, seed: int, knots: int = 3, wrap: bool = True) -> np.ndarray:
    """Grain running along x. Returns height-like value in [0,1]."""
    warp = spectral(h, w, beta=3.2, stretch_x=7.0, seed=seed)
    fibre = spectral(h, w, beta=1.2, stretch_x=14.0, seed=seed + 1)
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    t = yy / h * rings + warp * 4.0
    rng = np.random.default_rng(seed + 2)
    for _ in range(knots):
        cy, cx = rng.uniform(0, h), rng.uniform(0, w)
        dy, dx = wrapped_distance(h, w, cy, cx, wrap)
        r2 = (dx / (w * 0.06)) ** 2 + (dy / (h * 0.035)) ** 2
        t += 1.6 * np.exp(-r2) * np.sign(dy + 1e-3)
    rings_v = 0.5 + 0.5 * np.sin(2 * np.pi * t)
    rings_v = rings_v ** 2.2
    return np.clip(rings_v * 0.55 + fibre * 0.45, 0, 1)


def wood_planks(name: str, size: int, planks: int, palette: list, seed: int, gap_dark: float = 0.25,
                wear: float = 0.35) -> None:
    h = w = size
    rng = np.random.default_rng(seed)
    grain = np.zeros((h, w), np.float32)
    tint = np.zeros((h, w), np.float32)
    plank_h = h // planks
    height = np.zeros((h, w), np.float32)
    for p in range(planks):
        block = wood_grain(plank_h, w, rings=rng.integers(5, 9), seed=seed + 10 * p, knots=rng.integers(1, 3))
        y0 = p * plank_h
        # Each plank is offset so seams between planks look natural.
        block = np.roll(block, rng.integers(0, w), axis=1)
        grain[y0:y0 + plank_h] = block
        tint[y0:y0 + plank_h] = rng.uniform(-0.12, 0.12)
        edge = np.minimum(np.arange(plank_h), plank_h - 1 - np.arange(plank_h)).astype(np.float32)
        bevel = np.clip(edge / (size * 0.012), 0, 1)
        height[y0:y0 + plank_h] = bevel[:, None]
    grime = spectral(h, w, beta=2.6, seed=seed + 99)
    scratches = spectral(h, w, beta=0.6, stretch_x=40.0, seed=seed + 7)
    scratch_mask = (scratches > 0.82).astype(np.float32) * 0.25
    value = grain * 0.75 + tint + (grime - 0.5) * wear
    color = lerp_palette(value, palette)
    color *= (0.35 + 0.65 * height)[..., None] * (1 - gap_dark) + gap_dark * height[..., None]
    color += scratch_mask[..., None] * 40
    save(f"{name}_albedo.png", color)
    bump = height * 0.7 + grain * 0.3 - scratch_mask
    save(f"{name}_normal.png", normal_from_height(bump, 3.0))


def wood_tile(name: str, size: int, palette: list, seed: int, carve: bool) -> None:
    """One board square: grain, bevelled edges, worn centre, optional carved rune ring."""
    h = w = size
    grain = wood_grain(h, w, rings=7, seed=seed, knots=1, wrap=False)
    grime = spectral(h, w, beta=2.4, seed=seed + 5)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) / size
    bevel = np.clip(edge / 0.06, 0, 1)
    value = grain * 0.7 + (grime - 0.5) * 0.3
    # Centre is polished by hands; edges darker with dirt.
    centre = np.exp(-(((xx - w / 2) / (w * 0.45)) ** 2 + ((yy - h / 2) / (h * 0.45)) ** 2))
    value += centre * 0.12
    color = lerp_palette(value, palette)
    color *= (0.45 + 0.55 * bevel)[..., None]
    height = bevel * 0.8 + grain * 0.2
    if carve:
        r = np.sqrt((xx - w / 2) ** 2 + (yy - h / 2) ** 2) / size
        ring = np.exp(-((r - 0.3) / 0.012) ** 2)
        angle = np.arctan2(yy - h / 2, xx - w / 2)
        ticks = np.exp(-((r - 0.36) / 0.02) ** 2) * (np.cos(angle * 8) > 0.92)
        carving = np.clip(ring + ticks, 0, 1) * 0.55
        color *= (1 - carving * 0.6)[..., None]
        height -= carving * 0.5
    save(f"{name}_albedo.png", color)
    save(f"{name}_normal.png", normal_from_height(height, 4.0, wrap=False))


# --- metal & stone --------------------------------------------------------------

def iron(name: str, size: int, seed: int) -> None:
    h = w = size
    base = spectral(h, w, beta=2.2, seed=seed)
    hammer = spectral(h, w, beta=3.5, seed=seed + 1)
    rust = spectral(h, w, beta=2.0, seed=seed + 2)
    rust_mask = np.clip((rust - 0.62) * 5, 0, 1)
    color = lerp_palette(base * 0.6 + hammer * 0.4, [(28, 28, 32), (52, 52, 58), (78, 76, 80)])
    rust_col = lerp_palette(spectral(h, w, beta=1.0, seed=seed + 3), [(70, 32, 14), (122, 58, 22), (150, 82, 36)])
    color = color * (1 - rust_mask[..., None]) + rust_col * rust_mask[..., None]
    save(f"{name}_albedo.png", color)
    save(f"{name}_normal.png", normal_from_height(hammer * 0.8 + rust_mask * 0.2, 5.0))
    rough = np.clip(0.45 + rust_mask * 0.45 + (base - 0.5) * 0.2, 0, 1)
    save(f"{name}_roughness.png", gray(rough))


def marble(name: str, size: int, palette: list, vein: tuple, seed: int) -> None:
    h = w = size
    n1 = spectral(h, w, beta=2.8, seed=seed)
    n2 = spectral(h, w, beta=1.6, seed=seed + 1)
    veins = np.abs(np.sin((n1 * 6.0 + n2 * 1.5) * np.pi))
    veins = np.clip(1 - veins * 8, 0, 1)
    color = lerp_palette(n2 * 0.6 + n1 * 0.4, palette)
    color = color * (1 - veins[..., None] * 0.7) + np.array(vein, np.float32) * veins[..., None] * 0.7
    save(f"{name}_albedo.png", color)
    save(f"{name}_normal.png", normal_from_height(n2 * 0.5 - veins * 0.2, 1.5))


# --- UI art ---------------------------------------------------------------------

def parchment(name: str, w: int, h: int, seed: int, burn: float = 1.0) -> None:
    rng = np.random.default_rng(seed)
    stains = spectral(h, w, beta=2.4, seed=seed)
    fibres = spectral(h, w, beta=0.9, stretch_x=3.0, seed=seed + 1)
    blots = spectral(h, w, beta=3.0, seed=seed + 2)
    value = stains * 0.55 + fibres * 0.3 + blots * 0.15
    color = lerp_palette(value, [(176, 140, 92), (212, 182, 132), (232, 210, 165), (240, 224, 186)])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    ragged = edge + (spectral(h, w, beta=1.6, seed=seed + 3) - 0.5) * 18
    scorch = np.clip(1 - ragged / (min(w, h) * 0.09), 0, 1) ** 1.6 * burn
    color = color * (1 - scorch[..., None] * 0.75) + np.array([60, 30, 12]) * scorch[..., None] * 0.6
    # A few ink spots.
    for _ in range(3):
        cy, cx = rng.uniform(0.15, 0.85) * h, rng.uniform(0.15, 0.85) * w
        r2 = ((yy - cy) ** 2 + (xx - cx) ** 2) / (rng.uniform(4, 10) ** 2)
        spot = np.exp(-r2) * 0.25
        color *= (1 - spot[..., None])
    alpha = np.clip((ragged - 1.0) * 255, 0, 255)
    save(f"{name}.png", color, alpha)


def frame_9patch(name: str, size: int, border: int, seed: int, wood_palette: list) -> None:
    """Dark wooden frame with iron corner brackets and rivets; transparent centre."""
    h = w = size
    grain_h = wood_grain(h, w, rings=10, seed=seed, knots=0, wrap=False)
    grain_v = wood_grain(w, h, rings=10, seed=seed + 1, knots=0, wrap=False).T
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dist_lr = np.minimum(xx, w - 1 - xx)
    dist_tb = np.minimum(yy, h - 1 - yy)
    in_frame = (np.minimum(dist_lr, dist_tb) < border)
    vertical = dist_lr < dist_tb
    grain = np.where(vertical, grain_v, grain_h)
    color = lerp_palette(grain * 0.8 + spectral(h, w, beta=2.4, seed=seed + 4) * 0.2, wood_palette)
    # Bevel: light outer edge, dark inner edge.
    d = np.minimum(dist_lr, dist_tb)
    shade = np.where(d < 3, 1.25, 1.0) * np.where((d > border - 5) & (d < border), 0.55, 1.0)
    color *= shade[..., None]
    # Iron corner brackets.
    iron_col = lerp_palette(spectral(h, w, beta=2.0, seed=seed + 5), [(40, 40, 46), (70, 70, 78), (96, 94, 100)])
    corner = (np.minimum(xx, w - 1 - xx) < border * 1.6) & (np.minimum(yy, h - 1 - yy) < border * 1.6) & in_frame
    corner |= (np.minimum(xx, w - 1 - xx) < border * 1.6) & (np.minimum(yy, h - 1 - yy) < border * 1.6) & \
        (np.minimum(xx, w - 1 - xx) + np.minimum(yy, h - 1 - yy) < border * 2.2)
    color = np.where(corner[..., None], iron_col, color)
    # Rivets.
    for cy in (border * 0.5, h - border * 0.5):
        for cx in (border * 0.5, w - border * 0.5, border * 1.25, w - border * 1.25):
            r = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
            rivet = np.clip(1 - r / (border * 0.16), 0, 1)
            color = color * (1 - rivet[..., None]) + np.array([150, 140, 130]) * rivet[..., None] * (0.6 + 0.4 * rivet[..., None])
    for cx in (border * 0.5, w - border * 0.5):
        for cy in (border * 1.25, h - border * 1.25):
            r = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
            rivet = np.clip(1 - r / (border * 0.16), 0, 1)
            color = color * (1 - rivet[..., None]) + np.array([150, 140, 130]) * rivet[..., None] * (0.6 + 0.4 * rivet[..., None])
    alpha = np.where(in_frame | corner, 255, 0).astype(np.float32)
    save(f"{name}.png", color, alpha)


def leather_panel(name: str, size: int, seed: int) -> None:
    h = w = size
    pores = spectral(h, w, beta=0.8, seed=seed)
    folds = spectral(h, w, beta=2.8, seed=seed + 1)
    value = folds * 0.6 + pores * 0.4
    color = lerp_palette(value, [(30, 18, 12), (52, 32, 20), (74, 46, 28), (92, 60, 36)])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    # Stitched seam 14px inside the edge.
    seam = np.abs(edge - 16) < 1.6
    along = np.where(np.minimum(xx, w - 1 - xx) < np.minimum(yy, h - 1 - yy), yy, xx)
    stitch = seam & ((along % 14) < 8)
    color = np.where(stitch[..., None], np.array([196, 160, 104], np.float32), color)
    color *= np.clip(0.55 + edge / 40, 0.55, 1.0)[..., None]
    save(f"{name}.png", color)


def button_9patch(name: str, w: int, h: int, seed: int) -> None:
    grain = wood_grain(h, w, rings=4, seed=seed, knots=0, wrap=False)
    color = lerp_palette(grain * 0.8 + spectral(h, w, beta=2.2, seed=seed + 1) * 0.2,
                         [(46, 28, 16), (74, 46, 26), (100, 64, 36), (118, 78, 44)])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    band = edge < 7
    iron_col = lerp_palette(spectral(h, w, beta=2.0, seed=seed + 2), [(38, 38, 44), (66, 66, 74), (92, 90, 98)])
    color = np.where(band[..., None], iron_col, color)
    color *= np.where((edge >= 7) & (edge < 10), 0.6, 1.0)[..., None]
    color *= np.where(edge < 2, 1.3, 1.0)[..., None]
    save(f"{name}.png", color)


def main() -> None:
    walnut = [(30, 17, 9), (48, 28, 15), (66, 40, 22), (82, 52, 30)]
    oak = [(84, 54, 28), (116, 78, 42), (142, 100, 58), (162, 120, 74)]
    table = [(22, 13, 8), (38, 23, 13), (54, 34, 19), (66, 43, 25)]
    wood_planks("table", 1024, 4, table, seed=11)
    wood_planks("frame", 512, 2, walnut, seed=21, gap_dark=0.15, wear=0.25)
    wood_tile("tile_light", 512, oak, seed=31, carve=False)
    wood_tile("tile_light_rune", 512, oak, seed=32, carve=True)
    wood_tile("tile_dark", 512, walnut, seed=41, carve=False)
    wood_tile("tile_dark_rune", 512, walnut, seed=42, carve=True)
    iron("iron", 512, seed=51)
    marble("marble", 512, [(190, 186, 176), (214, 210, 200), (232, 228, 218)], (150, 140, 120), seed=61)
    marble("obsidian", 512, [(16, 14, 20), (30, 26, 36), (44, 38, 50)], (130, 40, 24), seed=71)
    parchment("ui_parchment", 400, 520, seed=81)
    frame_9patch("ui_card_frame", 256, 30, seed=91, wood_palette=walnut)
    leather_panel("ui_leather", 512, seed=101)
    button_9patch("ui_button", 256, 96, seed=111)


if __name__ == "__main__":
    main()
