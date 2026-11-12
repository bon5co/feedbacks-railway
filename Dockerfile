# Feedbacks for Railway.
#
# Feedbacks refuses to start in production without private S3 storage on an HTTPS endpoint, needs a unique
# ORGANIZATION_ID, and creates its first owner only through a CLI (`dist/cli/bootstrap.js`), so a stock deploy cannot
# boot from an empty form. This wrapper derives DATABASE_URL, APP_ORIGIN, S3_ENDPOINT and a stable ORGANIZATION_ID
# from the template variables, creates the bucket, creates the owner from ADMIN_EMAIL and ADMIN_PASSWORD, and then
# starts the unmodified upstream server.
FROM softinator/feedbacks:0.3.3@sha256:730d6b05e44bedb97b3e39bd2bf9d2e0e2fc0017fa6be6552e5664ae6ced5bf0

USER root
COPY --chmod=0755 railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY --chmod=0644 railway-init.mjs /app/railway-init.mjs
USER node

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["node", "dist/server/index.js"]
