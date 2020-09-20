import argparse
from typing import List
from .ultimate import get_note
import json

def dump_notes(urls: List[str], output_path: str):

    notes = []

    for url in urls:
        note = get_note(url)
        notes.append(note.dict())
    
    print("dumping %d notes to %s"  % (len(notes), output_path))
    with open(output_path, 'w') as w:
        json.dump(notes, w)

if __name__ == "__main__":


    def list_type(s: str) -> List[str]:
        return s.split(",")

    urls = [
        "https://tabs.ultimate-guitar.com/tab/passenger/new-until-its-old-chords-2621235"
    ];
    parser =argparse.ArgumentParser()
    parser.add_argument('-o', '--output', default='../assets/initial_data.json')
    parser.add_argument('-u', '--urls', default=urls, type=list_type)
    args = parser.parse_args()

    print(args.urls, args.output)

    dump_notes(args.urls, args.output)
