# Etapa 1: instala todas las dependencias necesarias para desarrollar
# y compilar la aplicación.
FROM node:19-alpine3.15 as dev-deps

# Define /app como la carpeta principal de trabajo dentro del contenedor.
WORKDIR /app

# Copiamos primero package.json para aprovechar la caché de Docker.
COPY package.json package.json

# Instala las dependencias respetando las versiones definidas
# en el archivo de bloqueo del proyecto.
RUN yarn install --frozen-lockfile


# Etapa 2: compila la aplicación.
FROM node:19-alpine3.15 as builder

WORKDIR /app

# Reutiliza las dependencias instaladas en la etapa anterior,
# evitando instalarlas nuevamente.
COPY --from=dev-deps /app/node_modules ./node_modules

# Copia el código fuente del proyecto.
COPY . .

# Aquí podrían ejecutarse las pruebas antes de compilar.
# RUN yarn test

# Compila la aplicación y genera los archivos que se utilizarán en producción.
RUN yarn build


# Etapa 3: instala únicamente las dependencias necesarias
# para ejecutar la aplicación en producción.
FROM node:19-alpine3.15 as prod-deps

WORKDIR /app

COPY package.json package.json

# --prod evita instalar dependencias utilizadas solamente durante desarrollo.
RUN yarn install --prod --frozen-lockfile


# Etapa 4: crea la imagen final que se ejecutará en producción.
FROM node:19-alpine3.15 as prod

# Indica que la aplicación utiliza el puerto 3000.
EXPOSE 3000

WORKDIR /app

# Variable disponible dentro del contenedor para identificar
# la versión de la aplicación.
ENV APP_VERSION=${APP_VERSION}

# Copia solamente las dependencias necesarias para producción.
COPY --from=prod-deps /app/node_modules ./node_modules

# Copia únicamente la aplicación ya compilada.
COPY --from=builder /app/dist ./dist

# Comando que se ejecutará cuando inicie el contenedor.
CMD ["node", "dist/main.js"]
