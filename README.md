# P0.0-ASIXc2gA-G08

Desplegament d'infraestructura multicapa (Mòdul 0379, ITB).
Grup A08. Entorn: Isard VDI.

## Arquitectura
Router R-N08 amb 3 xarxes (Default/NAT, DMZ, Intranet), servidors
W-N08 (web), F-N08 (FTP), B-N08 (MySQL), DHCP i DNS (dnsmasq al router)
i 2 clients (Linux i Windows).

## Documentació
- [Arquitectura](docs/arquitectura.md)
- [Xarxa i IPs](docs/xarxa-ips.md)
- [Segmentació](docs/segmentacio.md)
- Servidors: [Router](docs/servidors/router.md) · [BBDD](docs/servidors/bbdd.md) · [Web](docs/servidors/web.md) · [FTP](docs/servidors/ftp.md) · [Clients](docs/servidors/clients.md)
- [Control de versions](docs/git.md)

## Usuari d'accés
Tots els sistemes tenen l'usuari `bchecker`.
