CREATE SCHEMA IF NOT EXISTS arsenal_stats;
CREATE TABLE IF NOT EXISTS arsenal_stats.players (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(30) NOT NULL,
    shirtNumber INT,
    age INT,
    dateOfBirth DATE,
    cnation VARCHAR(30) NOT NULL,
    nation VARCHAR(30) NOT NULL,
    position VARCHAR(30) NOT NULL,
    height_cm INT,
    rating REAL,
    injury BOOLEAN,
    goals INT,
    penalties INT,
    assists INT,
    rcards INT,
    ycards INT,
    transferValue INT
);
CREATE TABLE IF NOT EXISTS arsenal_stats.coach (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(30) NOT NULL,
    age INT,
    dateOfBirth DATE,
    cnation VARCHAR(30) NOT NULL,
    nation VARCHAR(30) NOT NULL,
    height_cm INT,
    updated_utc TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);