# NativBook Adatkezelési Tájékoztató

**VÁZLAT — jogi átvizsgálásra vár. Még nem publikált.**
Hatályos: [[EFFECTIVE_DATE]] · 0.1 verzió

A NativBook egy e-könyv-olvasó, választható AI-fordítási szolgáltatással. Ez a
tájékoztató elmagyarázza, milyen adatot kezelünk, miért, meddig, és milyen
jogaid vannak. Röviden: **az olvasó teljes egészében a készülékeden működik; a
fordítószolgáltatás csak addig ér a könyvedhez, amíg a fordítás tart; nálunk
metaadat marad, könyv soha.**

## 1. Ki az adatkezelő

Adatkezelő: **[[OPERATOR_NAME]]**, [[OPERATOR_ADDRESS]].
Kapcsolat: [[CONTACT_EMAIL]].

## 2. Amit az app NEM gyűjt

- Maga az olvasó (importálás, olvasás, kiemelések, szótár, beállítások)
  **offline** működik. Az importált könyveid nem hagyják el a készüléked,
  hacsak nem indítasz fordítást.
- **Nincs analitikai vagy hirdetési SDK** az appban. Semmilyen külső követő
  nem fut benne.
- Személyes adatot hirdetési célra soha nem adunk el és nem osztunk meg.

## 3. Mit kezelünk, ha a fordítószolgáltatást használod

| Adat | Cél | Megőrzés |
|---|---|---|
| Bejelentkezési azonosító (Apple vagy Google token → belső felhasználó-azonosító) | fiók, vásárlások, visszaélés-megelőzés | a fiók törléséig |
| A feltöltött könyvfájl | a fordítás elvégzése | **a fordítás elkészültekor törlődik** |
| A lefordított könyv | kézbesítés a készülékedre | **kézbesítéskor törlődik** (max. 14 napig őrizzük, ha a készüléked nem elérhető; abszolút plafon 30 nap) |
| Vásárlási adatok (Apple tranzakció-azonosító, könyv-ujjlenyomat, célnyelv, ársáv) | a megvásárolt szolgáltatás biztosítása és helyreállítása | a fiók törléséig |
| Szolgáltatási események (pl. „fordítás elindult/meghiúsult", hibakategória, nyelvi várólista-jelölés) | a szolgáltatás működtetése, hibajavítás | gördülő ablakban törölve; csak metaadat, könyvszöveg soha |

A „könyv-ujjlenyomat" a fájl technikai lenyomata — arra való, hogy ugyanazt a
könyvet felismerjük (pl. vásárlás-helyreállításnál) anélkül, hogy magát a
könyvet tárolnánk.

## 4. Adatfeldolgozóink

- **Apple** — bejelentkezés és alkalmazáson belüli vásárlás (saját adatvédelmi
  feltételeik szerint).
- **[[AI_PROVIDER]]** — a gépi fordítást végzi. A könyv szövege
  adatfeldolgozási megállapodás alapján kerül hozzá; **a modelljeik tanítására
  nem használják**, a feldolgozás EU/US régióban történik
  ([[AI_PROVIDER_DPA_URL]]).
- **[[HOSTING_PROVIDER]]** — a szerverünket futtatja (régió: EU).
- **[[ERROR_MONITOR]]** — szerveroldali hibafigyelés. A hibajelentések
  szűrtek: könyvszöveget nem tartalmaznak, személyed csak hashelt
  azonosítóként jelenik meg.

Mindegyikkel adatfeldolgozási megállapodásunk van. Ha a lista változik, a
változás előtt frissítjük ezt a tájékoztatót.

## 5. Nemzetközi adattovábbítás

Ahol a feldolgozás az EGT-n kívül történik (pl. [[AI_PROVIDER]] US-régió), azt
az EU–US Data Privacy Framework és/vagy általános szerződési feltételek (SCC)
fedik.

## 6. Jogalapok (GDPR)

- Szerződés teljesítése (6. cikk (1) b)): fiók, fordítás, vásárlás,
  kézbesítés.
- Jogos érdek (6. cikk (1) f)): visszaélés-megelőzés, sebességkorlátozás,
  működés-megbízhatósági figyelés.
- Jogi kötelezettség (6. cikk (1) c)): a vásárlások számviteli bizonylatai.

## 7. Jogaid

Az appban: **Beállítások → Fiók** alatt **exportálhatod az adataidat** és
**törölheted a fiókodat** — a törlés azonnal eltávolítja a fiókod, a
jogosultsági metaadatokat és minden tárolt fájlt. Emellett megilletnek a GDPR
szerinti jogok (hozzáférés, helyesbítés, törlés, korlátozás, hordozhatóság,
tiltakozás) — írj a [[CONTACT_EMAIL]] címre. Panaszt a NAIH-nál tehetsz
(naih.hu).

## 8. AI-átláthatóság (EU AI-rendelet)

A fordításokat mesterséges intelligencia készíti. A lefordított könyveket az
app láthatóan jelöli, és a fájl géppel olvasható jelölést is hordoz, ahogy azt
az EU AI-rendelet 50. cikke előírja.

## 9. Gyermekek

A NativBook nem 16 év alattiaknak szól, tudatosan nem kezeljük az adataikat.

## 10. Változások

A módosításokat a [[POLICY_URL]] címen tesszük közzé új hatálydátummal;
lényeges változásról az appban is szólunk.
