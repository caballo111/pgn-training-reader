"""Export Android launcher PNGs from the original artwork (requires Pillow)."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/pgn-training-reader-icon.png"
RESOURCES = ROOT / "android/app/src/main/res"


def main():
    with Image.open(SOURCE) as source:
        if source.width != source.height:
            raise ValueError("Launcher artwork must be square")
        artwork = source.convert("RGB")
        for density, size in {
            "mdpi": 48,
            "hdpi": 72,
            "xhdpi": 96,
            "xxhdpi": 144,
            "xxxhdpi": 192,
        }.items():
            destination = RESOURCES / f"mipmap-{density}/ic_pgn_launcher.png"
            destination.parent.mkdir(parents=True, exist_ok=True)
            artwork.resize((size, size), Image.Resampling.LANCZOS).save(
                destination, optimize=True
            )
        destination = RESOURCES / "drawable-nodpi/pgn_launcher_art.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        artwork.resize((432, 432), Image.Resampling.LANCZOS).save(
            destination, optimize=True
        )


if __name__ == "__main__":
    main()
