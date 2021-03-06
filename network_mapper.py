"""
Locate network services in an AWS environment and surface it to end users.
"""
import boto3
import logging
import os

from dataclasses import dataclass
from os import environ

logging.getLogger().setLevel(environ.get("LOG_LEVEL", "INFO"))


@dataclass(frozen=True)
class NetworkMapper:
    """Class to interact with networking services in AWS"""

    ec2_client: object = boto3.client("ec2")

    def describe_network_interfaces(self, filters=None):
        """
        Describe network interfaces in current AWS environment

        :param filters: List of filters to apply to the network interfaces
        :return: List of network interfaces
        """
        return self.ec2_client.describe_network_interfaces(Filters=filters if filters else None)["NetworkInterfaces"]

    def get_network_info(self, client_ip_address, request_url_path, pod_name, pod_namespace, app_name):
        """
        Get information about the network and the caller

        :param client_ip_address: IP address of the caller
        :param request_url_path: Requested URI
        :param pod_name: Name of the pod
        :param pod_namespace: Namespace of the pod
        :param app_name: Name of the app

        :return: Dictionary of discovered network information
        """
        network_info = {"optionals": {}}
        network_interface = self.describe_network_interfaces(
            [{"Name": "addresses.private-ip-address", "Values": [client_ip_address]}]
        )

        logging.info(f"Found {len(network_interface)} network interfaces")

        if len(network_interface):
            logging.info(f"Network Interface Info: {network_interface}")

            if network_interface[0]["InterfaceType"] == "interface":
                if "InstanceId" in network_interface[0]["Attachment"]:
                    network_info["optionals"]["INSTANCE ID"] = network_interface[0]["Attachment"]["InstanceId"]
                elif network_interface[0]["Description"].startswith("ELB app"):
                    network_info["optionals"]["LOADBALANCER TYPE"] = "ApplicationLoadBalancer"

            if network_interface[0]["InterfaceType"] == "network_load_balancer":
                network_info["optionals"]["LOADBALANCER TYPE"] = "NetworkLoadBalancer"

            network_info["optionals"]["INTERFACE TYPE"] = network_interface[0]["InterfaceType"]
            if "Description" in network_interface[0]:
                network_info["optionals"]["INTERFACE DESCRIPTION"] = network_interface[0]["Description"]

        network_info["client_ip_address"] = client_ip_address
        network_info["pod_name"] = pod_name
        network_info["pod_namespace"] = pod_namespace
        network_info["app_name"] = app_name
        network_info["requested_uri"] = request_url_path

        # Get Instance ID and Availability Zone from EC2 Instance Metadata
        network_info["availability_zone"] = os.popen(
            f"curl -v http://169.254.169.254/latest/meta-data/placement/availability-zone"
        ).read()
        network_info["instance_id"] = os.popen(f"curl -v http://169.254.169.254/latest/meta-data/instance-id").read()

        return network_info
