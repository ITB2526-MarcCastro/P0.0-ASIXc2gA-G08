# Catàleg de proves G08

Aquest document descriu els identificadors que utilitza `script.sh`. El resultat de cada prova depèn de l'estat real dels equips en el moment de l'execució.

## 1. Router R-N08 — 33 proves locals

| ID | Comprovació |
|---|---|
| R01 | IP de la interfície DMZ `enp3s0`: 192.168.10.1/24 |
| R02 | IP de la interfície LAN `enp4s0`: 192.168.20.1/24 |
| R03enp1s0 | Existència de la interfície WAN `enp1s0` |
| R03enp2s0 | Existència de la interfície VPN `enp2s0` |
| R04 | Ruta per defecte per la interfície WAN `enp1s0` |
| R05 | Absència d'una ruta per defecte per la VPN `enp2s0` |
| R06 | Reenviament IPv4 activat (`net.ipv4.ip_forward=1`) |
| R07 | Servei dnsmasq actiu |
| R08 | Servei nftables actiu |
| R09 | Rang DHCP de la LAN |
| R10 | Gateway DHCP 192.168.20.1 |
| R11 | DNS DHCP 192.168.20.1 |
| R12 | Configuració DNS sense consultar `/etc/hosts` |
| R13 | Resolució DNS de R-N08 |
| R14 | Resolució DNS de W-N08 |
| R15 | Resolució DNS de F-N08 |
| R16 | Resolució DNS de B-N08 |
| R17 | Política `drop` de la cadena forward |
| R18 | Excepció W-N08 cap a B-N08 TCP 3306 |
| R19 | Regla de sortida de la LAN |
| R20 | Regla de sortida DMZ cap a WAN |
| R21 | NAT masquerade per la WAN |
| R22 | Validació de sintaxi de `/etc/nftables.conf` |
| R23 | Ping de R-N08 a W-N08 |
| R24 | Ping de R-N08 a F-N08 |
| R25 | Ping de R-N08 a B-N08 |
| R26 | TCP 80 de W-N08 accessible |
| R27 | TCP 21 de F-N08 accessible |
| R28 | TCP 3306 de B-N08 accessible des del router |
| R29 | Resposta HTTP 200 i contingut de l'aplicació PHP amb connexió MySQL i 1982 equipaments |
| R31 | Rebuig de l'accés FTP anònim |
| R32 | Autenticació FTP i llistat passiu amb l'usuari de proves |
| R41 | Sortida HTTPS a Internet des del router |

## 2. Resultats de l'execució remota — 4 comprovacions

A més de les proves pròpies de cada equip, el router registra si ha rebut resultats estructurats de cada execució SSH:

| ID | Comprovació |
|---|---|
| SSH-web | Execució remota de les proves de W-N08 |
| SSH-ftp | Execució remota de les proves de F-N08 |
| SSH-db | Execució remota de les proves de B-N08 |
| SSH-client | Execució remota de les proves de C-LINUX |

## 3. Servidor web W-N08 — 7 proves

| ID | Comprovació |
|---|---|
| W01 | Apache2 actiu |
| W02 | Mòdul PHP `mysqli` disponible |
| W03 | Aplicació web local: HTTP 200, connexió MySQL i 1982 equipaments |
| W04 | Connexió W-N08 cap a B-N08 TCP 3306 permesa |
| W05 | ICMP de W-N08 cap a B-N08 restringit |
| W06 | Accés W-N08 cap a B-N08 TCP 22 restringit |
| W07 | Sortida HTTPS a Internet des de W-N08 |

## 4. Servidor FTP F-N08 — 10 proves

| ID | Comprovació |
|---|---|
| F01 | vsftpd actiu |
| F02 | Port FTP local TCP 21 |
| F03 | Configuració `anonymous_enable=NO` |
| F04 | Configuració `local_enable=YES` |
| F05 | Port passiu mínim 40000 |
| F06 | Port passiu màxim 40100 |
| F07 | Configuració `chroot_local_user=YES` |
| F08 | Accés F-N08 cap a B-N08 TCP 3306 restringit |
| F09 | ICMP de F-N08 cap a B-N08 restringit |
| F10 | Sortida HTTPS a Internet des de F-N08 |

## 5. Servidor MySQL B-N08 — 6 proves

| ID | Comprovació |
|---|---|
| B01 | Servei MySQL actiu |
| B02 | Port MySQL local TCP 3306 |
| B03 | Recompte de 2710 files i 1982 `register_id` diferents |
| B04 | Ping de B-N08 a W-N08 |
| B05 | Ping de B-N08 a F-N08 |
| B06 | Accés a l'aplicació web i comprovació de la connexió amb MySQL |

## 6. Client Ubuntu C-LINUX — 15 proves

| ID | Comprovació |
|---|---|
| C01 | IP dins del rang DHCP 192.168.20.100–192.168.20.200 |
| C02 | Gateway 192.168.20.1 |
| C03 | DNS rebut del router 192.168.20.1 |
| C04 | Ping al gateway |
| C05 | Ping a W-N08 |
| C06 | Ping a F-N08 |
| C07 | Ping a B-N08 |
| C08 | Resolució DNS de W-N08 |
| C09 | Resolució DNS de F-N08 |
| C10 | Resolució DNS de B-N08 |
| C11 | Accés a l'aplicació web PHP |
| C21 | Rebuig d'FTP anònim |
| C22 | Autenticació FTP i llistat passiu |
| C30 | Connexió directa del client a MySQL TCP 3306 no accessible |
| C31 | Sortida HTTPS a Internet des de C-LINUX |

La prova C30 comprova que el port no és accessible des del client. Per si sola, una connexió fallida no demostra quin dispositiu o regla n'ha provocat el bloqueig; cal interpretar-la conjuntament amb les regles locals d'UFW de B-N08.

## 7. Client Windows C-WIN — 17 proves

Les comprovacions s'executen remotament des de R-N08 mitjançant OpenSSH Server i PowerShell.

| ID | Comprovació |
|---|---|
| CW01 | IP dins del rang DHCP 192.168.20.100–192.168.20.200 |
| CW02 | Gateway 192.168.20.1 |
| CW03 | DNS 192.168.20.1 |
| CW04 | DHCP activat a la interfície IPv4 |
| CW05 | Ping al router |
| CW06 | Ping a W-N08 |
| CW07 | Ping a F-N08 |
| CW08 | Ping a B-N08 |
| CW09 | Resolució DNS de W-N08 |
| CW10 | Resolució DNS de F-N08 |
| CW11 | Resolució DNS de B-N08 |
| CW12 | Accés web a Apache amb resposta HTTP 200 |
| CW13 | Presència del recompte de 1982 equipaments al contingut web |
| CW14 | Rebuig de l'accés FTP anònim |
| CW15 | Autenticació FTP i llistat passiu |
| CW16 | Accés directe a MySQL TCP 3306 bloquejat |
| CW17 | Sortida HTTPS a Internet |

## 8. Validació conjunta R40

| ID | Comprovació |
|---|---|
| R40 | Validació del conjunt de proves remotes de W-N08, F-N08, B-N08, C-LINUX i C-WIN |

R40 queda en estat `OK` quan les execucions remotes no han retornat errors, avisos ni proves omeses. Si hi ha incidències, es registra com a `AVIS`.

## 9. Recompte

| Grup | Nombre |
|---|---:|
| R-N08 | 33 |
| Execucions remotes SSH | 4 |
| W-N08 | 7 |
| F-N08 | 10 |
| B-N08 | 6 |
| C-LINUX | 15 |
| C-WIN | 17 |
| R40 | 1 |
| **Total** | **93** |

Les proves FTP de transferència de fitxers (`--ftp-write`) són opcionals al codi i no formen part del conjunt automàtic per defecte.
