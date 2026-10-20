# Router R-N08

Funcions: gateway de DMZ i Intranet, NAT, tallafocs (nftables), DHCP i DNS (dnsmasq).

![Nom del router](../img/router-hostnamectl.png)

## Interfícies i IPs

Interfícies: enp1s0 Default (WAN), enp2s0 Wireguard (gestió), enp3s0 DMZ, enp4s0 Intranet.

```bash
sudo nmcli connection add type ethernet ifname enp3s0 con-name DMZ ipv4.method manual ipv4.addresses 192.168.10.1/24
sudo nmcli connection add type ethernet ifname enp4s0 con-name INTRANET ipv4.method manual ipv4.addresses 192.168.20.1/24
```

![IPs del router](../img/router-ip.png)

## Reenviament d'IP

```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl --system
```

![ip_forward](../img/router-forward.png)

## DHCP i DNS (dnsmasq)

DHCP només a la Intranet (192.168.20.100-200). DNS resol `R-N08` i `R` cap al router, més els noms dels servidors. Fitxer: [`configs/router/projecte.conf`](../../configs/router/projecte.conf)

![Estat de dnsmasq](../img/router-dnsmasq.png)

![Ports 53 i 67](../img/router-ports.png)

> Incidència: `dig R-N08` retornava també `127.0.1.1`, perquè dnsmasq llegia `/etc/hosts`. Es va solucionar afegint `no-hosts` a la configuració.

![dig R-N08 i R](../img/router-dig.png)

![no-hosts](../img/router-nohosts.png)

## Tallafocs i NAT (nftables)

Masquerade per la WAN i `policy drop` al forward, amb excepcions. Fitxer: [`configs/router/nftables.conf`](../../configs/router/nftables.conf). Detall a [segmentació](../segmentacio.md).

![Regles actives](../img/router-nft-list.png)

![nftables.conf](../img/router-nftables-conf.png)

## Usuari

![Usuari bchecker](../img/router-id.png)
