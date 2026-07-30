#!/usr/bin/env python3
"""Build public-domain Alice EPUB fixtures for website/screenshot automation.

These are intentionally small excerpts, not replacement test fixtures. The normal
sample.epub stays stable for UI tests. The Alice fixtures are bundled only so
marketing screenshots can show a recognizable multi-language book.
"""

import html
import struct
import zlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "NativRead/Resources/Fixtures"

BOOKS = [
    {
        "filename": "alice-wonderland-en.epub",
        "title": "Alice's Adventures in Wonderland",
        "author": "Lewis Carroll",
        "language": "en",
        "uid": "urn:uuid:nativread-alice-en",
        "cover": (196, 111, 74),
        "chapters": [
            (
                "Down the Rabbit-Hole",
                [
                    "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do.",
                    "Once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it.",
                    "So she was considering, in her own mind, whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies.",
                    "Suddenly a White Rabbit with pink eyes ran close by her. There was nothing so very remarkable in that, nor did Alice think it so very much out of the way to hear the Rabbit say to itself, 'Oh dear! Oh dear! I shall be late!'",
                ],
            ),
            (
                "The Pool of Tears",
                [
                    "Curiouser and curiouser! cried Alice. She was so much surprised that for the moment she quite forgot how to speak good English.",
                    "She looked down at her feet, and wondered who would put on her shoes and stockings for her now, dear me, what nonsense I am talking!",
                    "Then she remembered the little golden key and hurried back to the glass table, hoping it might open one of the doors into the garden.",
                ],
            ),
        ],
    },
    {
        "filename": "alice-csodaorszagban-hu.epub",
        "title": "Alice Csodaországban",
        "author": "Lewis Carroll",
        "language": "hu",
        "uid": "urn:uuid:nativread-alice-hu",
        "cover": (79, 118, 91),
        "chapters": [
            (
                "Le a nyúlüregbe",
                [
                    "Alice már nagyon unta, hogy a parton üljön a nővére mellett, és semmi dolga se legyen.",
                    "Egyszer-kétszer belenézett a könyvbe, amelyet a nővére olvasott, de abban nem voltak se képek, se beszélgetések.",
                    "Éppen azon tűnődött, vajon megéri-e felkelni és százszorszépeket szedni egy lánchoz, amikor hirtelen egy fehér nyúl szaladt el mellette rózsaszín szemekkel.",
                    "Ebben még nem lett volna semmi különös, és Alice azon sem csodálkozott nagyon, hogy a Nyúl ezt mondja magában: Jaj, jaj, elkésem!",
                ],
            ),
            (
                "A könnyek tava",
                [
                    "Egyre furcsább és furcsább! kiáltotta Alice. Annyira meglepődött, hogy egy pillanatra egészen elfelejtett rendesen beszélni.",
                    "Lenézett a lábára, és azon gondolkodott, ki húzza majd fel rá a cipőt és a harisnyát. Ugyan, miféle butaságokat beszélek!",
                    "Aztán eszébe jutott a kis aranykulcs, és visszasietett az üvegasztalhoz, hátha kinyitja valamelyik ajtót a kert felé.",
                ],
            ),
        ],
    },
    {
        "filename": "alice-wunderland-de.epub",
        "title": "Alice im Wunderland",
        "author": "Lewis Carroll",
        "language": "de",
        "uid": "urn:uuid:nativread-alice-de",
        "cover": (80, 97, 146),
        "chapters": [
            (
                "Hinab in den Kaninchenbau",
                [
                    "Alice wurde es allmählich sehr langweilig, neben ihrer Schwester am Ufer zu sitzen und nichts zu tun zu haben.",
                    "Ein- oder zweimal hatte sie in das Buch geschaut, das ihre Schwester las, aber es enthielt weder Bilder noch Gespräche.",
                    "Da lief plötzlich ein weißes Kaninchen mit rosa Augen dicht an ihr vorbei.",
                    "Als das Kaninchen zu sich selbst sagte: O weh! O weh! Ich komme zu spät!, sprang Alice auf, denn ein sprechendes Kaninchen war doch eine merkwürdige Sache.",
                ],
            ),
            (
                "Der Tränenteich",
                [
                    "Immer seltsamer und seltsamer! rief Alice. Sie war so überrascht, dass sie für einen Augenblick ganz vergaß, ordentlich zu sprechen.",
                    "Dann dachte sie wieder an den kleinen goldenen Schlüssel und eilte zum Glastisch zurück.",
                    "Vielleicht, hoffte sie, würde er eine der Türen öffnen, die in den Garten führten.",
                ],
            ),
        ],
    },
]


def make_png(width, height, rgb):
    def chunk(kind, payload):
        block = kind + payload
        return struct.pack(">I", len(payload)) + block + struct.pack(">I", zlib.crc32(block) & 0xFFFFFFFF)

    row = b"\x00" + bytes(rgb) * width
    body = zlib.compress(row * height)
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", body) + chunk(b"IEND", b"")


def xhtml(title, paragraphs, language):
    body = "\n".join(f"    <p>{html.escape(p)}</p>" for p in paragraphs)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="{language}">
<head>
  <title>{html.escape(title)}</title>
  <link rel="stylesheet" type="text/css" href="css/style.css"/>
</head>
<body>
  <section>
    <h1>{html.escape(title)}</h1>
{body}
  </section>
</body>
</html>
"""


def build(book):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / book["filename"]
    chapters = [(f"ch{i + 1}.xhtml", title, paragraphs) for i, (title, paragraphs) in enumerate(book["chapters"])]
    manifest_items = "\n".join(
        f'    <item id="ch{i + 1}" href="{name}" media-type="application/xhtml+xml"/>'
        for i, (name, _, _) in enumerate(chapters)
    )
    spine_items = "\n".join(f'    <itemref idref="ch{i + 1}"/>' for i in range(len(chapters)))
    nav_lis = "\n".join(f'        <li><a href="{name}">{html.escape(title)}</a></li>' for name, title, _ in chapters)
    nav_points = "\n".join(
        f"""    <navPoint id="np{i + 1}" playOrder="{i + 1}">
      <navLabel><text>{html.escape(title)}</text></navLabel>
      <content src="{name}"/>
    </navPoint>"""
        for i, (name, title, _) in enumerate(chapters)
    )
    opf = f"""<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid" xml:lang="{book['language']}">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">{book['uid']}</dc:identifier>
    <dc:title>{html.escape(book['title'])}</dc:title>
    <dc:creator>{html.escape(book['author'])}</dc:creator>
    <dc:language>{book['language']}</dc:language>
    <meta property="dcterms:modified">2026-07-08T00:00:00Z</meta>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-image" href="cover.png" media-type="image/png" properties="cover-image"/>
    <item id="css" href="css/style.css" media-type="text/css"/>
{manifest_items}
  </manifest>
  <spine toc="ncx">
{spine_items}
  </spine>
</package>
"""
    nav = f"""<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="{book['language']}">
<head><title>Contents</title></head>
<body><nav epub:type="toc"><h1>Contents</h1><ol>
{nav_lis}
</ol></nav></body>
</html>
"""
    ncx = f"""<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="{book['uid']}"/></head>
  <docTitle><text>{html.escape(book['title'])}</text></docTitle>
  <navMap>
{nav_points}
  </navMap>
</ncx>
"""
    css = """
body { font-family: Georgia, serif; line-height: 1.58; margin: 0; padding: 1.2rem; }
h1 { font-size: 1.45rem; margin: 0 0 1rem; }
p { margin: 0 0 1rem; }
"""
    with zipfile.ZipFile(out, "w") as zf:
        zf.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        zf.writestr("META-INF/container.xml", """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>
""")
        zf.writestr("OEBPS/content.opf", opf)
        zf.writestr("OEBPS/nav.xhtml", nav)
        zf.writestr("OEBPS/toc.ncx", ncx)
        zf.writestr("OEBPS/css/style.css", css)
        zf.writestr("OEBPS/cover.png", make_png(900, 1300, book["cover"]))
        for name, title, paragraphs in chapters:
            zf.writestr(f"OEBPS/{name}", xhtml(title, paragraphs, book["language"]))
    print(out)


if __name__ == "__main__":
    for book in BOOKS:
        build(book)
