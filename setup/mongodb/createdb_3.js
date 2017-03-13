// Create a collection for disclosures in SanBan
db.createCollection("disclosures")

// Create a collection for tradedata in SanBan
db.createCollection("tradedata")

// Create index for companies 
db.companies.createIndex({code: 1}, {background: true, unique: true})

// Create index for tradedata
db.tradedata.createIndex({code: 1, date: 1}, {background: true, unique: true})

// Create index for disclosures
db.disclosures.createIndex({code: 1, disclosureCode: 1}, {background: true, unique: true})

// Insert the schema version
db.schema.remove({})
db.schema.insert({"schema_version": "3"})