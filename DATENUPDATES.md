# Datenupdates für ForeverCraft

Für aktuelle Skillgrenzen empfehlen wir [LibProfessionDB für WoW Forever](https://www.curseforge.com/wow/addons/libprofessiondb) als separates Addon. ForeverCraft bevorzugt pro Rezept die Daten der aktiven Forever-Bibliothek. Fehlt der Eintrag oder widerspricht seine Graugrenze dem Spielclient, verwendet ForeverCraft die mitgelieferten Werte, sofern sie zum Client passen.

## Wöchentlicher Build

Das Paket enthält den ForeverCraft-Quellordner, den Importer und den GitHub-Actions-Workflow. Im ForeverCraft-Repository liegt der Workflow unter `.github/workflows/profession-data.yml`. Der Download über die CurseForge-API benötigt das Repository-Secret `CURSEFORGE_API_KEY`.

Die Prüfung läuft montags um 05:23 UTC auf dem Standardbranch. Sie kann auch im Actions-Reiter manuell gestartet werden. Ändern sich die Skillgrenzen gegenüber dem Stand im Repository, baut der Workflow eine installierbare ZIP und legt sie zur Prüfung als GitHub-Actions-Artefakt ab. Derselbe Datensatz erhält bei unveränderter Addon-Version denselben Tag. Das Quell-Repository wird dabei nicht umgeschrieben. Die Veröffentlichung auf CurseForge ist separat.

Ein lokaler Import verwendet denselben Ablauf:

```sh
python3 tools/update_profession_data.py --archive /pfad/zu/ProfessionDB.zip
```

Mit `--force` baut der Importer auch bei identischen Daten eine Test-ZIP.
