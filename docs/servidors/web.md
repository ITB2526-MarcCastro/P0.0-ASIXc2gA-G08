# W-N08: servidor web (DMZ)

Apache 2 + PHP 8.3, IP fixa 192.168.10.10.

![Xarxa de W-N08](../img/web-xarxa.png)

![Usuari bchecker](../img/web-id.png)

## Accés a la BBDD

El router només deixa passar W-N08 -> B-N08 pel port 3306.

![Connexió MySQL](../img/web-mysql.png)

## Apache i PHP

```bash
sudo apt install -y apache2 php libapache2-mod-php php-mysql mysql-client
```

![Apache i PHP](../img/web-apache-php.png)

## Aplicació

`/var/www/html/index.php` mostra els equipaments únics (agrupats per `register_id`, primers 100). Fitxer: [`configs/web/index.php`](../../configs/web/index.php)

![Codi de l'aplicació](../img/web-codi.png)

![curl local](../img/web-curl-local.png)

![curl des de B-N08](../img/web-curl-b.png)

## Resultat al navegador

![Web des de C-LIN](../img/web-navegador-clin.png)

![Web des de C-WIN](../img/web-navegador-cwin.png)
