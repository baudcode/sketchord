from datetime import datetime
import bs4
import requests
import json
from  pprint import pprint
from .models import Note
import uuid

def clean_content(content: str) -> str:
    content = content.strip()
    if content[-1] == '\n':
        content = content[:-1].strip()
    return content

def get_note(url: str) -> Note:
    # url = "https://tabs.ultimate-guitar.com/tab/passenger/27-ukulele-2190875"
    # url = "https://tabs.ultimate-guitar.com/tab/passenger/and-i-love-her-tabs-1709320"
    # url = "https://tabs.ultimate-guitar.com/tab/passenger/new-until-its-old-chords-2621235"
    t = requests.get(url).text
    soup = bs4.BeautifulSoup(t, "html.parser")
    t = soup.find('div', {'class' :"js-store"})
    data = t.get("data-content")
    #with open("data.json", 'w') as w:
    #    w.write(data)

    k = json.loads(data)

    tab = k['store']['page']['data']['tab']
    view = k['store']['page']['data']['tab_view']
    tuning = None
    capo = None

    if "meta" in view:
        meta = view['meta']
        if "tuning" in meta:
            """
            "tuning": {
                        "name": "Standard",
                        "value": "E A D G B E",
                        "index": 1
            }
            """

            if "value" in meta['tuning']:
                tuning = meta['tuning']['value']
                if tuning.lower() == "e a d g b e":
                    tuning = None
                    
            elif "name" in meta['tuning']:
                tuning = meta['tuning']['name']

        if "capo" in meta:        
            capo = meta['capo']

    sections = []

    if "wiki_tab" in view:
        parts = view['wiki_tab']['content'].split("\r\n")
        title = None
        content = ""

        for part in parts:
            if len(part) == 0:
                continue
            
            if part.startswith("[ch]"):
                # chords
                part = part.replace("[ch]", "").replace("[/ch]", "").replace("[tab]", "").replace("[/tab]", "")
                content += part + "\n"

            elif part.startswith("[") and not part.startswith("[tab]"):
                start = 1
                end = part.find("]")

                if end == -1:
                    brackets = part[start:]
                else:
                    brackets = part[start:end]
                
                if brackets == "tab":
                    content += "\n"
                else:
                    if title is not None and content != "":
                        sections.append({
                            "title": title,
                            "content": clean_content(content),
                            "id": str(uuid.uuid4())
                        })
                        content = ""
                    title = brackets

            else:
                part = part.replace("[ch]", "").replace("[/ch]", "").replace("[tab]", "").replace("[/tab]", "")
                content += part + "\n"

        if title is not None and content is not None:
            sections.append({
                "title": title,
                "content": clean_content(content),
                "id": str(uuid.uuid4())
            })

    tabs_type = None
    title = tab['song_name']
    artist = tab['artist_name']
    rating = tab['rating']
    id = tab['id']

    if "type_name" in tab:
        tabs_type = tab['type_name']

    song = {
        "type": tabs_type,
        "title": title,
        "artist": artist,
        "rating": rating,
        "capo": capo,
        "tuning": tuning,
        "sections": sections,
        "label": "UG"
    }
    print(json.dumps(song))
    return Note(title=title, artist=artist, capo=capo, tuning=tuning, sections=sections, label='ultimate guitar', starred=False, id=str(id))