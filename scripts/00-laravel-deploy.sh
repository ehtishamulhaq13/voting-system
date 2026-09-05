#!/usr/bin/env bash

echo "Running composer"
composer install --no-dev --working-dir=/var/www/html

mkdir -p /var/www/html/database
touch /var/www/html/database/database.sqlite
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
chmod -R 775 /var/www/html/storage

echo "Caching config..."
php artisan config:cache

echo "Caching routes..."
php artisan route:cache

echo "Running migrations..."
php artisan migrate --force
