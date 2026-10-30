#!/usr/bin/env bash
# Deja Evolution listo para arrancar: dependencias, base MySQL y compilación. Sirve en Forge y en Git Bash (Herd).
# Después: npm run start:prod
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
    echo "Evolution necesita Node 20 o más (hay $(node -v)). En Forge: Servidor → Node → instalar la 22."
    exit 1
fi

if [ ! -f .env ]; then
    echo "Falta .env: copiá .env.example y completalo (clave y base)."
    exit 1
fi

# HUSKY=0: el paquete trae hooks de git (commitlint) que no son nuestros.
HUSKY=0 npm ci --no-audit --no-fund --loglevel=error

# Lo mismo que `npm run db:generate` y `db:deploy`, sin pasar por cmd.exe (en Windows rompen).
npx prisma generate --schema ./prisma/mysql-schema.prisma
rm -rf prisma/migrations
cp -r prisma/mysql-migrations prisma/migrations
npx prisma migrate deploy --schema ./prisma/mysql-schema.prisma

# `npm run build` corre antes `tsc --noEmit`, que sólo chequea tipos y tarda minutos: se compila directo.
npx tsup

echo "Listo. Se arranca con: npm run start:prod"
