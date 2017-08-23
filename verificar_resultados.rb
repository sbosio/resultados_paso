#!/usr/bin/env ruby

# Gemas requeridas para el funcionamiento
require 'open-uri'
require 'nokogiri'
require 'sqlite3'

def valor_sql(valor)
  return 'NULL' if nil
  "'#{valor.to_s.gsub("'", "''")}'"
end

# Crear la base de datos
base_sql = SQLite3::Database.new 'resultados.db'
uri_base = 'http://www.resultados.gob.ar/99/resu/content/telegramas/'

# Crear la tabla que guardará las provincias
base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS provincias (
    id     integer,
    codigo varchar(10),
    nombre varchar(200)
  );
SQL
provincia_id = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS secciones (
    id           integer,
    provincia_id integer,
    codigo       varchar(10),
    nombre       varchar(200)
  );
SQL
seccion_id = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS circuitos (
    id           integer,
    provincia_id integer,
    seccion_id   integer,
    codigo       varchar(10),
    nombre       varchar(200)
  );
SQL
circuito_id = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS mesas (
    id               integer,
    provincia_id     integer,
    seccion_id       integer,
    circuito_id      integer,
    codigo           varchar(10),
    nombre           varchar(200),
    datos_cargados   boolean,
    votos_impugnados integer
  );
SQL
mesa_id = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS agrupaciones_politicas (
    id     integer,
    nombre varchar(200)
  );
SQL
agrupacion_politica_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS agrupaciones_por_provincia (
    id                     integer,
    agrupacion_politica_id integer,
    provincia_id           integer
  );
SQL
agrupacion_por_provincia_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS cargos_electivos (
    id     integer,
    nombre varchar(200)
  );
SQL
cargo_electivo_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS cargos_por_provincia (
    id                integer,
    cargo_electivo_id integer,
    provincia_id      integer
  );
SQL
cargo_por_provincia_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS listas (
    id                          integer,
    agrupacion_por_provincia_id integer,
    nombre                      varchar(200)
  );
SQL
lista_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS votos_nulos (
    id                integer,
    mesa_id           integer,
    cargo_electivo_id integer,
    cantidad          integer
  );
SQL
voto_nulo_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS votos_en_blanco (
    id                integer,
    mesa_id           integer,
    cargo_electivo_id integer,
    cantidad          integer
  );
SQL
voto_en_blanco_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS votos_recurridos (
    id                integer,
    mesa_id           integer,
    cargo_electivo_id integer,
    cantidad          integer
  );
SQL
voto_recurrido_secuencia = 0

base_sql.execute <<-SQL
  CREATE TABLE IF NOT EXISTS votos_escrutados (
    id                integer,
    mesa_id           integer,
    cargo_electivo_id integer,
    lista_id          integer,
    cantidad          integer
  );
SQL
voto_escrutado_secuencia = 0

base_sql.execute_batch <<-SQL
  CREATE UNIQUE INDEX IF NOT EXISTS idx_agrupaciones_politicas_on_id_unq ON agrupaciones_politicas (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_agrupaciones_por_provincia_on_id_unq ON agrupaciones_por_provincia (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_cargos_electivos_on_id_unq ON cargos_electivos (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_cargos_por_provincia_on_id_unq ON cargos_por_provincia (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_circuitos_on_id_unq ON circuitos (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_listas_on_id_unq ON listas (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_mesas_on_id_unq ON mesas (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_provincias_on_id_unq ON provincias (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_secciones_on_id_unq ON secciones (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_votos_en_blanco_on_id_unq ON votos_en_blanco (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_votos_nulos_on_id_unq ON votos_nulos (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_votos_recurridos_on_id_unq ON votos_recurridos (id);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_votos_escrutados_on_id_unq ON votos_escrutados (id);
SQL

doc_provincias = Nokogiri::HTML(open(uri_base + 'IPRO.htm'))
id_ultima_provincia, codigo_ultima_provincia = base_sql.execute(
  <<-SQL
    SELECT id, codigo FROM provincias ORDER BY id DESC LIMIT 1;
  SQL
).first || [0, '']

doc_provincias
  .css("div[class='ulmes'] ul li")
  .map { |_p| [_p.at_css('a').text, _p.at_css('a')['href']] }.each do |texto_provincia, uri_secciones|
  # Parsear la info de la provincia para obtener el código y el nombre
  provincia_codigo, provincia_nombre = texto_provincia.strip.match(/([0-9]+)\s+-\s+(.*)/).to_a[1..2]

  if codigo_ultima_provincia != ''
    if codigo_ultima_provincia != provincia_codigo
      puts "> Los datos de la provincia '#{provincia_nombre} (#{provincia_codigo})' ya fueron descargados."
      next
    else
      puts "> La provincia '#{provincia_nombre} (#{provincia_codigo})' se descargó parcialmente. Retomando la descarga."
      codigo_ultima_provincia = ''
      provincia_id = id_ultima_provincia.to_i
    end
  else
    # Insertar los datos de esta provincia en la base
    provincia_id += 1
    base_sql.execute <<-SQL
      INSERT INTO provincias
        (id, codigo, nombre)
        VALUES (#{valor_sql(provincia_id)}, #{valor_sql(provincia_codigo)}, #{valor_sql(provincia_nombre)});
    SQL
    puts "> Iniciando descarga de datos de la provincia '#{provincia_nombre} (#{provincia_codigo})'"
  end

  doc_secciones = Nokogiri::HTML(open(uri_base + uri_secciones))
  id_ultima_seccion, codigo_ultima_seccion = base_sql.execute(
    <<-SQL
      SELECT id, codigo FROM secciones WHERE provincia_id = '#{provincia_id}' ORDER BY id DESC LIMIT 1;
    SQL
  ).first || [0, '']

  doc_secciones
    .css("div[class='ulmes'] ul li")
    .map { |_s| [_s.at_css('a').text, _s.at_css('a')['href']] }.each do |texto_seccion, uri_circuitos|
    # Parsear la info de la sección para obtener el código y el nombre
    seccion_codigo, seccion_nombre = texto_seccion.strip.match(/([0-9]+)\s+-\s+(.*)/).to_a[1..2]

    if codigo_ultima_seccion != ''
      if codigo_ultima_seccion != seccion_codigo
        puts "  > Los datos de la sección '#{seccion_nombre} (#{seccion_codigo})' ya fueron descargados."
        next
      else
        puts "  > La sección '#{seccion_nombre (}#{seccion_codigo})' se descargó parcialmente. Retomando la descarga."
        codigo_ultima_seccion = ''
        seccion_id = id_ultima_seccion.to_i
      end
    else
      # Insertar los datos de esta seccion en la base
      seccion_id += 1
      base_sql.execute <<-SQL
        INSERT INTO secciones
          (id, provincia_id, codigo, nombre)
          VALUES (#{valor_sql(seccion_id)}, #{valor_sql(provincia_id)}, #{valor_sql(seccion_codigo)}, #{valor_sql(seccion_nombre)});
      SQL
      puts "  > Iniciando descarga de datos de la sección '#{seccion_nombre} (#{seccion_codigo})'"
    end

    doc_circuitos = Nokogiri::HTML(open(uri_base + uri_circuitos))
    id_ultimo_circuito, codigo_ultimo_circuito = base_sql.execute(
      <<-SQL
        SELECT id, codigo FROM circuitos WHERE seccion_id = '#{seccion_id}' ORDER BY id DESC LIMIT 1;
      SQL
    ).first || [0, '']

    doc_circuitos
      .css("div[class='ulmes'] ul li")
      .map { |_s| [_s.at_css('a').text, _s.at_css('a')['href']] }.each do |texto_circuito, uri_mesas|
      # Parsear la info del circuito para obtener el código/nombre
      circuito_codigo = circuito_nombre = texto_circuito.strip.match(/([0-9]+[A-Z]*)/).to_a[1]

      if codigo_ultimo_circuito != ''
        if codigo_ultimo_circuito != circuito_codigo
          puts "    > Los datos del circuito '#{circuito_codigo}' ya fueron descargados."
          next
        else
          puts "    > El circuito '#{circuito_codigo}' se descargó parcialmente. Retomando la descarga."
          codigo_ultimo_circuito = ''
          circuito_id = id_ultimo_circuito.to_i
        end
      else
        # Insertar los datos de este circuito en la base
        circuito_id += 1
        base_sql.execute <<-SQL
          INSERT INTO circuitos
            (id, provincia_id, seccion_id, codigo, nombre)
            VALUES (
              #{valor_sql(circuito_id)},
              #{valor_sql(provincia_id)},
              #{valor_sql(seccion_id)},
              #{valor_sql(circuito_codigo)},
              #{valor_sql(circuito_nombre)}
            );
        SQL
        puts "    > Iniciando descarga de datos del circuito '#{circuito_nombre}'"
      end

      doc_mesas = Nokogiri::HTML(open(uri_base + uri_mesas))
      id_ultima_mesa, codigo_ultima_mesa = base_sql.execute(
        <<-SQL
          SELECT id, codigo FROM mesas WHERE circuito_id = '#{circuito_id}' ORDER BY id DESC LIMIT 1;
        SQL
      ).first || [0, '']

      doc_mesas
        .css("div[class='ulmes'] ul li")
        .map { |_s| [_s.at_css('a').text, _s.at_css('a')['href']] }.each do |texto_mesa, uri_mesa|

        # Parsear la info de la mesa para obtener el código/nombre
        mesa_codigo = mesa_nombre = texto_mesa.strip.match(/([0-9]+[A-Z]*)/).to_a[1]

        if codigo_ultima_mesa != ''
          if codigo_ultima_mesa != mesa_codigo
            puts "      > Los datos de la mesa '#{mesa_codigo}' ya fueron descargados."
            next
          else
            puts "      > Los datos de la mesa '#{mesa_codigo}' ya fueron descargados."
            codigo_ultima_mesa = ''
            mesa_id = id_ultima_mesa.to_i
            agrupacion_politica_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM agrupaciones_politicas ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            agrupacion_por_provincia_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM agrupaciones_por_provincia ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            cargo_electivo_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM cargos_electivos ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            cargo_por_provincia_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM cargos_por_provincia ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            lista_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM listas ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            voto_nulo_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM votos_nulos ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            voto_en_blanco_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM votos_en_blanco ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            voto_recurrido_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM votos_recurridos ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            voto_escrutado_secuencia = base_sql.execute(
              <<-SQL
                SELECT id FROM votos_escrutados ORDER BY id DESC LIMIT 1;
              SQL
            ).first.first.to_i
            next
          end
        end

        puts "      > Descargando, procesando y almacenando datos de la mesa '#{texto_mesa.strip}'"
        doc_mesa = Nokogiri::HTML(open(uri_base + uri_mesa))

        # Verificar si los datos de la mesa fueron cargados o no
        if doc_mesa.at_css('div[id="cajatitulo"]').nil?
          datos_cargados = true

          # Forkeamos un proceso para descargar el PDF mientras procesamos los datos de la tabla
          archivo_pdf = doc_mesa.at_css('iframe[id="caja_pdf"]')['src']
          #fork do
            system("wget -q -x -N -nH --cut-dirs=4 -P pdfs #{(uri_base + uri_mesa).match(/(.*\/).*\Z/)[1] + archivo_pdf}")
          #end

          # Obtener el número de votos impugnados
          votos_impugnados = doc_mesa.css("div[class='pt2'] table").at_css('td').text.to_i
        else
          datos_cargados = false
          votos_impugnados = nil
        end

        # Insertar los datos de esta mesa en la base
        mesa_id += 1
        base_sql.execute <<-SQL
          INSERT INTO mesas
            (id, provincia_id, seccion_id, circuito_id, codigo, nombre, datos_cargados, votos_impugnados)
            VALUES (
              #{valor_sql(mesa_id)},
              #{valor_sql(provincia_id)},
              #{valor_sql(seccion_id)},
              #{valor_sql(circuito_id)},
              #{valor_sql(mesa_codigo)},
              #{valor_sql(mesa_nombre)},
              #{valor_sql(datos_cargados)},
              #{valor_sql(votos_impugnados)}
            );
        SQL

        # Pasar a la siguiente mesa si esta no tiene datos cargados
        next unless datos_cargados

        # Obtener los cargos electivos desde el encabezado de la tabla en el DIV 'pt1'
        cargos_electivos = doc_mesa
                            .css("div[class='pt1'] table thead tr th")
                            .select { |col| col['class'].match /azuldos/ }
                            .map(&:text)
        cargo_electivo_ids_por_columna = []

        cargos_electivos.each do |cargo_electivo|
          # Verificar si el cargo electivo ya fue creado
          filas = base_sql.execute <<-SQL
                    SELECT id
                      FROM cargos_electivos
                      WHERE nombre = #{valor_sql(cargo_electivo)};
                  SQL
          if filas.empty?
            # Si no ha sido creado, insertar el registro en la tabla con el próximo ID de la serie
            cargo_electivo_id = (cargo_electivo_secuencia += 1)
            base_sql.execute <<-SQL
              INSERT INTO cargos_electivos
                (id, nombre)
                VALUES (#{valor_sql(cargo_electivo_secuencia)}, #{valor_sql(cargo_electivo)});
            SQL
          elsif filas.size == 1
            # Si ya existe, obtener su ID
            cargo_electivo_id = filas.first.first.to_i
          else
            # Si existe más de uno en la tabla, marcar el error
            raise "Se produjo un error... ¿Cargo electivo duplicado: '#{cargo_electivo}'?"
          end
          cargo_electivo_ids_por_columna << cargo_electivo_id

          # Verificar si la asociación entre el cargo electivo y la provincia ya fue creado
          filas = base_sql.execute <<-SQL
                    SELECT id
                      FROM cargos_por_provincia
                      WHERE
                        cargo_electivo_id = #{valor_sql(cargo_electivo_id)}
                        AND provincia_id = #{valor_sql(provincia_id)};
                  SQL

          # Si no ha sido creada la asociación, insertar el registro en la tabla con el proximo ID de la serie
          next unless filas.empty?
          cargo_por_provincia_secuencia += 1
          base_sql.execute <<-SQL
            INSERT INTO cargos_por_provincia
              (id, cargo_electivo_id, provincia_id)
              VALUES (
                #{valor_sql(cargo_por_provincia_secuencia)},
                #{valor_sql(cargo_electivo_id)},
                #{valor_sql(provincia_id)}
              );
          SQL

        end # doc_mesa...each do |cargo_electivo|

        # Parsear la tabla para extraer votos nulos, en blanco y recurridos
        doc_mesa.css("div[class='pt1'] table tbody tr").each do |fila|
          selector = fila.at_css('th').text
          valores = fila.css('td').map{ |v| v.text.chomp.strip.to_i }

          # La cantidad de cargos electivos debe coincidir con la cantidad de valores por fila en esta tabla
          if cargo_electivo_ids_por_columna.size != valores.size
            raise 'La cantidad de valores de la tabla "pt1" no coincide con la cantidad de cargos electivos'
          end

          # Guardar los valores para los cargos electivos de acuerdo con la categoría
          case selector
          when 'Votos nulos'
            valores.each_with_index do |cantidad, i|
              voto_nulo_secuencia += 1
              base_sql.execute <<-SQL
                INSERT INTO votos_nulos
                  (id, mesa_id, cargo_electivo_id, cantidad)
                  VALUES (
                    #{valor_sql(voto_nulo_secuencia)},
                    #{valor_sql(mesa_id)},
                    #{valor_sql(cargo_electivo_ids_por_columna[i])},
                    #{valor_sql(valores[i])}
                  );
              SQL
            end
          when 'Votos en blanco'
            valores.each_with_index do |cantidad, i|
              voto_en_blanco_secuencia += 1
              base_sql.execute <<-SQL
                INSERT INTO votos_en_blanco
                  (id, mesa_id, cargo_electivo_id, cantidad)
                  VALUES (
                    #{valor_sql(voto_en_blanco_secuencia)},
                    #{valor_sql(mesa_id)},
                    #{valor_sql(cargo_electivo_ids_por_columna[i])},
                    #{valor_sql(valores[i])}
                  );
              SQL
            end
          when 'Votos recurridos'
            valores.each_with_index do |cantidad, i|
              voto_recurrido_secuencia += 1
              base_sql.execute <<-SQL
                INSERT INTO votos_recurridos
                  (id, mesa_id, cargo_electivo_id, cantidad)
                  VALUES (
                    #{valor_sql(voto_recurrido_secuencia)},
                    #{valor_sql(mesa_id)},
                    #{valor_sql(cargo_electivo_ids_por_columna[i])},
                    #{valor_sql(valores[i])}
                  );
              SQL
            end
          else
            raise "Categoría de tipo de votos no válida: '#{selector}'"
          end

        end # Para cada fila de la tabla 'pt1'

        # Parsear la tabla para extraer los votos de cada agrupación política y lista
        agrupacion_politica_id = nil
        agrupacion_por_provincia_id = nil
        lista_id = nil
        doc_mesa.css("table[id='TVOTOS'] tbody tr").each do |fila|
          next if fila.at_css('th').nil?
          encabezado = fila.at_css('th').text
          clases = fila.at_css('th')['class'].split(" ").reject(&:empty?).uniq
          valores = fila.css('td').map{ |v| v.text.chomp.strip.to_i }

          case
          when clases.member?('alaizquierda')
            # Es una agrupación política
            # Verificar si la agrupación política ya fue creada
            filas = base_sql.execute <<-SQL
                      SELECT id
                        FROM agrupaciones_politicas
                        WHERE nombre = #{valor_sql(encabezado)};
                    SQL
            if filas.empty?
              # Si no ha sido creada, insertar el registro en la tabla con el próximo ID de la serie
              agrupacion_politica_id = (agrupacion_politica_secuencia += 1)
              base_sql.execute <<-SQL
                INSERT INTO agrupaciones_politicas
                  (id, nombre)
                  VALUES (#{valor_sql(agrupacion_politica_secuencia)}, #{valor_sql(encabezado)});
              SQL
            elsif filas.size == 1
              # Si ya existe, obtener su ID
              agrupacion_politica_id = filas.first.first.to_i
            else
              # Si existe más de uno en la tabla, marcar el error
              raise "Se produjo un error... ¿Agrupación política duplicada: '#{encabezado}'?"
            end

            # Verificar si la relación entre la agrupación política y la provincia ya fue creada
            filas = base_sql.execute <<-SQL
                      SELECT id
                        FROM agrupaciones_por_provincia
                        WHERE
                          agrupacion_politica_id = #{valor_sql(agrupacion_politica_id)}
                          AND provincia_id = #{valor_sql(provincia_id)};
                    SQL
            if filas.empty?
              # Si no ha sido creada, insertar el registro en la tabla con el próximo ID de la serie
              agrupacion_por_provincia_id = (agrupacion_por_provincia_secuencia += 1)
              base_sql.execute <<-SQL
                INSERT INTO agrupaciones_por_provincia
                  (id, agrupacion_politica_id, provincia_id)
                  VALUES (
                    #{valor_sql(agrupacion_por_provincia_secuencia)},
                    #{valor_sql(agrupacion_politica_id)},
                    #{valor_sql(provincia_id)}
                  );
              SQL
            elsif filas.size == 1
              # Si ya existe, obtener su ID
              agrupacion_por_provincia_id = filas.first.first.to_i
            else
              # Si existe más de uno en la tabla, marcar el error
              raise "Se produjo un error... ¿Agrupación por provincia duplicada?"
            end
            next

          when clases.member?('aladerecha')
            # Es una lista
            # Verificar si la lista ya fue creada
            filas = base_sql.execute <<-SQL
                      SELECT id
                        FROM listas
                        WHERE
                          agrupacion_por_provincia_id = #{valor_sql(agrupacion_por_provincia_id)}
                          AND nombre = #{valor_sql(encabezado)};
                    SQL
            if filas.empty?
              # Si no ha sido creada, insertar el registro en la tabla con el próximo ID de la serie
              lista_id = (lista_secuencia += 1)
              base_sql.execute <<-SQL
                INSERT INTO listas
                  (id, agrupacion_por_provincia_id, nombre)
                  VALUES (
                    #{valor_sql(lista_secuencia)},
                    #{valor_sql(agrupacion_por_provincia_id)},
                    #{valor_sql(encabezado)});
              SQL
            elsif filas.size == 1
              # Si ya existe, obtener su ID
              lista_id = filas.first.first.to_i
            else
              # Si existe más de uno en la tabla, marcar el error
              raise "Se produjo un error... ¿Lista duplicada: '#{encabezado}'?"
            end

          else
            # Indicar un error si no tiene alguna de las clases esperadas
            raise "Se produjo un error... Se encontró una clase que no corresponde a una agrupación ni una lista."
          end

          # Si la cantidad de cargos electivos debe coincidir con la cantidad de valores por fila en esta tabla
          if cargo_electivo_ids_por_columna.size != valores.size
            raise 'La cantidad de valores de la tabla de votos escrutados no coincide con la cantidad de cargos electivos'
          end

          # Guardar los votos escrutados
          valores.each_with_index do |cantidad, i|
            voto_escrutado_secuencia += 1
            base_sql.execute <<-SQL
              INSERT INTO votos_escrutados
                (id, mesa_id, cargo_electivo_id, lista_id, cantidad)
                VALUES (
                  #{valor_sql(voto_escrutado_secuencia)},
                  #{valor_sql(mesa_id)},
                  #{valor_sql(cargo_electivo_ids_por_columna[i])},
                  #{valor_sql(lista_id)},
                  #{valor_sql(valores[i])}
                );
            SQL
          end

        end # Para cada fila de la tabla de votos escrutados

      end # Para cada mesa del circuito

      puts "    > Finalizó la descarga del circuito '#{circuito_nombre}'"
    end # Para cada circuito de la sección

    puts "  > Finalizó la descarga de datos de la sección '#{seccion_nombre}'"
  end # Para cada sección de la provincia

  puts "> Finalizó la descarga de datos de la provincia '#{provincia_nombre}'"
end # Para cada provincia
