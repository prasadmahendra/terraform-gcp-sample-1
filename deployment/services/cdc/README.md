# Postgres CloudSQL Setup

Do the following as `maindbuser` user:

```
CREATE ROLE datastreamuser WITH LOGIN PASSWORD 'your_secure_password' REPLICATION;  

ALTER USER maindbuser WITH REPLICATION;

CREATE PUBLICATION dbz_publication FOR ALL TABLES;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastreamuser;  
GRANT USAGE ON SCHEMA public TO datastreamuser;  
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastreamuser;
   

```

### Troubleshooting queries

```
SELECT * FROM pg_replication_slots;  
SELECT * FROM pg_publication;  
SELECT * FROM pg_publication_tables;  
  
-- Check role permissions  
SELECT rolname, rolreplication, rolconnlimit  
FROM pg_roles  
WHERE rolname = 'datastreamuser';  
  
-- Check table privileges  
SELECT grantee, table_schema, table_name, privilege_type  
FROM information_schema.table_privileges  
WHERE grantee = 'datastreamuser';  
  
SELECT * FROM pg_replication_slots  
WHERE slot_name = 'data_stream_replication_slot';  
  
SELECT pubname, puballtables, pubowner::regrole  
FROM pg_publication  
WHERE pubname = 'dbz_publication';

SELECT pg_create_logical_replication_slot('data_stream_replication_slot', 'pgoutput');  
-- to drop replication_slot
SELECT pg_drop_replication_slot('data_stream_replication_slot');
-- terminate pid
SELECT pg_terminate_backend(1569770);
-- create 
CREATE PUBLICATION dbz_publication FOR ALL TABLES;
```