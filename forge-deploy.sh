# Script de deploy del sitio en Forge (Sitio → Deployments → Deploy script). Se pega tal cual.
# El sitio NO es «zero downtime»: así instances/ (las sesiones vinculadas) y .env quedan donde están entre deploys.
cd $FORGE_SITE_PATH
git pull origin $FORGE_SITE_BRANCH

bash deploy/instalar.sh

# El daemon (npm run start:prod) lo vuelve a levantar solo con el código nuevo. Los números siguen vinculados.
pkill -f "$FORGE_SITE_PATH/dist/main" || true

for intento in 1 2 3 4 5 6 7 8 9 10 11 12; do
    sleep 5
    if curl -fsS -o /dev/null http://127.0.0.1:8080/; then
        echo "Evolution responde."
        exit 0
    fi
done

echo "Evolution no respondió en 60 s. Revisar el log del daemon (Servidor → Daemons → Log)."
exit 1
