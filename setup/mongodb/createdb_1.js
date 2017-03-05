// Create a collection for top users
db.createCollection("topUsers")

// Create a collection for account
db.createCollection("account")

// Create a schema collection and insert the first schema version
db.createCollection("schema")
db.schema.insert({"schema_version": "1"})