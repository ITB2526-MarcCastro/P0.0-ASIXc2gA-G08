# Instal·lació del joc de proves G08

## 1. Requisits previs

La instal·lació central es fa a **R-N08** (Ubuntu). Cal disposar de:

- Bash i systemd.
- Client OpenSSH (`ssh`).
- `curl`, `timeout`, `base64`, `iconv`, `sed`, `grep`, `tee` i eines bàsiques de GNU.
- `dig` i `ping` per a les proves DNS i ICMP.
- `nft` per inspeccionar nftables.
- Accés de lectura als fitxers de configuració que es comproven.
- Una clau SSH utilitzable sense interacció i un `known_hosts` amb les empremtes verificades.

Els equips remots han de tenir els serveis necessaris instal·lats i configurats:

| Equip | Requisit |
|---|---|
| W-N08 | Apache2, PHP i extensió `mysqli` |
| F-N08 | vsftpd i usuari FTP de proves |
| B-N08 | MySQL i client MySQL |
| C-LINUX | OpenSSH Server |
| C-WIN | OpenSSH Server i PowerShell |

## 2. Copiar els scripts al router

Des de l'arrel del repositori local, a R-N08:

```bash
sudo mkdir -p /opt/joc-proves
sudo install -m 755 "joc de proves/scripts/esperar_serveis.sh" /opt/joc-proves/
sudo install -m 755 "joc de proves/scripts/script.sh" /opt/joc-proves/
sudo install -m 644 "joc de proves/scripts/go8-proves.service" /etc/systemd/system/
```

Comprovar els fitxers:

```bash
ls -l /opt/joc-proves/
sudo systemctl cat go8-proves.service
```

## 3. Configurar les credencials FTP al router

La prova d'autenticació FTP necessita les credencials de l'usuari de proves `bchecker` de F-N08.

Crear un fitxer local protegit:

```bash
sudo install -o root -g root -m 600 /dev/null /etc/go8-proves.env
sudo nano /etc/go8-proves.env
```

Contingut:

```ini
FTP_USER=bchecker
FTP_PASS="CONTRASENYA_REAL_DE_BCHECKER"
```

Substituir el valor d'exemple per la contrasenya real. No afegir aquest fitxer al repositori.

Indicar a systemd que carregui el fitxer:

```bash
sudo systemctl edit go8-proves.service
```

Contingut del drop-in:

```ini
[Service]
EnvironmentFile=/etc/go8-proves.env
```

Desar i recarregar systemd:

```bash
sudo systemctl daemon-reload
sudo systemctl show go8-proves.service -p EnvironmentFiles
```

## 4. Instal·lar i habilitar el servei

```bash
sudo systemctl daemon-reload
sudo systemctl enable go8-proves.service
```

Comprovar que està habilitat:

```bash
sudo systemctl is-enabled go8-proves.service
```

El resultat esperat és `enabled`.

## 5. Validar la sintaxi i els requisits previs

```bash
sudo bash -n /opt/joc-proves/script.sh
sudo bash -n /opt/joc-proves/esperar_serveis.sh
```

Fer una sola ronda de comprovacions, sense iniciar el joc:

```bash
sudo bash /opt/joc-proves/esperar_serveis.sh --check-once
```

Si hi ha serveis pendents, revisar el fitxer:

```bash
sudo tail -n 50 /opt/joc-proves/logs/espera_serveis.log
```

Quan la comprovació única indiqui que tots els requisits estan preparats, es pot iniciar una execució de validació:

```bash
sudo systemctl start --no-block go8-proves.service
```

## 6. Arrencada automàtica

El servei queda habilitat perquè systemd iniciï el procés després de cada arrencada normal de R-N08. No cal executar manualment cap dels scripts.

Per validar l'execució de l'arrencada actual:

```bash
sudo journalctl -b -u go8-proves.service --no-pager
```

Per seguir el procés en directe:

```bash
sudo journalctl -fu go8-proves.service
```

## 7. Actualitzar els scripts instal·lats

Després d'actualitzar els fitxers del repositori, copiar les versions noves a `/opt/joc-proves/` i validar-ne la sintaxi:

```bash
sudo install -m 755 "joc de proves/scripts/esperar_serveis.sh" /opt/joc-proves/
sudo install -m 755 "joc de proves/scripts/script.sh" /opt/joc-proves/
sudo bash -n /opt/joc-proves/script.sh
sudo bash -n /opt/joc-proves/esperar_serveis.sh
```

No cal tornar a instal·lar la unitat systemd si no ha canviat `go8-proves.service`. Si la unitat canvia:

```bash
sudo install -m 644 "joc de proves/scripts/go8-proves.service" /etc/systemd/system/
sudo systemctl daemon-reload
```

## 8. Precaucions

- No copiar `/etc/go8-proves.env` al repositori.
- No copiar la clau privada SSH.
- No publicar `.mylogin.cnf`.
- No executar `git add` sobre els directoris de credencials o logs locals.
- Abans de reiniciar o fer una prova, comprovar que les sis màquines estan engegades i que els serveis necessaris estan disponibles.
