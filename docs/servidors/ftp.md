# F-N08: servidor FTP (DMZ)

vsftpd, IP fixa 192.168.10.11.

![Xarxa de F-N08](../img/ftp-xarxa.png)

![Usuari bchecker](../img/ftp-id.png)

## Configuració

Sense accés anònim, usuaris locals amb chroot i mode passiu (ports 40000-40100). Fitxer: [`configs/ftp/vsftpd.conf`](../../configs/ftp/vsftpd.conf)

![vsftpd.conf](../img/ftp-conf.png)

![Port 21](../img/ftp-ss.png)

![Estat de vsftpd](../img/ftp-status.png)

## Proves

Des del propi F-N08:

![curl FTP local](../img/ftp-curl-local.png)

Des de la Intranet:

![FTP des de B-N08](../img/ftp-curl-b.png)

> Nota: FTP envia usuari i contrasenya en text pla. Millora possible: FTPS amb certificat.
