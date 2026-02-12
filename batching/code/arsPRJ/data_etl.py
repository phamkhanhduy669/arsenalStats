import requests
import logging
from typing import List, Dict, Any, Optional
from arsPRJ.utils.db_connection import WarehouseConnection
from arsPRJ.utils.db_config import get_db_config
import os
from dotenv import load_dotenv

def fallent_squad_data(members: Dict[str, Any], squad_title: str) -> Dict[str, Any]:
    if squad_title == 'coach':
        coach = {
            'title' : squad_title,
            'id': members.get('id'),
            'height': members.get('height'),
            'age': members.get('age'),
            'dateOfBirth': members.get('dateOfBirth'),
            'name': members.get('name'),
            'ccode': members.get('ccode'),
            'cname': members.get('cname')
        }
        return coach
    else:
        player = {
            'title' : squad_title,
            'id': members.get('id'),
            'height': members.get('height'),
            'age': members.get('age'),
            'dateOfBirth': members.get('dateOfBirth'),
            'name': members.get('name'),
            'shirtNumber': members.get('shirtNumber'),
            'position': members.get('positionIdsDesc', ''),
            'ccode': members.get('ccode'),
            'cname': members.get('cname'),
            'injury': members.get('injured','False'),
            'rating': members.get('rating', 0.0),
            'goals': members.get('goals', 0),
            'penalties': members.get('penalties', 0),
            'assists': members.get('assists', 0),
            'rcards': members.get('rcards', 0),
            'ycards': members.get('ycards', 0),
            'transferValue': members.get('transferValue', 0)
        }
        return player

def parse_players_data(squad_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    parsed_data = []
    for member in squad_data:
        title = member.get('title', '').lower()
        member_data = fallent_squad_data(member.get('members')[0], title)
        parsed_data.append(member_data)
    return parsed_data

def get_squad_data() -> Dict[str, Any]:
    load_dotenv()
    url = f"https://free-api-live-football-data.p.rapidapi.com/football-get-list-player?teamid=9825"
    headers = {
        "x-rapidapi-key": (os.getenv('RAPIDAPI_KEY', '')),
        "x-rapidapi-host": "free-api-live-football-data.p.rapidapi.com"
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        squad_data = response.json().get('response', {}).get('list', {}).get('squad', {})
        print(squad_data)
        return squad_data
    except requests.RequestException as e:
        logging.error(f"Error fetching squad data: {e}")
        return {}
    
def get_insert_players_query() -> str:
    return """
    INSERT INTO arsenal_stats.players (
       id, name, role, shirtNumber, age, dateOfBirth, cnation, nation, position, height_cm, rating, 
       injury, goals, penalties, assists, rcards, ycards, transferValue
    ) VALUES (
         %(id)s, %(name)s, %(title)s, %(shirtNumber)s, %(age)s, %(dateOfBirth)s, %(ccode)s, 
         %(cname)s, %(position)s, %(height)s, %(rating)s, %(injury)s, %(goals)s, 
         %(penalties)s, %(assists)s, %(rcards)s, %(ycards)s, %(transferValue)s
    )
    ON CONFLICT (id) DO UPDATE SET
        rating = EXCLUDED.rating,
        penalties = EXCLUDED.penalties,
        age = EXCLUDED.age,
        shirtNumber = EXCLUDED.shirtNumber,
        position = EXCLUDED.position,
        height_cm = EXCLUDED.height_cm,
        injury = EXCLUDED.injury,
        goals = EXCLUDED.goals,
        assists = EXCLUDED.assists,
        ycards = EXCLUDED.ycards,
        rcards = EXCLUDED.rcards,
        transferValue = EXCLUDED.transferValue;
    """
    
def get_insert_coach_query() -> str:
    return """
    INSERT INTO arsenal_stats.coach (
        id, name, role, age, dateOfBirth, cnation, nation, height_cm
    ) VALUES (
        %(id)s, %(name)s, %(title)s, %(age)s, %(dateOfBirth)s, %(ccode)s, 
        %(cname)s, %(height)s
    )
    ON CONFLICT (id) DO UPDATE SET
        age = EXCLUDED.age,
        dateOfBirth = EXCLUDED.dateOfBirth,
        height_cm = EXCLUDED.height_cm;
    """
    
def run() -> None:
    squad_data = get_squad_data()
    parsed_data = parse_players_data(squad_data)
    
    db_config = get_db_config()
    with WarehouseConnection(db_config).managed_cursor() as cursor:
        for member in parsed_data:
            if member['title'] == 'coach':
                cursor.execute(get_insert_coach_query(), member)
            else:
                cursor.execute(get_insert_players_query(), member)
    
    print("Data ETL process completed successfully.")
                
if __name__ == "__main__":
    run()