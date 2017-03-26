// Set hasContent for all record that has 'content'
db.disclosures.update({content: {$exists: true}}, {$set: {hasContent: true}}, {multi: true})

// Create index for disclosures
db.disclosures.createIndex({hasContent: 1, publishTime: 1}, {background: true})

// Insert the schema version
db.schema.remove({})
db.schema.insert({"schema_version": "5"})