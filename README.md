# Ecos de Papel 🦉

Aplicación web del club de escritura **Ecos de Papel**.

**Repositorio:** https://github.com/jarkkio/Ecos-de-papel

**URL prevista cuando GitHub Pages esté activado:** https://jarkkio.github.io/Ecos-de-papel/

## Qué incluye

- **Lectodinamicas:** actividades independientes en el tiempo, cada una con título, consigna, texto inicial, tres imágenes, participaciones, votos y resultado final. Se conserva el historial.
- **Búhos de lectura:** promoción de escritos; orden de menor a mayor número de vistas (dato proporcionado por el autor) y marcador de lecturas.
- **Miembros:** perfiles, biografías y enlaces a Wattpad u otras plataformas.
- **Mi espacio:** identidad literaria y participaciones propias.
- **Roles:** miembro, moderador y administrador, con permisos protegidos en la base de datos.

## Archivos

| Archivo | Propósito |
| --- | --- |
| `index.html` | Interfaz navegable responsive |
| `config.js` | Configuración pública del backend; inicia en blanco |
| `live.js` | Integración Supabase Auth, Postgres y Storage |
| `supabase/schema.sql` | Tablas, índices, perfiles automáticos y reglas RLS |
| `.github/workflows/pages.yml` | Workflow para publicar el sitio |

## Modo demostración y modo conectado

El archivo `config.js` está vacío intencionalmente. Por lo tanto, **la web inicia en modo demo con datos ficticios y almacenamiento local**, sin usuarios reales ni sincronización. Puedes probar las tres secciones y el cambio de roles simulado.

Para pasar a producción, configura un proyecto nuevo en Supabase. **Nunca ejecutes el SQL de Ecos de Papel en el proyecto UMBRA Reader.**

1. Crea un proyecto Supabase independiente llamado **Ecos de Papel** en la organización y el plan que elijas.
2. En su SQL Editor ejecuta `supabase/schema.sql`. El esquema habilita RLS, comprueba los roles e impide los votos a la propia participación o fuera del periodo abierto.
3. Registra la URL del proyecto y la **publishable key** (`sb_publishable_...`) en `config.js`. Ninguna contraseña, secret key, service_role ni token privado debe subirse al repositorio.
4. En Supabase Authentication, habilita Email/Password y configura **Site URL** y **Redirect URLs** para la web pública, por ejemplo `https://jarkkio.github.io/Ecos-de-papel/**`.
5. Crea tu cuenta desde la web. Para otorgarte el primer rol de administración, desde SQL Editor de **Ecos de Papel** ejecuta con tu correo:
   ```sql
   update public.profiles set role = 'admin'
   where id = (select id from auth.users where email = 'TU_CORREO@DOMINIO.COM');
   ```
6. Vuelve a iniciar sesión y comprueba que puedes crear y cerrar Lectodinamicas. Los miembros nuevos se crean con rol `member`.

Los permisos de modificación de roles nunca se conceden al navegador. Los moderadores y administradores pueden abrir/cerrar dinámicas. Cada miembro puede editar sus propios fragmentos mientras estén abiertos, emitir un voto por dinámica que no sea para sí mismo y registrar obras/lecturas.

## Publicar con GitHub Pages

En GitHub ve a **Settings → Pages → Build and deployment → Source: GitHub Actions**. Después ejecuta **Actions → Publicar Ecos de Papel → Run workflow** si no se inició automáticamente. Los siguientes cambios a los archivos web se publicarán con este workflow.

El workflow está preparado, **pero su existencia no garantiza que Pages ya esté habilitado ni que la web esté en línea**. Hay que revisar Actions para confirmar el despliegue.

## Notas del MVP

- Las fechas del reto se muestran, pero su apertura/cierre efectivos los controla el estado: `upcoming`, `open` o `closed`.
- Los votos se contabilizan por dinámica; si existe un empate, se anuncia el empate.
- El número de vistas de Wattpad y otras plataformas es **declarado por los miembros**, no consultado automáticamente.
- Las imágenes se alojarán en Supabase Storage solo después de configurar la base real.
- El adaptador trae hasta 5,000 filas por tabla. Se necesitará paginación en una versión de mayor escala.
- No existe migración automática de datos ficticios a usuarios auténticos.
- Antes de usar un concurso oficial se deben hacer pruebas con múltiples cuentas, roles, cierre y votaciones.
