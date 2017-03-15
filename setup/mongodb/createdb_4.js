// Create index for disclosures
db.disclosures.createIndex({publishTime: 1}, {background: true, unique: true})

// Insert the schema version
db.schema.remove({})
db.schema.insert({"schema_version": "4"})