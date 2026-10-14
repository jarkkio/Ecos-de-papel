# Ecos de Papel 🦉
Aplicación web del club de escritura Ecos de Papel.

**Sitio web:** https://jarkkio.github.io/Ecos-de-papel/

**Backend:** Supabase `Ecos de Papel` (`bioaztyrkmingcziolot`). Es totalmente independiente de UMBRA Reader.

## Estado actual (13 de octubre de 2026)

**El backend está creado y conectado a la web:** `config.js` contiene únicamente la URL y publishable key públicas de Supabase, con Row Level Security (RLS).

Las tablas creadas son `profiles`, `lectodinamicas`, `lectodinamica_images`, `fragments`, `votes`, `works`, `readings` y `role_assignments`. El bucket Storage `lectodinamicas` permite administrar tres imágenes por reto.

Los formularios, las operaciones sobre lecturas, los fragmentos, la votación y la gestión de roles ya están conectados al backend. En esta instalación no se importaron usuarios ficticios: las tablas comienzan vacías.

**Pendiente antes de admitir miembros reales:** configurar el correo SMTP del proyecto Supabase, crear/verificar la primera cuenta y otorgarle el rol de administrador. Hasta completar esto, no presentar el sistema como un servicio con registro público listo.

## Habilitar registro real de los miembros

**1. Configurar la entrega de correos.** En [Supabase Auth SMTP](https://supabase.com/dashboard/project/bioaztyrkmingcziolot/auth/smtp) agrega un proveedor SMTP autorizado (por ejemplo, Resend, Brevo, Amazon SES o el servicio que prefiera la administración). Sin SMTP propio, el servicio predeterminado de Supabase solo admite correos autorizados del equipo del proyecto. [Documentación oficial SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

**2. Configurar la URL de autenticación.** En [Authentication → URL Configuration](https://supabase.com/dashboard/project/bioaztyrkmingcziolot/auth/url-configuration), establece:
- **Site URL:** `https://jarkkio.github.io/Ecos-de-papel/`
- **Redirect URLs:** `https://jarkkio.github.io/Ecos-de-papel/**`

**3. Registrar al administrador inicial.** Entra al sitio publicado, crea tu cuenta con correo y contraseña y confírmala a través del mensaje recibido. Si el correo no llega, revisa SMTP y los registros de Auth.

**4. Otorgar el primer permiso administrativo.** En el [SQL Editor del proyecto Ecos de Papel](https://supabase.com/dashboard/project/bioaztyrkmingcziolot/sql/new), ejecuta sustituyendo el correo por el usado al registrarse:

```sql
update public.profiles
set role = 'admin'
where id = (
  select id from auth.users
  where lower(email) = lower('TU_CORREO@DOMINIO.COM')
);
```

**5. Administrar roles desde la web.** Cierra sesión y vuelve a entrar. En la sección **Miembros → Gestionar roles**, el administrador podrá nombrar moderadores y otros administradores. Los cambios quedan auditados en `role_assignments`. Los miembros nuevos siempre comienzan como `member`.

## Funciones

- **Lectodinamicas**: retos independientes, tres imágenes de referencia, consigna y texto de arranque; participaciones, un voto por persona, prohibición del voto propio y resultados cuando se cierra el reto. Las actividades anteriores no se sobrescriben.
- **Búhos de lectura**: orden de menor a mayor número de vistas, promociones literarias y marca personal de lectura. Las cifras de vistas las indica el autor, no se obtienen automáticamente de Wattpad.
- **Miembros**: biografía y enlaces Wattpad/externos, permiso según rol.
- **Mi espacio**: edición del perfil, obras y resumen de participaciones.
- **Acceso**: registro, inicio y cierre de sesión, confirmación por correo y recuperación de contraseña (esta última también requiere SMTP).

## Seguridad y mantenimiento

- Clave pública en `config.js`, nunca una secret key ni service_role.
- Todas las tablas públicas tienen RLS; el análisis Security Advisor no reporta observaciones actualmente.
- Los roles están protegidos de la edición directa desde el cliente. Los cambios administrativos usan una tabla de auditoría y un trigger privado. Moderadores no pueden concederse privilegios.
- Un miembro no puede crear ni cerrar retos, no puede votar por sí mismo ni emitir más de un voto por reto.
- Los votos y fragmentos se bloquean al finalizar el reto; el histórico permanece.
- El frontend obtiene hasta 5 000 registros por tabla, por lo que se necesitará paginación si el club crece mucho.
- Para implementar mejoras usa commits en `main`. El workflow [Publicar Ecos de Papel](.github/workflows/pages.yml) realiza el despliegue mediante GitHub Pages.

## Archivos principales

| Archivo | Propósito |
| --- | --- |
| `index.html` | Interfaz web responsive y operaciones |
| `config.js` | Conexión pública a Supabase del club |
| `live.js` | Cliente de Supabase: login, escritos, votos, imágenes, roles |
| `supabase/schema.sql` | Esquema inicial; aplicado al proyecto real |
| `supabase/02_roles_indexes_images.sql` | Migración posterior: gestión de roles, índices e imágenes obligatorias; ya aplicada |
| `.github/workflows/pages.yml` | Publicación automática |

## Verificación completada

Se ejecutaron pruebas transaccionales de inserción de perfiles mediante trigger, publicación de dinámicas, participaciones, votos y lecturas, rechazo de acciones no autorizadas y gestión de roles. Los datos de esas pruebas se revirtieron y no aparecen como participantes reales. El análisis del archivo JavaScript terminó sin errores de sintaxis. Falta validar el ciclo completo desde el navegador con cuentas verdaderas después de configurar SMTP.
