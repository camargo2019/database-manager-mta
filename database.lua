/* Gabriel Camargo <git@camargo2019> */

local _CMR = {
    Data = {},
    Type = Config.type, -- Tipo de banco de dados sqlite/mysql
    AutoDetect = false, -- O AutoDetect ele faz a leitura de todas as tabelas que tenha no mysql/sqlite se não quiser especifique.
    TablesName = {
        -- Tabelas que você quer especificadas.
        { name = "exemplo" }
    },
    QuerysType = {
        ["sqlite"] = {
            ShowTables = "SELECT name FROM sqlite_master WHERE type='table'",
            ShowColumns = "PRAGMA table_info(?)"
        },
        ["mysql"] = {
            ShowTables = "SELECT table_name as name FROM information_schema.tables WHERE table_type = 'BASE TABLE'",
            ShowColumns = "SELECT COLUMN_NAME AS name, COLUMN_TYPE AS type FROM information_schema.columns WHERE table_name = ?"
        }
    }
}

if _CMR.Type == "sqlite" then
    _CMR.Connection = dbConnect(_CMR.Type, Config.sqlite);
else
    _CMR.Connection = dbConnect( "mysql", "dbname="..Config.mysql.database..";host="..Config.mysql.host..";charset=utf8", Config.mysql.username, Config.mysql.password, "share=1");
end


_CMR.CreateThread = function(func)
    return coroutine.resume(coroutine.create(func))
end

_CMR.CheckTable = function(tableName)
    if not _CMR.Data[tableName] then
        _CMR.Data[tableName] ={
            Values = {},
            Columns = {},
            NextId = 1
        };
    end
end

_CMR.LoadTables = function()
    local AllTables = _CMR.TablesName;

    if _CMR.AutoDetect then
        AllTables = dbPoll(dbQuery(_CMR.Connection, _CMR.QuerysType[_CMR.Type].ShowTables), -1);
    end

    for _, InfoTable in pairs(AllTables) do
        local Columns = dbPoll(dbQuery(_CMR.Connection, _CMR.QuerysType[_CMR.Type].ShowColumns, InfoTable.name), -1);
        _CMR.CheckTable(InfoTable.name);

        _CMR.Data[InfoTable.name].Columns = {}

        for _, v in pairs(Columns) do
            table.insert(_CMR.Data[InfoTable.name].Columns, { name =  v.name })
        end
    end
end

_CMR.LoadData = function(event)
    _CMR.CreateThread(function()
        _CMR.LoadTables();

        for tableName, _ in pairs(_CMR.Data) do
            local ShowRegister = dbPoll(dbQuery(_CMR.Connection, string.format("SELECT count(*) as registers FROM %s", tableName)), -1);

            if ShowRegister and ShowRegister[1] then
                local TotalPages = math.ceil(ShowRegister[1].registers / 1000);

                for Page = 1, TotalPages do
                    local Offset = (Page - 1) * 1000;
                    local Values = dbPoll(dbQuery(_CMR.Connection, string.format("SELECT * FROM %s LIMIT 1000 OFFSET %d", tableName, Offset)), -1);

                    for i, v in pairs(Values) do
                        v.id = i + Offset;
                        _CMR.Data[tableName].Values[v.id] = v;
                    end

                    if TotalPages > 100 then
                        _CMR.Wait(100);
                    end
                end

                _CMR.Data[tableName].NextId = table.getn(_CMR.Data[tableName].Values) + 1;
            end

        end

        if event then
            event();
        end
    end);
end

_CMR.SaveData = function(event)
    _CMR.CreateThread(function()
        for tableName, tableValues in pairs(_CMR.Data) do
            dbExec(_CMR.Connection, string.format("DELETE FROM %s", tableName))

            local columnNames = {}
            for _, c in pairs(tableValues.Columns) do
                table.insert(columnNames, c.name)
            end

            local batchSize = 500
            local totalValues = #tableValues.Values

            for i = 1, totalValues, batchSize do
                local valuesList = {}
                local batch = {}

                for key = i, math.min(i + batchSize - 1, totalValues) do
                    local valueSet = {}

                    if tableValues.Values[key] then
                        for _, c in pairs(tableValues.Columns) do
                            table.insert(valueSet, "?")
                            table.insert(batch, tableValues.Values[key][c.name])
                        end

                        table.insert(valuesList, "("..table.concat(valueSet, ", ")..")")
                    end
                end

                dbExec(_CMR.Connection, string.format(
                    "INSERT INTO %s(%s) VALUES %s;",
                    tableName,
                    table.concat(columnNames, ", "),
                    table.concat(valuesList, ", ")
                ), unpack(batch))
            end
        end

        if event then
            event()
        end
    end)
end

_CMR.GetColumns = function(tableName)
    _CMR.CheckTable(tableName);

    return _CMR.Data[tableName].Columns;
end

_CMR.GetAllData = function(tableName)
    return _CMR.Data[tableName].Values;
end

_CMR.Insert = function(tableName, data)
    _CMR.CheckTable(tableName);

    data.id = _CMR.Data[tableName].NextId;
    _CMR.Data[tableName].Values[data.id] = data;
    _CMR.Data[tableName].NextId = _CMR.Data[tableName].NextId + 1;

    return data.id;
end

_CMR.Update = function(tableName, index, data)
    _CMR.CheckTable(tableName);

    if not _CMR.Data[tableName].Values[index] then
        return false;
    end

    _CMR.Data[tableName].Values[index] = data;

    return true;
end

_CMR.Select = function(tableName, criteria)
    _CMR.CheckTable(tableName);

    if type(criteria) == "table" then
        _Results = {}

        for _, v in pairs(_CMR.Data[tableName].Values) do
            if criteria.id and criteria.id == v.id then
                table.insert(_Results, v);
                break;
            end

            local KeysCriteria = 0
            local CountCriteria = 0

            for key, c in pairs(criteria) do
                if v[key] == c then
                    KeysCriteria = KeysCriteria + 1;
                end
                CountCriteria = CountCriteria + 1;
            end

            if KeysCriteria == CountCriteria then
                table.insert(_Results, v);
            end
        end

        return _Results;
    end

    if type(criteria) == "number" then
        return _CMR.Data[tableName].Values[criteria];
    end

    return false
end

_CMR.Delete = function(tableName, index)
    _CMR.CheckTable(tableName);

    _CMR.Data[tableName].Values[index] = nil;
    return true
end

_CMR.SelectAndUpdate = function(tableName, search, insert)
    local Data = _CMR.Select(tableName, search);

    if not Data or not Data[1] then
        return false;
    end

    local ValueInsert = Data[1];

    for key, value in pairs(insert) do
        ValueInsert[key] = value;
    end

    return _CMR.Update(tableName, ValueInsert.id, ValueInsert);
end

_CMR.SelectAndDelete = function(tableName, search)
    local Data = _CMR.Select(tableName, search);

    if not Data or not Data[1] then
        return false;
    end

    return _CMR.Delete(tableName, Data[1].id);
end

_CMR.Wait = function(milliseconds)
    local event = coroutine.running()

    local resume = function()
        coroutine.resume(event)
    end

    setTimer(resume, milliseconds, 1)
    coroutine.yield()
end

addEventHandler("onResourceStart", getResourceRootElement(), function()
    _CMR.LoadData(function()
        if _CMR.Timer then
            killTimer(_CMR.Timer)
        end

        _CMR.Timer = setTimer(function()
            _CMR.SaveData(function()
                outputDebugString('Database Manager | Backup do banco de dados realizado com sucesso!', 4, 93, 14, 171);
            end)
        end, Config.autoSave.time * Config.autoSave.format, 0)

        outputDebugString('Database Manager | Banco de dados carregado com sucesso!', 4, 93, 14, 171);
    end)
end)

addEventHandler("onResourceStop", getResourceRootElement(), function()
    _CMR.SaveData(function()
        outputDebugString('Database Manager | Banco de dados salvo com sucesso!', 4, 93, 14, 171);
    end)
end)