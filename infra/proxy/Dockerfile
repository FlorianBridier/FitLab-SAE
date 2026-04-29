FROM nginx:alpine

# On supprime TOUTES les configs Nginx par défaut (dont celles qui peuvent ajouter une CSP)
RUN rm -rf /etc/nginx/conf.d/*

# DEV
#COPY nginx.dev.conf /etc/nginx/nginx.conf

# PROD
COPY nginx.prod.conf /etc/nginx/nginx.conf

