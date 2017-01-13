// Script to create the database, users and collections in MongoDB

conn = new Mongo();

db = conn.getDB("admin");
db.auth("superuser", "devtools123");

db = conn.getDB("trade");
schema = db.schema.findOne({})

if (schema.schema_version == 1) {
  print("DB already created.")
  quit(0)
}

db.createUser({
  user: "trade", pwd: "ca$hc0w",
  roles: [{role: "readWrite", db: "trade"}]
})
// Create a collection for top users
db.createCollection("topUsers");

// Create a collection for account
db.createCollection("account")

// Create a schema collection and insert the first schema version
db.createCollection("schema")
db.schema.insert({"schema_version": "1"})