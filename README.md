Este archivo Dockerfile sirve para preparar una aplicación de Node.js en varias etapas. La idea es separar la instalación de dependencias, la compilación y la versión final que realmente se ejecutará.

Al hacerlo de esta manera, la imagen final contiene solamente lo necesario para funcionar y evita incluir archivos o dependencias que solo se utilizaron durante el desarrollo.

## 1. Instalación de dependencias de desarrollo

```dockerfile
FROM node:19-alpine3.15 as dev-deps
WORKDIR /app
COPY package.json package.json
RUN yarn install --frozen-lockfile
```

Primero se crea una etapa llamada `dev-deps`.

```dockerfile
FROM node:19-alpine3.15 as dev-deps
```

Aquí se indica que se utilizará Node.js 19 sobre Alpine Linux.

Alpine es una distribución de Linux pequeña, por lo que suele utilizarse para crear imágenes de Docker más ligeras.

El nombre `dev-deps` nos permite utilizar después los archivos generados en esta etapa.

```dockerfile
WORKDIR /app
```

Establece `/app` como la carpeta principal de trabajo dentro del contenedor.

A partir de este momento, los siguientes comandos se ejecutarán dentro de esa carpeta.

```dockerfile
COPY package.json package.json
RUN yarn install --frozen-lockfile
```

Primero se copia el archivo `package.json`, que contiene las dependencias del proyecto.

Después, Yarn instala todas las dependencias necesarias para desarrollar y compilar la aplicación.

La opción `--frozen-lockfile` hace que Yarn respete exactamente las versiones definidas en el archivo de bloqueo del proyecto, evitando que se instalen versiones diferentes accidentalmente.

## 2. Compilación de la aplicación

```dockerfile
FROM node:19-alpine3.15 as builder
WORKDIR /app
COPY --from=dev-deps /app/node_modules ./node_modules
COPY . .
RUN yarn build
```

La segunda etapa se llama `builder` y se encarga de compilar la aplicación.

```dockerfile
COPY --from=dev-deps /app/node_modules ./node_modules
```

En lugar de volver a instalar todas las dependencias, se copian desde la etapa anterior.

Después:

```dockerfile
COPY . .
```

Se copia el código completo del proyecto dentro del contenedor.

Finalmente:

```dockerfile
RUN yarn build
```

Se ejecuta el proceso de compilación de la aplicación.

Normalmente este comando genera una carpeta como:

```text
dist/
```

Esa carpeta contiene el código preparado para ejecutarse en producción.

También existe esta línea:

```dockerfile
# RUN yarn test
```

Como empieza con `#`, está comentada y Docker no la ejecuta.

Si se quitara el comentario, los tests del proyecto se ejecutarían antes de compilar la aplicación.

## 3. Dependencias de producción

```dockerfile
FROM node:19-alpine3.15 as prod-deps
WORKDIR /app
COPY package.json package.json
RUN yarn install --prod --frozen-lockfile
```

Esta etapa se llama `prod-deps`.

Su objetivo es instalar solamente las dependencias necesarias para ejecutar la aplicación en producción.

La diferencia importante está aquí:

```dockerfile
yarn install --prod
```

La opción `--prod` evita instalar dependencias utilizadas únicamente durante el desarrollo.

Por ejemplo, herramientas de testing, compilación o desarrollo pueden ser necesarias para construir la aplicación, pero no para ejecutarla.

Esto ayuda a reducir el tamaño de la imagen final.

## 4. Imagen final de producción

```dockerfile
FROM node:19-alpine3.15 as prod
EXPOSE 3000
WORKDIR /app
ENV APP_VERSION=${APP_VERSION}
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

CMD [ "node","dist/main.js"]
```

Esta es la etapa final y es la imagen que realmente se utilizará cuando se ejecute el contenedor.

```dockerfile
EXPOSE 3000
```

Indica que la aplicación utiliza el puerto `3000`.

Esto funciona principalmente como documentación dentro de la imagen. Para poder acceder realmente al puerto desde fuera del contenedor todavía es necesario publicarlo al ejecutar Docker.

Por ejemplo:

```bash
docker run -p 3000:3000 nombre-imagen
```

Después se vuelve a establecer `/app` como carpeta de trabajo.

```dockerfile
ENV APP_VERSION=${APP_VERSION}
```

Esta línea define una variable de entorno llamada `APP_VERSION`.

Puede utilizarse para guardar o consultar la versión de la aplicación desde dentro del contenedor.

Después se copian solamente los archivos que realmente necesita la aplicación:

```dockerfile
COPY --from=prod-deps /app/node_modules ./node_modules
```

Copia las dependencias necesarias para producción.

```dockerfile
COPY --from=builder /app/dist ./dist
```

Copia la aplicación ya compilada desde la etapa `builder`.

Finalmente:

```dockerfile
CMD [ "node","dist/main.js"]
```

Este es el comando que se ejecuta cuando inicia el contenedor.

Es equivalente a ejecutar:

```bash
node dist/main.js
```

Por lo tanto, Node.js inicia el archivo principal de la aplicación que se encuentra dentro de la carpeta `dist`.

## Flujo completo

Puedes imaginar todo el Dockerfile de esta manera:

```text
Código del proyecto
        |
        v
Instalar dependencias de desarrollo
        |
        v
Compilar la aplicación
        |
        v
Instalar únicamente dependencias de producción
        |
        v
Crear una imagen final
        |
        v
Ejecutar dist/main.js
```

La principal ventaja de hacerlo en varias etapas es que la imagen final no necesita guardar todas las herramientas utilizadas durante la compilación.

Solo termina incluyendo:

```text
Node.js
Dependencias de producción
Aplicación compilada
```

Esto permite tener una imagen más pequeña, más limpia y preparada específicamente para ejecutar la aplicación.
