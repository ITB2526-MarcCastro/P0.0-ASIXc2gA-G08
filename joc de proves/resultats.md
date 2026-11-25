# Resultats, logs i diagnòstic

## 1. Resultat final validat

En l'última execució mostrada durant el projecte, el resum va ser:

| Estat | Nombre |
|---|---:|
| OK | 93 |
| KO | 0 |
| AVIS | 0 |
| OMITIDES | 0 |
| **Total** | **93** |

Això correspon a una execució concreta de la versió integrada amb Linux i Windows. Si es modifica el codi, les credencials, les regles de xarxa o els serveis, cal repetir la validació.

## 2. Ubicació dels logs

Els logs centralitzats es desen al router R-N08:

```text
/opt/joc-proves/logs/
```

| Fitxer | Contingut |
|---|---|
| `espera_serveis.log` | Comprovacions prèvies, intents `WAIT` i moment en què els equips estan preparats |
| `execucio.log` | Inici, resultats individuals i resum final de cada execució |
| `errors.log` | Registres de les proves amb estat `KO` |
| `resultats.csv` | Resultats estructurats separats per punt i coma |

El CSV conté les columnes:

```text
data;execucio;equip;rol;id;estat;prova;detall
```

Els logs s'acumulen entre execucions. Cal filtrar per data i identificador d'execució per no confondre resultats antics amb els de l'última prova.

## 3. Consultar systemd

Comprovar si el servei està habilitat:

```bash
sudo systemctl is-enabled go8-proves.service
```

Consultar l'estat:

```bash
sudo systemctl status go8-proves.service --no-pager
```

Consultar els registres de l'arrencada actual:

```bash
sudo journalctl -b -u go8-proves.service --no-pager
```

Seguir l'execució en directe:

```bash
sudo journalctl -fu go8-proves.service
```

Una unitat `Type=oneshot` pot aparèixer com a `inactive (dead)` després de finalitzar. Això és normal si l'execució ha acabat. Cal revisar `Result`, `ExecMainStatus`, el journal i el resum del joc de proves.

## 4. Consultar els resultats

Últimes línies del registre general:

```bash
sudo tail -n 30 /opt/joc-proves/logs/execucio.log
```

Consultar els errors:

```bash
sudo cat /opt/joc-proves/logs/errors.log
```

Consultar el CSV:

```bash
sudo tail -n 30 /opt/joc-proves/logs/resultats.csv
```

Consultar només les proves de Windows:

```bash
sudo grep -E ';CW[0-9]+;' /opt/joc-proves/logs/resultats.csv | tail -n 17
```

Consultar les proves C30 i R40:

```bash
sudo grep -E ';(C30|R40);' /opt/joc-proves/logs/resultats.csv | tail -n 2
```

## 5. Significat dels estats

| Estat | Significat |
|---|---|
| `OK` | La comprovació ha obtingut el resultat esperat. |
| `KO` | La comprovació no ha obtingut el resultat esperat. |
| `AVIS` | Hi ha una limitació o un resultat que requereix revisió. |
| `OMITIDA` | La prova no s'ha pogut executar, falta una eina, una credencial o una condició necessària. |
| `WAIT` | Estat del procés d'espera: encara no s'han complert tots els requisits previs. No és un resultat final d'una prova. |

## 6. Diagnòstic habitual

### El procés continua mostrant WAIT

Consultar:

```bash
sudo tail -n 60 /opt/joc-proves/logs/espera_serveis.log
```

Comprovar que els sis equips estan engegats, que els serveis estan habilitats i actius, que els ports són accessibles i que SSH funciona sense demanar contrasenya.

### SSH no funciona

Comprovar la clau privada, el fitxer `known_hosts`, l'usuari remot i els permisos de `authorized_keys`. No desactivar `StrictHostKeyChecking` com a solució permanent; verificar primer l'empremta del servidor.

### Prova FTP omesa o fallida

Comprovar que `/etc/go8-proves.env` existeix a R-N08, té permisos restrictius, conté `FTP_USER` i `FTP_PASS`, i que el drop-in de systemd carrega el fitxer. Revisar també l'usuari `bchecker`, vsftpd i el rang passiu 40000–40100.

### B03 MySQL omesa

Comprovar a B-N08 que l'usuari `isard` té configurat el login-path `go8`:

```bash
mysql_config_editor print --all
```

No s'ha de publicar la contrasenya. Provar el recompte:

```bash
mysql --login-path=go8 -N -B -e \
"SELECT COUNT(*), COUNT(DISTINCT register_id) FROM equipaments.equipaments;"
```

### C30 o CW16 no passa

Comprovar les regles UFW locals de B-N08 i confirmar que MySQL no és accessible des de C-LINUX o C-WIN, però sí des dels orígens autoritzats. Una connexió fallida no identifica per si sola la causa; cal revisar les regles i els registres del tallafoc.

### Les proves Windows no retornen resultats

Comprovar l'accés SSH a C-WIN, l'execució de `powershell.exe`, el servei `sshd`, els permisos del fitxer `administrators_authorized_keys` i el contingut de la sortida remota.

## 7. Evidències del projecte

Les captures de les execucions i de la validació s'han de mantenir a la carpeta `img/` existent a l'arrel del repositori. No s'ha de crear una segona carpeta `img/` dins de `joc de proves/`.

Es recomana conservar evidències de:

- Estat final amb 93 proves correctes.
- Arrencada automàtica del servei systemd.
- Comprovació prèvia de tots els serveis.
- Resultats de C-LINUX i C-WIN.
- Logs centrals del router.

Abans de publicar captures, comprovar que no hi apareguin contrasenyes, claus privades, tokens o altres dades sensibles.
