-- Base de dades i usuari
CREATE DATABASE IF NOT EXISTS equipaments CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'bchecker'@'%' IDENTIFIED BY 'bchecker121';
GRANT ALL PRIVILEGES ON equipaments.* TO 'bchecker'@'%';
FLUSH PRIVILEGES;

USE equipaments;

-- Taula (tot text: el CSV té molts camps buits i dates amb zona horària)
CREATE TABLE equipaments (
  register_id VARCHAR(40),
  name VARCHAR(255),
  institution_id VARCHAR(40),
  institution_name VARCHAR(255),
  created VARCHAR(40),
  modified VARCHAR(40),
  addresses_roadtype_id VARCHAR(40),
  addresses_roadtype_name VARCHAR(100),
  addresses_road_id VARCHAR(40),
  addresses_road_name VARCHAR(255),
  addresses_start_street_number VARCHAR(40),
  addresses_end_street_number VARCHAR(40),
  addresses_neighborhood_id VARCHAR(40),
  addresses_neighborhood_name VARCHAR(255),
  addresses_district_id VARCHAR(40),
  addresses_district_name VARCHAR(255),
  addresses_zip_code VARCHAR(20),
  addresses_town VARCHAR(100),
  addresses_main_address VARCHAR(20),
  addresses_type VARCHAR(100),
  values_id VARCHAR(40),
  values_attribute_id VARCHAR(40),
  values_category VARCHAR(255),
  values_attribute_name VARCHAR(255),
  values_value TEXT,
  values_outstanding VARCHAR(20),
  values_description TEXT,
  secondary_filters_id VARCHAR(40),
  secondary_filters_name VARCHAR(255),
  secondary_filters_fullpath TEXT,
  secondary_filters_tree TEXT,
  secondary_filters_asia_id VARCHAR(40),
  geo_epgs_25831_x VARCHAR(40),
  geo_epgs_25831_y VARCHAR(40),
  geo_epgs_4326_lat VARCHAR(40),
  geo_epgs_4326_lon VARCHAR(40),
  estimated_dates VARCHAR(255),
  start_date VARCHAR(40),
  end_date VARCHAR(40),
  timetable TEXT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Càrrega (el CSV prèviament convertit a UTF-8 i copiat a /var/lib/mysql-files/)
LOAD DATA INFILE '/var/lib/mysql-files/equipaments_utf8.csv'
INTO TABLE equipaments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
