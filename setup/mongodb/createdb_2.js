// Create a collection for listed companies in SanBan
db.createCollection("companies");

//insert the schema version
db.schema.insert({"schema_version": 2})