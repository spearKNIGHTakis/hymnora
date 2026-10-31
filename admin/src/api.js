import {createClient} from '@supabase/supabase-js';
import {config} from './config';
import {validateHymn,safeAudioPath} from './domain';
export const supabase=createClient(config.url,config.key);
const check=({data,error})=>{if(error)throw Error(error.message);return data;};
const rpc=async(name,args)=>check(await supabase.rpc(name,args));
async function all(table,order='updated_at'){const result=[];for(let offset=0;;offset+=500){const page=check(await supabase.from(table).select('*').order(order,{ascending:false}).range(offset,offset+499));result.push(...page);if(page.length<500)break;}return result;}
export const api={
 access:()=>rpc('hymnora_is_admin'),
 async load(){const [hymns,recordings]=await Promise.all([all('hymn_drafts'),all('hymn_recordings')]);return {hymns,recordings};},
 async save(h,status='draft'){return rpc('hymnora_save_hymn',{p_document:validateHymn({...h,status},{review:status==='review'}),p_expected_revision:h.revision??null});},
 publish:h=>rpc('hymnora_publish_hymn',{p_id:h.id,p_expected_revision:h.revision}),
 unpublish:h=>rpc('hymnora_unpublish_hymn',{p_id:h.id,p_expected_revision:h.revision}),
 async history(id){return check(await supabase.from('hymn_revisions').select('*').eq('hymn_id',id).order('created_at',{ascending:false}).limit(100));},
 async importCatalogue(items,progress,cancel){let imported=0;for(let i=0;i<items.length;i+=50){if(cancel())break;imported+=await rpc('hymnora_import_catalogue',{p_items:items.slice(i,i+50)});progress(Math.min(i+50,items.length));}return imported;},
 async upload(h,file,metadata){if(!h.id)throw Error('Save the hymn first.');const path=safeAudioPath(file,h.id);check(await supabase.storage.from('hymn-audio-drafts').upload(path,file,{contentType:file.type||'audio/mpeg',upsert:false}));try{return await rpc('hymnora_save_recording',{p_document:{hymn_id:h.id,language:h.language,storage_path:path,...metadata}});}catch(error){await supabase.storage.from('hymn-audio-drafts').remove([path]);throw error;}},
 saveRecording:r=>rpc('hymnora_save_recording',{p_document:r}),
 async recordingUrl(r){if(r.storage_bucket==='hymn-audio'&&r.is_published)return supabase.storage.from('hymn-audio').getPublicUrl(r.storage_path).data.publicUrl;return check(await supabase.storage.from(r.storage_bucket||'hymn-audio-drafts').createSignedUrl(r.storage_path,300)).signedUrl;},
 async setRecordingPublished(r,publish){const path=r.storage_path;
  if(publish){const blob=check(await supabase.storage.from('hymn-audio-drafts').download(path));const up=await supabase.storage.from('hymn-audio').upload(path,blob,{contentType:blob.type||'audio/mpeg',upsert:false});if(up.error&&!/already exists/i.test(up.error.message))throw up.error;}
  else if(r.storage_bucket==='hymn-audio'){const blob=check(await supabase.storage.from('hymn-audio').download(path));const saved=await supabase.storage.from('hymn-audio-drafts').upload(path,blob,{upsert:false});if(saved.error&&!/already exists/i.test(saved.error.message))throw saved.error;}
  const result=await rpc('hymnora_set_recording_publication',{p_id:r.id,p_publish:publish});if(!publish){const clean=await supabase.storage.from('hymn-audio').remove([path]);if(clean.error)throw Error('Recording hidden. Retry unpublishing to remove the remaining public copy.');}return result;
 },
 async uploadSource(language,file){if(!file.name.toLowerCase().endsWith('.pdf')||file.size>100*1024*1024)throw Error('Choose a PDF smaller than 100 MB.');check(await supabase.storage.from('hymn-source-documents').upload(`${language.toLowerCase()}/source.pdf`,file,{contentType:'application/pdf',upsert:true}));},
 async sourceUrl(language,page=1){return check(await supabase.storage.from('hymn-source-documents').createSignedUrl(`${language.toLowerCase()}/source.pdf`,300)).signedUrl+`#page=${page}`;}
};
