# NativRead Adatkezelési Tájékoztató

**VÁZLAT — jogi átvizsgálásra vár.**
Hatályos: 2026. augusztus 5. · 1.3 verzió

Az olvasás alapból magánügy. A könyveid a készülékeden maradnak, hacsak
tudatosan nem indítasz AI-fordítást. Ez a tájékoztató elmagyarázza, milyen
adatot kezelünk, miért, meddig és milyen döntéseid vannak.

## 1. Ki az adatkezelő

Az adatkezelő: **[[OPERATOR_NAME]]**, [[OPERATOR_ADDRESS]].
Kapcsolat: [[CONTACT_EMAIL]]. Az aktuális támogatási adatok a NativRead
App Store-termékoldalán is elérhetők.

## 2. Privát, offline olvasás

- Az importálás, az olvasás, a kiemelések, az Apple Look Up és az olvasási
  beállítások helyben működnek.
- A NativRead nem tartalmaz hirdetési vagy analitikai SDK-t, nem értékesít
  személyes adatot.
- A könyv csak akkor hagyja el a készülékedet, amikor AI-fordítást indítasz.

## 3. A fordításhoz kezelt adatok

| Adat | Cél | Megőrzés |
|---|---|---|
| Az Apple-lel történő bejelentkezés állandó fiókazonosítója | fiókhitelesítés, jogosultságok, visszaélés-megelőzés | a fiók törléséig |
| A feltöltött EPUB és választott célnyelv | a fordítás elkészítése | sikeres kézbesítéskor törlődik; megszakadt feldolgozásnál legfeljebb 30 nap |
| A lefordított könyv | kézbesítés a készülékedre | kézbesítéskor törlődik; megszakadt kézbesítésnél legfeljebb 30 nap |
| A könyv technikai ujjlenyomata, fordítási állapot, vásárlási és jogosultsági adatok | hozzáférés-helyreállítás, kézbesítés, visszaélés-megelőzés, szolgáltatásüzemeltetés | a fiók törléséig, illetve ameddig jogszabály előírja |
| Álneves fiókazonosító, könyvujjlenyomat, elfogadásazonosító, kliens- és szerveridőpont, nyelv, módszer, nyilatkozat- és feltételverzió, archivált feltétel URL | az aktív Felhasználási Feltétel-elfogadás bizonyítása | a fiók törléséig, illetve jogi igény esetén a szükséges ideig |

A NativRead nem kéri el az Apple-től a nevedet vagy az e-mail-címedet. A
könyv technikai ujjlenyomata segít felismerni ugyanazt a fájlt anélkül, hogy
magát a könyvet tartósan tárolnánk.

## 4. AI- és egyéb szolgáltatók

Külön engedélyed után a könyv szövegét a **Google Gemini API**, egy külső
AI-szolgáltatás kapja meg a fordítás elkészítéséhez. A fizetős API a kéréseket
és válaszokat nem használja Google-termékek vagy modellek fejlesztésére. A
Google visszaélés-felismerés és kötelező jogi adatszolgáltatás céljából
korlátozott ideig megőrizheti őket. Részletek: [Google Gemini API
feltételek](https://ai.google.dev/gemini-api/terms).

A Gemini API-t a Google LLC üzemelteti az Egyesült Államokban, így a kérés
elhagyja az EGT-t. A továbbítás jogalapja a Google adatfeldolgozási
feltételeiben szereplő általános szerződési feltételek (SCC), valamint a
Google EU–USA adatvédelmi keret (Data Privacy Framework) szerinti
tanúsítása. A könyv szövege ezen kívül nem kerül az EGT-n kívülre.

Az Apple a saját feltételei szerint kezeli a bejelentkezési és alkalmazáson
belüli vásárlási adatokat. A NativRead tárhely- és futtatási szolgáltatója a
**Cloudflare**. A könyvfájlok R2-tárhelye, a D1-metaadatbázis és a
fordítókonténerek EU-joghatósághoz kötöttek; a titkosított kérés Cloudflare
globális peremhálózatán haladhat át. A Cloudflare és az AI-szolgáltató
kizárólag a szolgáltatás biztosításához dolgozhatja fel az adatokat, legalább
az itt leírt védelemmel.

## 5. Jogalapok

- Szerződés teljesítése: fiók, fordítás, vásárlás és kézbesítés.
- Hozzájárulás: a könyv szövegének külső AI-szolgáltatóhoz továbbítása. Ezt
  elutasíthatod; az offline olvasót továbbra is használhatod.
- Jogos érdek: visszaélés-megelőzés és a szolgáltatás megbízható működtetése.
- Jogi kötelezettség: a kötelező adózási és számviteli nyilvántartások.

## 6. Megőrzés és fióktörlés

A forrás- és a lefordított szerverpéldány a sikeres kézbesítés után törlődik.
A normál automatikus lejárat 24 óra; külön tárhelyi biztonsági szabály
biztosítja, hogy rendellenes megszakadás után se maradjon objektum 30 napnál
tovább.

A fordítási fiókot a **Beállítások → Fiók → Fiók törlése** útvonalon
törölheted. Az Apple-fiók újbóli megerősítése után visszavonjuk az Apple-lel
történő bejelentkezést, és végleg eltávolítjuk a szerveroldali fiókot, a
fordítási feladatokat, a jogosultságokat és a kapcsolódó adatokat, amelyeket
jogszabály alapján nem kell megőriznünk. A helyi könyvtáradban lévő könyveket
a fióktörlés nem távolítja el. A törlés után a korábbi vásárlások
helyreállíthatósága megszűnik.

## 7. Jogaid

Az AI-feldolgozást elutasíthatod, és az offline olvasót ettől továbbra is
használhatod. A jövőbeli AI-feldolgozási engedélyeket a **Beállítások →
Adatvédelmi beállítások → AI-engedélyek törlése** útvonalon vonhatod vissza.
Ez a már a kérésedre elkezdett vagy befejezett feldolgozást nem teszi
semmissé; egy későbbi fordítás előtt az app újra engedélyt kér.

Az alkalmazandó jogtól függően kérhetsz hozzáférést, helyesbítést, törlést,
korlátozást és adathordozhatóságot, illetve tiltakozhatsz az adatkezelés ellen
a [[CONTACT_EMAIL]] címen. A megkeresésekre 30 napon belül válaszolunk.
Panaszt a lakóhelyed szerinti felügyeleti hatóságnál tehetsz; Magyarországon
ez a NAIH.

Ha Kaliforniában élsz: a NativRead nem adja el és nem osztja meg a személyes
adataidat, így nincs miről leiratkoznod. A fent leírt megismerési, törlési és
helyesbítési jogok ugyanazon a kapcsolattartási címen gyakorolhatók.

## 8. Biztonság és életkor

A munkamenet az iOS Kulcskarikában tárolódik, a fordítási kérések
hitelesített kapcsolaton mennek. Az offline olvasásnak nincs korhatára. A
fordítószolgáltatás felnőtteknek szól, és tudatosan nem hoz létre fordítási
fiókot 18 év alattiaknak.

## 9. Változások

Az AI-adatkezelés lényeges változásához új engedélyt kérünk az appban. A
hatálybalépési dátumot és a verziót minden lényeges módosításkor frissítjük.
A közzétett változat címe:
https://nativread.com/privacy/.
