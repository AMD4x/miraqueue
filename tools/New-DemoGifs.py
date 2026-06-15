from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "media"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 980, 560
BG = (14, 18, 24)
PANEL = (25, 31, 41)
TEXT = (230, 236, 244)
MUTED = (148, 163, 184)
GREEN = (74, 222, 128)
YELLOW = (250, 204, 21)
CYAN = (103, 232, 249)
RED = (248, 113, 113)

try:
    FONT = ImageFont.truetype("consola.ttf", 24)
    SMALL = ImageFont.truetype("consola.ttf", 20)
    TITLE = ImageFont.truetype("consolab.ttf", 30)
except Exception:
    FONT = ImageFont.load_default()
    SMALL = ImageFont.load_default()
    TITLE = ImageFont.load_default()

def frame(title, lines):
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((26, 26, W - 26, H - 26), radius=14, fill=PANEL, outline=(57, 72, 92), width=2)
    draw.text((52, 48), title, fill=CYAN, font=TITLE)
    y = 100
    for text, color in lines:
        draw.text((56, y), text, fill=color, font=FONT if color != MUTED else SMALL)
        y += 36
    return img

def save(name, scenes):
    images = [frame(title, lines) for title, lines in scenes]
    images[0].save(OUT / name, save_all=True, append_images=images[1:], duration=950, loop=0)

save("miraqueue-overview.gif", [
    ("MiraQueue V1.0.0", [("Pairs: 1    Pending: 0    Watcher: RUN", GREEN), ("[1] Apply Pending", YELLOW), ("[2] Preview Pending", YELLOW), ("[3] Full Mirror", YELLOW), ("Config: C:\\Demo\\MiraQueue.config.json", MUTED)]),
    ("MiraQueue V1.0.0", [("Watching configured sources. Changes are stored until you apply them.", MUTED), ("Watching: C:\\Demo\\Source -> D:\\Demo\\Backup", TEXT), ("Queued: docs\\plan.md", YELLOW), ("Queued: src\\tool.ps1", YELLOW)]),
])

save("manage-paths-demo.gif", [
    ("Manage Paths", [("No pairs configured.", YELLOW), ("[1] Add pair", YELLOW), ("Source path: C:\\Demo\\Source", TEXT), ("Destination path: D:\\Demo\\Backup", TEXT)]),
    ("Add Pair", [("Detected name: Source", GREEN), ("Source       : C:\\Demo\\Source", MUTED), ("Destination  : D:\\Demo\\Backup", MUTED), ("Press Enter to save this pair", CYAN)]),
])

save("preview-apply-pending.gif", [
    ("Preview Pending", [("Pair        Action   Type   Path", CYAN), ("Source      COPY     FILE   docs\\plan.md", TEXT), ("Source      MKDIR    DIR    reports", TEXT), ("Source      DELETE   FILE   old\\draft.txt", RED)]),
    ("Apply Pending", [("[##########----------]  50%", GREEN), ("COPY docs\\plan.md", TEXT), ("MKDIR reports", TEXT), ("Waiting: old\\draft.txt", YELLOW)]),
    ("Apply Results", [("Copied          : 1", GREEN), ("Created folders : 1", GREEN), ("Deleted         : 1", YELLOW), ("Failed          : 0", GREEN)]),
])

save("full-mirror-policies.gif", [
    ("Full Mirror", [("[1] Strict Full Mirror", YELLOW), ("[2] Update From Source, Keep Extras", YELLOW), ("[3] Safe Missing Only", YELLOW), ("Recommended: preview first", CYAN)]),
    ("Full Mirror Preview", [("Pair      Mode    Status   New  Upd  Extra", CYAN), ("Source    STRICT  CHANGED  4    2    1", TEXT), ("Extra means destination-only content", MUTED)]),
    ("Full Mirror Apply", [("Policy: UPDATE", CYAN), ("Copied new files: 4", GREEN), ("Updated files   : 2", GREEN), ("Extras kept     : 1", YELLOW)]),
])

print(f"Wrote demo GIFs to {OUT}")
