// Script to create and/or update the database in MongoDB
// It will load the createdb_X.js till the latest version to upgrade the schema
// to the latest version

conn = new Mongo();

// Connecting to the admin and authenticate
db = conn.getDB("admin");
db.auth("superuser", "devtools123");

// Get the trade database and the schema record
db = conn.getDB("trade");
schema = db.schema.findOne({})
version = schema.schema_version

if (version >= 1) {
  print("Current DB schema version is " + schema.schema_version)
} else {
  print("DB does not yet created.")
  version = 0
}

// Load createdb_X.js scripts that matching the current schema version
while (true) {
  version++
  try {
    load('createdb_' + version + '.js')

    print("Applied schema version: " + version)
  } catch (err) {
    break
  }
}
