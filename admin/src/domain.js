export const TYPES=[['male_solo','Male solo'],['female_solo','Female solo'],['choir','Choir'],['congregation','Congregation']];
export const canonicalNumber=n=>String(n).trim().toUpperCase().replace(/^EH/,'PH').replace(/\s/g,'');
export function validateHymn(h,{review=false}={}) {
 const number=canonicalNumber(h.number);
 if(!/^PH[1-9]\d*$/.test(number))throw Error('Enter a PH number such as PH1.');
 if(!['Twi','English'].includes(h.language))throw Error('Choose English or Twi.');
 if(!h.title?.trim())throw Error('Enter the hymn title.');
 if(review && (!h.reviewed || !h.stanzas?.length || h.stanzas.some(s=>!s.body?.trim())))throw Error('Proofread and complete every verse before review.');
 return {...h,number,title:h.title.trim(),stanzas:(h.stanzas||[]).map((s,i)=>({position:i+1,kind:s.kind==='chorus'?'chorus':'verse',body:s.body.trim()}))};
}
export function parseCues(text,count) {
 if(!text.trim())return [];
 const seen=new Set();let previous=-1;
 return text.trim().split(/\n+/).map(line=>{
  const m=/^\s*(\d+)\s*=\s*(\d+(?:\.\d+)?)\s*$/.exec(line);
  if(!m)throw Error('Use verse=seconds, for example 2=34.5.');
  const position=Number(m[1]),milliseconds=Math.round(Number(m[2])*1000);
  if(position<1||position>count||seen.has(position)||milliseconds<=previous)throw Error('Use distinct verse numbers in increasing time order.');
  seen.add(position);previous=milliseconds;return {position,milliseconds};
 });
}
export function safeAudioPath(file,id){const ext=file.name.split('.').pop()?.toLowerCase();if(!['mp3','m4a','wav','ogg','flac'].includes(ext))throw Error('Choose MP3, M4A, WAV, OGG or FLAC audio.');if(file.size<=0||file.size>50*1024*1024)throw Error('Audio must be non-empty and smaller than 50 MB.');return `${id}/${crypto.randomUUID()}.${ext}`;}
export const newHymn=()=>({number:'PH',language:'Twi',title:'',stanzas:[{kind:'verse',body:''}],reviewed:false,status:'draft'});
export const statusLabel=s=>({review:'In review',published:'Published',draft:'Draft',archived:'Unpublished'})[s]||s;
