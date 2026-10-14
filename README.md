# Ecos de Papel 🦉

**Sitio:** https://jarkkio.github.io/Ecos-de-papel/

**Código:** https://github.com/jarkkio/Ecos-de-papel

**Backend:** proyecto Supabase Ecos de Papel `bioaztyrkmingcziolot`, independiente de UMBRA Reader.

## Acceso sencillo

La aplicación **solo pide nombre de usuario y contraseña**, no solicita dirección de correo ni confirmación. Los nombres de usuario admiten de 3 a 24 caracteres (letras a-z, números, guion bajo); contraseñas de 8 a 72 caracteres. Cada cuenta se crea con rol **Miembro**.

Supabase Auth funciona en el servidor con un identificador técnico interno, que no se muestra al usuario. La creación se realiza mediante la Edge Function `username-register` (ya desplegada), con validación de campos, limitación básica de registros y claves secretas confinadas en el servidor. El frontend utiliza exclusivamente la *publishable key*.

**La cuenta administradora inicial todavía no está creada**: se debe registrar desde la interfaz y después promover en Supabase. No habilitar el club para miembros externos hasta realizarlo.

## Iniciar como administrador del club

1. Abre la web y pulsa **Crear uno**, introduce el usuario elegido (por ejemplo, `admin`) y su contraseña.
2. Después de completar el registro, se debe promover el usuario a administrador una sola vez desde el SQL Editor, ejecutando:
```sql
update public.profiles set role='admin' where username='admin';
```
3. Vuelve a iniciar sesión. El administrador ya puede asignar roles desde la sección **Miembros → Gestionar roles**.
4. Cambia la contraseña provisional desde **Mi espacio → Cambiar contraseña**, especialmente si se compartió por chat.

No publiques la contraseña del administrador en archivos de GitHub ni en configuraciones. Si olvidas la contraseña, la recuperación debe realizarla otro administrador o el propietario del proyecto; **no hay recuperación automática por correo**.

## Funciones

- **Lectodinamicas** independientes con tres imágenes, consigna, fragmentos, votación por otros participantes y resultados al cerrar. Se conserva el historial.
- **Búhos de lectura:** catálogo de obras ordenadas de menos a más vistas, enlaces y lecturas marcadas por el usuario.
- **Miembros:** perfiles con biografía y enlaces a Wattpad y otros sitios.
- **Mi espacio:** nombre literario, publicaciones y cambio de contraseña.
- **Administración:** gestión de roles. Las políticas de la base de datos impiden a los usuarios comunes asignarse privilegios.

## Archivos

| Archivo | Uso |
| --- | --- |
| `index.html` | Web responsive y formularios de usuario/contraseña |
| `live.js` | Conexión a Auth, Database, Storage y registro |
| `config.js` | Configuración **pública** de Supabase |
| `supabase/schema.sql` | Esquema inicial ya aplicado |
| `supabase/02_roles_indexes_images.sql` | Actualización de roles e imágenes obligatorias ya aplicada |
| `supabase/03_usuario_password.sql` | Migración de usuarios sin correo ya aplicada |
| `supabase/functions/username-register/index.ts` | Código de la Edge Function desplegada |
| `.github/workflows/pages.yml` | Despliegue automático mediante GitHub Pages |

## Comprobaciones

El proyecto utiliza tablas protegidas mediante Row Level Security, limitación de un voto por dinámica y prohibición de votar por el propio fragmento. Supabase Security Advisor no mostró avisos en la revisión anterior. Se probó en transacciones la protección de roles y votos, con reversión de los datos de prueba. La autenticación por usuario/contraseña requiere todavía una prueba completa real con un usuario registrado y acceso desde el navegador.

**Observación:** los alias internos no son correos recuperables. El uso de contraseñas únicas y el cuidado de la cuenta administradora es especialmente importante.
