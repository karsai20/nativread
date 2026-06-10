#!/usr/bin/env python3
"""Builds a small but spec-correct EPUB 3 (with EPUB 2 NCX fallback and a
cover image) used as the bundled sample book and by the UI tests."""

import struct
import zlib
import zipfile
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / (
    "LumenRead/Resources/Fixtures/sample.epub"
)

TITLE = "The Lantern of Aldebaran"
AUTHOR = "E. M. Voss"

CHAPTERS = [
    (
        "The Harbour of Glass",
        [
            "The harbour lay under a skin of green glass, and the boats "
            "stood in it like flies in amber. Mirelle counted them from "
            "the customs tower every morning: nine sloops, a grain barge, "
            "and the white packet from Esmer that had not sailed in a "
            "year. Nothing in the harbour moved, and nothing in the "
            "harbour had moved since the night the lantern went out.",
            "Her grandfather said the glass was the sea holding its "
            "breath. He said it the way other men said the weather was "
            "turning, as if it were a thing one simply lived with, like "
            "rain, like taxes, like the slow rust eating the customs "
            "bell. But Mirelle had read the harbour-master's old logs, "
            "and she knew the sea had held its breath twice before, and "
            "both times it had exhaled fire.",
            "On the morning this story begins she found a crack in the "
            "glass. It ran from the third mooring post to the hull of "
            "the Esmer packet, thin as a hair from a grey head, and in "
            "the crack there was light: a soft amber pulse, slow as a "
            "sleeping heart. She knelt on the frozen sea and put her "
            "ear to it, and heard, very faintly, a bell that was not "
            "the customs bell ringing somewhere far below.",
            "She did not tell her grandfather. She told the lighthouse "
            "keeper's son instead, because he owned a diving suit and "
            "owed her three favours, and because he was the only person "
            "in the town of Brine who believed the lantern could be lit "
            "again.",
        ],
    ),
    (
        "The Keeper's Son",
        [
            "Tomas kept the diving suit in the lamp room, folded over "
            "the dead lantern like a man at prayer. The lantern itself "
            "was a drum of bronze and crystal two fathoms across, and "
            "in the old days its beam had reached Aldebaran, or so the "
            "keepers swore when they were paid in brandy.",
            "When Mirelle told him about the crack he did not laugh, "
            "which was the first point in his favour. He took down his "
            "father's chart of the harbour floor and spread it across "
            "the lantern's cold glass, and with a carpenter's pencil he "
            "marked the third mooring post, and the packet, and drew "
            "between them a line that passed directly over the spot "
            "where the old light-barge had sunk.",
            "The light-barge, he said, had carried the lantern's first "
            "heart: a stone that drank the sun all summer and paid it "
            "back all winter. When the barge went down the keepers cut "
            "a new heart of mirrors and oil, and it had served for a "
            "hundred years, and now it too was dead. But a sun-stone "
            "does not die. It only waits for someone to come and ask "
            "it politely to get up.",
            "They went down through the crack on the last day of the "
            "frost fair, while the whole town danced on the dead green "
            "sea above them.",
        ],
    ),
    (
        "Under the Glass",
        [
            "Below the glass the water was warm, which was the first "
            "wrong thing. The second wrong thing was the light: it came "
            "from beneath, amber and patient, and it threw their "
            "shadows upward onto the frozen ceiling where the dancers "
            "spun in their boots and ribbons.",
            "The light-barge sat upright on the harbour floor as if it "
            "had merely decided to stop sailing. In its hold the "
            "sun-stone burned low, a coal the size of a calf, and "
            "around it the bell they had heard was ringing: a small "
            "brass ship's bell, swinging with no hand to swing it, "
            "keeping time with the stone's slow pulse.",
            "Tomas reached for the stone and the water itself pushed "
            "his hand back, gently, the way one turns away a child "
            "from a hot stove. It was Mirelle who understood. She took "
            "off her glove, laid her bare palm against the hull, and "
            "asked, in the oldest words the logs had taught her, for "
            "the loan of the light.",
            "The stone rose. The bell stopped. Far above them, with a "
            "sound like spring arriving all at once, the harbour "
            "exhaled.",
        ],
    ),
    (
        "The Lantern Lit",
        [
            "They lit the lantern at dusk, when the first real waves "
            "in a year were combing the harbour mouth white. The "
            "sun-stone settled into the bronze cradle as if it had "
            "never left, and the beam that sprang from the crystal was "
            "the colour of October honey.",
            "The packet from Esmer sailed on the morning tide, and the "
            "grain barge after it, and the nine sloops raced each "
            "other to the fishing grounds like dogs let off a chain. "
            "Mirelle watched them go from the lamp room, drinking the "
            "keeper's terrible coffee, writing the day into a fresh "
            "page of the log.",
            "Her grandfather never asked how the sea had come to "
            "breathe again. He only said, in the way other men remark "
            "that the rain has stopped, that the lantern was burning a "
            "little amber this year, and that amber, in his "
            "experience, was the colour of a debt being repaid.",
            "Aldebaran rose that night over a working harbour, and the "
            "lantern reached up and touched it, keeper to keeper, "
            "light to ancient light.",
        ],
    ),
]


def make_png(width, height, rgb):
    """Tiny pure-stdlib PNG: one solid colour."""
    def chunk(kind, payload):
        block = kind + payload
        return (
            struct.pack(">I", len(payload))
            + block
            + struct.pack(">I", zlib.crc32(block) & 0xFFFFFFFF)
        )

    row = b"\x00" + bytes(rgb) * width
    body = zlib.compress(row * height)
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", body)
        + chunk(b"IEND", b"")
    )


def xhtml(title, paragraphs):
    body = "\n".join(f"    <p>{p}</p>" for p in paragraphs)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
  <title>{title}</title>
  <link rel="stylesheet" type="text/css" href="css/style.css"/>
</head>
<body>
  <section>
    <h1>{title}</h1>
{body}
  </section>
</body>
</html>
"""


def build(out=OUT, title=TITLE, author=AUTHOR, with_cover=True):
    chapter_files = [
        (f"ch{i + 1}.xhtml", title, paragraphs)
        for i, (title, paragraphs) in enumerate(CHAPTERS)
    ]

    manifest_items = "\n".join(
        f'    <item id="ch{i + 1}" href="{name}" '
        f'media-type="application/xhtml+xml"/>'
        for i, (name, _, _) in enumerate(chapter_files)
    )
    spine_items = "\n".join(
        f'    <itemref idref="ch{i + 1}"/>'
        for i in range(len(chapter_files))
    )

    cover_manifest = (
        '    <item id="cover-image" href="cover.png" media-type="image/png"\n'
        '          properties="cover-image"/>\n' if with_cover else ""
    )
    cover_meta = (
        '    <meta name="cover" content="cover-image"/>\n'
        if with_cover else ""
    )
    opf = f"""<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
         unique-identifier="uid" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:9f4d9b3a-lumen-sample</dc:identifier>
    <dc:title>{title}</dc:title>
    <dc:creator>{author}</dc:creator>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-06-11T00:00:00Z</meta>
{cover_meta}
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml"
          properties="nav"/>
    <item id="ncx" href="toc.ncx"
          media-type="application/x-dtbncx+xml"/>
{cover_manifest}    <item id="css" href="css/style.css" media-type="text/css"/>
{manifest_items}
  </manifest>
  <spine toc="ncx">
{spine_items}
  </spine>
</package>
"""

    nav_lis = "\n".join(
        f'        <li><a href="{name}">{title}</a></li>'
        for name, title, _ in chapter_files
    )
    nav = f"""<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="en">
<head><title>Contents</title></head>
<body>
  <nav epub:type="toc">
    <h1>Contents</h1>
    <ol>
{nav_lis}
    </ol>
  </nav>
</body>
</html>
"""

    nav_points = "\n".join(
        f"""    <navPoint id="np{i + 1}" playOrder="{i + 1}">
      <navLabel><text>{title}</text></navLabel>
      <content src="{name}"/>
    </navPoint>"""
        for i, (name, title, _) in enumerate(chapter_files)
    )
    ncx = f"""<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:9f4d9b3a-lumen-sample"/>
  </head>
  <docTitle><text>{title}</text></docTitle>
  <navMap>
{nav_points}
  </navMap>
</ncx>
"""

    container = """<?xml version="1.0" encoding="utf-8"?>
<container version="1.0"
           xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
              media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""

    css = """body { font-family: serif; }
h1 { font-variant: small-caps; }
"""

    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()

    with zipfile.ZipFile(out, "w") as zf:
        # The mimetype entry must be first and stored uncompressed.
        zf.writestr(
            zipfile.ZipInfo("mimetype"), "application/epub+zip",
            compress_type=zipfile.ZIP_STORED,
        )
        zf.writestr("META-INF/container.xml", container)
        zf.writestr("OEBPS/content.opf", opf)
        zf.writestr("OEBPS/nav.xhtml", nav)
        zf.writestr("OEBPS/toc.ncx", ncx)
        zf.writestr("OEBPS/css/style.css", css)
        if with_cover:
            zf.writestr(
                "OEBPS/cover.png", make_png(120, 180, (31, 58, 51))
            )
        for name, title, paragraphs in chapter_files:
            zf.writestr(f"OEBPS/{name}", xhtml(title, paragraphs))

    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    build()
    build(
        out=OUT.with_name("sample-nocover.epub"),
        title="Letters from the Brine Coast",
        author="Mirelle Anh",
        with_cover=False,
    )
