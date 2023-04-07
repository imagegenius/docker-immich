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
    conn = psycopg2.connect(
        host=host,
        port=port,
        user=username,
        password=password,
        dbname=database
    )

    # Open a cursor to perform database operations
    cur = conn.cursor()

    # Define a SQL query to update the rows in the assets table
    sql = "UPDATE assets SET \"originalPath\" = REPLACE(\"originalPath\", 'upload/', '/photos/'), \"resizePath\" = REPLACE(\"resizePath\", 'upload/', '/photos/'), \"webpPath\" = REPLACE(\"webpPath\", 'upload/', '/photos/'), \"encodedVideoPath\" = REPLACE(\"encodedVideoPath\", 'upload/', '/photos/') WHERE \"originalPath\" LIKE 'upload/%';"

    # Execute the SQL query
    cur.execute(sql)

    # Commit the changes to the database
    conn.commit()

    # Close the cursor and database connection
    cur.close()
    conn.close()


except psycopg2.Error as e:
    print("Database update failed:", e)
    exit(1)
