// Ecos de Papel: registro público con nombre de usuario, sin exigir correo real.
// Los alias @login.ecos-de-papel.invalid se generan SOLO internamente.
// La clave privilegiada es una variable protegida de Edge Functions, nunca frontend.
import { createClient } from 'npm:@supabase/supabase-js@2.95.0';

const allowedOrigin = 'https://jarkkio.github.io';
const loginDomain = 'login.ecos-de-papel.invalid';
const usernamePattern = /^[a-z0-9_]{3,24}$/;

function asJson(body: Record<string,unknown>, status = 200, origin = allowedOrigin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type':'application/json; charset=utf-8',
      'Cache-Control':'no-store',
      'Access-Control-Allow-Origin':origin,
      'Access-Control-Allow-Methods':'POST, OPTIONS',
      'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
      'Vary':'Origin'
    }
  });
}
const normalize = (s: unknown) => typeof s === 'string' ? s.trim().toLowerCase() : '';
function validPassword(s: unknown): s is string {
  return typeof s === 'string' && s.length >= 8 && s.length <= 72;
}
Deno.serve(async req => {
  const origin = req.headers.get('origin');
  const corsOrigin = origin === allowedOrigin ? allowedOrigin : allowedOrigin;
  if(origin && origin !== allowedOrigin) return asJson({ error:'Origen no autorizado.' },403,corsOrigin);
  if(req.method === 'OPTIONS') return asJson({},200,corsOrigin);
  if(req.method !== 'POST') return asJson({error:'Método no permitido.'},405,corsOrigin);
  const url = Deno.env.get('SUPABASE_URL');
  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url || !serviceRole) return asJson({error:'Servicio no disponible.'},503,corsOrigin);
  let requestBody: Record<string,unknown>;
  try {
    const text = await req.text();
    if(text.length > 4096) return asJson({error:'Solicitud demasiado grande.'},413,corsOrigin);
    requestBody = JSON.parse(text);
    if(!requestBody || Array.isArray(requestBody) || typeof requestBody !== 'object') throw new Error('body');
  } catch {
    return asJson({error:'Datos inválidos.'},400,corsOrigin);
  }
  const admin = createClient(url,serviceRole, {
    auth:{ autoRefreshToken:false, persistSession:false }
  });
  const action = requestBody.action === 'reset' ? 'reset' : 'register';
  if(action === 'reset') {
    const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i,'');
    if(!token || !validPassword(requestBody.password)) return asJson({error:'Solicitud inválida.'},400,corsOrigin);
    const {data:identity,error:identError} = await admin.auth.getUser(token);
    if(identError || !identity.user) return asJson({error:'Sesión inválida.'},401,corsOrigin);
    const {data:actor,error:roleError} = await admin.from('profiles').select('role').eq('id',identity.user.id).single();
    if(roleError || actor?.role !== 'admin') return asJson({error:'Sin permisos de administración.'},403,corsOrigin);
    const target = typeof requestBody.targetId === 'string' ? requestBody.targetId : '';
    if(!/^[0-9a-f-]{36}$/.test(target) || target === identity.user.id) return asJson({error:'Usuario inválido.'},400,corsOrigin);
    const {error:resetError} = await admin.auth.admin.updateUserById(target,{ password: requestBody.password });
    if(resetError) return asJson({error:'No se pudo restablecer el acceso.'},400,corsOrigin);
    return asJson({ok:true},200,corsOrigin);
  }

  const username=normalize(requestBody.username);
  if(!usernamePattern.test(username)) {
    return asJson({error:'El usuario debe tener de 3 a 24 caracteres: letras sin acentos, números o _.'},400,corsOrigin);
  }
  if(!validPassword(requestBody.password)) {
    return asJson({error:'La contraseña debe tener entre 8 y 72 caracteres.'},400,corsOrigin);
  }

  // Cuota por origen; requiere un servidor, no se puede falsificar desde el formulario.
  const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-real-ip') ||
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
  const ipHashArray = new Uint8Array(await crypto.subtle.digest(
    'SHA-256', new TextEncoder().encode('ecos-de-papel:v1:' + ip)
  ));
  const fingerprint=Array.from(ipHashArray).map(b=>b.toString(16).padStart(2,'0')).join('');
  const {data:permit,error:limitError} = await admin.rpc('reserve_ecos_signup_slot',{ p_ip_hash:fingerprint });
  if(limitError) {
    console.error('Rate limit unavailable:', limitError.code);
    return asJson({error:'No se pudo procesar el registro.'},503,corsOrigin);
  }
  if(!permit) return asJson({error:'Demasiados intentos. Prueba más tarde.'},429,corsOrigin);
  const {data,error} = await admin.auth.admin.createUser({
    email:username+'@'+loginDomain,
    email_confirm:true,
    password:requestBody.password,
    user_metadata:{name:username}
  });
  if(error) {
    if(/already|registered|exists|duplicate/i.test(error.message)) {
      return asJson({error:'Ese nombre de usuario ya está ocupado.'},409,corsOrigin);
    }
    console.error('Registration failure:', error.code || error.status);
    return asJson({error:'No se pudo crear tu cuenta. Inténtalo de nuevo.'},400,corsOrigin);
  }
  return asJson({ok:true,username:data.user?.user_metadata?.name || username},201,corsOrigin);
});
