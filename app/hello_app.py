"""En liten webbapp som deployas till AKS för att visa att klustret fungerar.

Appen har två adresser:
  /        svarar med en hälsning och namnet på podden som svarade.
  /health  används av Kubernetes och av smoke-testet för att se att appen lever.
"""

import socket

from flask import Flask, jsonify

# Texten som visas på startsidan. Smoke-testet letar inte efter den,
# så den kan ändras fritt.
GREETING = "Hello from AKS"

# Svaret från /health. Kubernetes bryr sig bara om statuskoden (200),
# men smoke-testet kontrollerar även att texten stämmer.
HEALTHY_STATUS = "ok"


def index():
    """Svara med en hälsning och poddens namn.

    Poddens namn (hostname) gör det lätt att se vilken pod som svarade
    när flera kopior av appen körs samtidigt.
    """
    return jsonify(message=GREETING, hostname=socket.gethostname())


def health():
    """Svara att appen lever. Används av Kubernetes och smoke-testet."""
    return jsonify(status=HEALTHY_STATUS)


def create_app():
    """Skapa och returnera Flask-appen.

    Appen skapas i en funktion i stället för på modulnivå, så att testerna
    kan få en ny, ren app för varje test.
    """
    app = Flask(__name__)
    app.add_url_rule("/", view_func=index)
    app.add_url_rule("/health", view_func=health)
    return app
