## ADDED Requirements

### Requirement: Dar acceso por mail (HU-01.3)
`node scripts/acceso/acceso.mjs dar <mail>` MUST dejar la cuenta de ese mail
con el claim `rol: admin`, conservando los otros claims que tuviera. Si la
cuenta no existe, MUST crearla **sin contraseña**. MUST imprimir qué hizo y
cómo entra la persona.

#### Scenario: Mail nuevo
- **WHEN** se da acceso a un mail que no tiene cuenta
- **THEN** la cuenta se crea sin contraseña, con `rol: admin`, y el script dice que entre con Google o pida el correo de contraseña

#### Scenario: Cuenta existente verificada
- **WHEN** se da acceso a una cuenta con el mail verificado
- **THEN** la cuenta queda con `rol: admin` y conserva sus otros claims

### Requirement: No habilitar una cuenta que otro pudo registrar
El script MUST negarse (salida distinta de 0, sin tocar la cuenta) a dar acceso
a una cuenta que tenga contraseña y el mail **sin verificar**: cualquiera puede
registrar un mail ajeno con la API key pública, y habilitarla le daría el panel
a quien la registró.

#### Scenario: Cuenta registrada por un tercero
- **WHEN** se da acceso a una cuenta con contraseña y `emailVerified: false`
- **THEN** el script sale con error, explica por qué, y la cuenta sigue sin claim

### Requirement: Quitar acceso
`quitar <mail>` MUST sacar el claim `rol` y revocar las sesiones de la cuenta.
MUST decir que un token ya emitido sigue valiendo hasta una hora.

#### Scenario: Quitar a alguien con acceso
- **WHEN** se quita el acceso a una cuenta habilitada
- **THEN** la cuenta queda sin `rol` y sus refresh tokens revocados

### Requirement: Listar quién tiene acceso
`listar` MUST imprimir el mail de cada cuenta con `rol: admin`, recorriendo
todas las páginas de usuarios.

#### Scenario: Dos cuentas habilitadas y una sin permiso
- **WHEN** hay dos cuentas con el claim y una sin él
- **THEN** la lista tiene las dos y no la tercera

### Requirement: Baranda de proyecto
El script MUST conectarse a `bouquet-vinos` con el `projectId` fijo, o al
emulador de Auth con `demo-bouquet` cuando se lo pide `--emulador`, y MUST NOT
usar el proyecto activo de `gcloud`.

#### Scenario: gcloud apunta a otro proyecto
- **WHEN** el proyecto activo de gcloud es otro
- **THEN** el script igual opera sobre `bouquet-vinos`
