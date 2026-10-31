"""Build source-traceable hymn data from extract_pdf_layout.py intermediates."""
import json,re,bisect
from pathlib import Path
from collections import defaultdict,Counter
ROOT=Path(__file__).resolve().parents[1]
LAYOUT=ROOT/'build'/'pdf-preview'
OUT=ROOT/'build'/'catalogue'
OUT.mkdir(parents=True,exist_ok=True)

def textclean(text):
    return re.sub(r'\s+',' ',text.replace('\u00ad','').replace('\ufffe','')).strip()

def merge_fragments(lines):
    out=[]
    for line in lines:
        line=dict(line)
        if out and abs(line['y']-out[-1]['y'])<2.5 and -1<=line['x']-out[-1]['right']<30:
            old=out[-1]
            if not (old['right']<300<line['x'] and line['x']-old['right']>12):
                gap=' ' if line['x']-old['right']>1.5 else ''
                old['text']+=gap+line['text'];old['right']=line['right'];continue
        out.append(line)
    return out

def reading_order(lines, split=285, force_columns=False):
    ordered=[]
    by_page=defaultdict(list)
    for line in lines:by_page[line.get('page',0)].append(line)
    for page, items in sorted(by_page.items()):
        columns=force_columns or not any(l['x']<split-20 and l['right']>split+30 for l in items)
        for col in ([0,1] if columns else [0]):
            part=[l for l in items if not columns or int(l['x']>=split)==col]
            part.sort(key=lambda l:(l['y'],l['x']))
            groups=[]
            for line in part:
                if groups and abs(line['y']-groups[-1][0]['y'])<2.5:groups[-1].append(line)
                else:groups.append([line])
            for group in groups:
                group.sort(key=lambda l:l['x'])
                result=dict(group[0]);chunks=[result['text']]
                for line in group[1:]:
                    gap=' ' if line['x']-result['right']>1 else ''
                    chunks.append(gap+line['text']);result['right']=max(result['right'],line['right'])
                result['text']=''.join(chunks)
                ordered.append(result)
    return ordered
def stanzas(lines,language):
    result=[]; current=[]; numbers=[]; problems=[]; expected=1
    def flush():
        if current:
            result.append({'id':f's{len(result)+1}','position':len(result)+1,'kind':'verse','body':'\n'.join(current).strip()})
            current.clear()
    for line in merge_fragments(lines):
        text=textclean(line['text'])
        if not text:continue
        if language=='Twi':
            if line['size']<8 or 'Italic' in line['font']:continue
            if re.search(r'\b\d{4}\s*[-–]\s*\d{4}\b',text) or re.fullmatch(r'[A-Z.,;\s]+(?:\d{4})?',text):continue
            if re.match(r'^(?:Nky\.|Dw[.:]|Efi [“"]|O\.A\.B\.|J\.G\.C\.|W\.E\.O\.A\.)',text):continue
        marker=re.match(r'^(\d{1,2})(?:\s*[.)]\s*|\s+)([A-Za-zƐƆɛɔ‘’"].*)$',text)
        if marker:
            n=int(marker[1])
            if 1<=n<=25:
                if current:flush()
                if numbers and n!=numbers[-1]+1:problems.append(f'stanza sequence {numbers[-1]}→{n}')
                numbers.append(n);text=marker[2]
        elif not numbers and not current:
            numbers.append(1)
        if text.startswith('['):text=text[1:]
        current.append(text)
    flush()
    return result,sorted(set(problems))

def twi():
    pages=json.loads((LAYOUT/'twi-layout.json').read_text(encoding='utf8'))
    headers={}
    for p in pages[:441]:
        for l in p['lines']:
            m=re.match(r'^(\d{1,3})\.?($|\s)',l['text'])
            if m and 'Bold' in l['font'] and 11<=l['size']<14 and l['x']<180:
                n=int(m[1])
                if 1<=n<=850 and n not in headers:headers[n]=(p['page'],l['y'])
    assert len(headers)==850, f'Missing Twi headings: {set(range(1,851))-headers.keys()}'
    sorted_headers=sorted((location,n) for n,location in headers.items())
    keys=[loc for loc,n in sorted_headers]
    heading_counts=Counter(l['text'] for page in pages[:442] for l in page['lines'] if re.match(r'^\d+[.]',l['text']) and 190<l['x']<300 and l['y']<205)
    section_titles=set(heading_counts)
    bodies=defaultdict(list)
    for p in pages[:442]:
        for l in p['lines']:
            if not (8<=l['size']<=10.5) or l['y']<190:continue
            if any(pg==p['page'] and abs(y-l['y'])<9 for pg,y in headers.values()):continue
            at=bisect.bisect_right(keys,(p['page'],l['y']))-1
            if at>=0:
                n=sorted_headers[at][1]
                if l['text'] in section_titles:continue
                if p['page']==headers[n][0] and l['y']<headers[n][1]+12:continue
                bodies[n].append({**l,'page':p['page']})
    hymns=[]
    for n in range(1,851):
        verses,issues=stanzas(reading_order(bodies[n]),'Twi')
        if not verses: issues.append('no lyrics extracted')
        title=verses[0]['body'].split('\n')[0] if verses else f'Hymn {n}'
        hymns.append({'id':f'local:twi:{n}','number':f'PH{n}','title':title.rstrip(' ,;.!'),
            'language':'Twi','source':'Presbyterian Twi hymnbook','source_page':headers[n][0],
            'stanzas':verses,'review':issues})
    return hymns

def norm(s):return re.sub(r'[^a-z]','',s.lower())

def english():
    pages=json.loads((LAYOUT/'english-layout.json').read_text(encoding='utf8'))
    blocks=[]; current=None;pending=None; last_stanza=0; candidate=None
    def start(number,page,method):
        nonlocal current,last_stanza,candidate,pending
        current={'number':number,'page':page,'method':method,'lines':[],'issues':[]}
        blocks.append(current);last_stanza=0;candidate=None;pending=None
    for p in pages[12:458]:
        # Native text order follows the left column, then right column.
        for l in reading_order([{**line,'page':p['page']} for line in p['lines']],split=p['width']/2,force_columns=True):
            text=textclean(l['text'])
            heading=re.fullmatch(r'\d{1,3}',text)
            if heading and 10.5<=l['size']<=15 and l['y']>50 and l['x']<240:
                n=int(text)
                if 1<=n<=972 and (current is None or current['number']<n<=current['number']+15):
                    start(n,p['page'],'printed heading')
                continue
            if not (7<=l['size']<=9.5) or len(re.findall('[A-Za-z]',text))<4:continue
            if l['y']<50 or l['y']>p['height']-18:continue
            if sum(c.isalpha() for c in text)/max(len(text),1)<.48:continue
            if re.fullmatch(r'[A-Z\s.\-]+',text):continue
            marker=re.match(r'^(\d{1,2})\s+([A-Za-z].*)',text)
            n=int(marker[1]) if marker else None
            if current is None:start(1,p['page'],'first hymn')
            if n==1 and current['lines']:
                start(current['number']+1,p['page'],'stanza reset')
            elif n and 2<=n<=12 and last_stanza>=n and current['lines']:
                # A missing decorative first stanza number is common in this scan.
                # Split only at an observed unnumbered paragraph gap, retaining a review flag.
                if candidate is not None:
                    tail=current['lines'][candidate:];current['lines']=current['lines'][:candidate]
                    start(current['number']+1,tail[0]['page'],'unnumbered first stanza')
                    current['lines'].extend(tail)
                    current['issues'].append('first stanza number missing in scan')
                else:
                    current['issues'].append(f'possible missing hymn boundary before verse {n}')
            if n and n<=20:last_stanza=n;candidate=None
            elif current['lines']:
                prev=current['lines'][-1]
                if prev['page']==p['page'] and l['x']<prev['x']+40 and 17<l['y']-prev['bottom']<65:
                    candidate=len(current['lines'])
            current['lines'].append({**l,'page':p['page']})
    # Do not assign uncertain duplicate numbers to published records.
    by_number=defaultdict(list)
    for block in blocks:by_number[block['number']].append(block)
    hymns=[]
    for n,group in sorted(by_number.items()):
        chosen=next((b for b in group if b['method']=='printed heading'),group[0])
        verses,issues=stanzas(chosen['lines'],'English')
        issues+=chosen['issues']
        if len(group)>1:issues.append('numbering collision: verify source')
        if not verses:continue
        title=verses[0]['body'].split('\n')[0]
        hymns.append({'id':f'local:english:{n}','number':f'PH{n}','title':title.rstrip(' ,;.!'),
            'language':'English','source':'The Presbyterian Hymnal (Philadelphia edition)',
            'source_page':chosen['page'],'stanzas':verses,'review':sorted(set(issues)),
            'number_method':chosen['method']})
    (OUT/'english-blocks.json').write_text(json.dumps(blocks,ensure_ascii=False),encoding='utf8')
    return hymns

if __name__=='__main__':
    hymns=twi()+english()
    (OUT/'hymns-draft.json').write_text(json.dumps(hymns,ensure_ascii=False,indent=2),encoding='utf8')
    for lang in ['Twi','English']:
        rows=[h for h in hymns if h['language']==lang]
        expected=850 if lang=='Twi' else 972
        found={int(re.sub(r'\D','',h['number'])) for h in rows}
        print(lang,'hymns',len(rows),'stanzas',sum(len(h['stanzas']) for h in rows),'flagged',sum(bool(h['review']) for h in rows))
        print('MISSING',sorted(set(range(1,expected+1))-found))
        for h in rows[:5]:print(h['number'],h['title'],len(h['stanzas']),h['review'])
