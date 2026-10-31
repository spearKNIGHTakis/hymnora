"""Extract PDF text with source geometry and legacy Twi font conversion.
The generated layout files are intermediates for the catalogue importer.
"""
import argparse
import ctypes as C
import json
from pathlib import Path
import pypdfium2 as pdfium
import pypdfium2.raw as raw

TWI_MAP = str.maketrans({'1': 'ɛ', '4': 'ɔ', '!': 'Ɛ', '$': 'Ɔ'})

def extract(path, output, twi=False):
    pdf = pdfium.PdfDocument(str(path))
    pages=[]
    for page_idx in range(len(pdf)):
        page=pdf[page_idx]
        height=page.get_height()
        textpage=page.get_textpage()
        lines=[]
        chars=[]
        def flush():
            if not chars: return
            text=''.join(c['text'] for c in chars).strip()
            if text:
                lines.append({'text':text,'x':round(min(c['x'] for c in chars),2),
                    'right':round(max(c['right'] for c in chars),2),
                    'y':round(min(c['y'] for c in chars),2),
                    'bottom':round(max(c['bottom'] for c in chars),2),
                    'size':round(max(c['size'] for c in chars if c['text'].strip()),2),
                    'font':max((c for c in chars if c['text'].strip()),key=lambda c:c['size'])['font'],
                    'order':len(lines)})
            chars.clear()
        font_buffer=C.create_string_buffer(256)
        flags=C.c_int()
        for idx in range(textpage.count_chars()):
            value=raw.FPDFText_GetUnicode(textpage.raw,idx)
            if value in (10,13): flush(); continue
            if value<32 or value>0x10ffff: continue
            char=chr(value)
            left,bottom,right,top=textpage.get_charbox(idx)
            size=raw.FPDFText_GetFontSize(textpage.raw,idx)
            raw.FPDFText_GetFontInfo(textpage.raw,idx,font_buffer,256,C.byref(flags))
            font=font_buffer.value.decode('utf8',errors='replace')
            if twi and ('Capecoast' in font or 'TT9BF4' in font):
                nextcode=raw.FPDFText_GetUnicode(textpage.raw,idx+1) if idx+1<textpage.count_chars() else 0
                nextchar=chr(nextcode) if 0<nextcode<=0x10ffff else ''
                if char != '!' or nextchar.isalpha():
                    if not (char in '14' and nextchar == '.' and not any(c['text'].strip() for c in chars)):
                        char=char.translate(TWI_MAP)
            origin_x=C.c_double(); origin_y=C.c_double()
            raw.FPDFText_GetCharOrigin(textpage.raw,idx,C.byref(origin_x),C.byref(origin_y))
            baseline=height-origin_y.value
            if chars and (abs(baseline-chars[-1]['baseline'])>2 or left<chars[-1]['x']-2 or left-chars[-1]['right']>12):
                flush()
            chars.append({'text':char,'x':left,'right':right,'y':height-top,'bottom':height-bottom,'size':size,'font':font,'baseline':baseline})
        flush()
        pages.append({'page':page_idx+1,'width':page.get_width(),'height':height,'lines':lines})
        textpage.close();page.close()
        if page_idx%25==0: print(output.name, page_idx+1,'/',len(pdf),flush=True)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(pages,ensure_ascii=False),encoding='utf8')
    print('SAVED',output,len(pages),'pages',flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('source',type=Path);p.add_argument('output',type=Path);p.add_argument('--twi',action='store_true')
    a=p.parse_args();extract(a.source,a.output,a.twi)
