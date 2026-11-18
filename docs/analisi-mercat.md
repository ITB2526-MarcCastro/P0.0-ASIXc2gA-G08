# Anàlisi de mercat

Aquest document justifica les eines i el sistema operatiu que hem fet servir al projecte, i els compara amb les alternatives més habituals del sector.

## Context

El projecte planteja una infraestructura multicapa (router, web, base de dades, FTP, DHCP, DNS i clients) per a una petita organització. Una empresa d'aquest tipus busca solucions estables, amb suport a llarg termini, bona documentació i un cost de llicències baix. Els criteris amb què hem comparat cada opció són:

- Estabilitat i suport a llarg termini.
- Extensió al mercat i facilitat de trobar documentació i professionals que la coneguin.
- Cost (llicències i recursos).
- Seguretat.
- Simplicitat de manteniment i de documentació.

Per aquests criteris ens hem decantat per programari lliure d'ús molt estès.

## Entorn de desplegament: Isard VDI

Hem desplegat tota la infraestructura sobre Isard, una plataforma de virtualització d'escriptoris basada en KVM.

| Opció | Avantatges d'Isard davant d'ella |
|---|---|
| Virtualització local (VirtualBox, VMware) | No depèn de la potència del nostre ordinador. L'entorn és accessible des del navegador i es pot revisar des de qualsevol lloc |
| Servidor físic o Proxmox propi | No requereix maquinari ni manteniment d'infraestructura |
| Núvol públic (AWS, Azure) | Sense costos per ús, i permet xarxes privades aïllades (itb8, itb18) tan senzilles com les d'un laboratori |

Isard també ens permet crear plantilles de cada màquina, cosa que equival a una còpia de seguretat i accelera el desplegament de màquines noves.

## Sistema operatiu: Ubuntu 24.04 LTS Gnome Desktop

Totes les màquines (router, servidors i client Linux) fan servir Ubuntu 24.04 LTS amb entorn gràfic Gnome.

### Per què Ubuntu LTS

- **Suport a llarg termini.** Les versions LTS reben actualitzacions de seguretat durant anys, que és el que es requereix en un servidor.
- **Molt estès als servidors.** Té una de les comunitats més grans, amb molta documentació i respostes a gairebé qualsevol problema, cosa que redueix el temps de resolució d'incidències.
- **Programari actual als repositoris.** Apache, PHP 8.3, MySQL 8.0, nftables, dnsmasq i vsftpd s'instal·len amb `apt`, sense compilar res i amb actualitzacions de seguretat.
- **Una sola distribució per a tot.** Mateix sistema a totes les màquines implica les mateixes ordres, els mateixos fitxers de configuració i un manteniment més simple.

### Per què la versió amb entorn gràfic

- **Proves de punta a punta des de qualsevol màquina.** Amb un navegador a cada equip es pot comprovar la web, el FTP i la connexió amb la base de dades des de la xarxa on toca, tal com ho faria un usuari real.
- **Imatge única per a totes les màquines.** Router, servidors i client parteixen del mateix sistema, i es poden clonar des d'una mateixa plantilla.
- **Gestió de xarxa amb NetworkManager.** Inclou `nmcli`, que permet canviar IPs, gateways i DNS amb una sola ordre i sense editar fitxers YAML. Les ordres són fàcils de documentar i de repetir.
- **Eines gràfiques per diagnosticar.** Consola, monitor del sistema i editor de text faciliten trobar errors durant el desplegament.
- **Mateix entorn que el client.** El client Linux també és Desktop, així que servidor i client es poden comparar amb les mateixes eines.

El cost és un consum més alt de RAM i disc. En un entorn virtual com aquest no és un problema, i en un desplegament real es pot reduir arrencant en mode text amb `systemctl set-default multi-user.target`, sense reinstal·lar res. Les configuracions són directament reutilitzables en un Ubuntu Server.

### Comparativa amb altres sistemes

| Sistema | Punts forts | Per què hem preferit Ubuntu |
|---|---|---|
| Ubuntu Server | Més lleuger, ideal per producció | Mateixa base i mateixes configuracions. Desktop aporta més facilitat de prova i diagnòstic |
| Debian | Molt estable | Ubuntu LTS ofereix paquets més recents i un cicle de suport clar de 5 anys |
| Rocky / AlmaLinux | Habitual en grans empreses | Cal treballar amb `dnf`, SELinux i firewalld, que complica els serveis bàsics sense aportar res que necessitem |
| Windows Server | Integració amb Active Directory | Cost de llicència, més recursos i cap servei del projecte ho requereix |

## Eines per servei

### Tallafocs i NAT: nftables

- **Substitueix iptables.** Les distribucions actuals l'adopten com a estàndard.
- **Una sola sintaxi** per a NAT, filtrat i definició de variables (`define WAN = ...`), cosa que fa el fitxer més clar i curt.
- **Ve amb el nucli**, sense instal·lar res a part, i permet validar un fitxer abans d'aplicar-lo (`nft -c`).
- **Davant de pfSense o OPNsense**: són distribucions senceres amb interfície web, més pesades. Per a un router amb tres xarxes, un sistema Linux amb nftables fa la mateixa feina amb menys recursos i es documenta amb text, que es versiona a Git.

### DHCP i DNS: dnsmasq

- **Dos serveis en un.** Un únic paquet i un únic fitxer fan DHCP i DNS.
- **Lleuger i simple.** Una configuració de 25 línies cobreix el rang DHCP, els noms interns i el reenviament cap a l'exterior.
- **Resol els noms interns directament** amb `host-record`, sense muntar zones.
- **Davant d'ISC DHCP i BIND**: són més potents, però cal instal·lar-ne dos i configurar zones i fitxers de zona. Per a una xarxa petita, aquesta complexitat no aporta res.

### Servidor web: Apache 2 amb PHP

- **Integració directa amb PHP** (mòdul `libapache2-mod-php`), sense configurar res addicional.
- **Molt documentat** i habitual en servidors de producció, cosa que facilita trobar solucions.
- **Configuració per defecte funcional**: n'hi ha prou amb deixar l'aplicació a `/var/www/html`.
- **Davant de Nginx**: Nginx guanya amb molt de trànsit o com a proxy invers, però per una aplicació petita no es nota, i requereix PHP-FPM a part.

### Base de dades: MySQL 8.0

- **Base de dades relacional estàndard**, molt estesa i demanada per l'enunciat.
- **Compatible amb PHP** (`php-mysql`) sense afegir res més.
- **`LOAD DATA INFILE`** permet carregar un CSV de milers de files en menys d'un segon (2710 files en 0,10 s).
- **Usuaris i permisos per host**, que permeten restringir qui es connecta.
- **Davant de PostgreSQL**: és més complet, però per a una sola taula no aporta avantatges. **MariaDB** és compatible, però MySQL és la referència que demana el projecte.

### FTP: vsftpd

- **Segur per defecte**: sense accés anònim i amb usuaris locals tancats al seu directori (chroot).
- **Molt lleuger**, amb un fitxer de configuració curt i fàcil de documentar.
- **Ve als repositoris d'Ubuntu** i s'integra amb PAM i amb els usuaris del sistema.
- **Davant de ProFTPD i Pure-FTPd**: ofereixen més funcions, però vsftpd cobreix el que necessitem amb menys superfície d'atac.

### Accés remot: OpenSSH

- **Estàndard universal** per administrar servidors Linux.
- **Xifra tot el trànsit** i permet autenticar-se amb contrasenya o amb claus.
- **Inclou `scp`**, que hem fet servir per copiar configuracions de les màquines al repositori.

### Configuració de xarxa: NetworkManager i nmcli

- **Ordres d'una línia** per fixar IP, gateway i DNS, que es poden copiar directament a la documentació o a un script.
- **Aplica els canvis a l'instant** sense reiniciar.
- **Integrat a Ubuntu Desktop**, sense instal·lar res més.

### Control de versions: Git i GitHub

- **Estàndard del sector** per versionar configuració i documentació.
- **Autenticació amb clau pública/privada** (deploy key), més segura que una contrasenya.
- **Historial de canvis**: permet veure qui ha fet què i recuperar versions anteriors.
- **Davant de GitLab o Bitbucket**: GitHub és el més conegut i el que renderitza millor el Markdown amb imatges.

### Documentació: Markdown

- **Text pla** que es versiona amb Git juntament amb el codi.
- **GitHub el renderitza** directament, amb taules, imatges i blocs de codi.
- **Davant de Word o una wiki**: la documentació viu al mateix lloc que les configuracions i no hi ha fitxers que es desincronitzin.

### Planificació i diagrama

- **Proofhub** per al backlog i els sprints, tal com demana el mòdul.
- **draw.io** per al diagrama: gratuït, sense instal·lació i exporta a PNG, cosa que permet incrustar-lo al Markdown. Visio és de pagament i Lucidchart limita la versió gratuïta.

## Per què l'arquitectura amb DMZ i Intranet

Separar la web i el FTP (DMZ) de la base de dades i els clients (Intranet) és la pràctica habitual a les empreses:

- **Els serveis més exposats van a una zona aïllada.** Si el web es veu compromès, l'atacant no arriba directament a les dades.
- **Principi de mínim privilegi.** Només hem obert un pas de la DMZ a la Intranet: de W-N08 a B-N08 pel port 3306. Tota la resta està bloquejat per política (`policy drop`).
- **Davant d'una xarxa plana**: seria més fàcil de muntar, però qualsevol equip podria arribar a qualsevol altre, i el tallafocs no tindria res a protegir.

## Cost

Tot el programari és lliure i no té llicències. La plataforma ja la proporciona l'institut. El cost real és el temps de dedicació, unes 5 hores setmanals.

## Limitacions i millores

- Les màquines porten escriptori, que consumeix més recursos. En producció es pot arrencar en mode text o migrar a Ubuntu Server amb les mateixes configuracions.
- FTP no xifra les dades; es podria passar a FTPS amb certificat.
- Les contrasenyes són les de la pràctica; en un entorn real caldria canviar-les i fer servir claus SSH.
- Millores previstes: SSH amb port knocking, HTTPS amb certificats, segmentar la base de dades en taules relacionades i un script de desplegament.

## Conclusió

Hem triat programari lliure, ben documentat i habitual al mercat, amb Ubuntu 24.04 LTS com a base comuna a totes les màquines. Cada eina cobreix el seu servei amb menys complexitat que les alternatives i es pot descriure en fitxers de text versionats. L'escriptori ens ha permès provar i diagnosticar cada capa de la infraestructura, i les configuracions es poden reutilitzar tal qual en un servidor sense entorn gràfic.
