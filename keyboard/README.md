# Clavier SPI — swap @ / \< (diagnostiqué, fix différé)

**Statut : diagnostic terminé, fix différé par l'utilisateur.**
Tout est prêt pour le reprendre.

## Symptôme

Sur la disposition **fr-mac** (la seule adéquate, déjà correcte en console
et GNOME), les touches marquées `@` et `<` du clavier physique produisent
le caractère l'une de l'autre.

## Diagnostic (fait le 15/10/2026)

Le clavier SPI n'est **pas** un uinput : c'est le driver noyau natif
`pxa2xx-spi` sur `/dev/input/event4` (`Apple SPI Keyboard`).

Capture brute avec un outil custom (source `/tmp/keycap30.c`, binaire
`/tmp/keycap90`, log : `keycap90.log`) :

| Touche physique marquée | Keycode émis | Symbole xkb (fr-mac) | Caractère affiché |
|---|---|---|---|
| `@` | **86** (KEY_ASTERISK) | `<AE11>` | `<` / `>` |
| `<` | **41** (KEY_GRAVE) | `<TLDE>` | `@` |

La touche `<` émet donc `41` et **jamais** `106` (KEY_102ND / `<LSGT>`) :
**le firmware T1 mappe mal cette touche** — elle envoie le keycode de la
touche grave au lieu de celui du LSGT. Le layout fr-mac est correct
(export complet : `fr-mac-xkb.txt`) ; le problème est dans le mapping
firmware/couches HID du T1.

## Fix prévu (quand on reprendra)

Remap **evdev/udev** (uinput) :

- `41 (KEY_GRAVE) → 106 (KEY_102ND)` — pour que la touche `<` donne `<`
- `86 (KEY_ASTERISK) → 41 (KEY_GRAVE)` — pour que la touche `@` donne `@`

**Précaution obligatoire** : vérifier d'abord le keycode réel de la touche
`&` (position TLDE physique) avant d'appliquer — elle pourrait aussi
émettre 41, dans lequel cas le remap global casserait la touche `&`.
Outils prêts : `/tmp/keycap30.c` + `/tmp/keycap90`.

Alternative : un layout xkb dédié (variant fr-mac-t1) si le remap evdev
s'avère trop envahissant.

## Fichiers

- `keycap90.log` — capture définitive des keycodes (grep `code=(86|41|106) `).
- Sur la machine (pas dans le repo) : `~/t1-diag/fr-mac-xkb.txt`
  (export xkb complet de la variante mac de fr).
