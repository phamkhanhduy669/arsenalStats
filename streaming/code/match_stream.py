from dataclasses import asdict, dataclass, field
from typing import List, Tuple

from jinja2 import Environment, FileSystemLoader
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment
from dotenv import load_dotenv
import os
from typing import Any

load_dotenv()

REQUIRED_JARS = [
    "file:///opt/flink/flink-sql-connector-kafka-1.17.0.jar",
    "file:///opt/flink/flink-connector-jdbc-3.0.0-1.16.jar",
    "file:///opt/flink/postgresql-42.6.0.jar",
]

@dataclass(frozen = True)
class StreamConfig:
    job_name : str = 'MatchStreamJob'
    jars : List[str] = field(default_factory=lambda: REQUIRED_JARS)
    checkpoint_interval : int = 10
    checkpoint_pause : int = 5
    checkpoint_timeout : int = 20
    parallelism : int = 5
    
@dataclass(frozen=True)
class KafkaConfig:
    bootstrap_servers : str = 'kafka:9092'
    topic : str = 'arsenal_live_match'
    connector : str = 'kafka'
    scan_startup_mode : str = 'latest-offset'
    consumer_group_id : str = 'arsenal-flink-group'
    
@dataclass(frozen=True)
class DatabaseConfig:
    driver : str = 'org.postgresql.Driver'
    url : str = 'jdbc:postgresql://postgres:5432/arsenal_db'
    username : str = 'postgres'
    password : str = 'postgres'
    
@dataclass(frozen=True)
class MatchLiveConfig(KafkaConfig):
    topic : str = 'arsenal_live_match'
    format : str = 'json'
    
@dataclass(frozen=True)
class MatchTableConfig(DatabaseConfig):
    table_name : str = 'arsenal_live_match'
    
@dataclass(frozen=True)
class MatchEventsTableConfig(DatabaseConfig):
    table_name : str = 'live_match_events'    
        
def get_execution_environment(config: StreamConfig) -> Tuple[StreamExecutionEnvironment, StreamTableEnvironment]:
    s_env = StreamExecutionEnvironment.get_execution_environment()
    for jar in config.jars:
        s_env.add_jars(jar)
        
    s_env.enable_checkpointing(config.checkpoint_interval * 1000)
    s_env.get_checkpoint_config().set_min_pause_between_checkpoints(config.checkpoint_pause * 1000)
    s_env.get_checkpoint_config().set_checkpoint_timeout(config.checkpoint_timeout * 1000)
    
    execution_config = s_env.get_config()
    execution_config.set_parallelism(config.parallelism)
    
    t_env = StreamTableEnvironment.create(s_env)
    job_config = t_env.get_config().get_configuration()
    job_config.set_string("pipeline.name", config.job_name)
    return s_env, t_env
    
def get_sql_query(entity:str, type:str = 'source',
                  template_env = Environment(loader=FileSystemLoader('code/'))) -> str:
    template = template_env.get_template(f'{type}/{entity}.sql')
    
    config_map = {
        'arsenal_live_match': MatchLiveConfig(),
        'live_match_events': MatchEventsTableConfig(),
        'match_logic': MatchTableConfig()
    }
    
    return template.render(asdict(config_map.get(entity)))

def run_match_stream(t_env : StreamTableEnvironment,get_sql_query = get_sql_query) -> None: 
    t_env.execute_sql(get_sql_query('arsenal_live_match', 'source'))
    t_env.execute_sql(get_sql_query('live_match_events', 'sink'))
    stmt_set = t_env.create_statement_set()
    stmt_set.add_insert_sql(get_sql_query('match_logic', 'process'))
    checkout_job = stmt_set.execute()
    print (f'Job Result: {checkout_job.get_job_client().get().get_job_status().to_string()}')   
    
    
if __name__ == '__main__':
    _, t_env = get_execution_environment(StreamConfig())
    run_match_stream(t_env)