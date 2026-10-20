# Segmentació DMZ / Intranet

## Política del tallafocs (nftables al router)

| Origen | Destí | Resultat |
|---|---|---|
| Intranet | Tot (DMZ i Internet) | Permès |
| DMZ | Internet | Permès |
| W-N08 (192.168.10.10) | B-N08 (192.168.20.10) només TCP 3306 | Permès (excepció) |
| DMZ | Intranet (qualsevol altre) | **Bloquejat** (`policy drop`) |

Regla d'excepció:

Fitxer complet: [`configs/router/nftables.conf`](../configs/router/nftables.conf)

## Proves

### DMZ -> Intranet bloquejat

W-N08:

![Ping bloquejat des de W-N08](img/seg-ping-w-bloquejat.png)

F-N08:

![Ping bloquejat des de F-N08](img/seg-ping-f-bloquejat.png)

### W-N08 -> B-N08 pel port 3306 permès

![Connexió MySQL des de W-N08](img/seg-mysql-w-b.png)

### Intranet -> DMZ permès

![Ping des de B-N08 a la DMZ](img/seg-ping-b-dmz.png)
