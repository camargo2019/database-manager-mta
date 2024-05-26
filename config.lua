/* Gabriel Camargo <git@camargo2019> */

Config = {
    type = "sqlite",
    sqlite = "database.db",
    mysql = {
        host = "localhost",
        username = "user",
        password = "pass",
        database = "database",
    },
    autoSave = { time = 10, format = 1000 }
}