# Manual d'administrador

Aquest manual explica com està muntada la infraestructura i com mantenir-la. Per a la part de client, vegeu el [manual d'usuari](manual-usuari.md).

## Com està muntat

Tot funciona sobre Isard. Hi ha un router (R-N08) amb quatre targetes: Default per sortir a Internet, Wireguard només per gestió, itb8 com a DMZ i itb18 com a Intranet. Els detalls són a [arquitectura](arquitectura.md) i [xarxa i IPs](xarxa-ips.md).

- **R-N08**: router, NAT, tallafocs (nftables), DHCP i DNS (dnsmasq). IPs 192.168.10.1 (DMZ) i 192.168.20.1 (Intranet).
- **W-N08** (192.168.10.10): Apache i PHP, a la DMZ.
- **F-N08** (192.168.10.11): vsftpd, a la DMZ.
- **B-N08** (192.168.20.10): MySQL, a la Intranet.
- **Clients Linux i Windows**: Intranet, IP per DHCP (192.168.20.100-200).

## Accés als equips

Tots els equips tenen l'usuari `bchecker` / `bchecker121` amb permisos de sudo. S'hi entra per la consola d'Isard o per SSH des del router, per exemple `ssh bchecker@192.168.10.10`. Aquestes contrasenyes són les que demana la pràctica; en un entorn real caldria canviar-les i fer servir claus SSH.

## Ordre d'arrencada

Cal engegar primer el router, perquè sense ell no hi ha ni DHCP, ni DNS, ni sortida a Internet. Després B-N08, després W-N08 i F-N08, i al final els clients. Si es reinicia el router, nftables i dnsmasq han d'arrencar sols; es pot comprovar amb `systemctl is-enabled nftables dnsmasq`.

## Router

El reenviament d'IP està activat a `/etc/sysctl.d/99-forward.conf`. Es comprova amb `cat /proc/sys/net/ipv4/ip_forward`, que ha de donar 1.

El tallafocs és a `/etc/nftables.conf` (còpia a `configs/router/nftables.conf`). La política del forward és `drop`, i només es permet: Intranet cap a tot arreu, DMZ cap a Internet, i una excepció de W-N08 a B-N08 pel port 3306. Per veure les regles actives, `sudo nft list ruleset`. Per aplicar canvis:

```
sudo nft -c -f /etc/nftables.conf
sudo nft -f /etc/nftables.conf
```

Si cal obrir un accés nou, s'afegeix una regla dins de `chain forward` abans de les línies `iifname`. Més detall a [segmentació](segmentacio.md).

El DHCP i el DNS són a `/etc/dnsmasq.d/projecte.conf`. El DHCP només reparteix a la Intranet. El DNS resol `R-N08` i `R` cap al router, més els noms dels servidors. Les concessions es veuen a `/var/lib/misc/dnsmasq.leases` i el servei es reinicia amb `sudo systemctl restart dnsmasq`.

## Base de dades

MySQL a B-N08 escolta a tots els interfícies (`bind-address = 0.0.0.0`) perquè W-N08 hi pugui arribar. La base de dades es diu `equipaments` i té una sola taula amb 2710 files, que corresponen a 1982 equipaments únics (el CSV té una fila per cada atribut). L'script `configs/bbdd/equipaments.sql` ho recrea tot.

El CSV de l'Ajuntament ve en UTF-16, i si es carrega directament els accents es trenquen. Cal convertir-lo abans:

```
iconv -f UTF-16 -t UTF-8 equipaments.csv -o equipaments_utf8.csv
```

i copiar-lo a `/var/lib/mysql-files/`, que és l'únic directori des d'on MySQL deixa fer `LOAD DATA INFILE`.

## Web

L'aplicació és `/var/www/html/index.php` (còpia a `configs/web/`). Es connecta a B-N08 amb l'usuari `bchecker` i mostra els equipaments únics. Si dona error de connexió, normalment és que B-N08 està apagada o que la regla del 3306 no està carregada al router. Els errors d'Apache són a `/var/log/apache2/error.log`.

## FTP

vsftpd a F-N08, configurat a `/etc/vsftpd.conf` (còpia a `configs/ftp/`). Sense accés anònim, amb usuaris locals tancats a casa seva i mode passiu als ports 40000-40100. Estat amb `systemctl status vsftpd`.

## Control de versions

Tota la configuració és al repositori de GitHub, validat des de R-N08 amb una clau SSH ed25519 afegida com a deploy key amb permís d'escriptura. El flux és `git add .`, `git commit -m "..."` i `git push`. Si s'han pujat fitxers des del web de GitHub, cal fer `git pull` abans del `push`. Més a [git.md](git.md).

## Problemes que hem tingut

- **Accents trencats al carregar el CSV**: el fitxer era UTF-16, es va convertir amb `iconv`.
- **`dig R-N08` donava també 127.0.1.1**: dnsmasq llegia `/etc/hosts`. Es va solucionar amb `no-hosts`.
- **La regla del 3306 no funcionava**: s'havia aplicat el tallafocs a W-N08 en lloc de al router. Les regles de filtratge han d'estar sempre a R-N08.

## Punts de seguretat a millorar

- FTP envia usuari i contrasenya sense xifrar; es podria passar a FTPS amb certificat.
- `index.php` té la contrasenya de la base de dades en text pla.
- MySQL accepta l'usuari `bchecker` des de qualsevol IP (`'%'`); es podria limitar a 192.168.10.10.
- La cadena `input` del router està en `accept`; es podria tancar i deixar només SSH, DHCP i DNS.
- Millores previstes: SSH amb port knocking, HTTPS, script de desplegament, segmentar la base de dades en taules relacionades.
