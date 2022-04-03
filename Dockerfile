FROM python:alpine3.15

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip3 install -r requirements.txt

RUN apk add curl

COPY static/ /app/static/

COPY templates/ /app/templates/

COPY network_mapper.py app.py .

USER 1001

EXPOSE 5000

CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0"]
