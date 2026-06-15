from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC_DIR = ROOT / "doc"
README = ROOT / "README.md"

START_MARKER = "<!-- LANGUAGE-STATS:START -->"
END_MARKER = "<!-- LANGUAGE-STATS:END -->"

IGNORED_DIRS = {
    ".git",
    ".godot",
    ".vscode",
    "__pycache__",
    "doc",
}

IGNORED_SUFFIXES = {
    ".import",
    ".uid",
    ".tmp",
    ".log",
    ".webp",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".ttf",
    ".otf",
    ".wav",
    ".mp3",
    ".ogg",
}

LANGUAGES = {
    ".gd": ("GDScript", "#478CBF"),
    ".tscn": ("Godot Scene", "#6CC551"),
    ".tres": ("Godot Resource", "#78D0FF"),
    ".godot": ("Godot Config", "#355070"),
    ".py": ("Python", "#3572A5"),
    ".md": ("Markdown", "#083fa1"),
    ".json": ("JSON", "#292929"),
    ".yaml": ("YAML", "#cb171e"),
    ".yml": ("YAML", "#cb171e"),
    ".toml": ("TOML", "#9c4221"),
    ".cfg": ("Config", "#6A737D"),
    ".ini": ("Config", "#6A737D"),
}


@dataclass(frozen=True)
class LanguageStat:
    name: str
    color: str
    bytes_count: int
    percent: float


def is_ignored(path: Path) -> bool:
    parts = set(path.relative_to(ROOT).parts)
    if parts & IGNORED_DIRS:
        return True
    return path.suffix.lower() in IGNORED_SUFFIXES


def collect_language_bytes() -> dict[str, tuple[str, int]]:
    totals: dict[str, tuple[str, int]] = {}

    for path in ROOT.rglob("*"):
        if not path.is_file() or is_ignored(path):
            continue

        suffix = path.suffix.lower()
        if suffix not in LANGUAGES:
            continue

        name, color = LANGUAGES[suffix]
        previous_color, previous_bytes = totals.get(name, (color, 0))
        totals[name] = (previous_color, previous_bytes + path.stat().st_size)

    return totals


def build_stats(totals: dict[str, tuple[str, int]]) -> list[LanguageStat]:
    total_bytes = sum(bytes_count for _, bytes_count in totals.values())
    if total_bytes == 0:
        return []

    stats = [
        LanguageStat(
            name=name,
            color=color,
            bytes_count=bytes_count,
            percent=bytes_count / total_bytes * 100,
        )
        for name, (color, bytes_count) in totals.items()
    ]
    return sorted(stats, key=lambda item: item.bytes_count, reverse=True)


def format_size(size: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"


def write_svg(stats: list[LanguageStat]) -> None:
    width = 760
    height = 290 if len(stats) <= 6 else 330
    bar_x = 36
    bar_y = 92
    bar_width = width - bar_x * 2
    bar_height = 18

    if not stats:
        bar_segments = (
            f'<rect x="{bar_x}" y="{bar_y}" width="{bar_width}" '
            f'height="{bar_height}" rx="6" fill="#E5E7EB" />'
        )
        legend = '<text x="36" y="146" fill="#6B7280" font-size="18">No source files found.</text>'
    else:
        cursor = bar_x
        segments = []
        for index, stat in enumerate(stats):
            segment_width = bar_width * stat.percent / 100
            if index == len(stats) - 1:
                segment_width = bar_x + bar_width - cursor
            segments.append(
                f'<rect x="{cursor:.2f}" y="{bar_y}" width="{max(segment_width, 0):.2f}" '
                f'height="{bar_height}" fill="{stat.color}" />'
            )
            cursor += segment_width

        bar_segments = "\n      ".join(segments)

        legend_items = []
        columns = 3
        item_width = 230
        row_height = 42
        start_y = 150
        for index, stat in enumerate(stats):
            col = index % columns
            row = index // columns
            x = 38 + col * item_width
            y = start_y + row * row_height
            label = escape(stat.name)
            legend_items.append(
                f'<g transform="translate({x}, {y})">'
                f'<circle cx="0" cy="-6" r="8" fill="{stat.color}" />'
                f'<text x="18" y="0" fill="#374151" font-size="18" font-weight="600">{label}</text>'
                f'<text x="18" y="25" fill="#6B7280" font-size="15">{stat.percent:.2f}% · {format_size(stat.bytes_count)}</text>'
                f"</g>"
            )
        legend = "\n      ".join(legend_items)

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">
  <title id="title">Most Used Languages</title>
  <desc id="desc">Generated local source language statistics for this project.</desc>
  <style>
    text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
  </style>
  <rect x="8" y="8" width="{width - 16}" height="{height - 16}" rx="14" fill="#FFFFFF" stroke="#E5E7EB" />
  <text x="36" y="58" fill="#2F80ED" font-size="30" font-weight="700">Most Used Languages</text>
  <g clip-path="url(#barClip)">
      {bar_segments}
  </g>
  <rect x="{bar_x}" y="{bar_y}" width="{bar_width}" height="{bar_height}" rx="6" fill="none" stroke="#F3F4F6" />
  <defs>
    <clipPath id="barClip">
      <rect x="{bar_x}" y="{bar_y}" width="{bar_width}" height="{bar_height}" rx="6" />
    </clipPath>
  </defs>
  <g>
      {legend}
  </g>
</svg>
"""
    (DOC_DIR / "language-stats.svg").write_text(svg, encoding="utf-8", newline="\n")


def write_markdown(stats: list[LanguageStat]) -> None:
    rows = [
        "# 语言占比",
        "",
        "由 `python tools/generate_language_stats.py` 生成。",
        "",
        "默认统计已映射的源码、配置和文档文件，排除 `doc/`、`.git/`、`.godot/`、导入缓存和二进制资源。",
        "",
        "![Most Used Languages](./language-stats.svg)",
        "",
        "| 语言 | 占比 | 大小 |",
        "|---|---:|---:|",
    ]
    if stats:
        rows.extend(
            f"| {stat.name} | {stat.percent:.2f}% | {format_size(stat.bytes_count)} |"
            for stat in stats
        )
    else:
        rows.append("| 未找到源码文件 | 0.00% | 0 B |")

    (DOC_DIR / "language-stats.md").write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")


def update_readme() -> None:
    block = "\n".join(
        [
            START_MARKER,
            '<p align="center">',
            '  <img src="./doc/language-stats.svg" alt="Most Used Languages" width="760">',
            "</p>",
            END_MARKER,
        ]
    )

    content = README.read_text(encoding="utf-8")
    if START_MARKER not in content or END_MARKER not in content:
        return

    before = content.split(START_MARKER, 1)[0]
    after = content.split(END_MARKER, 1)[1]
    README.write_text(before + block + after, encoding="utf-8", newline="\n")


def main() -> None:
    DOC_DIR.mkdir(exist_ok=True)
    stats = build_stats(collect_language_bytes())
    write_svg(stats)
    write_markdown(stats)
    update_readme()


if __name__ == "__main__":
    main()
