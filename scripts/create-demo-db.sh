#!/usr/bin/env bash
set -e

DB_PATH="static/demo.db"

rm -f "$DB_PATH"

sqlite3 "$DB_PATH" <<EOF
CREATE TABLE users (
  id INTEGER,
  name TEXT,
  role TEXT,
  content TEXT
);

INSERT INTO users VALUES
  (1, 'Sam', 'Admin', 'Sam is the site administrator and manages user access.'),
  (2, 'Oggy', 'User', 'Oggy is a regular user who browses and posts content.'),
  (3, 'Jack', 'Editor', 'Jack edits articles and reviews submissions.'),
  (4, 'Olivia', 'Moderator', 'Olivia moderates comments and keeps the community safe.'),
  (5, 'Evee', 'Guest', 'Evee is a guest with read-only access to the site.');
EOF

echo "Demo database created at $DB_PATH (users + content). Run scripts/add-vec0-to-demo-db.mjs to add vector search (requires sqlite-vec native extension)."
