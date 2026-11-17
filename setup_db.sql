DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dentacloud') THEN
    CREATE ROLE dentacloud WITH SUPERUSER CREATEDB LOGIN PASSWORD 'dentacloud';
  ELSE
    ALTER ROLE dentacloud WITH SUPERUSER CREATEDB LOGIN PASSWORD 'dentacloud';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dentacloud_app') THEN
    CREATE ROLE dentacloud_app WITH LOGIN PASSWORD 'dentacloud_app' NOSUPERUSER NOBYPASSRLS;
  ELSE
    ALTER ROLE dentacloud_app WITH LOGIN PASSWORD 'dentacloud_app' NOSUPERUSER NOBYPASSRLS;
  END IF;
END
$$;

SELECT 'CREATE DATABASE dentacloud OWNER dentacloud'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dentacloud')\gexec

GRANT CONNECT ON DATABASE dentacloud TO dentacloud_app;
GRANT ALL PRIVILEGES ON DATABASE dentacloud TO dentacloud;

