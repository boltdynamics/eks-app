"""
Entrypoint for the application.
"""
from os import environ

from flask import Flask, render_template, request
from flask_bootstrap import Bootstrap

from network_mapper import NetworkMapper

app = Flask(__name__)
Bootstrap(app)


@app.route("/")
def eks_app():
    """
    Run Flask app
    """
    # Initialize the network mapper class
    init_networkz = NetworkMapper()

    # Get caller's IP address
    client_ip_address = request.remote_addr
    # Get caller requested URI
    request_url_path = request.path

    # Kubernetes specific environment variables
    pod_name = environ.get("POD_NAME", None)
    pod_namespace = environ.get("POD_NAMESPACE", None)
    app_name = environ.get("APP_NAME", None)

    # Get network interace information
    network_interface_info = init_networkz.get_network_info(
        client_ip_address, request_url_path, pod_name, pod_namespace, app_name
    )

    return render_template("index.html", network_interface_info=network_interface_info)
