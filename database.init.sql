
CREATE TABLE IF NOT EXISTS virtual_domains ( 
    "name" VARCHAR(128) NOT NULL PRIMARY KEY 
);

GRANT SELECT ON virtual_domains to postfix;

CREATE TABLE IF NOT EXISTS virtual_users (
    "domain" VARCHAR(128) REFERENCES virtual_domains,
    "password" VARCHAR(128) NOT NULL,
    "email" VARCHAR(128) NOT NULL PRIMARY KEY
);GRANT SELECT ON virtual_users to postfix;

CREATE TABLE IF NOT EXISTS virtual_aliases (
    "domain" VARCHAR(128) REFERENCES virtual_domains,
    "source" VARCHAR(128) NOT NULL,
    "destination" VARCHAR(128) NOT NULL
);

GRANT SELECT ON virtual_aliases to postfix;








