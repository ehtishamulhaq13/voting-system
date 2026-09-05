#!/usr/bin/env bash

echo "Running composer"
composer install --no-dev --working-dir=/var/www/html

mkdir -p /var/www/html/database
touch /var/www/html/database/database.sqlite

echo "Caching config..."
php artisan config:cache

echo "Caching routes..."
php artisan route:cache

echo "Running migrations..."
php artisan migrate --force
