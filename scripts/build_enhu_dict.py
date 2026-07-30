import bz2, re, struct, html as htmlmod, urllib.parse, collections, sys

SRC = '/tmp/nativread-enhu/en_ontolex.ttl.bz2'
subj_re = re.compile(r'^eng:__tr_hun_\d+_(.+?)\s*$')
wf_re = re.compile(r'dbnary:writtenForm\s+"(.*)"@hu')

def clean_word(uri_part):
    # word__POS__n  -> (word, POS)
    parts = uri_part.split('__')
    word = urllib.parse.unquote(parts[0]).replace('_', ' ').strip()
    pos = parts[1] if len(parts) > 1 else ''
    return word, pos

def unescape_ttl(s):
    return s.replace('\\"', '"').replace('\\\\', '\\')

data = collections.defaultdict(lambda: collections.defaultdict(list))  # key -> pos -> [hu]
display = {}
in_hun = False; src_id = None; n=0
with bz2.open(SRC, 'rt', encoding='utf-8') as f:
    for line in f:
        m = subj_re.match(line)
        if m:
            in_hun = True; src_id = m.group(1); continue
        if line and not line[0].isspace():
            in_hun = False
        if in_hun:
            wm = wf_re.search(line)
            if wm:
                hu = unescape_ttl(wm.group(1))
                hu = hu.replace('[[','').replace(']]','')
                hu = re.sub(r'\s+',' ',hu).strip()
                if hu.lower() in ('null','','—','-'): 
                    continue
                word, pos = clean_word(src_id)
                if word and hu and len(word) <= 80:
                    key = word.lower()
                    display.setdefault(key, word)
                    lst = data[key][pos]
                    if hu not in lst:
                        lst.append(hu); n += 1
print(f'headwords={len(data)} pairs={n}', file=sys.stderr)

# build StarDict (plain .dict + .idx + .ifo), sametypesequence=h
POSLABEL={'Noun':'fn','Verb':'ige','Adjective':'mn','Adverb':'hsz','Proper noun':'tn',''.strip():''}
words = sorted(data.keys())
dictbuf = bytearray(); idx = []
for key in words:
    disp = display[key]
    parts=[]
    for pos, hus in data[key].items():
        lbl = POSLABEL.get(pos, pos.lower()) if pos else ''
        body = htmlmod.escape(', '.join(hus))
        parts.append((f'<i>{htmlmod.escape(lbl)}</i> ' if lbl else '') + body)
    definition = '<br>'.join(parts)
    b = definition.encode('utf-8')
    off = len(dictbuf); dictbuf.extend(b)
    wb = disp.encode('utf-8')
    idx.append(wb + b'\x00' + struct.pack('>I', off) + struct.pack('>I', len(b)))
idxbuf = b''.join(idx)

OUT='/tmp/nativread-enhu/out'
import os; os.makedirs(OUT, exist_ok=True)
open(f'{OUT}/enhu.dict','wb').write(dictbuf)
open(f'{OUT}/enhu.idx','wb').write(idxbuf)
ifo = ("StarDict's dict ifo file\nversion=3.0.0\n"
       f"bookname=English-Hungarian (Wiktionary)\nwordcount={len(words)}\n"
       f"idxfilesize={len(idxbuf)}\nsametypesequence=h\n"
       "description=Built from DBnary (Wiktionary), CC-BY-SA 4.0\n")
open(f'{OUT}/enhu.ifo','w',encoding='utf-8').write(ifo)
print('wrote', OUT, 'dictbytes', len(dictbuf), 'idxbytes', len(idxbuf))
