--
-- Create the database roles that xTuple software needs for bootstrapping
--

CREATE ROLE xtrole WITH NOLOGIN;

CREATE ROLE admin WITH PASSWORD 'admin'
                       SUPERUSER
                       CREATEDB
                       CREATEROLE
                       LOGIN
                       IN ROLE xtrole;

