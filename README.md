# resultados_paso
Herramienta para descargar los datos publicados en el sitio 'resultados.gob.ar' (PASO del 13/08/2017)

La herramienta es un pequeño script de Ruby que procesa los datos publicados en las tablas con el volcado de la información de los telegramas.

Adicionalmente descarga los PDFs organizados en directorios con la misma estructura que en el servidor.

Testeado con Ruby 2.4.1.



Para su correcta ejecución requiere que tenga instalado una versión reciente de SQlite (https://www.sqlite.org/download.html) y  las siguientes gemas:
- 'sqlite3'
- 'open-uri'
- 'nokogiri'

Para instalar las gemas utilice el comando:

```bash
gem install sqlite3 open-uri nokogiri
```

Para iniciar o retomar el proceso de descarga ejecute desde la línea de comandos:
```bash
./descargar_resultados
```
