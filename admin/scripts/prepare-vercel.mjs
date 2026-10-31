import {readFile,readdir,mkdir,cp,rm,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const dist=path.join(root,'dist');
const stage=path.join(root,'.local','vercel-deploy');
await readFile(path.join(dist,'index.html'));
await mkdir(stage,{recursive:true});
for(const item of await readdir(stage)) {
 if(item==='.vercel')continue;
 const target=path.resolve(stage,item);
 const relative=path.relative(stage,target);
 if(!relative||relative.startsWith('..')||path.isAbsolute(relative))throw Error('Invalid staging path');
 await rm(target,{recursive:true,force:true});
}
for(const item of await readdir(dist))await cp(path.join(dist,item),path.join(stage,item),{recursive:true});
const config=JSON.parse(await readFile(path.join(root,'vercel.json'),'utf8'));
await writeFile(path.join(stage,'vercel.json'),JSON.stringify({...config,framework:null,buildCommand:null,outputDirectory:'.'},null,2)+'\n');
await writeFile(path.join(stage,'.vercelignore'),'.vercel\n.env*\n.gitignore\n*.log\n');
try {
 const identity=JSON.parse(await readFile(path.join(root,'vercel-project.json'),'utf8'));
 await mkdir(path.join(stage,'.vercel'),{recursive:true});
 await writeFile(path.join(stage,'.vercel','project.json'),JSON.stringify({projectId:identity.projectId,orgId:identity.orgId,projectName:identity.projectName})+'\n');
} catch(error) {if(error.code!=='ENOENT')throw error;}
console.log('Prepared static dashboard at '+stage);
