# Clients

Els dos clients són a la xarxa **itb18** (Intranet) i reben IP, gateway i DNS per DHCP.

## C-LIN (Linux)

![Nom i IP per DHCP](../img/clin-ip.png)

![Proves de xarxa](../img/clin-ping.png)

![Usuari bchecker](../img/clin-id.png)

> Incidència: el client tenia també Default i Wireguard i dues rutes per defecte (la de Default amb metric més baix), així que el trànsit cap a la DMZ no passava pel router i la web donava timeout. Es va solucionar deixant el client només amb itb18.

![Rutes amb l'error](../img/clin-ruta-error.png)

![Rutes corregides](../img/clin-ruta-ok.png)

![FTP des del client](../img/clin-ftp.png)

![Web al navegador](../img/web-navegador-clin.png)

## C-WIN (Windows)

![Nom i IP per DHCP](../img/cwin-ip.png)

![Proves de xarxa](../img/cwin-ping.png)

![Usuari bchecker](../img/cwin-user.png)

![FTP des del client](../img/cwin-ftp.png)

![Web al navegador](../img/web-navegador-cwin.png)
