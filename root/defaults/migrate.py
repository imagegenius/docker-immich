import psycopg2
import os

# Define connection parameters
host = os.environ.get('DB_HOSTNAME', '')
port = os.environ.get('DB_PORT', '5432')
username = os.environ.get('DB_USERNAME', '')
password = os.environ.get('DB_PASSWORD', '')
database = os.environ.get('DB_DATABASE_NAME', '')

# Connect to the database
try:
    with psycopg2.connect(
        host=host,
        port=port,
        user=username,
        password=password,
        dbname=database
    ) as conn:
        # Open a cursor to perform database operations
        with conn.cursor() as cur:
            # Check if assets table exists (if this is a new instance)
            cur.execute("SELECT EXISTS(SELECT * FROM information_schema.tables WHERE table_name='assets')")
            assets_table_exists = cur.fetchone()[0]

            if not assets_table_exists:
                exit(0)
                
            # Check if asset paths have already been changed (prevent running the migration a second time)
            sql = """
                SELECT "originalPath" FROM assets LIMIT 1;
            """

            # Execute the SQL query
            cur.execute(sql)

            # Fetch the first row of the result set
            result = cur.fetchone()

            # Check if the first value in the tuple starts with "/photos"
            if result[0].startswith('/photos'):
                exit(0)

            print("Attempting to automatically migrate the database...")
            # Define a SQL query to update the rows in the assets table
            sql = """
                UPDATE assets
                SET "originalPath" = REGEXP_REPLACE("originalPath", '^upload/', '/photos/'),
                    "resizePath" = REGEXP_REPLACE("resizePath", '^upload/', '/photos/'),
                    "webpPath" = REGEXP_REPLACE("webpPath", '^upload/', '/photos/'),
                    "encodedVideoPath" = REGEXP_REPLACE("encodedVideoPath", '^upload/', '/photos/')
                WHERE "originalPath" LIKE 'upload/%';
            """

            # Execute the SQL query
            cur.execute(sql)

            # Define a SQL query to update the rows in the users table
            sql = """
                UPDATE users
                SET "profileImagePath" = REGEXP_REPLACE("profileImagePath", '^upload/', '/photos/')
                WHERE "profileImagePath" LIKE 'upload/%';
            """

            # Execute the SQL query
            cur.execute(sql)

            # Commit the changes to the database
            conn.commit()
            print("Database migration successfully completed.")


except psycopg2.Error as e:
    print("Database update failed:", e)
    print("ERROR: Database migration failed!")
    exit(1)
