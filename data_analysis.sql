CREATE DATABASE netflix_project;
USE netflix_project;
CREATE TABLE titles (
    id VARCHAR(20),
    title TEXT,
    type VARCHAR(20),
    description TEXT,
    release_year INT,
    age_certification VARCHAR(10),
    runtime INT,
    genres TEXT,
    production_countries TEXT,
    seasons INT,
    imdb_id VARCHAR(20),
    imdb_score FLOAT,
    imdb_votes INT,
    tmdb_popularity FLOAT,
    tmdb_score FLOAT
);



LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/titles.csv'
INTO TABLE titles
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


CREATE TABLE credits (
    person_id INT,
    id VARCHAR(20),
    name TEXT,
    character_name TEXT,
    role TEXT
);


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/titles.csv'
IGNORE
INTO TABLE titles
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/credits.csv'
IGNORE
INTO TABLE credits
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


SELECT COUNT(*) FROM titles;
SELECT COUNT(*) FROM credits;


SELECT
    COUNT(*) AS total_rows,
    SUM(imdb_score IS NULL) AS missing_imdb_score,
    SUM(runtime IS NULL) AS missing_runtime,
    SUM(genres IS NULL) AS missing_genres,
    SUM(production_countries IS NULL) AS missing_countries
FROM titles;

CREATE TABLE titles_clean AS
SELECT
    id,
    title,
    type,
    release_year,
    imdb_score,
    runtime,
    genres,
    production_countries,
    imdb_votes,
    tmdb_popularity,
    tmdb_score
FROM titles;


ALTER TABLE titles_clean
ADD COLUMN runtime_hours FLOAT;

UPDATE titles_clean
SET runtime_hours = runtime / 60;


ALTER TABLE titles_clean
ADD COLUMN decade INT;

UPDATE titles_clean
SET decade = FLOOR(release_year / 10) * 10;


ALTER TABLE titles_clean
ADD COLUMN content_age INT;

UPDATE titles_clean
SET content_age = YEAR(CURDATE()) - release_year;


/*1) Netflix content growth over time

Business question: Is Netflix adding more content every decade?*/

SELECT decade, COUNT(*) AS total_titles
FROM titles_clean
GROUP BY decade
ORDER BY decade;

/*2) Movies vs TV Shows distribution

Business question: What type of content dominates Netflix?*/

SELECT type, COUNT(*) AS total_titles,
ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM titles_clean), 2) AS percentage
FROM titles_clean
GROUP BY type;

/*3) Average rating: Movies vs Shows

Business question: Are TV shows better rated than movies?*/

SELECT type, ROUND(AVG(imdb_score),2) AS avg_rating
FROM titles_clean
GROUP BY type;

/*4) Top 10 highest rated content

Business question: What are the best shows/movies on Netflix?*/
SELECT title, type, imdb_score, release_year
FROM titles_clean
ORDER BY imdb_score DESC
LIMIT 10;

/*5) Countries producing most Netflix content

We extract the first country (quick analysis version):*/
SELECT production_countries, COUNT(*) AS total_titles
FROM titles_clean
GROUP BY production_countries
ORDER BY total_titles DESC
LIMIT 10;


ALTER TABLE titles_clean
ADD COLUMN country_clean VARCHAR(50);


UPDATE titles_clean
SET country_clean =
REPLACE(REPLACE(REPLACE(production_countries,'[',''),']',''),'"','');


UPDATE titles_clean
SET country_clean = 'Unknown'
WHERE country_clean = '';


SELECT country_clean, COUNT(*) AS total_titles
FROM titles_clean
GROUP BY country_clean
ORDER BY total_titles DESC
LIMIT 10;


/*6) Top genres on Netflix*/
SELECT genres, COUNT(*) AS total_titles
FROM titles_clean
GROUP BY genres
ORDER BY total_titles DESC
LIMIT 10;

/*7) Average runtime: Movies vs Shows

Business question → Are movies longer than shows?*/
SELECT type, ROUND(AVG(runtime),1) AS avg_runtime_minutes
FROM titles_clean
GROUP BY type;

/*8) Content production trend after 2010*/
SELECT release_year, COUNT(*) AS total_titles
FROM titles_clean
WHERE release_year >= 2010
GROUP BY release_year
ORDER BY release_year;

/*9) Most popular content by votes*/
SELECT title, imdb_votes, imdb_score
FROM titles_clean
ORDER BY imdb_votes DESC
LIMIT 10;


SELECT DISTINCT role FROM credits;
SELECT name, COUNT(*) AS appearances
FROM credits
WHERE TRIM(role) = 'ACTOR'
GROUP BY name
ORDER BY appearances DESC
LIMIT 10;

UPDATE credits
SET role = TRIM(REPLACE(role, '\r', ''));

SELECT name, COUNT(*) AS appearances
FROM credits
WHERE role = 'ACTOR'
GROUP BY name
ORDER BY appearances DESC
LIMIT 10;




CREATE VIEW vw_content_overview AS
SELECT
    type,
    COUNT(*) AS total_titles,
    ROUND(AVG(imdb_score),2) AS avg_rating,
    ROUND(AVG(runtime),1) AS avg_runtime
FROM titles_clean
GROUP BY type;
CREATE VIEW vw_yearly_growth AS
SELECT
    release_year,
    type,
    COUNT(*) AS total_titles
FROM titles_clean
GROUP BY release_year, type;


CREATE VIEW vw_country_analysis AS
SELECT
    country_clean,
    COUNT(*) AS total_titles,
    ROUND(AVG(imdb_score),2) AS avg_rating
FROM titles_clean
GROUP BY country_clean;


CREATE VIEW vw_actor_appearances AS
SELECT
    c.name AS actor,
    COUNT(*) AS appearances
FROM credits c
JOIN titles_clean t ON c.id = t.id
WHERE c.role_clean = 'ACTOR'
GROUP BY c.name;


DROP VIEW IF EXISTS vw_actor_appearances;

CREATE VIEW vw_actor_appearances AS
SELECT
    credits.name AS actor,
    COUNT(*) AS appearances
FROM credits
JOIN titles_clean ON credits.id = titles_clean.id
WHERE credits.role_clean = 'ACTOR'
GROUP BY credits.name;


ALTER TABLE credits ADD COLUMN role_clean VARCHAR(20);
UPDATE credits
SET role_clean = UPPER(TRIM(
  REPLACE(REPLACE(REPLACE(role, '\r', ''), '\n', ''), '\t', '')
));


SELECT DISTINCT role_clean FROM credits;

DROP VIEW IF EXISTS vw_actor_appearances;

CREATE VIEW vw_actor_appearances AS
SELECT
    credits.name AS actor,
    COUNT(*) AS appearances
FROM credits
JOIN titles_clean ON credits.id = titles_clean.id
WHERE credits.role_clean = 'ACTOR'
GROUP BY credits.name;


SHOW FULL TABLES
WHERE TABLE_TYPE = 'VIEW';
SELECT * FROM vw_actor_appearances;




DROP VIEW IF EXISTS vw_actor_appearances;
CREATE VIEW vw_actor_appearances AS
SELECT
    credits.name AS actor,
    COUNT(*) AS appearances
FROM credits
JOIN titles_clean 
ON credits.id = titles_clean.id
WHERE credits.role_clean = 'ACTOR'
GROUP BY credits.name;
SELECT * FROM vw_actor_appearances;



DROP VIEW IF EXISTS vw_country_analysis;

CREATE VIEW vw_country_analysis AS
SELECT
    TRIM(BOTH '"' FROM
        SUBSTRING_INDEX(
            SUBSTRING_INDEX(titles_clean.production_countries, ',', 1),
        '[', -1)
    ) AS country_clean,
    COUNT(*) AS total_titles,
    ROUND(AVG(titles_clean.imdb_score),2) AS avg_rating
FROM titles_clean
GROUP BY 1;


SELECT * FROM vw_country_analysis LIMIT 20;


DROP VIEW IF EXISTS vw_rating_trend;

CREATE VIEW vw_rating_trend AS
SELECT 
    release_year,
    ROUND(AVG(imdb_score),2) AS avg_rating,
    COUNT(*) AS total_titles
FROM titles_clean
GROUP BY release_year;
