# Database Manager
Realiza um gerenciamento mais simples do banco de dados, sem a necessidade de executar dbExec ou dbPoll a cada vez. Ele carrega tudo em uma tabela e salva automaticamente após o encerramento do resource.

## Exemplos

**Insert:**
```lua
_CMR.Insert("Tabela", { campo = "valor" });
```
A função retornará o índice do novo valor.


**Select:**
```lua
_CMR.Select("Tabela", { campo = "valor" });
```
Ele vai retornar uma lista de valores que combinem com o `campo = "valor"`. Caso não encontre, retornará uma lista vazia.


**Select:**
```lua
_CMR.Select("Tabela", 1);
```
Ele vai retornar apenas o valor do índice, se for encontrado. Caso contrário, retornará false.


**Update:**
```lua
_CMR.Update("Tabela", 1, { campo = "Novo Valor" });
```
Ele atualiza o índice informado para o novo valor. Você precisa passar todos os campos.

**Select And Update:**
```lua
_CMR.SelectAndUpdate("Tabela", { campo = "valor" }, { campo = "Novo valor"});
```
Ele atualiza apenas um registros que combinem com o `campo = "valor"`. Aqui você só precisa passar o campo que deseja atualizar.

**Delete:**
```lua
_CMR.Delete("Tabela", 1);
```
Irá excluir o registro correspondente ao índice informado.

**Select and Delete:**
```lua
_CMR.SelectAndDelete("Tabela", { campo = "valor" });
```
Irá excluir apenas o primeiro registro encontrado.

**Get All Data:**
```lua
_CMR.GetAllData("Tabela");
```
Irá obter todos os registros na tabela informada.