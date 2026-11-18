# Anàlisi de mercat

Aquest document explica per què hem triat les eines i el sistema operatiu del projecte, i quines alternatives hi havia.

## Context

El projecte demana una infraestructura multicapa (router, web, base de dades, FTP, DHCP, DNS i clients) per a una petita organització. Una empresa així necessita solucions estables, amb suport a llarg termini, que es trobin fàcilment documentades i que no tinguin un cost de llicències alt. Per això ens hem decantat per programari lliure i d'ús molt estès.

## Entorn: Isard VDI

Hem treballat sobre Isard, la plataforma de virtualització de l'institut. Ens permet crear les màquines i les xarxes privades (itb8 i itb18) sense maquinari propi, i accedir-hi des del navegador.

| Alternativa | Per què no |
|---|---|
| VirtualBox / VMware al nostre PC | Cal un ordinador potent, i les VMs no serien accessibles per al professor |
| Proxmox o servidor físic | Cost i manteniment de maquinari que no tenim |
| Núvol públic (AWS, Azure) | Cost, i no és necessari per a un entorn d'aprenentatge |

## Sistema operatiu: Ubuntu 24.04 Gnome Desktop LTS

Totes les màquines (router, servidors i client Linux) són Ubuntu 24.04 LTS amb entorn gràfic Gnome.

### Per què Ubuntu LTS

- **Suport a llarg termini.** Les versions LTS reben actualitzacions de seguretat durant anys, que és el que es demana en servidors.
- **Molt estès en servidors.** Hi ha molta documentació, fòrums i paquets al repositori, i això redueix el temps per resoldre problemes.
- **Programari actual als repositoris.** Apache, PHP 8.3, MySQL 8.0, nftables, dnsmasq i vsftpd s'instal·len amb `apt` sense compilar res.
- **Una sola distribució per a tot.** Tenir el mateix sistema a totes les màquines simplifica el manteniment i fa que les ordres i els fitxers de configuració siguin els mateixos a tot arreu.

### Per què la versió amb entorn gràfic (Gnome Desktop)

Cal ser honestos: la raó principal és pràctica. La plantilla que teníem disponible a Isard era Ubuntu 24.04 Desktop, i no n'hi havia cap de Server. Fer-ne una de nova hauria suposat instal·lar-la des de la ISO, i hem preferit dedicar el temps als serveis.

Això té avantatges i inconvenients:

| Avantatges | Inconvenients |
|---|---|
| Es pot obrir un navegador a qualsevol màquina per provar la web | Gasta més RAM i disc |
| Consola gràfica més còmoda per treballar | Més programari instal·lat vol dir més superfície d'atac |
| NetworkManager facilita configurar la xarxa | En producció un servidor no necessita escriptori |

[REVISA] Si es volgués passar a producció, el correcte seria usar Ubuntu Server. Es podria reduir part de la càrrega arrencant en mode text amb `systemctl set-default multi-user.target`, sense reinstal·lar res.

### Alternatives considerades

| Sistema | Per què no |
|---|---|
| Ubuntu Server | És la millor opció en producció, però no teníem la plantilla |
| Debian | Molt estable, però l'equip coneix millor Ubuntu i els paquets són una mica més antics |
| Rocky / AlmaLinux (Red Hat) | Són habituals en empreses grans, però ens obligaria a aprendre eines diferents (`dnf`, SELinux, firewalld) |
| Windows Server | Cost de llicència i més recursos; no és necessari per als serveis que muntem |

## Eines per servei

| Funció | Eina triada | Per què | Alternatives |
|---|---|---|---|
| Tallafocs i NAT | nftables | És el substitut modern d'iptables i ve amb el nucli. Una sola sintaxi per a NAT i filtrat | iptables (antic), pfSense/OPNsense (distribució dedicada, més pesada) |
| DHCP i DNS | dnsmasq | Fa les dues coses amb un sol servei i un sol fitxer, i és lleuger | ISC DHCP + BIND (més potents però molt més complexos per a una xarxa petita) |
| Servidor web | Apache 2 + PHP | Molt documentat i fàcil d'integrar amb PHP i MySQL | Nginx (més ràpid amb molt de trànsit, però no ho necessitem) |
| Base de dades | MySQL 8.0 | Relacional, molt estès amb PHP i demanat a l'enunciat | MariaDB (compatible), PostgreSQL (més complet, però sense necessitat aquí) |
| FTP | vsftpd | Segur per defecte, lleuger i ve als repositoris d'Ubuntu | ProFTPD, Pure-FTPd |
| Accés remot | OpenSSH | És l'estàndard. Permet també `scp` per copiar configuracions | Cap alternativa real |
| Xarxa a les VMs | NetworkManager i `nmcli` | És el que porta Ubuntu Desktop. Les ordres es poden copiar a la documentació | Netplan, que a Desktop només delega a NetworkManager |
| Control de versions | Git + GitHub | Estàndard del sector, amb autenticació per clau SSH | GitLab, Bitbucket |
| Planificació | Proofhub | Demanat pel mòdul, amb backlog i sprints | Trello, Jira |
| Documentació | Markdown | Es llegeix bé a GitHub i es versiona amb el codi | Word, Wiki |
| Diagrama | draw.io | Gratuït i exporta a PNG | Visio (de pagament), Lucidchart |

## Per què l'arquitectura amb DMZ i Intranet

Separar la web i el FTP (DMZ) de la base de dades i els clients (Intranet) és la pràctica habitual en empreses: els serveis més exposats van en una zona aïllada, de manera que si un d'ells es veu compromès, l'atacant no arriba directament a les dades. Només hem obert un únic pas, de la web a la base de dades pel port 3306.

Una alternativa seria posar-ho tot en una sola xarxa pla. Seria més fàcil de muntar, però molt menys segur.

## Cost

Tot el programari és lliure i sense llicències, i la plataforma ja la proporciona l'institut. El cost real és el temps de dedicació (5 hores setmanals).

## Limitacions i millores

- Les màquines porten escriptori sense necessitat; en producció caldria Ubuntu Server.
- FTP no xifra les dades; es podria passar a FTPS.
- Les contrasenyes són les de la pràctica, i en un entorn real caldria canviar-les.
- Hi ha millores previstes, com SSH amb port knocking, HTTPS amb certificats i segmentar la base de dades.

## Conclusió

Hem triat programari lliure, habitual en empreses i ben documentat, amb Ubuntu LTS com a base per a tot. L'escriptori de les màquines és una decisió de comoditat i de plantilla disponible, i en producció se substituiria per la versió Server.
