## ADDED Requirements

### Requirement: Entrar con mail y contraseña (HU-01.1)
El panel MUST permitir entrar con mail y contraseña. Un error MUST mostrarse en
la misma pantalla, en palabras, sin el código de Firebase. Mail o contraseña
equivocados MUST dar **un solo** mensaje, sin decir cuál de los dos falló.

#### Scenario: Contraseña equivocada
- **WHEN** una persona escribe un mail habilitado y una contraseña que no es
- **THEN** ve "El mail o la contraseña no coinciden" y sigue en la pantalla de entrada

#### Scenario: Demasiados intentos
- **WHEN** Firebase responde `too-many-requests`
- **THEN** la pantalla dice que espere unos minutos, no que la contraseña está mal

#### Scenario: Entrar bien
- **WHEN** una cuenta con el claim `rol: admin` entra con su contraseña
- **THEN** llega a Catálogo

### Requirement: Entrar con Google (HU-01.1)
El panel MUST ofrecer entrar con una cuenta de Google. En la web MUST usar la
ventana emergente de Firebase. Si la persona cierra la ventana, MUST volver a
la pantalla de entrada **sin** mostrar un error.

#### Scenario: Ventana cerrada
- **WHEN** la persona abre la ventana de Google y la cierra sin elegir cuenta
- **THEN** la pantalla de entrada queda como estaba, sin aviso

#### Scenario: Google con el mismo mail que una cuenta habilitada
- **WHEN** una persona con acceso dado por el script entra con Google usando ese mail
- **THEN** cae en la misma cuenta y tiene el mismo permiso

### Requirement: El panel no crea cuentas
El panel MUST NOT ofrecer registrarse. Las cuentas nacen sólo por
`panel-cuentas`.

#### Scenario: Buscar un registro
- **WHEN** se recorre la pantalla de entrada
- **THEN** no hay ningún botón ni enlace para crear una cuenta

### Requirement: Crear o recuperar la contraseña por mail (HU-01.1)
"¿No tenés contraseña o te la olvidaste?" MUST pedir el mail y mandar el correo
de restablecimiento de Firebase, en español. El mensaje de confirmación MUST
ser el mismo exista o no la cuenta, para no revelar qué mails tienen acceso.

#### Scenario: Mail con acceso
- **WHEN** alguien pide el correo para un mail habilitado
- **THEN** ve "Si ese mail tiene acceso, te mandamos un correo" y el correo llega

#### Scenario: Mail sin cuenta
- **WHEN** alguien pide el correo para un mail que no existe
- **THEN** ve exactamente el mismo mensaje que con un mail habilitado

### Requirement: Saber que la cuenta no tiene permiso (HU-01.2)
Una sesión cuyo token no tiene `rol == 'admin'` MUST ver la pantalla de acceso
denegado, con el mail con el que entró, y MUST NOT ver ninguna sección.
"Ya me dieron acceso" MUST renovar el token a la fuerza y volver a evaluar el
permiso. "Entrar con otra cuenta" MUST cerrar la sesión.

#### Scenario: Cuenta sin claim
- **WHEN** entra una cuenta sin el claim
- **THEN** ve "Tu cuenta todavía no tiene acceso" con su mail, y no la barra de secciones

#### Scenario: Acceso recién dado
- **WHEN** a una cuenta que está en esa pantalla le dan el claim y la persona toca "Ya me dieron acceso"
- **THEN** el token se renueva y llega a Catálogo sin tener que volver a escribir la contraseña

#### Scenario: Intentar entrar por la URL
- **WHEN** una cuenta sin claim escribe `/catalogo` en la barra del navegador
- **THEN** vuelve a la pantalla de acceso denegado

### Requirement: Salir
Desde cualquier sección MUST poder cerrarse la sesión, y al salir MUST volver a
la pantalla de entrada.

#### Scenario: Salir desde Catálogo
- **WHEN** el operador toca "Salir"
- **THEN** ve la pantalla de entrada y `/catalogo` ya no se abre sin volver a entrar
