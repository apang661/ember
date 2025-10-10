# Dockerfile for PostgreSQL with PostGIS
FROM postgis/postgis:16-3.4

COPY ./schema/init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
