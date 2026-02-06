CREATE OR REPLACE FUNCTION arsenal_stats.update_updated_utc() RETURNS TRIGGER AS $$ BEGIN NEW.updated_utc = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER set_updated_utc BEFORE
UPDATE ON arsenal_stats.players FOR EACH ROW EXECUTE FUNCTION arsenal_stats.update_updated_utc();
CREATE TRIGGER set_updated_utc_coach BEFORE
UPDATE ON arsenal_stats.coach FOR EACH ROW EXECUTE FUNCTION arsenal_stats.update_updated_utc();