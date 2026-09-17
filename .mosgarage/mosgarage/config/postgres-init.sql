-- mosgarage database initialisation
-- Runs once on first postgres startup.

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable trigram indexes (fast workspace name search)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enable case-insensitive text
CREATE EXTENSION IF NOT EXISTS citext;

-- EF Core migrations will create all tables.
-- This file just ensures extensions are available.
