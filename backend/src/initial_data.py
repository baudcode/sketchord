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
        "https://tabs.ultimate-guitar.com/tab/passenger/new-until-its-old-chords-2621235",
        "https://tabs.ultimate-guitar.com/tab/ben-howard/keep-your-head-up-chords-1180866",
        "https://tabs.ultimate-guitar.com/tab/john-mayer/slow-dancing-in-a-burning-room-chords-706621",
        "https://tabs.ultimate-guitar.com/tab/fleetwood-mac/landslide-chords-1729327",
        "https://tabs.ultimate-guitar.com/tab/fleetwood-mac/go-your-own-way-chords-13586",
        "https://tabs.ultimate-guitar.com/tab/green-day/boulevard-of-broken-dreams-chords-146744",
        "https://tabs.ultimate-guitar.com/tab/mumford-sons/guiding-light-chords-2475920",
        "https://tabs.ultimate-guitar.com/tab/abba/mamma-mia-chords-709013",
        "https://tabs.ultimate-guitar.com/tab/sons-of-the-east/into-the-sun-chords-1994861",
        "https://tabs.ultimate-guitar.com/tab/passenger/lifes-for-the-living-chords-1196622"
    ];
    parser =argparse.ArgumentParser()
    parser.add_argument('-o', '--output', default='../assets/initial_data.json')
    parser.add_argument('-u', '--urls', default=urls, type=list_type)
    args = parser.parse_args()

    print(args.urls, args.output)

    dump_notes(args.urls, args.output)
