# Landing

Página de DonaLabs. El formulario anota el correo en una hoja de Google si
`LANDING_SHEETS_WEBHOOK_URL` apunta a un Apps Script publicado. No manda
ningún correo de vuelta.

## Hoja de cálculo

1. Crea una hoja en Google Sheets.
2. Abre **Extensiones → Apps Script** y sustituye el código por este:

```javascript
function doPost(e) {
  var body = JSON.parse(e.postData.contents)
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet()
  sheet.appendRow([body.email, body.date, body.origin])
  return ContentService.createTextOutput(
    JSON.stringify({ ok: true })
  ).setMimeType(ContentService.MimeType.JSON)
}
```

Cada envío añade una fila: correo, fecha en ISO y el origen `donalabs`.

3. **Implementar → Nueva implementación → Aplicación web.**
4. Ejecutar como **yo**. Quién tiene acceso: **Cualquier persona**.
5. Copia la URL que termina en `/exec` a `LANDING_SHEETS_WEBHOOK_URL` dentro
   de `.env.local`, junto a esta app. No la subas al repositorio: quien tenga
   esa URL puede añadir filas.
6. Reinicia el servidor. Si la variable falta o no es `https`, el formulario
   dice que el envío no está configurado.
