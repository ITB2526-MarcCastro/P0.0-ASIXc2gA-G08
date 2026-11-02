

# Manual d'usuari

Aquest manual explica com utilitzar els serveis que hem muntat des d'un ordinador de la xarxa interna (el client Linux o el client Windows). No cal configurar res: l'ordinador agafa la xarxa sol quan s'encén.

Per entrar a qualsevol equip el usuari és `bchecker` i la contrasenya `bchecker121`.

## Veure la web dels equipaments

Obre el navegador (Firefox al Linux, Edge al Windows) i escriu a la barra d'adreces:

http://192.168.10.10


És important escriure el `http://`, perquè si no el navegador prova amb `https://` i no carrega (el servidor no té certificat).

La pàgina mostra un missatge en verd que diu que s'ha connectat a la base de dades, el nombre d'equipaments que hi ha (1982) i una taula amb els 100 primers: identificador, nom, carrer, barri i districte.

![Web al navegador](img/web-navegador-clin.png)

Si en comptes del missatge verd surt un error en vermell, vol dir que la base de dades està apagada o no s'hi arriba. Això no ho pots arreglar des del client, cal avisar l'administrador.

## Pujar i baixar fitxers amb el FTP

El servidor FTP és a `192.168.10.11` i s'entra amb el mateix usuari `bchecker`.

Des del Windows, el més fàcil és obrir l'Explorador de fitxers i escriure a la barra d'adreces `ftp://192.168.10.11`. Et demanarà l'usuari i la contrasenya.

Des del Linux, o des de la consola del Windows, s'escriu:

ftp 192.168.10.11


Un cop dins, les ordres que farem servir més són:

- `ls` per veure els fitxers
- `get nom` per descarregar-ne un
- `put nom` per pujar-ne un
- `bye` per sortir

Si al Windows el `ls` es queda penjat, és cosa del client de consola; fes servir l'Explorador de fitxers.

## Coses que no es poden fer

Només es pot accedir a la web i al FTP. No hi ha accés directe a la base de dades des del client: només hi arriba la pàgina web. I els servidors de la DMZ (web i FTP) no poden connectar amb la xarxa interna, això està bloquejat expressament al router per seguretat.

## Si alguna cosa no funciona

- **No carrega la web:** comprova que has escrit `http://192.168.10.10` bé. Si és correcte, prova de fer `ping 192.168.10.10`; si no respon, l'ordinador no té xarxa.
- **L'ordinador no té xarxa:** reinicia'l. Si continua igual, el problema és al router i cal avisar l'administrador.
- **El FTP rebutja l'usuari:** revisa que has escrit bé la contrasenya. Les majúscules importen.
