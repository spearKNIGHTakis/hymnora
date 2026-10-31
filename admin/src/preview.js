import {validateHymn} from './domain';
export async function createPreview(){
 let hymns=JSON.parse(localStorage.getItem('hymnora_design_v1')||'null')||[
  ['PH1','Twi','Monkamfo Nyankopɔn'],['PH1','English','Ye servants of God'],['PH2','Twi','Kamfo Yehowa'],['PH2','English',"Before Jehovah's awful throne"]
 ].map(([number,language,title],i)=>({id:`preview-${i}`,number,language,title,stanzas:[{kind:'verse',body:'Local interface preview. Enter your hymn text here.'}],status:'draft',revision:1,reviewed:false,updated_at:new Date().toISOString()}));
 const snapshots=[];const persist=()=>localStorage.setItem('hymnora_design_v1',JSON.stringify(hymns));
 const save=async(h,status='draft')=>{const row={...validateHymn({...h,status},{review:status==='review'}),id:h.id||crypto.randomUUID(),revision:(h.revision||0)+1,updated_at:new Date().toISOString()};hymns=hymns.filter(x=>x.id!==row.id).concat(row);snapshots.push({id:crypto.randomUUID(),revision:row.revision,snapshot:structuredClone(row),action:status,created_at:row.updated_at});persist();return row;};
 return {load:async()=>({hymns:[...hymns],recordings:[]}),save,publish:h=>save(h,'published'),unpublish:h=>save(h,'archived'),history:async()=>[...snapshots].reverse(),importCatalogue:async(items,progress,cancel)=>{let n=0;for(const item of items){if(cancel())break;await save({...item,id:undefined});progress(++n);}return n;},upload:async()=>{throw Error('Uploads need the live admin backend.');},sourceUrl:async()=>{throw Error('Source previews need private backend storage.');},uploadSource:async()=>{throw Error('Uploads need the live admin backend.');}};
}
