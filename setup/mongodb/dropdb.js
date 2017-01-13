// Script to drop the database and users in MongoDB

conn = new Mongo();

db = conn.getDB("admin");
db.auth("superuser", "devtools123");
db = conn.getDB("trade");
db.dropUser("trade")
db.dropDatabase()