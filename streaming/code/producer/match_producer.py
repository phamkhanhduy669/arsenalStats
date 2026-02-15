import requests, os, json, logging
import time as time_module
from dotenv import load_dotenv
from datetime import datetime, timezone
from typing import Dict, Any, List
from kafka import KafkaProducer
from arsPRJ.utils.db_connection import WarehouseConnection
from arsPRJ.utils.db_config import get_db_config

load_dotenv()

RAPIDAPI_KEY = os.getenv('RAPIDAPI_KEY')
team_id = 42 # Arsenal's team ID in SofaScore

def utc_to_datetime(utc_timestamp: int) -> str:
    dt = datetime.fromtimestamp(utc_timestamp, tz=timezone.utc)
    return dt.astimezone()

def get_next_match() -> Dict[str, Any]:
    url = f"https://sofascore.p.rapidapi.com/teams/get-next-matches?teamId={team_id}&pageIndex=0"
    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": "sofascore.p.rapidapi.com"
    }
    
    response = requests.get(url, headers=headers)
    return response.json().get('events', [])[0]

def format_next_match_data(match: dict) -> dict:
    return {
        'league': match.get('season', {}).get('name'),
        'round': match.get('roundInfo', {}).get('round'),
        'home_team': match.get('homeTeam', {}).get('name'),
        'away_team': match.get('awayTeam', {}).get('name'),
        'start_timestamp': match.get('startTimestamp'),
        'start_time': utc_to_datetime(match.get('startTimestamp')),
        'match_id': match.get('id'),
        'status': 'notstarted'
    }
    
    
def insert_match_data_to_db(status: str = 'notstarted', **match: dict)-> str:
    insert_query = """
    INSERT INTO arsenal_stats.match (league, round, home_team, away_team, start_timestamp, start_time, match_id, status) 
    VALUES (%(league)s, %(round)s, %(home_team)s, %(away_team)s, %(start_timestamp)s, %(start_time)s, %(match_id)s, %(status)s)
    ON CONFLICT(match_id) DO NOTHING;
    """
    db_config = get_db_config()
    with WarehouseConnection(db_config).managed_cursor() as cursor:
        cursor.execute(insert_query, {**match, 'status': status})
    
def update_match_status_in_db(match_id: int, status: str) -> None:
    query = """
    UPDATE arsenal_stats.match
    SET status = %(status)s
    WHERE match_id = %(match_id)s;
    """
    try:
        with WarehouseConnection(get_db_config()).managed_cursor() as cursor:
            cursor.execute(query, {'match_id': match_id, 'status': status})
            if cursor.rowcount == 0:
                logging.warning(f"Match ID {match_id} not found in DB for status update.")
    except Exception as e:
        logging.error(f"Failed to update match status: {e}")
        

def check_live_match(team_id: int) -> Dict[str, Any]:
    url = f"https://sofascore.p.rapidapi.com/tournaments/get-live-events?sport=football"
    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": "sofascore.p.rapidapi.com"
    }
    try:
        response = requests.get(url, headers=headers)
        datas = response.json().get('events', [])
        for data in datas :
            homeTeam_id = data.get('homeTeam', {}).get('id')
            awayTeam_id = data.get('awayTeam', {}).get('id')
            if homeTeam_id == team_id or awayTeam_id == team_id:
                return data
        time_module.sleep(15)
    except Exception as e:
        logging.error(f"Failed to fetch live match data: {e}")
        time_module.sleep(15)
    return None

def get_kafka_producer() -> KafkaProducer:
    producer = None
    while not producer:
        try:
            producer = KafkaProducer(
                bootstrap_servers='kafka:9092',
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            logging.info("Kafka producer connected successfully.")
        except Exception as e:
            logging.error(f"Failed to connect to Kafka: {e}. Retrying in 5 seconds...")
            time_module.sleep(5)
    return producer

def match_details(match_id: int) -> dict:
    url = f"https://sofascore.p.rapidapi.com/matches/detail?matchId={match_id}"
    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": "sofascore.p.rapidapi.com"
    }
    try:
        response = requests.get(url, headers=headers)
        data = response.json()
        time_module.sleep(5)
        return {
            'match_id': match_id,
            'status': data.get('event', {}).get('status', {}).get('type'),
            'start_time': data.get('event', {}).get('startTimestamp'),
            'current_period_start': data.get('event', {}).get('currentPeriodStartTimestamp'),
            'home_score' : data.get('event', {}).get('homeScore', {}).get('current'),
            'away_score' : data.get('event', {}).get('awayScore', {}).get('current')
        }
    except Exception as e:
        logging.error(f"Failed to fetch match end data: {e}")
        time_module.sleep(5)
        
def prase_match_statistics(statistics: list[dict], details : dict) -> dict:
    parse_data = details
    
    if not statistics or len(statistics) < 1:
        logging.warning("Statistics data is empty or incomplete.")
        return parse_data
    
    parse_data['home_yellowCards'] = 0
    parse_data['away_yellowCards'] = 0
    parse_data['home_redCards'] = 0
    parse_data['away_redCards'] = 0
    
    for stat in statistics[0].get('statisticsItems', []):
        name = stat.get('key')
        home_value = stat.get('homeValue')
        away_value = stat.get('awayValue')
        parse_data[f'home_{name}'] = home_value
        parse_data[f'away_{name}'] = away_value
    
    if len(statistics) > 1:
        shotOnTarget_data = statistics[1].get('statisticsItems', [])
        if len(shotOnTarget_data) > 1:
            name = shotOnTarget_data[1].get('key')
            home_value = shotOnTarget_data[1].get('homeValue')
            away_value = shotOnTarget_data[1].get('awayValue')
            parse_data[f'home_{name}'] = home_value
            parse_data[f'away_{name}'] = away_value
    return parse_data

def stream_macth(producer: KafkaProducer, match_id: int)-> None:
    logging.info(f"Starting to stream match data for match ID: {match_id}")
    while True:
        url = f"https://sofascore.p.rapidapi.com/matches/get-statistics?matchId={match_id}"
        headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": "sofascore.p.rapidapi.com"
        }
        try:
            response = requests.get(url, headers=headers)
            data = response.json().get('statistics', [])[0].get('groups', [])
            details = match_details(match_id)
            parsed_data = prase_match_statistics(data, details)
            producer.send('arsenal_live_match', value=parsed_data)
            producer.flush()
            logging.info(f"Sent match statistics to Kafka for match ID: {match_id}")
            if details.get('status') == 'finished':
                logging.info(f"Match ID: {match_id} has finished. Stopping stream.")
                update_match_status_in_db(match_id, 'finished')
                break
            time_module.sleep(10)  # Sleep for 10 seconds
        except Exception as e:
            logging.error(f"Failed to fetch match statistics: {e}")
            time_module.sleep(30)  # Sleep for 30
       
   
def main():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    producer = get_kafka_producer()
    team_id = 42 # Arsenal's team ID in SofaScore
    while True:
        live_match = check_live_match(team_id)
        if live_match:
            match_id = live_match.get('id')
            logging.info(f"Live match found with ID: {match_id}. Starting to stream data.")
            try:
                match_data = format_next_match_data(live_match)
                match_data['status'] = 'inprogress'
                insert_match_data_to_db(**match_data)
                logging.info(f"Match {match_id} inserted/updated in DB with status 'inprogress'")
            except Exception as e:
                logging.error(f"Could not insert/update match data: {e}")
            stream_macth(producer, match_id)
            continue
        next_match = format_next_match_data(get_next_match())
        if next_match:
            insert_match_data_to_db(**next_match)
            logging.info(f"Next match data inserted into DB: {next_match}")
            match_id = next_match.get('match_id')
            start_time = next_match.get('start_time')
            now = datetime.now().astimezone()
            wait_second = (start_time - now).total_seconds()
            wait_second -= 600
            
            if wait_second > 0:
                logging.info(f"Waiting for {wait_second} seconds until streaming starts for match ID: {match_id}")
                time_module.sleep(wait_second)
                logging.info(f"Preparing to stream data for match ID: {match_id}")
            else:
                logging.info(f"Match ID: {match_id} is starting soon or already started. Starting to stream immediately.")
                time_module.sleep(60)
        else:
            logging.error("No upcoming match found")
            time_module.sleep(7200)

if __name__ == "__main__":
    main()