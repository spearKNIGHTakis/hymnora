"""Package complete source pages and source-traceable extracted hymn records."""
import json,re
from pathlib import Path
from PIL import ImageChops
import pypdfium2 as pdfium
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'build/catalogue/hymns-draft.json').read_text(encoding='utf8'))
by_number={int(re.sub(r'\D','',h['number'])):h for h in rows if h['language']=='English'}
blocks=json.loads((ROOT/'build/catalogue/english-blocks.json').read_text(encoding='utf8'))
anchors=sorted((b['number'],b['page']) for b in blocks if b['method']=='printed heading')
# Source pages remain available for every numbered entry, including OCR gaps.
for n in range(1,973):
    if n not in by_number:
        before=[a for a in anchors if a[0]<n]
        after=[a for a in anchors if a[0]>n]
        page=before[-1][1] if before else (after[0][1] if after else 13)
        by_number[n]={'id':f'local:english:{n}','number':f'PH{n}','title':f'English hymn {n}',
            'language':'English','source':'The Presbyterian Hymnal (Philadelphia edition)',
            'source_page':page,'stanzas':[],'review':['OCR heading not recovered; read the source pages'],
            'number_method':'source page range'}
# Inferred numbering is accepted only when it fits between adjacent printed anchors.
for (left,_),(right,_) in zip(anchors,anchors[1:]):
    interval=[b for b in blocks if left<b['number']<right]
    if len(interval)!=right-left-1:
        for n in range(left+1,right):
            if by_number[n]['number_method']!='printed heading':
                by_number[n]['review'].append('inferred numbering needs checking against the source')
records=[h for h in rows if h['language']=='Twi']+list(by_number.values())
for h in records:
    for s in h['stanzas']:s['id']=f"{h['id']}:{s['position']}"
(ROOT/'assets/data/hymns.json').write_text(json.dumps(records,ensure_ascii=False,separators=(',',':')),encoding='utf8')
report=['# Catalogue extraction review','',
 'All 850 Twi and 972 English numbered entries are represented. Source PDFs are available privately to administrators for proofreading. Text extraction is a draft, not a complete proofreading pass.',
 '', 'The English Philadelphia edition is a separate book; its numbering is not a translation mapping to the PCG Twi book.', '',
 'Both books display PH numbers with an explicit language label. Matching numbers do not imply translation equivalence. Source pages are PDF page numbers.', '',
 '| Hymn | PDF page | Checks needed |','|---|---:|---|']
for h in records:
    if h['review']:report.append(f"| {h['number']} · {h['language']} | {h['source_page']} | {'; '.join(h['review'])} |")
(ROOT/'CATALOGUE_REVIEW.md').write_text('\n'.join(report)+'\n',encoding='utf8')
print('PACKAGED',len(records),'hymn entries',flush=True)

sources=[('twi',r'C:\Users\offic\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\AC\INetCache\Z8HBA3LZ\751880468-Phb-Twi-Final[1].pdf',1,442),
 ('english',r'C:\Users\offic\Downloads\presbyterianhymn00pres.pdf',13,458)]
for name,path,start,end in sources:
    pdf=pdfium.PdfDocument(path)
    for i in range(start-1,end):
        output=ROOT/'assets/sources'/name/f'{i+1}.jpg'
        if output.exists():continue
        page=pdf[i]
        image=page.render(scale=2).to_pil().convert('L')
        # Remove only the blank exterior margin; preserve all printed content.
        mask=image.point(lambda p:255 if p<210 else 0)
        bbox=mask.getbbox()
        if bbox:
            x0,y0,x1,y1=bbox
            image=image.crop((max(0,x0-14),max(0,y0-14),min(image.width,x1+14),min(image.height,y1+14)))
        image.save(output,'JPEG',quality=83,optimize=True)
        page.close()
        if i%25==0:print(name,'rendered PDF page',i+1,'/',end,flush=True)
    pdf.close()
print('SOURCE PAGES READY',flush=True)
