import sqlalchemy as sa
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.sql.expression import FunctionElement

# =============================================================================
# 1. CROSS-WAREHOUSE DIALECT ABSTRACTIONS
# =============================================================================


class date_add(FunctionElement):
    name = "date_add"
    inherit_cache = False


@compiles(date_add, "snowflake")
def compile_date_add_sf(element, compiler, **kw):
    date_part, interval, date_expr = list(element.clauses)
    # Compile the date part and strip any quotes so it outputs as a keyword (e.g., day)
    dp = compiler.process(date_part, **kw).replace("'", "").lower()
    return f"DATEADD({dp}, {compiler.process(interval, **kw)}, {compiler.process(date_expr, **kw)})"


@compiles(date_add, "bigquery")
def compile_date_add_bq(element, compiler, **kw):
    date_part, interval, date_expr = list(element.clauses)
    # Compile the date part and strip quotes (e.g., outputs as DAY)
    dp = compiler.process(date_part, **kw).replace("'", "").upper()
    return f"DATE_ADD({compiler.process(date_expr, **kw)}, INTERVAL {compiler.process(interval, **kw)} {dp})"


# =============================================================================
# 2. STANDALONE METRIC GENERATOR
# =============================================================================


class SegmentStandaloneMetricGenerator:
    def __init__(self, table_name: str = "tracks", schema: str = "segment_events"):
        self.metadata = sa.MetaData()
        self.tracks = sa.Table(
            table_name,
            self.metadata,
            sa.Column("id", sa.String),
            sa.Column("user_id", sa.String),
            sa.Column("context_group_id", sa.String),
            sa.Column("event", sa.String),
            sa.Column("timestamp", sa.DateTime),
            schema=schema,
        )

        # --- THE METRIC REGISTRY ---
        # Maps string names to: (Lookback Days, SQLAlchemy Expression Lambda)
        self.metrics = {
            "dau": (
                0,
                lambda da, spine: sa.func.count(
                    sa.distinct(
                        sa.case(
                            (da.c.activity_date == spine.c.metric_date, da.c.user_id)
                        )
                    )
                ),
            ),
            "wau": (
                7,
                lambda da, spine: sa.func.count(
                    sa.distinct(
                        sa.case(
                            (
                                da.c.activity_date
                                > date_add(
                                    sa.literal_column("'day'"), -7, spine.c.metric_date
                                ),
                                da.c.user_id,
                            )
                        )
                    )
                ),
            ),
            "mau": (
                30,
                lambda da, spine: sa.func.count(
                    sa.distinct(
                        sa.case(
                            (
                                da.c.activity_date
                                > date_add(
                                    sa.literal_column("'day'"), -30, spine.c.metric_date
                                ),
                                da.c.user_id,
                            )
                        )
                    )
                ),
            ),
            "n_events_daily": (
                0,
                lambda da, spine: sa.func.sum(
                    sa.case(
                        (da.c.activity_date == spine.c.metric_date, da.c.n_events),
                        else_=0,
                    )
                ),
            ),
            "active_days_7d": (
                7,
                lambda da, spine: sa.func.count(
                    sa.distinct(
                        sa.case(
                            (
                                da.c.activity_date
                                > date_add(
                                    sa.literal_column("'day'"), -7, spine.c.metric_date
                                ),
                                da.c.activity_date,
                            )
                        )
                    )
                ),
            ),
        }

    def _get_base_ctes(self):
        """Generates the foundational CTEs needed by all time-series metrics."""
        # 1. Cleaned Tracks
        stg_tracks = (
            sa.select(
                self.tracks.c.user_id,
                self.tracks.c.context_group_id.label("account_id"),
                self.tracks.c.timestamp.label("event_at"),
            )
            .where(self.tracks.c.context_group_id.isnot(None))
            .cte("stg_tracks")
        )

        # 2. Dim Accounts (First Seen Date)
        dim_accounts = (
            sa.select(
                stg_tracks.c.account_id,
                sa.func.min(stg_tracks.c.event_at).label("first_seen_at"),
            )
            .group_by(stg_tracks.c.account_id)
            .cte("dim_accounts")
        )

        # 3. Recursive Date Spine
        base_date = sa.select(
            sa.cast(sa.literal("2026-01-01"), sa.Date).label("date_day")
        ).cte("date_spine", recursive=True)
        recursive_term = sa.select(
            sa.cast(
                date_add(sa.literal_column("'day'"), 1, base_date.c.date_day), sa.Date
            )
        ).where(base_date.c.date_day < sa.func.current_date())
        date_spine = base_date.union_all(recursive_term)

        # 4. Account Spine (Dates bounded by account lifespan)
        account_spine = (
            sa.select(
                date_spine.c.date_day.label("metric_date"), dim_accounts.c.account_id
            )
            .select_from(
                date_spine.join(
                    dim_accounts,
                    date_spine.c.date_day
                    >= sa.cast(dim_accounts.c.first_seen_at, sa.Date),
                )
            )
            .cte("account_spine")
        )

        # 5. Pre-aggregated Daily Activity
        daily_activity = (
            sa.select(
                sa.cast(stg_tracks.c.event_at, sa.Date).label("activity_date"),
                stg_tracks.c.account_id,
                stg_tracks.c.user_id,
                sa.func.count().label("n_events"),
            )
            .group_by(
                sa.cast(stg_tracks.c.event_at, sa.Date),
                stg_tracks.c.account_id,
                stg_tracks.c.user_id,
            )
            .cte("daily_activity")
        )

        return account_spine, daily_activity

    def generate_sql(self, metric_name: str, dialect_name: str) -> str:
        """Dynamically generates the SQL for a single specific metric."""
        if metric_name not in self.metrics:
            raise ValueError(
                f"Metric '{metric_name}' is not in the registry. Available metrics: {list(self.metrics.keys())}"
            )

        lookback_days, expr_lambda = self.metrics[metric_name]
        account_spine, daily_activity = self._get_base_ctes()

        # Build dynamic JOIN conditions to heavily optimize the query
        # We ONLY join the days required for this specific metric
        join_conditions = [daily_activity.c.account_id == account_spine.c.account_id]

        if lookback_days == 0:
            join_conditions.append(
                daily_activity.c.activity_date == account_spine.c.metric_date
            )
        else:
            join_conditions.extend(
                [
                    daily_activity.c.activity_date
                    > date_add(
                        sa.literal_column("'day'"),
                        -lookback_days,
                        account_spine.c.metric_date,
                    ),
                    daily_activity.c.activity_date <= account_spine.c.metric_date,
                ]
            )

        # Construct final query
        query = (
            sa.select(
                account_spine.c.metric_date,
                account_spine.c.account_id,
                expr_lambda(daily_activity, account_spine).label(metric_name),
            )
            .select_from(
                account_spine.outerjoin(daily_activity, sa.and_(*join_conditions))
            )
            .group_by(account_spine.c.metric_date, account_spine.c.account_id)
        )

        # Load appropriate dialect compiler
        if dialect_name.lower() == "bigquery":
            from sqlalchemy_bigquery import BigQueryDialect

            dialect = BigQueryDialect()
        elif dialect_name.lower() == "snowflake":
            from snowflake.sqlalchemy.snowdialect import SnowflakeDialect

            dialect = SnowflakeDialect()
        else:
            raise ValueError("Dialect must be 'snowflake' or 'bigquery'")

        return str(
            query.compile(dialect=dialect, compile_kwargs={"literal_binds": True})
        )


# =============================================================================
# 3. USAGE
# =============================================================================

if __name__ == "__main__":
    generator = SegmentStandaloneMetricGenerator(
        table_name="tracks", schema="segment_prod"
    )

    dialects = ["bigquery", "snowflake"]

    for dialect in dialects:
        for metric in generator.metrics:
            print(f"--- GENERATING {dialect.upper()} SQL FOR {metric.upper()} ---")
            sql = generator.generate_sql(metric_name=metric, dialect_name=dialect)
            print(sql)
            print("\n")
