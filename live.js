/* Ecos de Papel · Adaptador de datos Supabase, v1.1.
   Usa solamente una publishable key; los privilegios se hacen cumplir en Postgres (RLS).
   Dependencia externa fijada a una versión específica. */
(function () {
  'use strict';
  const CDN = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.95.0/+esm';
  function required(data, error) {
    if (error) throw error;
    return data;
  }
  function safeLink(value) {
    if (!value) return null;
    const url = new URL(value);
    if (!['https:', 'http:'].includes(url.protocol)) throw Error('Solo se admiten enlaces HTTP o HTTPS.');
    return url.href;
  }
  async function create(url, key) {
    const { createClient } = await import(CDN);
    const client = createClient(url, key, {
      auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true }
    });
    const from = name => client.from(name);
    // Cada consulta devuelve y valida su propio error.
    async function rows(name) {
      const { data, error } = await from(name).select('*').limit(5000);
      return required(data, error);
    }
    async function load(userId) {
      const [people, activities, pictures, entries, ballots, publications, finished] = await Promise.all([
        rows('profiles'), rows('lectodinamicas'), rows('lectodinamica_images'),
        rows('fragments'), rows('votes'), rows('works'), rows('readings')
      ]);
      const members = people.map(p => ({
        id: p.id, name: p.display_name, role: p.role, bio: p.bio || '',
        wattpad: p.wattpad_url || '', other: p.other_url || ''
      }));
      const dynamics = activities.map(d => ({
        id: d.id, title: d.title, theme: d.theme, stage: d.stage,
        start: d.start_date || '', end: d.end_date || '', prompt: d.prompt, starter: d.starter,
        images: pictures.filter(p => p.dynamic_id === d.id).sort((a,b)=>a.position-b.position)
          .map(p => ({ label: p.label, url: p.image_url || '', scene: p.position - 1 })),
        submissions: entries.filter(e => e.dynamic_id === d.id).map(e => ({
          id: e.id, author: e.author_id, text: e.body, date: e.created_at.slice(0, 10)
        })),
        votes: Object.fromEntries(ballots.filter(v=>v.dynamic_id === d.id)
          .map(v => [v.voter_id, v.submission_id]))
      })).sort((a,b)=>(b.start||'').localeCompare(a.start||''));
      const works = publications.map(w => ({
        id:w.id, author:w.author_id, title:w.title, description:w.description || '',
        genre:w.genre, views:w.views, url:w.url || ''
      }));
      const readBy = {};
      for (const r of finished) (readBy[r.reader_id] ||= []).push(r.work_id);
      return { currentUser:userId, members, dynamics, works, readBy };
    }
    async function createDynamic(d, uid) {
      if (!Array.isArray(d.images) || d.images.length !== 3) throw Error('Cada dinámica debe incluir tres referencias.');
      const dynId = crypto.randomUUID();
      const imageRows = [];
      for (let i = 0; i < 3; i++) {
        const image = d.images[i];
        let imageUrl = safeLink(image.url);
        if (image.file) {
          if (image.file.size > 5 * 1024 * 1024) throw Error('Cada imagen debe pesar menos de 5 MB.');
          const types = { 'image/jpeg':'jpg', 'image/png':'png', 'image/webp':'webp' };
          const ext = types[image.file.type];
          if (!ext) throw Error('Imagen no admitida: usa JPG, PNG o WebP.');
          const path = dynId + '/' + (i + 1) + '.' + ext;
          const { error } = await client.storage.from('lectodinamicas')
            .upload(path, image.file, { contentType:image.file.type, upsert:false });
          if (error) throw error;
          imageUrl = client.storage.from('lectodinamicas').getPublicUrl(path).data.publicUrl;
        }
        imageRows.push({ dynamic_id:dynId, position:i+1, label:image.label, image_url:imageUrl });
      }
      const { error:dynError } = await from('lectodinamicas').insert({
        id:dynId, created_by:uid, title:d.title, theme:d.theme, prompt:d.prompt,
        starter:d.starter, stage:d.stage, start_date:d.start || null, end_date:d.end || null
      });
      if (dynError) throw dynError;
      const { error:imageError } = await from('lectodinamica_images').insert(imageRows);
      if (imageError) throw imageError;
      return dynId;
    }
    async function saveFragment(dynamicId, uid, body, existingId) {
      const { error } = existingId
        ? await from('fragments').update({body}).eq('id', existingId).eq('dynamic_id',dynamicId)
        : await from('fragments').insert({ dynamic_id:dynamicId, author_id:uid, body });
      if (error) throw error;
    }
    async function saveWork(uid, w) {
      const { error } = await from('works').insert({
        author_id:uid, title:w.title, genre:w.genre, description:w.description,
        views:w.views, url:safeLink(w.url)
      });
      if (error) throw error;
    }
    async function saveProfile(uid, p) {
      const { error } = await from('profiles').update({
        display_name:p.name, bio:p.bio, wattpad_url:safeLink(p.wattpad),
        other_url:safeLink(p.other)
      }).eq('id',uid);
      if (error) throw error;
    }
    async function vote(dynId,uid,submissionId,previous) {
      if (previous === submissionId) {
        const { error } = await from('votes').delete()
          .eq('dynamic_id',dynId).eq('voter_id',uid);
        if (error) throw error;
      } else {
        const { error } = await from('votes').upsert({
          dynamic_id:dynId, voter_id:uid, submission_id:submissionId
        }, { onConflict:'dynamic_id,voter_id' });
        if (error) throw error;
      }
    }
    async function setRead(workId,uid,alreadyRead) {
      const { error } = alreadyRead
        ? await from('readings').delete().eq('work_id',workId).eq('reader_id',uid)
        : await from('readings').insert({work_id:workId,reader_id:uid});
      if (error) throw error;
    }
    async function setStage(dynId, stage) {
      if (!['upcoming','open','closed'].includes(stage)) throw Error('Estado inválido.');
      const { error } = await from('lectodinamicas').update({ stage }).eq('id',dynId);
      if (error) throw error;
    }
    async function setMemberRole(uid, memberId, role) {
      if (!['member','moderator','admin'].includes(role) || uid === memberId) throw Error('Asignación de rol inválida.');
      const { error } = await from('role_assignments').insert({ assigned_by:uid, target_id:memberId, new_role:role });
      if (error) throw error;
    }
    return {
      load, createDynamic, saveFragment, saveWork, saveProfile, vote, setRead, setStage, setMemberRole,
      async signUp(name,email,password) {
        const {data,error} = await client.auth.signUp({email,password,options:{data:{name},emailRedirectTo:window.location.origin+window.location.pathname}});
        return required(data,error);
      },
      async signIn(email,password) {
        const {data,error} = await client.auth.signInWithPassword({email,password});
        return required(data,error);
      },
      async resetPassword(email) {
        const {error} = await client.auth.resetPasswordForEmail(email,{
          redirectTo:window.location.origin+window.location.pathname
        });
        if(error)throw error;
      },
      async updatePassword(password) {
        const {error} = await client.auth.updateUser({password});
        if(error)throw error;
      },
      async signOut() { const {error} = await client.auth.signOut(); if(error) throw error; },
      async getUser() {
        const { data } = await client.auth.getUser();
        return data?.user || null;
      },
      onAuthChange(callback) {
        return client.auth.onAuthStateChange(callback).data.subscription;
      }
    };
  }
  window.EcosLive = { create };
})();
