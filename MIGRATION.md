  ### Unraid: Migrate from docker-compose

  **⚠️ Pre-read all these steps before doing anying, if you are confused open an issue.**

  When using the official Immich docker-compose, the PostgreSQL data is stored in a docker volume which _should_ be located at `/var/lib/docker/volumes/pgdata/_data`. Before preceeding you **must** stop the docker-compose stack.

  #### 1. Move the database

  To move the PostgreSQL data to the unraid array run:

  ```bash
  mv /var/lib/docker/volumes/pgdata/_data /mnt/user/appdata/postgres14
  ```

  Install `postgresql14` from the Unraid CA and remove these variables from the template: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`.
  The database is already initialised and these variables don't do anything.
  Also set `Database Storage Path` to `/mnt/user/appdata/postgres14`.

  #### 2. Move the uploads

  In the docker-compose .env you would have set the `UPLOAD_LOCATION`, copy that down and use it below:

  **⚠️ Note that Immich created the `uploads` folder within the `UPLOAD_LOCATION`.**

  ```bash
  mv <upload_location>/uploads /mnt/user/<elsewhere>
  ```

  #### 3. Setup the `imagegenius/immich` container

  Search the unraid CA for `immich`

  **⚠️ You must configure the template to the values listed in the docker-compose .env**

  Ensure that the template matches the `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME` from the .env. Set `Path: /photos` to `/mnt/user/<elsewhere>`.

  Click Apply, Open the WebUI and login. Everything _Should_ be as it was.
