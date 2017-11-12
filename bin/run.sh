# docker run -d --env-file ./.env --name email-backend mail-script
docker run -p 80:80 --env-file ./.env --name email-backend mail-script